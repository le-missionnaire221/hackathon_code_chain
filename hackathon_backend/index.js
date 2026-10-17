import './env.js';
import express from 'express';
import crypto from 'node:crypto';
import { bitnob } from './bitnob.js';
import dns from 'node:dns';
import { initDb, pool, getInvoice, createInvoiceRecord, listPendingInvoices, settleInvoice, releaseInvoice, buildWalletPayload, findInvoiceByScan, payFromBuyerWallet, SAT_TO_FCFA } from './db.js';
import { requireAuth, mountAuth } from './auth.js';
import { mountDocs } from './swagger.js';
import { mountAdmin } from './admin.js';

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
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, x-signature, x-bitnob-signature');
  if (req.method === 'OPTIONS') return res.sendStatus(200);
  next();
});

mountAuth(app);
mountDocs(app);
mountAdmin(app);

// === ROUTE DE SANTÉ (HEALTHCHECK RÉEL) ===
app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({
      status: 'OK',
      server: 'Express Node.js',
      database: 'postgresql',
      port: port,
      features: ['accounts', 'wallets', 'pos', 'escrow_bilateral', 'lightning_settlement', 'admin'],
      uptimeSeconds: Math.floor(process.uptime()),
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    res.status(503).json({ status: 'DEGRADED', database: 'down', error: 'PostgreSQL indisponible' });
  }
});

async function reconcileInvoice(invoice) {
  if (!invoice || invoice.status === 'paid' || !invoice.bitnobId) return invoice;
  try {
    const bitnobCheck = await bitnob('GET', `/api/lightning/invoices/${invoice.bitnobId}`);
    if (bitnobCheck.data?.status === 'paid') {
      const settled = await settleInvoice(invoice.reference, { preimage: bitnobCheck.data.preimage });
      console.log(`✅ [BITNOB SETTLEMENT] ${invoice.reference} réglée. Code: ${settled?.releaseCode}`);
      return settled;
    }
  } catch {
    // Le polling suivant réessaiera.
  }
  return invoice;
}

// === PORTEFEUILLE DU COMPTE CONNECTÉ ===
app.get('/wallet', requireAuth, async (req, res) => {
  try {
    const pending = await listPendingInvoices(req.user.id);
    for (const invoice of pending) {
      await reconcileInvoice(invoice);
    }
    res.json(await buildWalletPayload(req.user.id));
  } catch (err) {
    console.error('Erreur /wallet:', err);
    res.status(500).json({ error: 'Impossible de lire le portefeuille' });
  }
});

// === CRÉATION D'UNE INVOICE LIGHTNING (AVEC OPTION SÉQUESTRE DISTANCE) ===
app.post('/invoice', requireAuth, async (req, res) => {
  const { customerId, description, amount, isEscrow } = req.body;
  const sats = Number(amount);
  if (!Number.isInteger(sats) || sats <= 0) {
    return res.status(400).json({ error: 'Montant invalide' });
  }

  try {
    const reference = (isEscrow ? 'ESC_' : 'LTG_') + Date.now();
    const label = description || (isEscrow ? 'Séquestre PayChain' : 'Paiement Lightning');

    const invoiceResponse = await bitnob('POST', '/api/lightning/invoices', {
      customer_id: customerId,
      amount: sats,
      description: label,
      expiry: 3600,
      reference: reference,
      auto_settle: true
    });

    if (invoiceResponse.status >= 400 || invoiceResponse.error || invoiceResponse.code) {
      console.error('Erreur Bitnob:', invoiceResponse);
      return res.status(invoiceResponse.status || 400).json({
        error: invoiceResponse.detail || invoiceResponse.message || "Erreur Bitnob",
        ...invoiceResponse
      });
    }

    const payload = invoiceResponse.data || {};
    const bitnobId = payload.id;
    const bolt11 = payload.request || '';

    await createInvoiceRecord({
      userId: req.user.id,
      reference,
      bitnobId,
      amount: sats,
      description: label,
      isEscrow: Boolean(isEscrow),
      bolt11
    });

    console.log(`⚡ Invoice créée : ${reference} pour +${req.user.phone} (Séquestre: ${Boolean(isEscrow)})`);
    res.json({
      ...invoiceResponse,
      reference,
      isEscrow: Boolean(isEscrow),
      escrowStatus: isEscrow ? 'awaiting_lock' : 'none'
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "API fetch failed" });
  }
});

