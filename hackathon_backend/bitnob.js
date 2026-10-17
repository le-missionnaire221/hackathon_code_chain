import './env.js';
import crypto from 'node:crypto';
import https from 'node:https';

const { BITNOB_CLIENT_ID: ID, BITNOB_CLIENT_SECRET: SECRET } = process.env;

export function bitnob(method, path, body) {
  return new Promise((resolve, reject) => {
    const payload = body ? JSON.stringify(body) : '';
    const ts = Math.floor(Date.now() / 1000).toString();
    const nonce = crypto.randomBytes(16).toString('hex');

    const signature = crypto
      .createHmac('sha256', String(SECRET))
      .update(`${ID}:${ts}:${nonce}:${payload}`)
      .digest('hex');

    const options = {
      hostname: 'api.bitnob.com',
      port: 443,
      path: path,
      method: method,
      headers: {
        'Content-Type': 'application/json',
        'X-Auth-Client': String(ID),
        'X-Auth-Timestamp': ts,
        'X-Auth-Nonce': nonce,
        'X-Auth-Signature': signature,
        ...(payload ? { 'Content-Length': Buffer.byteLength(payload) } : {})
      }
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          resolve(parsed);
        } catch (e) {
          resolve(data);
        }
      });
    });

    req.on('error', (err) => {
      reject(err);
    });

    if (payload) {
      req.write(payload);
    }
    req.end();
  });
}
