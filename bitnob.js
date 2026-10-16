import crypto from 'node:crypto';
import 'dotenv/config'; // Charge automatiquement le fichier .env
import dns from 'node:dns';

dns.setDefaultResultOrder('ipv4first');

const { BITNOB_CLIENT_ID: ID, BITNOB_CLIENT_SECRET: SECRET } = process.env;

// Chez Bitnob, la Sandbox et la Prod utilisent la même adresse URL ! 
// C'est ta clé (qui commence par prd:sandbox_) qui indique que tu es en mode test.
const BASE = 'https://api.bitnob.com';

export async function bitnob(method, path, body) {
  const payload = body ? JSON.stringify(body) : '';

  // 1. Le timestamp (l'heure exacte)
  const ts = Math.floor(Date.now() / 1000).toString();

  // 2. Le nonce (la valeur unique pour éviter les doublons)
  const nonce = crypto.randomBytes(16).toString('hex');

  // 3. La signature HMAC-SHA256 (Le coffre-fort mathématique)
  // On utilise le SECRET pour signer, mais on ne l'envoie JAMAIS.
  const signature = crypto
    .createHmac('sha256', String(SECRET))
    .update(`${ID}:${ts}:${nonce}:${payload}`)
    .digest('hex');

  // 4. L'envoi de la requête avec les headers de sécurité
  const res = await fetch(BASE + path, {
    method,
    headers: {
      'Content-Type': 'application/json',
      'X-Auth-Client': String(ID),
      'X-Auth-Timestamp': ts,
      'X-Auth-Nonce': nonce,
      'X-Auth-Signature': signature,
    },
    body: payload || undefined,
  });

  return res.json();
}

// Petit test si on exécute ce fichier directement :
if (process.argv[1]?.endsWith('bitnob.js')) {
    console.log("Test de connexion à l'API Bitnob...");
    bitnob('GET', '/api/whoami').then(console.log).catch(console.error);
}