// === SUIVI DU STATUT DE L'INVOICE & DU SÉQUESTRE ===
app.get('/invoice/:reference/status', async (req, res) => {
  const invoice = await getInvoice(req.params.reference);
  if (!invoice) {
    return res.status(404).json({ error: "Invoice non trouvée" });
  }
  res.json(await reconcileInvoice(invoice));
});

// === LECTURE D'UN QR LIGHTNING, D'UN LIEN OU D'UNE RÉFÉRENCE ===
app.post('/invoice/lookup', async (req, res) => {
  const invoice = await findInvoiceByScan(req.body?.code || req.body?.reference || '');
  if (!invoice) {
    return res.status(404).json({ error: 'QR code ou facture introuvable' });
  }
  res.json(invoice);
});

// === PAIEMENT DEPUIS LE PORTEFEUILLE PAYCHAIN ===
app.post('/invoice/:reference/pay', requireAuth, async (req, res) => {
  try {
    const result = await payFromBuyerWallet(req.params.reference, req.user.id);
    if (result.error) {
      return res.status(result.status || 400).json({ success: false, error: result.error });
    }
    const invoice = result.invoice;
    const fcfa = Math.round(invoice.amount * SAT_TO_FCFA);
    console.log(`⚡ [PAIEMENT APP] ${req.user.phone} → ${invoice.reference} (${fcfa} FCFA)`);
    res.json({
      success: true,
      reference: invoice.reference,
      status: invoice.status,
      amount: invoice.amount,
      amountFcfa: fcfa,
      description: invoice.description,
      merchantName: invoice.merchantName,
      isEscrow: invoice.isEscrow,
      escrowStatus: invoice.escrowStatus,
      releaseCode: invoice.releaseCode,
      preimage: invoice.preimage,
      message: result.already
        ? 'Cette facture est déjà payée.'
        : `${fcfa} FCFA débités de votre portefeuille. ${invoice.merchantName} est crédité.`
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, error: 'Paiement impossible' });
  }
});

