import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { requireAdmin, requireAuth } from './auth.js';
import {
  adjustWallet,
  adminOverview,
  getAppBranding,
  listInvoices,
  listUsers,
  publicUser,
  setUserStatus,
  updateAppBranding,
} from './db.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const publicDir = path.join(__dirname, 'public');
const uploadsDir = path.join(publicDir, 'uploads');

function fail(res, error) {
  res.status(error.status || 500).json({ error: error.message || 'Erreur interne' });
}

function ensureUploadsDir() {
  if (!fs.existsSync(uploadsDir)) fs.mkdirSync(uploadsDir, { recursive: true });
}

function saveLogoFromDataUrl(dataUrl) {
  const match = String(dataUrl || '').match(/^data:image\/(png|jpeg|jpg|webp);base64,(.+)$/i);
  if (!match) {
    const err = new Error('Logo invalide. Utilisez une image PNG, JPG ou WEBP.');
    err.status = 400;
    throw err;
  }
  const ext = match[1].toLowerCase() === 'jpeg' ? 'jpg' : match[1].toLowerCase();
  const buffer = Buffer.from(match[2], 'base64');
  if (buffer.length > 2_500_000) {
    const err = new Error('Logo trop lourd (max 2,5 Mo).');
    err.status = 400;
    throw err;
  }
  ensureUploadsDir();
  const fileName = `logo_${Date.now()}.${ext}`;
  fs.writeFileSync(path.join(uploadsDir, fileName), buffer);
  return `uploads/${fileName}`;
}

export function mountAdmin(app) {
  app.get('/admin', (req, res) => {
    res.sendFile(path.join(publicDir, 'admin.html'));
  });

  app.get('/admin/api/overview', requireAuth, requireAdmin, async (req, res) => {
    try {
      res.json({ success: true, overview: await adminOverview() });
    } catch (error) {
      fail(res, error);
    }
  });

  app.get('/admin/api/users', requireAuth, requireAdmin, async (req, res) => {
    try {
      res.json({ success: true, users: await listUsers() });
    } catch (error) {
      fail(res, error);
    }
  });

  app.get('/admin/api/invoices', requireAuth, requireAdmin, async (req, res) => {
    try {
      res.json({ success: true, invoices: await listInvoices(150) });
    } catch (error) {
      fail(res, error);
    }
  });

  app.get('/admin/api/branding', requireAuth, requireAdmin, async (req, res) => {
    try {
      res.json({ success: true, branding: await getAppBranding() });
    } catch (error) {
      fail(res, error);
    }
  });

  app.post('/admin/api/branding', requireAuth, requireAdmin, async (req, res) => {
    try {
      const appName = req.body?.appName;
      let logoFile;
      if (req.body?.logoDataUrl) {
        logoFile = saveLogoFromDataUrl(req.body.logoDataUrl);
      }
      const branding = await updateAppBranding({ appName, logoFile });
      res.json({ success: true, branding });
    } catch (error) {
      fail(res, error);
    }
  });

  app.post('/admin/api/users/:id/status', requireAuth, requireAdmin, async (req, res) => {
    try {
      const user = await setUserStatus(req.params.id, req.body?.status, req.user.id);
      res.json({ success: true, user: publicUser(user) });
    } catch (error) {
      fail(res, error);
    }
  });

  app.post('/admin/api/users/:id/credit', requireAuth, requireAdmin, async (req, res) => {
    try {
      const user = await adjustWallet(req.params.id, Number(req.body?.sats), req.body?.note);
      res.json({ success: true, user: publicUser(user) });
    } catch (error) {
      fail(res, error);
    }
  });
}
