# ⚡ MÉMOIRE DE PROJET & JOURNAL DE BORD : HACKATHON CODE & CHAIN DAKAR 2026

---

## 1. Contexte, Rôle & Objectif Global

### 🎯 Le Projet
* **Événement** : Hackathon **Code & Chain Dakar 2026**.
* **Développeur** : Idrissa Coulibaly.
* **Projet** : Solution de paiement instantané **Bitcoin Lightning Network** pour l'Afrique de l'Ouest, propulsée par l'API **Bitnob** et une application mobile native **Flutter**.

### 🤝 Pourquoi et Comment je vous accompagne (Rôle de Coach)
Mon rôle d'assistant et coach technique tout au long de cette aventure a été guidé par 3 principes fondamentaux :
1. **Pas de "boîte noire"** : Chaque ligne de code, chaque en-tête HTTP et chaque choix cryptographique a été expliqué (l'analogie du colis scellé pour les webhooks, le nonce pour éviter les attaques par rejeu, etc.).
2. **Résolution proactive des pièges du monde réel** : Les documentations officielles présentent souvent un cas théorique parfait. En pratique, nous avons rencontré et résolu des anomalies réelles (doublons de Content-Type chez Bitnob, HMAC-SHA512 au lieu de SHA256, instabilité des tunnels de développement, gestion des adresses IPv6 sous Windows).
3. **Sécurité dès la conception (Security by Design)** : Ne jamais exposer de clés privées sur un appareil mobile, vérifier l'intégrité de chaque événement reçu, et comparer les signatures en temps constant (`crypto.timingSafeEqual`) pour bloquer les attaques temporelles.

---

## 2. Architecture du Projet : Pourquoi cette organisation ?

L'architecture repose sur une séparation claire en deux briques complémentaires :

```
                        ┌───────────────────────────────────────────┐
                        │              BITNOB API                   │
                        │ (Sandbox / Testnet Lightning Network)    │
                        └───────▲───────────────────────────┬───────┘
                                │ 1. POST /api/lightning/invoices   │ 4. Webhook (POST /webhook)
                                │    (Génération BOLT11)            │    (lightning.invoice.paid)
                                │                                   ▼
┌───────────────────────────────┴───────────────────────────────────────┐
│                    BACKEND (Node.js / Express)                        │
│             C:\Users\hp\StudioProjects\hackathon_backend              │
│                                                                       │
│  • Protège les secrets (.env : CLIENT_SECRET, WEBHOOK_SECRET)         │
│  • Valide cryptographiquement les signatures HMAC-SHA512              │
│  • Maintient l'état des factures (pending -> paid)                    │
│  • Expose l'API locale avec support CORS                              │
└───────▲───────────────────────────────────────────────────────┬───────┘
        │ 2. POST /invoice                                      │ 5. GET /invoice/:ref/status
        │    (Montant en Sats)                                  │    (Polling statut paiement)
        │                                                       ▼
┌───────┴───────────────────────────────────────────────────────────────┐
│                     FRONTEND MOBILE (Flutter)                         │
│             C:\Users\hp\StudioProjects\hackathon_mobile               │
│                                                                       │
│  • UI Dark Mode Fintech moderne aux couleurs Bitcoin / Lightning ⚡    │
│  • Génération & Dessin dynamique du QR Code Lightning BOLT11          │
│  • Bouton de copie du code BOLT11 pour les portefeuilles externes     │
│  • Écoute en temps réel et bascule instantanée sur écran de succès    │
└───────────────────────────────────────────────────────────────────────┘
```

### Pourquoi le Backend est-il obligatoire ?
1. **Confidentialité des clés privées** : Une application mobile compilée (APK Android) peut être décompilée. Si vos clés secrètes `BITNOB_CLIENT_SECRET` et `BITNOB_WEBHOOK_SECRET` s'y trouvent, elles sont compromises. Le backend sert de coffre-fort.
2. **Réception des Webhooks** : Bitnob envoie des requêtes HTTPS pour avertir qu'une facture est payée. Un smartphone derrière un réseau mobile (4G Orange/Free/Expresso) ou Wi-Fi n'a pas d'adresse IP publique fixe et ne peut pas recevoir d'appels entrants venant d'Internet.

---

## 3. Historique Chronologique & Défis Techniques Résolus

### Étape 1 : Initialisation & Appel Sécurisé à Bitnob
* **Problème initial** : Timeout de connexion Node.js vers `api.bitnob.com` sous Windows.
* **Solution** : Ajout de `dns.setDefaultResultOrder('ipv4first')` pour forcer Node.js à privilégier l'IPv4 sur les box internet locales.
* **Authentification custom** (`bitnob.js`) : Implémentation du protocole d'authentification Bitnob par signature dynamique d'en-tête :
  $$\text{Signature} = \text{HMAC-SHA256}(\text{SECRET}, \text{ID} : \text{timestamp} : \text{nonce} : \text{payload})$$

### Étape 2 : Création de Client & Facture Lightning
* **Route `/customer`** : Enregistrement d'un utilisateur auprès de Bitnob (`POST /api/customers`).
* **Route `/invoice`** : Utilisation de l'endpoint officiel `/api/lightning/invoices` générant un montant en Satoshis et retournant une chaîne BOLT11 (`lntb10u1...`).

### Étape 3 : Le Grand Défi du Webhook & Tunnels
Pour que Bitnob puisse joindre notre machine locale en développement, nous devions ouvrir une porte sur Internet :
1. **Échec de `localtunnel`** : Le domaine `loca.lt` générait des erreurs 408/503 et un écran d'avertissement bloquant les requêtes automatisées de Bitnob.
2. **Essai avec `cloudflared`** : Cloudflare Tunnel a permis les premiers tests, mais les serveurs de livraison Bitnob (Wand) ont révélé deux particularités non documentées :
   * **En-tête Content-Type dupliqué** : Bitnob envoyait `Content-Type: application/json, application/json`. Express rejetait la requête (`body: undefined`).
   * **Algorithme HMAC-SHA512** : La signature envoyée dans `x-bitnob-signature` comportait 128 caractères hexadécimaux (SHA-512) et non 64 (SHA-256).
3. **Le Correctif Définitif** :
   * Configuration du parser Express : `type: (req) => (req.headers['content-type'] || '').includes('json')`.
   * Détection automatique de la taille de signature : bascule dynamique entre SHA-256 et SHA-512.
   * Comparaison sécurisée `crypto.timingSafeEqual` pour contrer les attaques par canal auxiliaire.
4. **Validation Réelle par Bitnob** : Réception avec succès d'un événement test Bitnob, authentifié et validé avec un code **HTTP 200**.

### Étape 4 : Évolution vers Flutter Mobile
* Création de `C:\Users\hp\StudioProjects\hackathon_backend` et `C:\Users\hp\StudioProjects\hackathon_mobile`.
* Ajout du support **CORS** et d'un point d'accès `GET /invoice/:reference/status` pour permettre à l'application mobile de vérifier en arrière-plan si le paiement a été honoré.
* Implémentation de l'application mobile Flutter avec rendu vectoriel de QR Code (`qr_flutter`) et polling réactif.

---

## 4. Inventaire des Fichiers du Projet

### A. Dossier Backend (`hackathon_backend`)
| Fichier | Rôle |
|---|---|
| `.env` | Variables d'environnement secrètes (`BITNOB_CLIENT_ID`, `BITNOB_CLIENT_SECRET`, `BITNOB_WEBHOOK_SECRET`). |
| `bitnob.js` | Module d'appel à l'API Bitnob avec génération dynamique des signatures d'authentification. |
| `index.js` | Serveur Express : écoute sur le port 3000, gère les routes `/customer`, `/invoice`, `/invoice/:reference/status`, et `/webhook`. |
| `package.json` | Dépendances Node.js (`express`, `dotenv`). |

### B. Dossier Mobile (`hackathon_mobile`)
| Fichier | Rôle |
|---|---|
| `pubspec.yaml` | Configuration Flutter avec dépendances `qr_flutter` et `http`. |
| `lib/main.dart` | Application Flutter complète (Thème sombre Bitcoin, sélection de montants, génération de facture, affichage QR Code, polling et écran de succès). |

---

## 5. Guide d'Exécution : Comment Lancer la Solution

### Étape 1 : Démarrer le Serveur Backend
Dans un premier terminal :
```powershell
cd C:\Users\hp\StudioProjects\hackathon_backend
node index.js
```
*Le terminal doit afficher :*
`🚀 Serveur démarré et en écoute sur http://localhost:3000`

### Étape 2 (Optionnel - Pour recevoir les Webhooks réels depuis Internet) :
Si vous voulez que Bitnob envoie des paiements depuis l'extérieur vers votre machine locale :
```powershell
ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=30 -R 80:localhost:3000 nokey@localhost.run
```
Copiez l'URL HTTPS générée (ex : `https://xxxxx.lhr.life/webhook`) dans votre tableau de bord Bitnob (section Webhooks).

### Étape 3 : Démarrer l'Application Flutter
1. Ouvrez **Android Studio**.
2. Faites **File > Open** et sélectionnez le dossier :
   `C:\Users\hp\StudioProjects\hackathon_mobile`
3. Choisissez votre appareil (émulateur Android, navigateur Chrome, ou smartphone physique connecté en USB).
4. Cliquez sur **Run** (ou tapez dans un terminal : `flutter run`).

> **Astuce de connexion Backend dans l'application** :
> * Sur un **émulateur Android**, l'adresse du backend est `http://10.0.2.2:3000`.
> * Sur **Chrome / Desktop**, l'adresse est `http://localhost:3000`.
> * Sur un **vrai smartphone**, appuyez sur l'icône d'engrenage ⚙️ en haut à droite de l'application et entrez l'adresse IP locale de votre PC (ex: `http://192.168.1.XX:3000`) ou l'URL de votre tunnel.

---

## 6. Conseils pour la Démonstration devant le Jury du Hackathon

1. **Raconter une histoire (Storytelling)** :
   * "En Afrique de l'Ouest, payer instantanément en ligne sans carte bancaire internationale est un frein majeur. Avec Bitcoin Lightning Network et Bitnob, nous permettons des micropaiements instantanés avec des frais quasi nuls."
2. **La Démo en Live** :
   * Entrez un montant (ex : 500 Satoshis).
   * Cliquez sur **GÉNÉRER LE QR CODE ⚡**.
   * Montrez le QR Code au jury : il s'agit d'une vraie facture Lightning BOLT11 standard.
   * Invitez un membre du jury à scanner le QR Code avec son application Lightning préférée, ou utilisez un portefeuille testnet pour régler la facture.
   * Dès que le réseau valide la transaction, l'application réagit **sans rechargement de page** et affiche le badge vert **"Paiement Reçu !"**.
3. **Mettre en avant la robustesse technique** :
   * Architecture sécurisée (aucun secret dans l'application mobile).
   * Validation cryptographique HMAC-SHA512 de chaque webhook.
   * Traitement idempotent évitant tout double-paiement.

---

*Document généré le 16 octobre 2026 pour Idrissa Coulibaly — Hackathon Code & Chain Dakar.*
