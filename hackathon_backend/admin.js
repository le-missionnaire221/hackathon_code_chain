import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { requireAdmin, requireAuth } from './auth.js';
import { adjustWallet, adminOverview, listInvoices, listUsers, publicUser, setUserStatus } from './db.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function fail(res, error) {
  res.status(error.status || 500).json({ error: error.message || 'Erreur interne' });
}

export function mountAdmin(app) {
  app.get('/admin', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'admin.html'));
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
