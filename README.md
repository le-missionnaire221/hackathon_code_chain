# ⚡ Hackathon Code & Chain Dakar 2026 - Lightning Payment Solution

Solution complète de paiement instantané sur le réseau **Bitcoin Lightning Network** pour l'Afrique de l'Ouest, propulsée par l'API **Bitnob** et une application mobile native **Flutter**.

---

## 🏗️ Architecture du Projet

Le projet est articulé en deux composantes :

* **`hackathon_backend/` (Node.js & Express)** :
  * Sécurise les clés d'API secrètes et gère les appels à l'API Bitnob.
  * Génère les factures Lightning BOLT11 (`POST /invoice`).
  * Réceptionne et vérifie cryptographiquement les Webhooks de Bitnob via HMAC-SHA512 (`POST /webhook`).
  * Maintient en mémoire l'état des paiements et expose un endpoint de statut (`GET /invoice/:reference/status`).

* **`hackathon_mobile/` (Flutter)** :
  * Interface mobile moderne Dark-Mode aux couleurs de Bitcoin.
  * Sélection ou saisie libre de montants en Satoshis.
  * Rendu vectoriel dynamique du **QR Code Lightning** via `qr_flutter`.
  * Copie en un clic du code de paiement BOLT11.
  * Détection en temps réel du paiement (polling) et affichage instantané de l'écran de succès.

---

## 🚀 Démarrage Rapide

### 1. Configuration du Backend

```bash
cd hackathon_backend
npm install
```

Créez un fichier `.env` basé sur `.env.example` :
```env
BITNOB_CLIENT_ID=votre_client_id
BITNOB_CLIENT_SECRET=votre_client_secret
BITNOB_WEBHOOK_SECRET=votre_webhook_secret
```

Lancez le serveur :
```bash
node index.js
```
Le serveur écoute sur `http://localhost:3000`.

### 2. Lancement de l'Application Mobile Flutter

```bash
cd hackathon_mobile
flutter pub get
flutter run
```

> **Astuce réseau pour les tests** :
> * Sur **émulateur Android**, l'URL du backend est `http://10.0.2.2:3000`.
> * Sur **vrai smartphone**, configurez l'adresse IP de votre PC dans l'application via l'icône paramètres ⚙️ (ex: `http://192.168.1.XX:3000`).

---

## 🔒 Sécurité & Cryptographie
* **Zéro secret côté mobile** : Toutes les clés API restent sur le serveur Node.js.
* **Vérification HMAC-SHA512** : Les webhooks reçus de Bitnob sont authentifiés mathématiquement avant d'être traités.
* **Comparaison en temps constant** : Utilisation de `crypto.timingSafeEqual` pour neutraliser les attaques temporelles (timing attacks).

---

## 📄 Documentation
Consultez le fichier [MEMOIRE_PROJET_HACKATHON.md](MEMOIRE_PROJET_HACKATHON.md) pour retrouver l'historique complet, les choix d'architecture et les défis techniques résolus lors du développement.

---
*Développé par Idrissa Coulibaly — Code & Chain Dakar 2026*
