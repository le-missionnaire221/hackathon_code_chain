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
// Format invoice : { reference, bitnobId, amount, description, status, isEscrow, escrowStatus, releaseCode, preimage, createdAt, paidAt, releasedAt }
const invoices = new Map();

// Helper pour extraire les 4 derniers caractères d'une preimage comme code OTP court
function extractShortCode(preimage) {
  if (!preimage) return '0000';
  const clean = preimage.replace(/[^a-fA-F0-9]/g, '');
  return clean.slice(-4).toUpperCase();
}

// === ROUTE DE SANTÉ (HEALTHCHECK RÉEL) ===
app.get('/health', (req, res) => {
  res.json({
    status: 'OK',
    server: 'Express Node.js',
    port: port,
    features: ['pos', 'escrow_bilateral', 'lightning_settlement'],
    uptimeSeconds: Math.floor(process.uptime()),
    timestamp: new Date().toISOString()
  });
});

// === ROUTE WALLET & TRANSACTIONS (AVEC SÉPARATION DU SÉQUESTRE) ===
app.get('/wallet', async (req, res) => {
  try {
    const bitnobRes = await bitnob('GET', '/api/lightning/invoices');
    const rawInvoices = bitnobRes.data?.invoices || [];

    let totalAvailableSats = 0;
    let totalEscrowSats = 0;
    let lockedEscrowCount = 0;

    const transactions = rawInvoices.map((inv) => {
      const isPaid = inv.status === 'paid';
      const sats = Number(inv.amount_sat || 0);

      // Récupérer les métadonnées de séquestre locales si existantes
      const local = invoices.get(inv.reference);
      const isEscrow = local?.isEscrow || false;
      const preimage = inv.preimage || local?.preimage || null;
      const releaseCode = local?.releaseCode || (preimage ? extractShortCode(preimage) : null);

      let escrowStatus = 'none';
      if (isEscrow) {
        if (!isPaid) {
          escrowStatus = 'awaiting_lock';
        } else if (local?.escrowStatus === 'released') {
          escrowStatus = 'released';
        } else {
          escrowStatus = 'locked'; // Fonds garantis bloqués sous séquestre
        }
      }

      // Calcul des balances
      if (isPaid) {
        if (isEscrow && escrowStatus === 'locked') {
          totalEscrowSats += sats;
          lockedEscrowCount++;
        } else {
          totalAvailableSats += sats;
        }
      }

      let displayStatus = 'En attente';
      if (isPaid) {
        if (isEscrow && escrowStatus === 'locked') {
          displayStatus = 'Séquestré 🔒';
        } else if (isEscrow && escrowStatus === 'released') {
          displayStatus = 'Livré & Libéré 🔓';
        } else {
          displayStatus = 'Confirmé ⚡';
        }
      } else if (inv.status === 'expired') {
        displayStatus = 'Expiré';
      }

      return {
        id: inv.id,
        reference: inv.reference || 'N/A',
        title: inv.description || (isEscrow ? 'Vente Séquestrée WhatsApp' : 'Encaissement Marchand POS'),
        category: isEscrow ? 'Commerce Distance (Séquestre)' : 'Encaissement Comptoir POS',
        amountSats: sats,
        amountFcfa: Math.round(sats * 0.65),
        isCredit: true,
        date: inv.created_at || new Date().toISOString(),
        status: displayStatus,
        isEscrow: isEscrow,
        escrowStatus: escrowStatus,
        releaseCode: releaseCode,
        preimage: preimage,
        request: inv.request
      };
    });

    res.json({
      success: true,
      balanceSats: totalAvailableSats,
      balanceFcfa: Math.round(totalAvailableSats * 0.65),
      escrowSats: totalEscrowSats,
      escrowFcfa: Math.round(totalEscrowSats * 0.65),
      escrowInvoicesCount: lockedEscrowCount,
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

// === CRÉATION D'UNE INVOICE LIGHTNING (AVEC OPTION SÉQUESTRE DISTANCE) ===
app.post('/invoice', async (req, res) => {
  const { customerId, description, amount, isEscrow } = req.body;
  
  try {
    const reference = (isEscrow ? 'ESC_' : 'LTG_') + Date.now();
    
    // Appel officiel à l'API Bitnob Lightning
    const invoiceResponse = await bitnob('POST', '/api/lightning/invoices', {
      customer_id: customerId,
      amount: Number(amount),
      description: description || (isEscrow ? 'Séquestre PayChain' : 'Paiement Lightning'),
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

    // Enregistrer la facture pour le suivi du statut et du séquestre
    invoices.set(reference, {
      reference,
      bitnobId,
      amount: Number(amount),
      description: description || (isEscrow ? 'Séquestre PayChain' : 'Paiement Lightning'),
      status: 'pending',
      isEscrow: Boolean(isEscrow),
      escrowStatus: isEscrow ? 'awaiting_lock' : 'none',
      releaseCode: null,
      createdAt: new Date().toISOString()
    });

    console.log(`⚡ Invoice créée : ${reference} (Bitnob ID: ${bitnobId}, Séquestre: ${Boolean(isEscrow)})`);
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
        invoice.releaseCode = extractShortCode(invoice.preimage);

        if (invoice.isEscrow && invoice.escrowStatus === 'awaiting_lock') {
          invoice.escrowStatus = 'locked'; // Les fonds sont maintenant verrouillés sous séquestre !
          console.log(`🔒 [SÉQUESTRE ACTIVÉ] L'invoice ${req.params.reference} a été verrouillée sous séquestre ! Code: ${invoice.releaseCode}`);
        } else {
          console.log(`✅ [BITNOB SETTLEMENT] L'invoice ${req.params.reference} a été RÉGLÉE ! Preimage: ${invoice.preimage}`);
        }

        invoices.set(req.params.reference, invoice);
      }
    } catch (e) {
      // Ignorer l'erreur réseau ponctuelle
    }
  }

  res.json(invoice);
});

// === RÈGLEMENT CLIENT DIRECT (DEPUIS L'APP OU LE BOUTON WEB) ===
app.post('/invoice/:reference/pay', (req, res) => {
  const { reference } = req.params;
  const invoice = invoices.get(reference);
  if (!invoice) {
    return res.status(404).json({ success: false, error: "Facture introuvable" });
  }

  if (invoice.status === 'paid') {
    return res.json({ success: true, message: "Déjà réglée", invoice });
  }

  invoice.status = 'paid';
  invoice.paidAt = new Date().toISOString();
  if (!invoice.preimage) {
    invoice.preimage = crypto.randomBytes(32).toString('hex');
  }
  invoice.releaseCode = extractShortCode(invoice.preimage);

  if (invoice.isEscrow) {
    invoice.escrowStatus = 'locked';
    console.log(`🔒 [PAIEMENT CLIENT APP/WEB] Commande ${reference} verrouillée sous séquestre ! Code secret: ${invoice.releaseCode}`);
  } else {
    console.log(`⚡ [PAIEMENT CLIENT APP/WEB] Commande ${reference} réglée avec succès !`);
  }

  invoices.set(reference, invoice);
  res.json({
    success: true,
    reference,
    status: invoice.status,
    isEscrow: invoice.isEscrow,
    escrowStatus: invoice.escrowStatus,
    releaseCode: invoice.releaseCode,
    preimage: invoice.preimage,
    message: invoice.isEscrow ? "Fonds consignés sous séquestre !" : "Paiement direct validé !"
  });
});

// === PAGE WEB DE PAIEMENT SÉCURISÉ & DÉLIVRANCE DU CODE SECRET CLIENT ===
app.get('/pay/:reference', (req, res) => {
  const { reference } = req.params;
  const invoice = invoices.get(reference);

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

  const fcfaAmount = Math.round(invoice.amount * 6.0);
  const isEscrow = Boolean(invoice.isEscrow);

  res.send(`
    <!DOCTYPE html>
    <html lang="fr">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
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
          --primary-glow: rgba(247, 147, 26, 0.2);
          --success: #10B981;
          --success-glow: rgba(16, 185, 129, 0.2);
          --text: #F1F5F9;
          --text-muted: #94A3B8;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; }
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
          max-width: 430px;
          width: 100%;
          background: var(--card);
          border: 1px solid var(--border);
          border-radius: 24px;
          padding: 24px 20px;
          box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.65);
          position: relative;
          overflow: hidden;
        }
        .container::before {
          content: "";
          position: absolute;
          top: -100px;
          left: 50%;
          transform: translateX(-50%);
          width: 220px;
          height: 220px;
          background: radial-gradient(circle, var(--primary-glow) 0%, transparent 70%);
          border-radius: 50%;
          pointer-events: none;
        }
        .header {
          display: flex;
          align-items: center;
          justify-content: space-between;
          margin-bottom: 20px;
        }
        .brand {
          font-weight: 800;
          font-size: 15px;
          letter-spacing: 0.5px;
          display: flex;
          align-items: center;
          gap: 6px;
          color: #fff;
        }
        .badge {
          display: inline-flex;
          align-items: center;
          gap: 5px;
          font-size: 11px;
          font-weight: 700;
          padding: 5px 10px;
          border-radius: 20px;
          background: rgba(247, 147, 26, 0.12);
          color: var(--primary);
          border: 1px solid rgba(247, 147, 26, 0.25);
        }
        .badge.escrow {
          background: rgba(16, 185, 129, 0.12);
          color: var(--success);
          border-color: rgba(16, 185, 129, 0.25);
        }
        .order-info {
          background: #0E121A;
          border: 1px solid var(--border);
          border-radius: 16px;
          padding: 16px;
          margin-bottom: 20px;
          text-align: center;
        }
        .order-title {
          font-size: 14px;
          color: var(--text-muted);
          margin-bottom: 4px;
        }
        .order-amount-fcfa {
          font-size: 30px;
          font-weight: 800;
          color: #fff;
          letter-spacing: -0.5px;
        }
        .order-amount-sats {
          font-size: 13px;
          font-weight: 600;
          color: var(--primary);
          margin-top: 2px;
          font-family: 'JetBrains Mono', monospace;
        }
        .qr-wrapper {
          background: #fff;
          padding: 14px;
          border-radius: 18px;
          width: 240px;
          height: 240px;
          margin: 0 auto 20px;
          display: flex;
          align-items: center;
          justify-content: center;
          box-shadow: 0 10px 25px rgba(0,0,0,0.4);
        }
        .qr-wrapper img {
          width: 100%;
          height: 100%;
          border-radius: 8px;
          display: block;
        }
        .actions {
          display: flex;
          flex-direction: column;
          gap: 10px;
        }
        .btn {
          display: flex;
          align-items: center;
          justify-content: center;
          gap: 8px;
          padding: 14px 18px;
          border-radius: 14px;
          font-weight: 700;
          font-size: 14px;
          text-decoration: none;
          cursor: pointer;
          border: none;
          transition: all 0.2s ease;
          width: 100%;
        }
        .btn-primary {
          background: linear-gradient(135deg, #F7931A 0%, #E67E00 100%);
          color: #fff;
          box-shadow: 0 4px 14px rgba(247, 147, 26, 0.4);
        }
        .btn-primary:active { transform: scale(0.98); }
        .btn-secondary {
          background: #1C2230;
          color: #CBD5E1;
          border: 1px solid var(--border);
        }
        .btn-secondary:active { background: #232B3E; }
        .guarantee-box {
          margin-top: 20px;
          padding: 12px 14px;
          border-radius: 12px;
          background: rgba(16, 185, 129, 0.08);
          border: 1px solid rgba(16, 185, 129, 0.2);
          font-size: 12px;
          line-height: 1.45;
          color: #A7F3D0;
          display: flex;
          align-items: flex-start;
          gap: 10px;
        }
        .guarantee-box span { font-size: 16px; }

        /* PAID & CODE STATE */
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
          width: 68px;
          height: 68px;
          border-radius: 50%;
          background: rgba(16, 185, 129, 0.15);
          border: 2px solid var(--success);
          display: flex;
          align-items: center;
          justify-content: center;
          font-size: 32px;
          margin: 10px auto 16px;
          box-shadow: 0 0 25px var(--success-glow);
        }
        .paid-title {
          font-size: 20px;
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
          border-radius: 18px;
          padding: 18px 16px;
          margin-bottom: 20px;
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
          font-size: 38px;
          font-weight: 900;
          color: #fff;
          letter-spacing: 8px;
          text-shadow: 0 0 15px rgba(16, 185, 129, 0.4);
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
        .instructions-box strong {
          color: #FBBF24;
        }
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
      </style>
    </head>
    <body>
      <div class="container">
        <!-- HEADER -->
        <div class="header">
          <div class="brand">
            <span>⚡</span> PAYCHAIN DAKAR
          </div>
          <div class="badge ${isEscrow ? 'escrow' : ''}">
            ${isEscrow ? '🛡️ Séquestre Anti-Arnaque' : '⚡ Paiement Direct'}
          </div>
        </div>

        <!-- COMMANDE INFOS -->
        <div class="order-info">
          <div class="order-title">${invoice.description || 'Commande PayChain'}</div>
          <div class="order-amount-fcfa">${fcfaAmount.toLocaleString('fr-FR')} FCFA</div>
          <div class="order-amount-sats">⚡ ${invoice.amount.toLocaleString()} Satoshis</div>
        </div>

        <!-- ZONE EN ATTENTE DE PAIEMENT -->
        <div id="pending-zone">
          <div class="qr-wrapper">
            <img src="https://api.qrserver.com/v1/create-qr-code/?size=240x240&data=${encodeURIComponent(invoice.bolt11)}" alt="QR Code Lightning BOLT11" />
          </div>

          <div class="actions">
            <a class="btn btn-primary" href="lightning:${invoice.bolt11}">
              ⚡ Payer avec Lightning Wallet
            </a>
            <button class="btn btn-secondary" onclick="copyInvoice()">
              📋 <span id="copy-text">Copier la Facture Lightning</span>
            </button>
            <button id="instant-pay-btn" class="btn btn-secondary" style="border-color: rgba(16, 185, 129, 0.4); color: #34D399; background: rgba(16, 185, 129, 0.1);" onclick="instantPay()">
              🛡️ Confirmer le Règlement (Dépôt Séquestre Démo)
            </button>
          </div>

          ${isEscrow ? `
            <div class="guarantee-box">
              <span>🛡️</span>
              <div>
                <strong>Protection Acheteur 100% Garantie :</strong>
                Vos fonds seront consignés sous séquestre sécurisé. Le vendeur ne sera payé que lorsque vous aurez inspecté et validé votre colis en mains propres !
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

      <script>
        const ref = "${reference}";
        const bolt11 = "${invoice.bolt11}";
        let isPaid = ${invoice.status === 'paid'};

        function copyInvoice() {
          navigator.clipboard.writeText(bolt11).then(() => {
            const btn = document.getElementById('copy-text');
            btn.innerText = 'Copié dans le presse-papier ! ✅';
            setTimeout(() => { btn.innerText = 'Copier la Facture Lightning'; }, 2500);
          });
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
            }
          } catch(e) {
            if (btn) {
              btn.innerText = 'Erreur';
              setTimeout(() => {
                btn.innerText = '🛡️ Confirmer le Règlement (Dépôt Séquestre Démo)';
                btn.disabled = false;
              }, 2000);
            }
          }
        }

        function showPaid(code, escrowStatus) {
          document.getElementById('pending-zone').style.display = 'none';
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

        // Sondage dynamique
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
app.post('/invoice/:reference/release', (req, res) => {
  const { reference } = req.params;
  const { code } = req.body;

  const invoice = invoices.get(reference);
  if (!invoice) {
    return res.status(404).json({ success: false, error: "Commande introuvable" });
  }

  if (!invoice.isEscrow) {
    return res.status(400).json({ success: false, error: "Cette facture n'est pas sous séquestre" });
  }

  if (invoice.status !== 'paid') {
    return res.status(400).json({ success: false, error: "Les fonds n'ont pas encore été déposés par le client" });
  }

  // Vérifier le code de déblocage (OTP fourni par le client au marchand lors de la remise)
  const provided = (code || '').toString().trim().toUpperCase();
  const expectedShort = invoice.releaseCode?.toUpperCase();
  const expectedFull = invoice.preimage?.toUpperCase();

  // Le code est obligatoire et doit concorder
  const isValidCode = provided && (
    provided === expectedShort ||
    (expectedFull && expectedFull.endsWith(provided)) ||
    provided === expectedFull
  );

  if (!isValidCode) {
    return res.status(400).json({
      success: false,
      error: `Code secret invalide ! Demandez au client son code à 4 chiffres affiché sur sa page de reçu.`
    });
  }

  invoice.escrowStatus = 'released';
  invoice.releasedAt = new Date().toISOString();
  invoices.set(reference, invoice);

  console.log(`🔓 [SÉQUESTRE DÉBLOQUÉ PAR CODE] Commande ${reference} libérée avec succès (Code: ${provided}) !`);

  res.json({
    success: true,
    reference,
    escrowStatus: 'released',
    amount: invoice.amount,
    message: "Cadenas débloqué ! Fonds transférés dans votre solde disponible."
  });
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
      const preimage = req.body.data?.preimage || current.preimage;
      const releaseCode = extractShortCode(preimage);

      invoices.set(ref, {
        ...current,
        status: 'paid',
        paidAt: new Date().toISOString(),
        preimage: preimage,
        releaseCode: releaseCode,
        escrowStatus: current.isEscrow ? 'locked' : current.escrowStatus,
        details: req.body.data
      });
    }
  }

  res.sendStatus(200);
});

// Lancer le serveur
app.listen(port, () => {
  console.log(`🚀 Serveur PayChain avec Séquestre Bilatéral démarré sur http://localhost:${port}`);
});
