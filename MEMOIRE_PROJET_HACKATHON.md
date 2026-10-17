# ⚡ MÉMOIRE DE PROJET : PAYCHAIN DAKAR
### Hackathon Code & Chain Dakar 2026

---

## 1. Vision & Positionnement Stratégique

* **Événement** : Hackathon **Code & Chain Dakar 2026**.
* **Développeur** : Idrissa Coulibaly (`@le-missionnaire221`).
* **Nom du Produit** : **PayChain Dakar** ⚡
* **Proposition de Valeur** : La première passerelle de paiement omnicanale (TPE de Comptoir + Facturation WhatsApp) propulsée par Bitcoin Lightning Network et l'API Bitnob, intégrant une garantie de livraison anti-arnaque certifiée par Preimage.

> **Slogan du Pitch :**  
> *"Wave a digitalisé le cash local à l'intérieur du Sénégal. **PayChain Dakar connecte les commerçants et freelances sénégalais au reste du monde** sans carte bancaire, sans délai SWIFT et sans intermédiaire."*

---

## 2. Les Problèmes Économiques Réels Résolus

| Problème Réel en Afrique | Situation Actuelle | Solution Apportée par PayChain Dakar |
|---|---|---|
| **Frais Transfrontaliers** | Western Union / MoneyGram prennent **8 % à 12 %** de frais sur chaque transfert. | **Frais quasi nuls** (< 1 FCFA / fraction de centime) via le protocole Lightning. |
| **Exclusion Bancaire** | 75 % de la population n'a pas de compte bancaire ou de carte Visa/Mastercard internationale. | **Aucune barrière** : un smartphone avec QR Code BOLT11 suffit pour encaisser n'importe qui dans le monde. |
| **Délais de Règlement** | Les virements bancaires internationaux SWIFT prennent **3 à 5 jours ouvrés**. | **Règlement instantané (Zero-Conf)** en **1 à 3 secondes**, 24h/24, 7j/7. |
| **Le Social Commerce (WhatsApp / Instagram)** | 90 % des jeunes commerçants vendent sur les réseaux sociaux et perdent les clients de la diaspora qui ne peuvent pas payer par Wave. | **Facturation WhatsApp en 1 clic** : envoi de factures sécurisées directement dans la discussion WhatsApp du client. |
| **Arnaques de Livraison (Le Défi de la Confiance)** | Acheteurs et vendeurs se méfient ("Livre d'abord vs Paie d'abord"). | **Preuve de Livraison Certifiée par Preimage** : la signature cryptographique prouve irrévocablement le déblocage des fonds. |

---

## 3. Architecture Technique Réelle (Zero Mock)

