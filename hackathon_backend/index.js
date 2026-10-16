import express from 'express';
import { bitnob } from './bitnob.js';
import dns from 'node:dns';
import crypto from 'node:crypto';

// Forcer IPv4 pour la connectivité réseau sous Windows
dns.setDefaultResultOrder('ipv4first');

const app = express();
const port = process.env.PORT || 5000;

// Parser JSON et conservation du corps brut pour vérification HMAC
app.use(express.json({
  type: (req) => (req.headers['content-type'] || '').includes('json'),
  verify: (req, res, buf) => { req.rawBody = buf.toString(); }
}));

// Configuration CORS pour Flutter (Web et Mobile)
app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, x-signature, x-bitnob-signature');
  if (req.method === 'OPTIONS') return res.sendStatus(200);
  next();
});

// Suivi local des factures et preimages
const invoices = new Map();

// === ROUTE DE SANTÉ (HEALTHCHECK RÉEL) ===
app.get('/health', (req, res) => {
  res.json({
    status: 'OK',
    server: 'Express Node.js',
    port: port,
    uptimeSeconds: Math.floor(process.uptime()),
    timestamp: new Date().toISOString()
  });
});

// === ROUTE WALLET & TRANSACTIONS 100% RÉELLES DEPUIS BITNOB ===
app.get('/wallet', async (req, res) => {
  try {
    const bitnobRes = await bitnob('GET', '/api/lightning/invoices');
    const rawInvoices = bitnobRes.data?.invoices || [];

    let totalPaidSats = 0;
    const transactions = rawInvoices.map((inv) => {
      const isPaid = inv.status === 'paid';
      const sats = Number(inv.amount_sat || 0);
      if (isPaid) {
        totalPaidSats += sats;
      }

      // Récupérer la preimage enregistrée en mémoire si disponible
      const localInvoice = invoices.get(inv.reference);
      const preimage = inv.preimage || localInvoice?.preimage || null;

      return {
        id: inv.id,
        reference: inv.reference || 'N/A',
        title: inv.description || 'Paiement Lightning',
        category: 'Encaissement Marchand POS',
        amountSats: sats,
        amountFcfa: Math.round(sats * 0.65),
        isCredit: true,
        date: inv.created_at || new Date().toISOString(),
        status: isPaid ? 'Confirmé ⚡' : (inv.status === 'expired' ? 'Expiré' : 'En attente'),
        preimage: preimage,
        request: inv.request
      };
    });

    res.json({
      success: true,
      balanceSats: totalPaidSats,
      balanceFcfa: Math.round(totalPaidSats * 0.65),
      btcPriceFcfa: 64850000,
      totalInvoices: rawInvoices.length,
      paidInvoicesCount: rawInvoices.filter(i => i.status === 'paid').length,
      transactions: transactions
    });
  } catch (err) {
    console.error('Erreur /wallet:', err);
    res.status(500).json({ error: 'Impossible de récupérer les données réelles de Bitnob' });
  }
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
    
    // Appel officiel à l'API Bitnob Lightning
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
      amount: Number(amount),
      description: description || 'Paiement Lightning',
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

  // Si pas encore payée, on interroge Bitnob pour vérifier le règlement
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
  const bitnobSignature =
    req.headers['x-signature'] ||
    req.headers['x-bitnob-signature'] ||
    req.headers['x-webhook-signature'];
  const webhookSecret = process.env.BITNOB_WEBHOOK_SECRET;

  if (!bitnobSignature) {
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
    return res.status(401).send('Signature invalide');
  }

  const eventName = req.body.event || (req.body.test ? 'test' : 'inconnu');
  if (eventName === 'lightning.invoice.paid') {
    const ref = req.body.data?.reference;
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
