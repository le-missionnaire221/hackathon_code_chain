# PayChain Dakar

Paiements Lightning pour commerçants en Afrique de l’Ouest — **Code & Chain Dakar 2026**.

Application Flutter + API Node.js / Express + PostgreSQL, branchée sur **Bitnob** (sandbox Lightning). Un marchand encaisse sur place avec un QR, ou à distance via un lien partageable ; l’argent peut rester bloqué jusqu’à la livraison.

**Développeur :** Idrissa Coulibaly ([@le-missionnaire221](https://github.com/le-missionnaire221))  
**API en ligne :** [https://hackathon-code-chain.onrender.com](https://hackathon-code-chain.onrender.com)

---

## Ce que fait l’app

| Parcours | Description |
| --- | --- |
| **Comptes** | Inscription / connexion (nom, téléphone, mot de passe). Session conservée. Chaque compte a son portefeuille. |
| **Encaisser sur place** | Montant en FCFA → facture Lightning Bitnob → QR. Le client paie avec PayChain, Blink, Phoenix, etc. |
| **Livraison (séquestre)** | Même facture, mais l’argent est gardé. Le client reçoit un code à 4 caractères ; le marchand le saisit à la remise du colis pour débloquer le solde. |
| **Lien de paiement** | `/pay/{référence}` partageable (WhatsApp, SMS, e-mail…). Sur PC : QR Lightning. Sur téléphone : bouton Payer (ouvre PayChain s’il est installé, sinon choix de portefeuille). |
| **Admin** | Dashboard pour comptes, soldes, ajustements. |
| **Docs API** | Swagger UI. |

Taux affiché dans l’app : **1 sat ≈ 0,65 FCFA**.

---

## Structure

```
hackathon_code_chain/
├── hackathon_backend/   # API Express, Bitnob, PostgreSQL, page /pay, admin, Swagger
├── hackathon_mobile/    # App Flutter (POS, portefeuille, scan, deep link paychain://)
├── render.yaml          # Blueprint Render (optionnel)
└── MEMOIRE_PROJET_HACKATHON.md
```

- **Backend** : clés Bitnob côté serveur uniquement, JWT, HMAC webhooks, factures en base.
- **Mobile** : pointe par défaut vers l’API Render ; deep link `paychain://pay/{référence}`.

---

## Stack

- Node.js (ESM), Express 5, `pg`, JWT, bcrypt  
- Flutter (Material), `mobile_scanner`, `qr_flutter`, `app_links`, `share_plus`  
- PostgreSQL  
- Bitnob Lightning API (sandbox)  
- Hébergement API : Render  

---

## Démarrage local

### Backend

```bash
cd hackathon_backend
npm install
cp .env.example .env
```

Renseignez au minimum dans `.env` :

- `DATABASE_URL` (ex. `postgresql://postgres:…@localhost:5432/hackathon`)
- `BITNOB_CLIENT_ID` / `BITNOB_CLIENT_SECRET` / `BITNOB_WEBHOOK_SECRET`
- `JWT_SECRET`, `ADMIN_PHONE`, `ADMIN_PASSWORD`
- `PORT=5000`

```bash
node index.js
```

- API : `http://localhost:5000`  
- Santé : `GET /health`  
- Swagger : `http://localhost:5000/docs`  
- Admin : `http://localhost:5000/admin`  

### Mobile

```bash
cd hackathon_mobile
flutter pub get
flutter run
```

L’app utilise `https://hackathon-code-chain.onrender.com` par défaut. Pour tester contre le serveur local, lancez l’API accessible depuis le téléphone (même Wi‑Fi) et adaptez l’URL de build si besoin.

APK release :

```bash
flutter build apk --release
```

Fichier : `hackathon_mobile/build/app/outputs/flutter-apk/app-release.apk`

---

## Déploiement (Render)

Service web Node sur la branche `main`, démarrage `node index.js` (racine du dépôt ou `hackathon_backend` selon la config). Variables d’environnement sur Render : `DATABASE_URL`, Bitnob, `JWT_SECRET`, admin, `PORT` (fourni par Render).

Whitelist les plages IP sortantes Render dans la clé API Bitnob sandbox.

---

## Endpoints utiles

| Méthode | Chemin | Rôle |
| --- | --- | --- |
| `POST` | `/auth/register`, `/auth/login` | Comptes |
| `GET` | `/wallet` | Solde et historique (auth) |
| `POST` | `/invoice` | Créer une facture Lightning (`isEscrow` pour livraison) |
| `GET` | `/invoice/:ref/status` | Statut public (sans code de déblocage) |
| `GET` | `/invoice/:ref/client-view` | Vue client après paiement (code si payé) |
| `POST` | `/invoice/lookup` | Résoudre un QR / lien / référence |
| `POST` | `/invoice/:ref/pay` | Payer depuis un compte PayChain (auth) |
| `POST` | `/invoice/:ref/release` | Débloquer le séquestre avec le code (marchand) |
| `GET` | `/pay/:ref` | Page web de paiement |
| `POST` | `/webhook` | Webhooks Bitnob (HMAC) |

---

## Sécurité

- Secrets Bitnob et JWT uniquement côté serveur (jamais dans l’app).  
- Webhooks vérifiés en HMAC (`timingSafeEqual`).  
- Le code de déblocage n’est pas renvoyé sur le statut public du marchand ; il apparaît pour l’acheteur après paiement.  

Ne committez jamais le fichier `.env`.

---

## Mémoire technique

Détail des choix et du parcours hackathon : [MEMOIRE_PROJET_HACKATHON.md](MEMOIRE_PROJET_HACKATHON.md).

---

*PayChain Dakar — Code & Chain Dakar 2026 — Idrissa Coulibaly*
