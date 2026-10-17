import './env.js';
import pg from 'pg';
import bcrypt from 'bcryptjs';
import crypto from 'node:crypto';

const { Pool } = pg;

export const SAT_TO_FCFA = 0.65;
export const SANDBOX_START_SATS = 20000;

function connectionString() {
  if (process.env.DATABASE_URL) return process.env.DATABASE_URL;
  const user = process.env.PGUSER || 'postgres';
  const password = process.env.PGPASSWORD || '';
  const host = process.env.PGHOST || 'localhost';
  const port = process.env.PGPORT || '5432';
  const database = process.env.PGDATABASE || 'hackathon';
  return `postgresql://${encodeURIComponent(user)}:${encodeURIComponent(password)}@${host}:${port}/${database}`;
}

const url = connectionString();
const needsSsl = /render\.com|sslmode=require/i.test(url) || process.env.PGSSL === 'true';

export const pool = new Pool({
  connectionString: url,
  ssl: needsSsl ? { rejectUnauthorized: false } : undefined,
});

export function normalizePhone(phone) {
  const digits = String(phone || '').replace(/\D/g, '');
  if (digits.startsWith('221') && digits.length >= 12) return digits;
  if (digits.length === 9) return `221${digits}`;
  return digits;
}

export function extractShortCode(preimage) {
  if (!preimage) return '0000';
  const clean = String(preimage).replace(/[^a-fA-F0-9]/g, '');
  return (clean.slice(-4) || '0000').toUpperCase();
}

export function toInvoice(row) {
  if (!row) return null;
  return {
    reference: row.reference,
    userId: row.user_id,
    bitnobId: row.bitnob_id,
    amount: Number(row.amount),
    description: row.description,
    status: row.status,
    isEscrow: row.is_escrow,
    escrowStatus: row.escrow_status,
    releaseCode: row.release_code,
    preimage: row.preimage,
    bolt11: row.bolt11 || '',
    request: row.bolt11 || '',
    createdAt: row.created_at,
    paidAt: row.paid_at,
    releasedAt: row.released_at,
  };
}

export function publicUser(row) {
  if (!row) return null;
  return {
    id: row.id,
    phone: row.phone,
    fullName: row.full_name,
    role: row.role,
    status: row.status,
    balanceSats: Number(row.balance_sats || 0),
    escrowSats: Number(row.escrow_sats || 0),
    createdAt: row.created_at,
  };
}

function displayStatus(invoice) {
  if (invoice.status !== 'paid') {
    return invoice.status === 'expired' ? 'Expiré' : 'En attente';
  }
  if (invoice.isEscrow && invoice.escrowStatus === 'locked') return 'Séquestré 🔒';
  if (invoice.isEscrow && invoice.escrowStatus === 'released') return 'Livré & Libéré 🔓';
  return 'Confirmé ⚡';
}