// === PAGE WEB DE PAIEMENT SÉCURISÉ (ADAPTATIVE MOBILE & PC) ===
app.get('/pay/:reference', async (req, res) => {
  const { reference } = req.params;
  const invoice = await getInvoice(reference);
  if (invoice) {
    invoice.description = String(invoice.description || '')
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
    invoice.bolt11 = String(invoice.bolt11 || '').replace(/["\\<>]/g, '');
  }

  if (!invoice) {
    return res.status(404).send(`
      <!DOCTYPE html>
      <html lang="fr">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Facture Introuvable - PayChain Dakar</title>
        <style>
          body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #0b0e14; color: #fff; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; padding: 20px; box-sizing: border-box; text-align: center; }
          .card { background: #161b26; border: 1px solid #232b3e; border-radius: 20px; padding: 32px 24px; max-width: 420px; width: 100%; box-shadow: 0 20px 40px rgba(0,0,0,0.5); }
          h2 { color: #ef4444; margin-top: 0; }
          p { color: #94a3b8; font-size: 15px; line-height: 1.5; }
        </style>
      </head>
      <body>
        <div class="card">
          <h2>⚠️ Commande Introuvable</h2>
          <p>Cette facture n'existe pas ou a expiré. Veuillez contacter le vendeur sur WhatsApp pour recevoir un nouveau lien.</p>
        </div>
      </body>
      </html>
    `);
  }

  const fcfaAmount = Math.round(invoice.amount * 0.65);
  const isEscrow = Boolean(invoice.isEscrow);
  const userAgent = (req.headers['user-agent'] || '').toLowerCase();
  const isMobileServer = /mobile|iphone|ipod|android|blackberry|opera mini|iemobile|wpdesktop/i.test(userAgent);

  res.send(`
    <!DOCTYPE html>
    <html lang="fr">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
      <title>Paiement Sécurisé - PayChain Dakar</title>
      <link rel="preconnect" href="https://fonts.googleapis.com">
      <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
      <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;600;700;800&family=JetBrains+Mono:wght@500;700;800&display=swap" rel="stylesheet">
      <style>
        :root {
          --bg: #090C10;
          --card: #151922;
          --border: #222938;
          --primary: #F7931A;
          --primary-glow: rgba(247, 147, 26, 0.25);
          --success: #10B981;
          --success-glow: rgba(16, 185, 129, 0.25);
          --text: #F1F5F9;
          --text-muted: #94A3B8;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; -webkit-tap-highlight-color: transparent; }
        body {
          font-family: 'Plus Jakarta Sans', -apple-system, sans-serif;
          background: var(--bg);
          color: var(--text);
          display: flex;
          align-items: center;
          justify-content: center;
          min-height: 100vh;
          padding: 16px;
        }
        .container {
          max-width: 440px;
          width: 100%;
          background: var(--card);
          border: 1px solid var(--border);
          border-radius: 26px;
          padding: 24px 20px;
          box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.7);
          position: relative;
          overflow: hidden;
        }
        .container::before {
          content: "";
          position: absolute;
          top: -100px;
          left: 50%;
          transform: translateX(-50%);
          width: 240px;
          height: 240px;
          background: radial-gradient(circle, var(--primary-glow) 0%, transparent 70%);
          border-radius: 50%;
          pointer-events: none;
        }
        .header {
          display: flex;
          align-items: center;
          justify-content: space-between;
          margin-bottom: 16px;
        }
        .brand {
          font-weight: 800;
          font-size: 15px;
          display: flex;
          align-items: center;
          gap: 6px;
          color: #fff;
        }
        .mode-toggle {
          display: inline-flex;
          background: #0E121A;
          border: 1px solid var(--border);
          border-radius: 20px;
          padding: 2px;
          cursor: pointer;
        }
        .mode-btn {
          font-size: 11px;
          font-weight: 700;
          padding: 4px 10px;
          border-radius: 16px;
          border: none;
          background: transparent;
          color: var(--text-muted);
          cursor: pointer;
          transition: all 0.2s ease;
        }
        .mode-btn.active {
          background: #232B3E;
          color: #fff;
        }

        /* BANNIÈRE DE DÉTECTION APPAREIL */
        .device-banner {
          display: flex;
          align-items: center;
          gap: 10px;
          padding: 10px 14px;
          border-radius: 14px;
          margin-bottom: 16px;
          font-size: 12px;
          line-height: 1.4;
          background: rgba(247, 147, 26, 0.08);
          border: 1px solid rgba(247, 147, 26, 0.2);
          color: #FDE68A;
        }
        .device-banner .icon {
          font-size: 20px;
          flex-shrink: 0;
        }

        /* INFOS COMMANDE */
        .order-info {
          background: #0E121A;
          border: 1px solid var(--border);
          border-radius: 18px;
          padding: 16px;
          margin-bottom: 18px;
          text-align: center;
        }
        .order-badge {
          display: inline-flex;
          align-items: center;
          gap: 5px;
          font-size: 11px;
          font-weight: 800;
          padding: 4px 10px;
          border-radius: 12px;
          margin-bottom: 8px;
          background: rgba(16, 185, 129, 0.12);
          color: var(--success);
          border: 1px solid rgba(16, 185, 129, 0.25);
        }
        .order-title {
          font-size: 14px;
          color: var(--text-muted);
          margin-bottom: 4px;
        }
        .order-amount-fcfa {
          font-size: 32px;
          font-weight: 800;
          color: #fff;
          letter-spacing: -0.5px;
        }
        .order-amount-sats {
          font-size: 13px;
          font-weight: 700;
          color: var(--primary);
          margin-top: 2px;
          font-family: 'JetBrains Mono', monospace;
        }

        /* ACTIONS */
        .actions {
          display: flex;
          flex-direction: column;
          gap: 10px;
        }
        .btn {
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
          padding: 14px 18px;
          border-radius: 14px;
          font-weight: 800;
          font-size: 14px;
          text-decoration: none;
          cursor: pointer;
          border: none;
          transition: all 0.2s ease;
          width: 100%;
          text-align: center;
        }
        .btn-primary {
          background: linear-gradient(135deg, #F7931A 0%, #D97706 100%);
          color: #fff;
          box-shadow: 0 4px 16px rgba(247, 147, 26, 0.35);
        }
        .btn-primary:active { transform: scale(0.98); }
        .btn-primary .subtext {
          font-size: 11px;
          font-weight: 600;
          opacity: 0.9;
          margin-top: 3px;
        }
        .btn-secondary {
          background: #1C2230;
          color: #CBD5E1;
          border: 1px solid var(--border);
          flex-direction: row;
          gap: 8px;
        }
        .btn-secondary:active { background: #232B3E; }
        .btn-demo {
          background: rgba(16, 185, 129, 0.12);
          color: #34D399;
          border: 1px solid rgba(16, 185, 129, 0.35);
          flex-direction: row;
          gap: 8px;
        }
        .btn-demo:hover { background: rgba(16, 185, 129, 0.22); }

        /* QR CODE PC */
        .qr-card-pc {
          background: #0E121A;
          border: 1px solid var(--border);
          border-radius: 20px;
          padding: 16px;
          margin-bottom: 18px;
          text-align: center;
        }
        .qr-wrapper {
          background: #fff;
          padding: 12px;
          border-radius: 16px;
          width: 220px;
          height: 220px;
          margin: 0 auto 12px;
          display: flex;
          align-items: center;
          justify-content: center;
          box-shadow: 0 8px 20px rgba(0,0,0,0.4);
        }
        .qr-wrapper img {
          width: 100%;
          height: 100%;
          display: block;
        }
        .qr-instructions {
          font-size: 12px;
          color: var(--text-muted);
          line-height: 1.4;
        }

        /* ACCORDÉON QR POUR MOBILE */
        .qr-accordion {
          margin-top: 8px;
          text-align: center;
        }
        .accordion-toggle {
          background: transparent;
          border: none;
          color: var(--text-muted);
          font-size: 12px;
          font-weight: 600;
          cursor: pointer;
          text-decoration: underline;
          padding: 8px;
        }
        .accordion-content {
          margin-top: 10px;
          animation: fadeIn 0.3s ease-out;
        }

        .guarantee-box {
          margin-top: 18px;
          padding: 12px 14px;
          border-radius: 14px;
          background: rgba(16, 185, 129, 0.08);
          border: 1px solid rgba(16, 185, 129, 0.2);
          font-size: 12px;
          line-height: 1.45;
          color: #A7F3D0;
          display: flex;
          align-items: flex-start;
          gap: 10px;
        }

        /* SUCCESS STATE */
        .paid-card {
          display: none;
          text-align: center;
          animation: fadeIn 0.4s ease-out forwards;
        }
        @keyframes fadeIn {
          from { opacity: 0; transform: translateY(10px); }
          to { opacity: 1; transform: translateY(0); }
        }
        .shield-icon {
          width: 72px;
          height: 72px;
          border-radius: 50%;
          background: rgba(16, 185, 129, 0.15);
          border: 2px solid var(--success);
          display: flex;
          align-items: center;
          justify-content: center;
          font-size: 34px;
          margin: 10px auto 16px;
          box-shadow: 0 0 25px var(--success-glow);
        }
        .paid-title {
          font-size: 21px;
          font-weight: 800;
          color: #fff;
          margin-bottom: 6px;
        }
        .paid-subtitle {
          font-size: 13px;
          color: var(--text-muted);
          margin-bottom: 22px;
        }
        .code-box {
          background: linear-gradient(180deg, #1A2233 0%, #111622 100%);
          border: 2px dashed #10B981;
          border-radius: 20px;
          padding: 20px 16px;
          margin-bottom: 20px;
          position: relative;
        }
        .code-label {
          font-size: 11px;
          font-weight: 800;
          letter-spacing: 1px;
          color: #10B981;
          text-transform: uppercase;
          margin-bottom: 8px;
        }
        .code-digits {
          font-family: 'JetBrains Mono', monospace;
          font-size: 40px;
          font-weight: 900;
          color: #fff;
          letter-spacing: 8px;
          text-shadow: 0 0 20px rgba(16, 185, 129, 0.4);
        }
        .instructions-box {
          background: #0E121A;
          border-radius: 14px;
          padding: 14px;
          border: 1px solid #222938;
          font-size: 12.5px;
          color: #CBD5E1;
          line-height: 1.5;
          text-align: left;
          margin-bottom: 20px;
        }
        .instructions-box strong { color: #FBBF24; }
        .status-chip {
          display: inline-flex;
          align-items: center;
          gap: 6px;
          padding: 6px 14px;
          border-radius: 20px;
          font-size: 12px;
          font-weight: 700;
          background: #1C2333;
          color: #94A3B8;
        }
        .status-chip.released {
          background: rgba(16, 185, 129, 0.2);
          color: #34D399;
          border: 1px solid #10B981;
        }

        /* TOAST */
        #toast {
          position: fixed;
          bottom: 20px;
          left: 50%;
          transform: translateX(-50%) translateY(100px);
          background: #1E293B;
          color: #fff;
          border: 1px solid var(--primary);
          padding: 12px 20px;
          border-radius: 14px;
          font-size: 12.5px;
          font-weight: 700;
          box-shadow: 0 10px 25px rgba(0,0,0,0.5);
          opacity: 0;
          transition: all 0.3s ease;
          z-index: 999;
          pointer-events: none;
          max-width: 90%;
          text-align: center;
        }
        #toast.show {
          transform: translateX(-50%) translateY(0);
          opacity: 1;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <!-- HEADER -->
        <div class="header">
          <div class="brand">
            <span>⚡</span> PAYCHAIN DAKAR
          </div>
          <!-- Sélecteur d'appareil (permet de simuler Mobile ou PC en direct) -->
          <div class="mode-toggle" title="Basculer entre l'affichage Smartphone et PC">
            <button id="btn-mode-mobile" class="mode-btn" onclick="setDeviceMode('mobile')">📱 Mobile</button>
            <button id="btn-mode-pc" class="mode-btn" onclick="setDeviceMode('pc')">💻 PC</button>
          </div>
        </div>

        <!-- ZONE DÉTECTION APPAREIL -->
        <div id="banner-mobile" class="device-banner">
          <span class="icon">📱</span>
          <div>
            <strong>Vous êtes sur votre smartphone :</strong><br>
            Pas besoin de scanner ! Ouvrez votre portefeuille en 1 clic.
          </div>
        </div>

        <div id="banner-pc" class="device-banner" style="display: none; background: rgba(0, 82, 255, 0.08); border-color: rgba(0, 82, 255, 0.25); color: #93C5FD;">
          <span class="icon">💻</span>
          <div>
            <strong>Vous êtes sur votre ordinateur :</strong><br>
            Prenez votre smartphone et scannez le QR code ci-dessous.
          </div>
        </div>

        <!-- COMMANDE INFOS -->
        <div class="order-info">
          <div class="order-badge">
            ${isEscrow ? '🛡️ Séquestre Anti-Arnaque' : '⚡ Paiement Direct'}
          </div>
          <div class="order-title">${invoice.description || 'Commande PayChain'}</div>
          <div class="order-amount-fcfa">${fcfaAmount.toLocaleString('fr-FR')} FCFA</div>
          <div class="order-amount-sats">⚡ ${invoice.amount.toLocaleString()} Satoshis</div>
        </div>

        <!-- ZONE EN ATTENTE DE PAIEMENT -->
        <div id="pending-zone">

          <!-- VUE PC : QR CODE MIS EN AVANT -->
          <div id="view-pc" style="display: none;">
            <div class="qr-card-pc">
              <div class="qr-wrapper">
                <img src="https://api.qrserver.com/v1/create-qr-code/?size=240x240&data=${encodeURIComponent(invoice.bolt11)}" alt="QR Code Lightning BOLT11" />
              </div>
              <div class="qr-instructions">
                Scannez avec <strong>Blink</strong>, <strong>Phoenix</strong>, <strong>Strike</strong>, <strong>WoS</strong> ou tout wallet Lightning
              </div>
            </div>
          </div>

          <!-- ACTIONS PRINCIPALES -->
          <div class="actions">
            <!-- BOUTON DEEP LINK (Optimisé pour Mobile) -->
            <a class="btn btn-primary" href="lightning:${invoice.bolt11}" onclick="handleDeepLink(event)">
              <span>⚡ Payer avec mon Portefeuille Lightning</span>
              <span class="subtext">Ouvre Blink, Phoenix, Strike, CashApp… en 1 clic</span>
            </a>

            <button class="btn btn-secondary" onclick="copyInvoice()">
              📋 <span id="copy-text">Copier la Facture Lightning</span>
            </button>

            <button id="instant-pay-btn" class="btn btn-demo" onclick="instantPay()">
              🛡️ Confirmer le Dépôt sous Séquestre (Démo 1-Clic)
            </button>
          </div>

          <!-- VUE MOBILE : ACCORDÉON POUR VOIR LE QR CODE SI BESOIN -->
          <div id="view-mobile" class="qr-accordion">
            <button class="accordion-toggle" onclick="toggleQr()">
              📷 <span id="accordion-label">Vous avez un 2ème téléphone ? Afficher le QR Code ▼</span>
            </button>
            <div id="collapsible-qr" class="accordion-content" style="display: none;">
              <div class="qr-wrapper">
                <img src="https://api.qrserver.com/v1/create-qr-code/?size=220x220&data=${encodeURIComponent(invoice.bolt11)}" alt="QR Code Lightning BOLT11" />
              </div>
            </div>
          </div>

          ${isEscrow ? `
            <div class="guarantee-box">
              <span style="font-size: 18px;">🛡️</span>
              <div>
                <strong>Garantie Séquestre Acheteur :</strong>
                Vos fonds sont consignés sous séquestre sécurisé. Le vendeur ne sera payé que lorsque vous aurez inspecté votre colis en mains propres !
              </div>
            </div>
          ` : ''}
        </div>

        <!-- ZONE PAIEMENT EFFECTUÉ & CODE SECRET -->
        <div id="paid-zone" class="paid-card">
          <div class="shield-icon">🛡️</div>
          <div class="paid-title">Fonds Consignés sous Séquestre !</div>
          <div class="paid-subtitle">Votre paiement a été validé et verrouillé avec succès.</div>

          <div class="code-box">
            <div class="code-label">🔑 VOTRE CODE SECRET DE DÉBLOCAGE (OTP)</div>
            <div class="code-digits" id="otp-display">${invoice.releaseCode || '••••'}</div>
          </div>

          <div class="instructions-box">
            ⚠️ <strong>RÈGLE D'OR DE SÉCURITÉ :</strong><br>
            Conservez précieusement ce code à 4 chiffres. Ne le remettez au livreur <strong>qu'après avoir vérifié la conformité de votre colis</strong>.<br><br>
            C'est ce code qui débloquera le paiement vers le compte du marchand.
          </div>

          <div id="live-status-chip" class="status-chip">
            🔒 Statut : Fonds verrouillés sous séquestre
          </div>
        </div>
      </div>

      <!-- TOAST DE NOTIFICATION -->
      <div id="toast"></div>

      <script>
        const ref = "${reference}";
        const bolt11 = "${invoice.bolt11}";
        let isPaid = ${invoice.status === 'paid'};
        let serverIsMobile = ${isMobileServer};

        function showToast(msg) {
          const t = document.getElementById('toast');
          t.innerText = msg;
          t.className = 'show';
          setTimeout(() => { t.className = ''; }, 3000);
        }

        function setDeviceMode(mode) {
          const isMobile = mode === 'mobile';
          document.getElementById('btn-mode-mobile').className = 'mode-btn' + (isMobile ? ' active' : '');
          document.getElementById('btn-mode-pc').className = 'mode-btn' + (!isMobile ? ' active' : '');

          document.getElementById('banner-mobile').style.display = isMobile ? 'flex' : 'none';
          document.getElementById('banner-pc').style.display = isMobile ? 'none' : 'flex';

          document.getElementById('view-pc').style.display = isMobile ? 'none' : 'block';
          document.getElementById('view-mobile').style.display = isMobile ? 'block' : 'none';
        }

        // Détection initiale intelligente
        const clientIsMobile = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent) || window.innerWidth < 768;
        setDeviceMode(clientIsMobile ? 'mobile' : 'pc');

        function toggleQr() {
          const box = document.getElementById('collapsible-qr');
          const lbl = document.getElementById('accordion-label');
          if (box.style.display === 'none') {
            box.style.display = 'block';
            lbl.innerText = 'Masquer le QR Code ▲';
          } else {
            box.style.display = 'none';
            lbl.innerText = 'Vous avez un 2ème téléphone ? Afficher le QR Code ▼';
          }
        }

        function copyInvoice() {
          navigator.clipboard.writeText(bolt11).then(() => {
            const btn = document.getElementById('copy-text');
            btn.innerText = 'Copié dans le presse-papier ! ✅';
            showToast('Facture Lightning copiée ! Ouvrez votre wallet pour coller.');
            setTimeout(() => { btn.innerText = 'Copier la Facture Lightning'; }, 2500);
          });
        }

        function handleDeepLink(e) {
          // Copie également la facture en arrière-plan pour assurer le coup
          navigator.clipboard.writeText(bolt11).catch(() => {});
          showToast('🚀 Lancement de votre portefeuille Lightning…');
        }

        async function instantPay() {
          const btn = document.getElementById('instant-pay-btn');
          if (btn) {
            btn.innerText = 'Règlement en cours… ⏳';
            btn.disabled = true;
          }
          try {
            const res = await fetch('/invoice/' + ref + '/pay', { method: 'POST' });
            const data = await res.json();
            if (data.success) {
              isPaid = true;
              showPaid(data.releaseCode || data.invoice?.releaseCode, data.escrowStatus || data.invoice?.escrowStatus);
            } else if (btn) {
              btn.innerText = data.error || 'Payez avec Blink ou l’application PayChain';
              btn.disabled = false;
            }
          } catch(e) {
            if (btn) {
              btn.innerText = 'Erreur';
              setTimeout(() => {
                btn.innerText = '🛡️ Confirmer le Dépôt sous Séquestre (Démo 1-Clic)';
                btn.disabled = false;
              }, 2000);
            }
          }
        }

        function showPaid(code, escrowStatus) {
          document.getElementById('pending-zone').style.display = 'none';
          document.getElementById('banner-mobile').style.display = 'none';
          document.getElementById('banner-pc').style.display = 'none';
          const paidZone = document.getElementById('paid-zone');
          paidZone.style.display = 'block';
          if (code) {
            document.getElementById('otp-display').innerText = code;
          }
          const chip = document.getElementById('live-status-chip');
          if (escrowStatus === 'released') {
            chip.className = 'status-chip released';
            chip.innerHTML = '🔓 Commande livrée & Fonds transférés au vendeur';
          }
        }

        if (isPaid) {
          showPaid("${invoice.releaseCode || ''}", "${invoice.escrowStatus || ''}");
        }

        // Sondage dynamique en temps réel
        setInterval(async () => {
          try {
            const res = await fetch('/invoice/' + ref + '/status');
            if (res.ok) {
              const data = await res.json();
              if (data.status === 'paid' && !isPaid) {
                isPaid = true;
                showPaid(data.releaseCode, data.escrowStatus);
              } else if (data.status === 'paid' && isPaid) {
                const chip = document.getElementById('live-status-chip');
                if (data.escrowStatus === 'released') {
                  chip.className = 'status-chip released';
                  chip.innerHTML = '🔓 Commande livrée & Fonds transférés au vendeur';
                }
              }
            }
          } catch(e) {}
        }, 2000);
      </script>
    </body>
    </html>
  `);
});

// === DÉBLOCAGE DU SÉQUESTRE (REMISE DU COLIS CONFIRMÉE) ===
app.post('/invoice/:reference/release', requireAuth, async (req, res) => {
  const { reference } = req.params;
  const existing = await getInvoice(reference);
  if (!existing) {
    return res.status(404).json({ success: false, error: "Commande introuvable" });
  }
  if (existing.userId !== req.user.id && req.user.role !== 'admin') {
    return res.status(403).json({ success: false, error: "Cette commande appartient à un autre compte" });
  }

  const result = await releaseInvoice(reference, req.body?.code);
  if (result.error) {
    return res.status(result.status || 400).json({ success: false, error: result.error });
  }

  console.log(`🔓 [SÉQUESTRE DÉBLOQUÉ] ${reference}`);
  res.json({
    success: true,
    reference,
    escrowStatus: 'released',
    amount: result.invoice.amount,
    message: "Cadenas débloqué ! Fonds transférés dans votre solde disponible."
  });
});

// === RÉCEPTION DES WEBHOOKS DE BITNOB ===
app.post('/webhook', async (req, res) => {
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
    if (ref) {
      const current = await getInvoice(ref);
      if (current) {
        await settleInvoice(ref, { preimage: req.body.data?.preimage || current.preimage });
      }
    }
  }

  res.sendStatus(200);
});

await initDb();

app.listen(port, () => {
  console.log(`🚀 Serveur PayChain démarré sur http://localhost:${port}`);
  console.log(`📚 Swagger : http://localhost:${port}/docs`);
  console.log(`🛡️ Admin   : http://localhost:${port}/admin`);
});
