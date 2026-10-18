# RAK TAK CASH — Contexte pour la présentation PowerPoint

**À envoyer à l’équipe** (design / slides / pitch jury).  
Hackathon **Code & Chain Dakar 2026**.

---

## Slogan officiel

# « Encaisse. Envoie. En confiance. »

*(variante courte sur slide titre : **Rak Tak. Cash. C’est parti.**)*

**Sous-titre / accroche :**  
Paiements Lightning pour les commerçants du Sénégal et d’Afrique de l’Ouest.

---

## En une phrase

**RAK TAK CASH** est une application qui permet aux commerçants d’**encaisser** (boutique ou livraison), de **recevoir** et d’**envoyer** de l’argent via **Bitcoin Lightning**, en **FCFA**, avec un portefeuille par compte — rapide, simple, et sécurisé jusqu’à la livraison.

---

## Identité

| | |
|--|--|
| **Nom** | RAK TAK CASH |
| **Slogan** | Encaisse. Envoie. En confiance. |
| **Logo** | Bleu + jaune (éclair + flèche) — fichier : `hackathon_mobile/assets/logo_rak_tak_cash.png` |
| **Développeur** | Idrissa Coulibaly (@le-missionnaire221) |
| **Événement** | Code & Chain Dakar 2026 |
| **API démo** | https://hackathon-code-chain.onrender.com |
| **Admin** | https://hackathon-code-chain.onrender.com/admin |
| **Docs** | https://hackathon-code-chain.onrender.com/docs |

---

## Le problème (slide “Pourquoi ?”)

- Frais élevés / délais des paiements classiques  
- Peu de solutions simples pour le **petit commerce** et la **vente WhatsApp / livraison**  
- Manque de **confiance** : le client paie, le marchand envoie le colis… et inversement  
- Besoin d’un outil **mobile**, en **français**, adapté à Dakar et à la sous-région  

---

## La solution (slide “Quoi ?”)

RAK TAK CASH = **portefeuille + TPE Lightning + livraison sécurisée + envoi entre comptes**.

| Besoin | Réponse dans l’app |
|--------|-------------------|
| Encaisser en boutique | QR Lightning (Bitnob) |
| Vendre à distance | Lien `/pay/...` + **séquestre** jusqu’à livraison |
| Recevoir d’un proche / autre compte | QR **Recevoir** |
| Payer | **Scanner** une facture ou une adresse |
| Suivre l’argent | **Reçus** (reçu = vert, payé = rouge) |
| Gérer l’identité | **Profil** |
| Pilotage | **Admin** (comptes, soldes, nom & logo) |

---

## Les 4 onglets de l’app

1. **Accueil** — solde FCFA / SATS, actions rapides, filtres transactions  
2. **Encaisser** — mode *Sur place* ou *Livraison*  
3. **Reçus** — historique clair (+ / −)  
4. **Profil** — infos compte, adresse Recevoir, connexion  

---

## Démo à raconter (script jury — 2 minutes)

### Scène A — Boutique (TPE)
1. Marchand ouvre **Encaisser** → *Sur place* → tape 1 000 FCFA  
2. Client **scanne** le QR (ou paie via Blink / Phoenix / lien)  
3. Paiement confirmé → argent sur le solde marchand  

### Scène B — Livraison WhatsApp (anti-arnaque)
1. Marchand → **Encaisser** → *Livraison* → crée le paiement  
2. Envoie le **lien** au client  
3. Client paie → argent **gardé** (séquestre)  
4. Client reçoit un **code**  
5. À la remise du colis → marchand entre le code dans **Reçus** → argent **libéré**  

### Scène C — Recevoir / Envoyer entre comptes
1. Compte A → **Recevoir** → montre le QR  
2. Compte B → **Scanner** → montant → Envoyer  
3. A voit **« Paiement reçu »** sans recharger l’app  

---

## Points techniques (1 slide max, pour les geeks)

- **Mobile :** Flutter (Android + Chrome)  
- **Backend :** Node.js / Express + PostgreSQL  
- **Lightning :** Bitnob (sandbox) pour les **factures Encaisser**  
- **Recevoir P2P :** transfert interne entre portefeuilles de l’app (pas Bitnob)  
- **Règles facture :** 1 seul paiement · validité **24 h**  
- **Branding :** nom + logo changeables depuis l’**admin**  
- **Taux affiché :** 1 sat ≈ 0,65 FCFA  

---

## Message clé pour le jury

> Avec RAK TAK CASH : **Encaisse. Envoie. En confiance.**  
> Du comptoir à la livraison WhatsApp, le commerçant a un vrai outil Lightning, en FCFA, pensé pour Dakar.

---

## Suggestion de plan PowerPoint (10–12 slides)

1. **Titre** — Logo + **RAK TAK CASH** + slogan  
2. **L’équipe / le hackathon**  
3. **Le problème**  
4. **Notre solution** (1 phrase + 3 piliers)  
5. **Parcours boutique** (TPE)  
6. **Parcours livraison** (séquestre)  
7. **Recevoir / envoyer**  
8. **Captures d’écran** Accueil · Encaisser · Reçus · Profil  
9. **Architecture** (simple schéma : App ↔ API ↔ Bitnob)  
10. **Démo live** (ou vidéo)  
11. **Pourquoi on gagne** (rapidité, confiance, local)  
12. **Closing** — slogan + QR vers l’app / le lien `/pay` démo  

---

## Visuel / design à respecter

- Couleurs : **bleu** `#0052FF` / `#0A2540` + **jaune** `#FFD166` (comme le logo)  
- Style : fintech claire, moderne, **pas** violet “IA générique”  
- Langue des slides : **français**  
- Toujours afficher le **slogan** sur slide titre + slide de fin  

---

## Fichiers utiles dans le repo

| Fichier | Contenu |
|---------|---------|
| `PRESENTATION_EQUIPE.md` | **Ce document** (pour l’équipe slides) |
| `BRIEF_DESIGN_IA.md` | Brief design détaillé |
| `hackathon_mobile/assets/logo_rak_tak_cash.png` | Logo |
| `README.md` | Technique / démarrage |

---

## Phrase de fin (à lire ou à mettre en gros)

# RAK TAK CASH  
## Encaisse. Envoie. En confiance.

*Code & Chain Dakar 2026*