```
┌────────────────────────────────────────────────────────────────────────┐
│                        BITNOB LIGHTNING API                            │
│                 (Sandbox / Testnet Lightning Network)                  │
└───────────────▲────────────────────────────────────────▲───────────────┘
                │ 1. POST /api/lightning/invoices        │ 4. Polling & Status
                │    (Génération BOLT11)                 │    (Preimage proof)
┌───────────────┴────────────────────────────────────────┴───────────────┐
│                     BACKEND (Node.js / Express)                        │
│            C:\Users\hp\StudioProjects\hackathon_backend                 │
│                                                                        │
│  • Port d'écoute : 5000 (évite tout conflit de port)                   │
│  • Sécurité Cryptographique : HMAC-SHA256 Client Auth + HMAC-SHA512    │
│  • API Réelle : GET /wallet, POST /invoice, GET /invoice/:ref/status   │
│  • Requêtes natives : node:https (connexion en 200ms sous Windows)     │
└────────────────────────────────▲───────────────────────────────────────┘
                                 │
                                 │ REST HTTP (JSON)
                                 ▼
┌────────────────────────────────────────────────────────────────────────┐
│                    FRONTEND MOBILE & WEB (Flutter)                     │
│             C:\Users\hp\StudioProjects\hackathon_mobile                 │
│                                                                        │
│  • Architecture Clean Modulaire : core/, models/, screens/, widgets/   │
│  • Design Neobank Moderne : Thème Bleu Royal & Blanc Fintech           │
│  • Mode TPE Comptoir : Rendu vectoriel QR Code BOLT11 dynamique       │
│  • Mode Vente à Distance : Partage WhatsApp en 1 clic                  │
│  • Garantie Anti-Arnaque : Affichage et copie de la Preimage           │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Organisation du Code Flutter (`hackathon_mobile/lib/`)

```
hackathon_mobile/lib/
├── core/
│   ├── constants/
│   │   ├── app_colors.dart         (Palette Bleu Neobank, Vert WhatsApp, Dégradés)
│   │   ├── app_constants.dart      (Taux de change SATS/FCFA, URLs, presets)
│   │   └── app_theme.dart          (ThemeData Material 3 Neobank)
│   └── services/
│       └── api_service.dart        (Appels HTTP isolés /wallet, /invoice, /health)
├── models/
│   └── transaction_item.dart       (Modèle TransactionItem avec fromJson)
├── screens/
│   ├── main_navigation_screen.dart (Coordination des onglets et état partagé)
│   ├── wallet_tab.dart             (Solde réel Bitnob, actions rapides, bannières)
│   ├── pos_tab.dart                (Terminal TPE Comptoir + Facturation WhatsApp)
│   ├── history_tab.dart            (Historique réel des factures Bitnob)
│   └── settings_tab.dart           (Supervision du nœud et test de latence ping)
├── widgets/
│   ├── transaction_card.dart       (Composant unitaire de transaction)
│   ├── receipt_bottom_sheet.dart   (Reçu officiel avec preuve cryptographique)
│   ├── blink_address_sheet.dart    (Adresse Lightning personnelle Blink)
│   └── whatsapp_share_modal.dart   (Modal de partage WhatsApp et reçu de livraison)
└── main.dart                       (Point d'entrée minimaliste et épuré - 20 lignes)
```

---

## 5. Guide du Pitch pour Gagner le Hackathon (2 Minutes)

### [0:00 - L'Accroche & Le Problème]
> *"Bonjour chers membres du jury. Aujourd'hui en Afrique de l'Ouest, Wave a réglé le problème du paiement local, mais nous avons un mur invisible : **comment un commerçant à Dakar ou un freelance peut-il être payé par un client à Paris ou New York ?**
> PayPal bloque le Sénégal. Les banques refusent les terminaux TPE aux petites PME. Et sur WhatsApp ou Instagram, les arnaques de livraison bloquent les ventes à distance."*

### [0:40 - La Solution PayChain Dakar]
> *"Voici **PayChain Dakar**. Une infrastructure de paiement omnicanale propulsée par le protocole Lightning Network et l'API Bitnob.  
> PayChain transforme n'importe quel smartphone en **Terminal de Caisse Mondial** pour les ventes en boutique, et en **Générateur de Factures WhatsApp** pour les ventes à distance, avec une garantie anti-arnaque fondée sur la Preimage cryptographique."*

### [1:00 - La Démo en Direct (Live Demo)]
> 1. *"Je choisis un montant : 500 Satoshis (~ 325 FCFA). Je tape le produit : 'Sac Artisanal en Cuir'.*
> 2. *Si le client est en boutique : il scanne directement mon **QR Code BOLT11**.*
> 3. *Si le client est à distance : je clique sur **'Partager sur WhatsApp'**, le message est prêt.*
> 4. *(Le paiement se règle en 4 secondes)*
> 5. *Regardez : l'écran bascule en vert ! Nous recevons la **Preimage cryptographique**. C'est le reçu officiel irrévocable qui protège le commerçant et l'acheteur contre toute contestation."*

### [1:45 - Conclusion & Impact]
> *"Le code est 100 % opérationnel, sans aucune donnée fictive, modulaire, open source sur GitHub et prêt pour la production. Avec PayChain Dakar, nous connectons l'économie sénégalaise au marché mondial. Merci !"*

---
*Document finalisé pour le Hackathon Code & Chain Dakar 2026.*
