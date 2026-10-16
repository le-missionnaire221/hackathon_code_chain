import express from 'express';
import { bitnob } from './bitnob.js';
import dns from 'node:dns';

// Force Node.js à utiliser IPv4 (corrige les problèmes de timeout sous Windows avec certaines box)
dns.setDefaultResultOrder('ipv4first');

const app = express();
const port = 3000;

// 1. On dit à Express d'accepter et de comprendre le format JSON
// Sans ça, les requêtes envoyées par Bitnob seront illisibles pour notre serveur.
// On garde aussi une copie "brute" (rawBody) : elle servira à vérifier la signature des webhooks.
// Bitnob envoie parfois l'en-tête "application/json, application/json" (dupliqué) :
// on accepte donc tout Content-Type qui contient "json".
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

// Suivi en mémoire des statuts des factures pour l'application mobile
const invoices = new Map();

// 2. On crée notre route de test (endpoint)
// app.get veut dire qu'on attend une requête de type GET à l'adresse /health
app.get('/health', (req, res) => {
  res.send('OK');
});

// === J-5 : CRÉATION D'UN CLIENT ===
app.post('/customer', async (req, res) => {
  const { email, firstName, lastName } = req.body;
  
  try {
    // 1. Appeler notre fonction bitnob pour créer le client
    const bitnobResponse = await bitnob('POST', '/api/customers', {
      email: email,
      firstName: firstName,
      lastName: lastName,
      phone: "0000000000",
      countryCode: "+221",
      customer_type: "individual"
    });

    // 2. Renvoyer la réponse au frontend
    res.json(bitnobResponse);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "API fetch failed" });
  }
});

// === J-5 : CRÉER UNE INVOICE LIGHTNING ===
app.post('/invoice', async (req, res) => {
  const { customerId, description, amount } = req.body;
  
  try {
    const reference = 'LTG_' + Date.now();
    
    // Endpoint officiel (doc Bitnob > Lightning > Create Invoice)
    const invoiceResponse = await bitnob('POST', '/api/lightning/invoices', {
      customer_id: customerId,          // optionnel : UUID du client Bitnob
      amount: amount,                   // en satoshis (1 à 20 000 000)
      description: description,         // obligatoire
      expiry: 3600,                     // l'invoice expire dans 1 heure
      reference: reference,             // référence unique de notre côté
    });

    // Mémoriser l'état initial pour l'app mobile
    invoices.set(reference, {
      reference,
      amount,
      description,
      status: 'pending',
      createdAt: new Date().toISOString()
    });

    // data.request = la chaîne BOLT11 (lntb...) à mettre dans le QR Code
    res.json({ ...invoiceResponse, reference });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "API fetch failed" });
  }
});

// Endpoint pour permettre à l'application Flutter de vérifier le statut de paiement
app.get('/invoice/:reference/status', (req, res) => {
  const invoice = invoices.get(req.params.reference);
  if (!invoice) {
    return res.status(404).json({ error: "Invoice non trouvée" });
  }
  res.json(invoice);
});

import crypto from 'node:crypto'; // Import nécessaire pour HMAC

// === J-4 : RECEVOIR LES WEBHOOKS DE BITNOB ===
// Bitnob appelle cette adresse quand quelque chose se passe (ex : une invoice est payée).
app.post('/webhook', (req, res) => {
  // 0. Diagnostic : on affiche TOUT appel reçu pour voir ce que Bitnob envoie vraiment
  console.log('\n📨 Appel reçu sur /webhook');
  console.log('Headers :', req.headers);
  console.log('Body    :', req.rawBody);

  // 1. Récupérer la signature envoyée par Bitnob et notre secret
  const bitnobSignature =
    req.headers['x-signature'] ||
    req.headers['x-bitnob-signature'] ||
    req.headers['x-webhook-signature'];
  const webhookSecret = process.env.BITNOB_WEBHOOK_SECRET;

  if (!bitnobSignature) {
    console.log('⚠️ Webhook ignoré : aucune signature (x-bitnob-signature)');
    return res.status(400).send('Signature manquante');
  }

  // 2. Refaire le calcul mathématique de notre côté
  // Bitnob signe avec HMAC-SHA512 (128 caractères hex). On accepte aussi SHA256 (64 caractères).
  const algo = bitnobSignature.length === 64 ? 'sha256' : 'sha512';
  const mySignature = crypto
    .createHmac(algo, webhookSecret)
    .update(req.rawBody || '') // texte brut gardé par express.json plus haut
    .digest('hex');

  // 3. Comparer (en temps constant) : si c'est différent, c'est un faux !
  const a = Buffer.from(mySignature);
  const b = Buffer.from(bitnobSignature);
  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) {
    console.log('🛑 ALERTE : Signature invalide ! Quelqu\'un se fait passer pour Bitnob.');
    console.log('   algo :', algo, '| reçue :', bitnobSignature.slice(0, 16) + '...', '| calculée :', mySignature.slice(0, 16) + '...');
    return res.status(401).send('Signature invalide');
  }

  // 4. Si c'est bon, on traite l'événement
  console.log('\n🔔 Vrai Webhook reçu de Bitnob !');
  const eventName = req.body.event || (req.body.test ? 'test' : 'inconnu'); // ex: "lightning.invoice.paid"
  console.log(`Événement : ${eventName}`);
  
  if (eventName === 'lightning.invoice.paid') {
    const ref = req.body.data?.reference;
    console.log(`✅ L'invoice ${ref} a été payée !`);
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

  // On répond 200 pour dire à Bitnob "C'est bon, j'ai bien reçu"
  res.sendStatus(200);
});

// 3. On lance le serveur
app.listen(port, () => {
  console.log(`🚀 Serveur démarré et en écoute sur http://localhost:${port}`);
});
