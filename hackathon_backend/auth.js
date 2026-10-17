import './env.js';
import jwt from 'jsonwebtoken';
import { createUser, findUserById, findUserByPhone, publicUser, verifyPassword } from './db.js';

function secret() {
  return process.env.JWT_SECRET || 'paychain-dev-secret-change-me';
}

export function signToken(user) {
  return jwt.sign(
    { sub: user.id, role: user.role, phone: user.phone },
    secret(),
    { expiresIn: '30d' }
  );
}

export async function requireAuth(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) return res.status(401).json({ error: 'Connexion requise' });
  try {
    const payload = jwt.verify(token, secret());
    const user = await findUserById(payload.sub);
    if (!user || user.status !== 'active') {
      return res.status(401).json({ error: 'Compte suspendu ou introuvable' });
    }
    req.user = user;
    next();
  } catch {
    return res.status(401).json({ error: 'Session invalide' });
  }
}

export function requireAdmin(req, res, next) {
  if (req.user?.role !== 'admin') {
    return res.status(403).json({ error: "Réservé à l'administrateur" });
  }
  next();
}

export function mountAuth(app) {
  app.post('/auth/register', async (req, res) => {
    try {
      const user = await createUser({
        phone: req.body?.phone,
        password: req.body?.password,
        fullName: req.body?.fullName,
      });
      res.status(201).json({
        success: true,
        token: signToken(user),
        user: publicUser(user),
      });
    } catch (error) {
      res.status(error.status || 500).json({ error: error.message || 'Inscription impossible' });
    }
  });

  app.post('/auth/login', async (req, res) => {
    try {
      const user = await findUserByPhone(req.body?.phone);
      if (!user || !(await verifyPassword(user, req.body?.password))) {
        return res.status(401).json({ error: 'Numéro ou mot de passe incorrect' });
      }
      if (user.status !== 'active') {
        return res.status(403).json({ error: 'Ce compte est suspendu' });
      }
      const full = await findUserById(user.id);
      res.json({
        success: true,
        token: signToken(full),
        user: publicUser(full),
      });
    } catch (error) {
      res.status(500).json({ error: 'Connexion impossible' });
    }
  });

  app.get('/auth/me', requireAuth, (req, res) => {
    res.json({ success: true, user: publicUser(req.user) });
  });
}