export async function initDb() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS users (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      phone VARCHAR(20) UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      full_name TEXT NOT NULL DEFAULT '',
      role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin')),
      status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended')),
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );

    CREATE TABLE IF NOT EXISTS wallets (
      user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
      balance_sats BIGINT NOT NULL DEFAULT 0,
      escrow_sats BIGINT NOT NULL DEFAULT 0,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );

    CREATE TABLE IF NOT EXISTS invoices (
      reference TEXT PRIMARY KEY,
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      bitnob_id TEXT,
      amount INTEGER NOT NULL,
      description TEXT,
      status TEXT NOT NULL DEFAULT 'pending',
      is_escrow BOOLEAN NOT NULL DEFAULT false,
      escrow_status TEXT NOT NULL DEFAULT 'none',
      release_code TEXT,
      preimage TEXT,
      bolt11 TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      paid_at TIMESTAMPTZ,
      released_at TIMESTAMPTZ
    );

    CREATE TABLE IF NOT EXISTS ledger (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      amount_sats BIGINT NOT NULL,
      kind TEXT NOT NULL,
      reference TEXT,
      note TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );

    CREATE INDEX IF NOT EXISTS invoices_user_idx ON invoices(user_id);
    CREATE INDEX IF NOT EXISTS invoices_status_idx ON invoices(status);
    CREATE INDEX IF NOT EXISTS ledger_user_idx ON ledger(user_id);
  `);

  const phone = normalizePhone(process.env.ADMIN_PHONE || '221770000001');
  const password = process.env.ADMIN_PASSWORD || 'PayChainAdmin2026';
  const existing = await pool.query('SELECT id FROM users WHERE phone = $1', [phone]);
  if (existing.rowCount === 0) {
    const hash = await bcrypt.hash(password, 10);
    const user = await pool.query(
      `INSERT INTO users (phone, password_hash, full_name, role)
       VALUES ($1, $2, $3, 'admin') RETURNING id`,
      [phone, hash, 'Administrateur PayChain']
    );
    await pool.query('INSERT INTO wallets (user_id) VALUES ($1)', [user.rows[0].id]);
    console.log(`👑 Compte admin prêt : +${phone}`);
  }

  const granted = await pool.query(
    `UPDATE wallets w
     SET balance_sats = $1, updated_at = now()
     WHERE w.balance_sats = 0
       AND NOT EXISTS (
         SELECT 1 FROM ledger l WHERE l.user_id = w.user_id AND l.kind = 'sandbox_grant'
       )
     RETURNING w.user_id`,
    [SANDBOX_START_SATS]
  );
  for (const row of granted.rows) {
    await pool.query(
      `INSERT INTO ledger (user_id, amount_sats, kind, reference, note)
       VALUES ($1, $2, 'sandbox_grant', 'SANDBOX', 'Solde sandbox initial')`,
      [row.user_id, SANDBOX_START_SATS]
    );
  }
}

export async function createUser({ phone, password, fullName }) {
  const normalized = normalizePhone(phone);
  if (normalized.length < 11) {
    const err = new Error('Numéro invalide. Exemple : 77 000 00 00 ou +221 77 000 00 00');
    err.status = 400;
    throw err;
  }
  if (!password || String(password).length < 6) {
    const err = new Error('Le mot de passe doit contenir au moins 6 caractères');
    err.status = 400;
    throw err;
  }
  const hash = await bcrypt.hash(String(password), 10);
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const inserted = await client.query(
      `INSERT INTO users (phone, password_hash, full_name)
       VALUES ($1, $2, $3)
       RETURNING id`,
      [normalized, hash, String(fullName || '').trim()]
    );
    await client.query(
      'INSERT INTO wallets (user_id, balance_sats) VALUES ($1, $2)',
      [inserted.rows[0].id, SANDBOX_START_SATS]
    );
    await client.query(
      `INSERT INTO ledger (user_id, amount_sats, kind, reference, note)
       VALUES ($1, $2, 'sandbox_grant', 'SANDBOX', 'Solde sandbox initial')`,
      [inserted.rows[0].id, SANDBOX_START_SATS]
    );
    await client.query('COMMIT');
    return findUserById(inserted.rows[0].id);
  } catch (error) {
    await client.query('ROLLBACK');
    if (error.code === '23505') {
      const err = new Error('Ce numéro est déjà inscrit');
      err.status = 409;
      throw err;
    }
    throw error;
  } finally {
    client.release();
  }
}

export async function findUserByPhone(phone) {
  const { rows } = await pool.query('SELECT * FROM users WHERE phone = $1', [normalizePhone(phone)]);
  return rows[0] || null;
}

export async function findUserById(id) {
  const { rows } = await pool.query(
    `SELECT u.id, u.phone, u.full_name, u.role, u.status, u.created_at,
            COALESCE(w.balance_sats, 0) AS balance_sats,
            COALESCE(w.escrow_sats, 0) AS escrow_sats
     FROM users u
     LEFT JOIN wallets w ON w.user_id = u.id
     WHERE u.id = $1`,
    [id]
  );
  return rows[0] || null;
}

export async function verifyPassword(user, password) {
  return bcrypt.compare(String(password || ''), user.password_hash);
}

export async function createInvoiceRecord({ userId, reference, bitnobId, amount, description, isEscrow, bolt11 }) {
  const { rows } = await pool.query(
    `INSERT INTO invoices
      (reference, user_id, bitnob_id, amount, description, status, is_escrow, escrow_status, bolt11)
     VALUES ($1, $2, $3, $4, $5, 'pending', $6, $7, $8)
     RETURNING *`,
    [reference, userId, bitnobId || null, amount, description, Boolean(isEscrow), isEscrow ? 'awaiting_lock' : 'none', bolt11 || null]
  );
  return toInvoice(rows[0]);
}

export async function getInvoice(reference) {
  const { rows } = await pool.query('SELECT * FROM invoices WHERE reference = $1', [reference]);
  return toInvoice(rows[0]);
}

export function extractScanCode(raw) {
  let text = String(raw || '').trim();
  if (text.toLowerCase().startsWith('lightning:')) text = text.slice('lightning:'.length);
  if (text.includes('/pay/')) {
    text = text.split('/pay/').pop().split('?')[0].split('#')[0].trim();
  }
  return text.trim();
}

export async function findInvoiceByScan(raw) {
  const code = extractScanCode(raw);
  if (!code) return null;
  const { rows } = await pool.query(
    `SELECT i.*, u.full_name AS merchant_name
     FROM invoices i
     JOIN users u ON u.id = i.user_id
     WHERE i.reference = $1 OR i.bolt11 = $1
     LIMIT 1`,
    [code]
  );
  if (!rows[0]) return null;
  const invoice = toInvoice(rows[0]);
  invoice.merchantName = rows[0].merchant_name || 'Marchand PayChain';
  invoice.amountFcfa = Math.round(invoice.amount * SAT_TO_FCFA);
  return invoice;
}

export async function payFromBuyerWallet(reference, buyerId) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const { rows } = await client.query('SELECT * FROM invoices WHERE reference = $1 FOR UPDATE', [reference]);
    const row = rows[0];
    if (!row) {
      await client.query('ROLLBACK');
      return { status: 404, error: 'Facture introuvable' };
    }
    const merchant = await client.query('SELECT full_name FROM users WHERE id = $1', [row.user_id]);
    const merchantName = merchant.rows[0]?.full_name || 'Marchand PayChain';
    if (row.status === 'paid') {
      await client.query('COMMIT');
      const invoice = toInvoice(row);
      invoice.merchantName = merchantName;
      invoice.amountFcfa = Math.round(invoice.amount * SAT_TO_FCFA);
      return { invoice, already: true };
    }
    if (row.user_id === buyerId) {
      await client.query('ROLLBACK');
      return { status: 400, error: 'Vous ne pouvez pas payer votre propre QR code.' };
    }

    const wallet = await client.query('SELECT balance_sats FROM wallets WHERE user_id = $1 FOR UPDATE', [buyerId]);
    const balance = Number(wallet.rows[0]?.balance_sats || 0);
    if (balance < Number(row.amount)) {
      await client.query('ROLLBACK');
      return {
        status: 400,
        error: `Solde insuffisant. Il faut ${row.amount} sats (≈ ${Math.round(row.amount * SAT_TO_FCFA)} FCFA) et votre portefeuille contient ${balance} sats.`,
      };
    }

    await client.query(
      `UPDATE wallets SET balance_sats = balance_sats - $2, updated_at = now() WHERE user_id = $1`,
      [buyerId, row.amount]
    );
    await client.query(
      `INSERT INTO ledger (user_id, amount_sats, kind, reference, note)
       VALUES ($1, $2, 'invoice_payment', $3, $4)`,
      [buyerId, -Number(row.amount), reference, `Paiement à ${merchantName}`]
    );

    const image = row.preimage || crypto.randomBytes(32).toString('hex');
    const code = extractShortCode(image);
    const escrowStatus = row.is_escrow ? 'locked' : 'none';
    const updated = await client.query(
      `UPDATE invoices
       SET status = 'paid', preimage = $2, release_code = $3, escrow_status = $4, paid_at = now()
       WHERE reference = $1
       RETURNING *`,
      [reference, image, code, escrowStatus]
    );

    if (row.is_escrow) {
      await client.query(
        `UPDATE wallets SET escrow_sats = escrow_sats + $2, updated_at = now() WHERE user_id = $1`,
        [row.user_id, row.amount]
      );
    } else {
      await client.query(
        `UPDATE wallets SET balance_sats = balance_sats + $2, updated_at = now() WHERE user_id = $1`,
        [row.user_id, row.amount]
      );
    }
    await client.query(
      `INSERT INTO ledger (user_id, amount_sats, kind, reference, note)
       VALUES ($1, $2, $3, $4, $5)`,
      [
        row.user_id,
        row.amount,
        row.is_escrow ? 'escrow_lock' : 'invoice_paid',
        reference,
        row.is_escrow ? 'Fonds consignés sous séquestre' : `Encaissement de ${merchantName}`,
      ]
    );

    await client.query('COMMIT');
    const invoice = toInvoice(updated.rows[0]);
    invoice.merchantName = merchantName;
    invoice.amountFcfa = Math.round(invoice.amount * SAT_TO_FCFA);
    return { invoice };
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function listPendingInvoices(userId) {
  const { rows } = await pool.query(
    `SELECT * FROM invoices
     WHERE user_id = $1 AND status = 'pending' AND bitnob_id IS NOT NULL`,
    [userId]
  );
  return rows.map(toInvoice);
}

export async function settleInvoice(reference, { preimage } = {}) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const { rows } = await client.query('SELECT * FROM invoices WHERE reference = $1 FOR UPDATE', [reference]);
    if (!rows[0]) {
      await client.query('ROLLBACK');
      return null;
    }
    if (rows[0].status === 'paid') {
      await client.query('COMMIT');
      return toInvoice(rows[0]);
    }

    const image = preimage || crypto.randomBytes(32).toString('hex');
    const code = extractShortCode(image);
    const escrowStatus = rows[0].is_escrow ? 'locked' : 'none';
    const updated = await client.query(
      `UPDATE invoices
       SET status = 'paid', preimage = $2, release_code = $3, escrow_status = $4, paid_at = now()
       WHERE reference = $1
       RETURNING *`,
      [reference, image, code, escrowStatus]
    );

    if (rows[0].is_escrow) {
      await client.query(
        `UPDATE wallets SET escrow_sats = escrow_sats + $2, updated_at = now() WHERE user_id = $1`,
        [rows[0].user_id, rows[0].amount]
      );
      await client.query(
        `INSERT INTO ledger (user_id, amount_sats, kind, reference, note)
         VALUES ($1, $2, 'escrow_lock', $3, 'Fonds consignés sous séquestre')`,
        [rows[0].user_id, rows[0].amount, reference]
      );
    } else {
      await client.query(
        `UPDATE wallets SET balance_sats = balance_sats + $2, updated_at = now() WHERE user_id = $1`,
        [rows[0].user_id, rows[0].amount]
      );
      await client.query(
        `INSERT INTO ledger (user_id, amount_sats, kind, reference, note)
         VALUES ($1, $2, 'invoice_paid', $3, 'Encaissement direct')`,
        [rows[0].user_id, rows[0].amount, reference]
      );
    }

    await client.query('COMMIT');
    return toInvoice(updated.rows[0]);
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function releaseInvoice(reference, code) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const { rows } = await client.query('SELECT * FROM invoices WHERE reference = $1 FOR UPDATE', [reference]);
    const row = rows[0];
    if (!row) {
      await client.query('ROLLBACK');
      return { status: 404, error: 'Commande introuvable' };
    }
    if (!row.is_escrow) {
      await client.query('ROLLBACK');
      return { status: 400, error: "Cette facture n'est pas sous séquestre" };
    }
    if (row.status !== 'paid') {
      await client.query('ROLLBACK');
      return { status: 400, error: "Les fonds n'ont pas encore été déposés par le client" };
    }
    if (row.escrow_status === 'released') {
      await client.query('COMMIT');
      return { invoice: toInvoice(row), already: true };
    }

    const provided = String(code || '').trim().toUpperCase();
    const expectedShort = String(row.release_code || '').toUpperCase();
    const expectedFull = String(row.preimage || '').toUpperCase();
    const isValid = Boolean(provided) && (
      provided === expectedShort ||
      provided === expectedFull ||
      (expectedFull && expectedFull.endsWith(provided))
    );
    if (!isValid) {
      await client.query('ROLLBACK');
      return {
        status: 400,
        error: 'Code secret invalide. Demandez au client son code à 4 caractères.',
      };
    }

    const updated = await client.query(
      `UPDATE invoices SET escrow_status = 'released', released_at = now() WHERE reference = $1 RETURNING *`,
      [reference]
    );
    await client.query(
      `UPDATE wallets
       SET escrow_sats = GREATEST(escrow_sats - $2, 0),
           balance_sats = balance_sats + $2,
           updated_at = now()
       WHERE user_id = $1`,
      [row.user_id, row.amount]
    );
    await client.query(
      `INSERT INTO ledger (user_id, amount_sats, kind, reference, note)
       VALUES ($1, $2, 'escrow_release', $3, 'Séquestre débloqué')`,
      [row.user_id, row.amount, reference]
    );
    await client.query('COMMIT');
    return { invoice: toInvoice(updated.rows[0]) };
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function buildWalletPayload(userId) {
  const user = await findUserById(userId);
  const { rows } = await pool.query(
    'SELECT * FROM invoices WHERE user_id = $1 ORDER BY created_at DESC',
    [userId]
  );
  const invoices = rows.map(toInvoice);
  const { rows: credits } = await pool.query(
    `SELECT * FROM ledger WHERE user_id = $1 AND kind IN ('admin_credit', 'invoice_payment') ORDER BY created_at DESC`,
    [userId]
  );

  const invoiceTx = invoices.map((invoice) => ({
    id: invoice.reference,
    reference: invoice.reference,
    title: invoice.description || (invoice.isEscrow ? 'Vente Séquestrée WhatsApp' : 'Encaissement Marchand POS'),
    category: invoice.isEscrow ? 'Commerce Distance (Séquestre)' : 'Encaissement Comptoir POS',
    amountSats: invoice.amount,
    amountFcfa: Math.round(invoice.amount * SAT_TO_FCFA),
    isCredit: true,
    date: invoice.createdAt,
    status: displayStatus(invoice),
    isEscrow: invoice.isEscrow,
    escrowStatus: invoice.escrowStatus,
    releaseCode: invoice.releaseCode,
    preimage: invoice.preimage,
    request: invoice.bolt11,
  }));

  const creditTx = credits.map((entry) => ({
    id: entry.id,
    reference: entry.reference || 'ADMIN',
    title: entry.note || (entry.kind === 'invoice_payment' ? 'Paiement envoyé' : 'Ajustement administrateur'),
    category: entry.kind === 'invoice_payment' ? 'Paiement envoyé' : 'Ajustement administrateur',
    amountSats: Math.abs(Number(entry.amount_sats)),
    amountFcfa: Math.round(Math.abs(Number(entry.amount_sats)) * SAT_TO_FCFA),
    isCredit: Number(entry.amount_sats) >= 0,
    date: entry.created_at,
    status: entry.kind === 'invoice_payment'
      ? 'Payé ⚡'
      : (Number(entry.amount_sats) >= 0 ? 'Crédit admin' : 'Débit admin'),
    isEscrow: false,
    escrowStatus: 'none',
    releaseCode: null,
    preimage: null,
    request: null,
  }));

  const transactions = [...invoiceTx, ...creditTx].sort(
    (a, b) => new Date(b.date).getTime() - new Date(a.date).getTime()
  );
  const locked = invoices.filter((invoice) => invoice.isEscrow && invoice.escrowStatus === 'locked');
  const balanceSats = Number(user.balance_sats || 0);
  const escrowSats = Number(user.escrow_sats || 0);

  return {
    success: true,
    balanceSats,
    balanceFcfa: Math.round(balanceSats * SAT_TO_FCFA),
    escrowSats,
    escrowFcfa: Math.round(escrowSats * SAT_TO_FCFA),
    escrowInvoicesCount: locked.length,
    btcPriceFcfa: 64850000,
    totalInvoices: invoices.length,
    paidInvoicesCount: invoices.filter((invoice) => invoice.status === 'paid').length,
    transactions,
    account: publicUser(user),
  };
}

export async function adminOverview() {
  const { rows } = await pool.query(`
    SELECT
      (SELECT COUNT(*)::int FROM users) AS users,
      (SELECT COUNT(*)::int FROM users WHERE status = 'active') AS active_users,
      (SELECT COUNT(*)::int FROM users WHERE role = 'admin') AS admins,
      (SELECT COALESCE(SUM(balance_sats), 0)::bigint FROM wallets) AS total_balance_sats,
      (SELECT COALESCE(SUM(escrow_sats), 0)::bigint FROM wallets) AS total_escrow_sats,
      (SELECT COUNT(*)::int FROM invoices) AS invoices,
      (SELECT COUNT(*)::int FROM invoices WHERE status = 'paid') AS paid_invoices,
      (SELECT COUNT(*)::int FROM invoices WHERE escrow_status = 'locked') AS locked_invoices
  `);
  const row = rows[0];
  return {
    ...row,
    totalBalanceSats: Number(row.total_balance_sats),
    totalEscrowSats: Number(row.total_escrow_sats),
    totalBalanceFcfa: Math.round(Number(row.total_balance_sats) * SAT_TO_FCFA),
    totalEscrowFcfa: Math.round(Number(row.total_escrow_sats) * SAT_TO_FCFA),
  };
}

export async function listUsers() {
  const { rows } = await pool.query(`
    SELECT u.id, u.phone, u.full_name, u.role, u.status, u.created_at,
           COALESCE(w.balance_sats, 0) AS balance_sats,
           COALESCE(w.escrow_sats, 0) AS escrow_sats,
           (SELECT COUNT(*)::int FROM invoices i WHERE i.user_id = u.id) AS invoice_count
    FROM users u
    LEFT JOIN wallets w ON w.user_id = u.id
    ORDER BY u.created_at DESC
  `);
  return rows.map((row) => ({
    ...publicUser(row),
    invoiceCount: row.invoice_count,
  }));
}

export async function listInvoices(limit = 100) {
  const { rows } = await pool.query(
    `SELECT i.*, u.phone, u.full_name
     FROM invoices i
     JOIN users u ON u.id = i.user_id
     ORDER BY i.created_at DESC
     LIMIT $1`,
    [limit]
  );
  return rows.map((row) => ({
    ...toInvoice(row),
    phone: row.phone,
    fullName: row.full_name,
  }));
}

export async function setUserStatus(userId, status, actorId) {
  if (!['active', 'suspended'].includes(status)) {
    const err = new Error('Statut invalide');
    err.status = 400;
    throw err;
  }
  if (userId === actorId && status === 'suspended') {
    const err = new Error('Vous ne pouvez pas suspendre votre propre compte');
    err.status = 400;
    throw err;
  }
  const { rows } = await pool.query(
    `UPDATE users SET status = $2 WHERE id = $1
     RETURNING id`,
    [userId, status]
  );
  if (!rows[0]) {
    const err = new Error('Utilisateur introuvable');
    err.status = 404;
    throw err;
  }
  return findUserById(userId);
}

export async function adjustWallet(userId, sats, note) {
  const amount = Number(sats);
  if (!Number.isInteger(amount) || amount === 0 || Math.abs(amount) > 100000000) {
    const err = new Error('Montant invalide. Entrez un nombre entier de satoshis, différent de zéro.');
    err.status = 400;
    throw err;
  }
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const { rows } = await client.query('SELECT balance_sats FROM wallets WHERE user_id = $1 FOR UPDATE', [userId]);
    if (!rows[0]) {
      const err = new Error('Portefeuille introuvable');
      err.status = 404;
      throw err;
    }
    if (Number(rows[0].balance_sats) + amount < 0) {
      const err = new Error('Solde insuffisant pour ce débit');
      err.status = 400;
      throw err;
    }
    await client.query(
      `UPDATE wallets SET balance_sats = balance_sats + $2, updated_at = now() WHERE user_id = $1`,
      [userId, amount]
    );
    await client.query(
      `INSERT INTO ledger (user_id, amount_sats, kind, reference, note)
       VALUES ($1, $2, 'admin_credit', 'ADMIN', $3)`,
      [userId, amount, note || (amount > 0 ? 'Crédit administrateur' : 'Débit administrateur')]
    );
    await client.query('COMMIT');
    return findUserById(userId);
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}
