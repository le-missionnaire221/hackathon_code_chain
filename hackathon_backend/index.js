import express from 'express';
import { bitnob } from './bitnob.js';
import dns from 'node:dns';
import crypto from 'node:crypto';

// Force Node.js à utiliser IPv4 (corrige les problèmes de timeout sous Windows avec certaines box)
dns.setDefaultResultOrder('ipv4first');

const app = express();
const port = process.env.PORT || 5000;

// 1. Parser JSON et copie brute (rawBody) pour la vérification HMAC des webhooks
app.use(express.json({
  type: (req) => (req.headers['content-type'] || '').includes('json'),
  verify: (req, res, buf) => { req.rawBody = buf.toString(); }
}));

// Configuration CORS pour permettre à l'application Flutter de communiquer avec l'API
app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, x-signature, x-bitnob-signature');
  if (req.method === 'OPTIONS') return res.sendStatus(200);
  next();
});

// Suivi en mémoire des factures
const invoices = new Map();

// Route de santé
app.get('/health', (req, res) => {
  res.send('OK');
});

// === CRÉATION D'UN CLIENT ===
app.post('/customer', async (req, res) => {
  const { email, firstName, lastName } = req.body;
  try {
    const bitnobResponse = await bitnob('POST', '/api/customers', {
      email,
      firstName,
      lastName,
      phone: "0000000000",
      countryCode: "+221",
      customer_type: "individual"
    });
    res.json(bitnobResponse);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "API fetch failed" });
  }
});

// === CRÉER UNE INVOICE LIGHTNING (AVEC RÈGLEMENT NÉGOCIÉ BITNOB) ===
app.post('/invoice', async (req, res) => {
  const { customerId, description, amount } = req.body;
  
  try {
    const reference = 'LTG_' + Date.now();
    
    // Endpoint officiel Bitnob Lightning (avec auto_settle pour le règlement Sandbox)
    const invoiceResponse = await bitnob('POST', '/api/lightning/invoices', {
      customer_id: customerId,
      amount: Number(amount),
      description: description || 'Paiement Lightning',
      expiry: 3600,
      reference: reference,
      auto_settle: true // Règlement automatique réel par le moteur de testnet Bitnob
    });

    if (invoiceResponse.status >= 400 || invoiceResponse.error || invoiceResponse.code) {
      console.error('Erreur Bitnob:', invoiceResponse);
      return res.status(invoiceResponse.status || 400).json({
        error: invoiceResponse.detail || invoiceResponse.message || "Erreur Bitnob",
        ...invoiceResponse
      });
    }

    const bitnobId = invoiceResponse.data?.id;

    // Enregistrer la facture pour le suivi du statut
    invoices.set(reference, {
      reference,
      bitnobId,
      amount,
      description,
      status: 'pending',
      createdAt: new Date().toISOString()
    });

    console.log(`⚡ Invoice créée : ${reference} (Bitnob ID: ${bitnobId})`);
    res.json({ ...invoiceResponse, reference });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "API fetch failed" });
  }
});

// === SUIVI DU STATUT DE L'INVOICE EN TEMPS RÉEL ===
app.get('/invoice/:reference/status', async (req, res) => {
  const invoice = invoices.get(req.params.reference);
  if (!invoice) {
    return res.status(404).json({ error: "Invoice non trouvée" });
  }

  // Si pas encore payée, on interroge Bitnob pour vérifier si la facture a été réglée
  if (invoice.status !== 'paid' && invoice.bitnobId) {
    try {
      const bitnobCheck = await bitnob('GET', `/api/lightning/invoices/${invoice.bitnobId}`);
      if (bitnobCheck.data?.status === 'paid') {
        invoice.status = 'paid';
        invoice.preimage = bitnobCheck.data.preimage;
        invoice.paidAt = bitnobCheck.data.updated_at || new Date().toISOString();
        invoices.set(req.params.reference, invoice);
        console.log(`✅ [BITNOB SETTLEMENT] L'invoice ${req.params.reference} a été RÉGLÉE ! Preimage: ${invoice.preimage}`);
      }
    } catch (e) {
      // Ignorer l'erreur réseau ponctuelle
    }
  }

  res.json(invoice);
});

// === RÉCEPTION DES WEBHOOKS DE BITNOB ===
app.post('/webhook', (req, res) => {
  console.log('\n📨 Appel reçu sur /webhook');
  console.log('Headers :', req.headers);
  console.log('Body    :', req.rawBody);

  const bitnobSignature =
    req.headers['x-signature'] ||
    req.headers['x-bitnob-signature'] ||
    req.headers['x-webhook-signature'];
  const webhookSecret = process.env.BITNOB_WEBHOOK_SECRET;

  if (!bitnobSignature) {
    console.log('⚠️ Webhook ignoré : aucune signature');
    return res.status(400).send('Signature manquante');
  }

  const algo = bitnobSignature.length === 64 ? 'sha256' : 'sha512';
  const mySignature = crypto
    .createHmac(algo, webhookSecret)
    .update(req.rawBody || '')
    .digest('hex');

  const a = Buffer.from(mySignature);
  const b = Buffer.from(bitnobSignature);
  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) {
    console.log('🛑 ALERTE : Signature invalide !');
    return res.status(401).send('Signature invalide');
  }

  console.log('\n🔔 Vrai Webhook reçu de Bitnob !');
  const eventName = req.body.event || (req.body.test ? 'test' : 'inconnu');
  console.log(`Événement : ${eventName}`);
  
  if (eventName === 'lightning.invoice.paid') {
    const ref = req.body.data?.reference;
    console.log(`✅ Webhook: L'invoice ${ref} a été payée !`);
    if (ref && invoices.has(ref)) {
      const current = invoices.get(ref);
      invoices.set(ref, {
        ...current,
        status: 'paid',
        paidAt: new Date().toISOString(),
        details: req.body.data
      });
    }
  }

  res.sendStatus(200);
});

// Lancer le serveur
app.listen(port, () => {
  console.log(`🚀 Serveur démarré et en écoute sur http://localhost:${port}`);
});
