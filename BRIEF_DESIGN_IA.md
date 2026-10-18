# BRIEF DESIGN IA — RAK TAK CASH

Document à coller / transmettre à une IA de design (UI, logo variants, landing, mockups).  
État du produit : **octobre 2026** · Hackathon **Code & Chain Dakar 2026**.

---

## 1. Identité

| Élément | Valeur |
|--------|--------|
| **Nom officiel** | **RAK TAK CASH** |
| **Ancien nom** | PayChain Dakar (ne plus utiliser dans les maquettes) |
| **Slogan officiel** | **Encaisse. Envoie. En confiance.** |
| **Accroche** | Paiements Lightning pour commerçants au Sénégal et en Afrique de l’Ouest |
| **Logo actuel** | `hackathon_mobile/assets/logo_rak_tak_cash.png` (aussi `Logo Rak Tak Cash bleu et jaune.png`) |
| **Palette logo** | Bleu (foncé → vif) + **jaune** (flèche / mot CASH) · fond sombre possible pour lockup |
| **Développeur** | Idrissa Coulibaly · @le-missionnaire221 |
| **API live** | https://hackathon-code-chain.onrender.com |
| **Admin** | https://hackathon-code-chain.onrender.com/admin |
| **Swagger** | https://hackathon-code-chain.onrender.com/docs |

**Branding dynamique :** le dashboard admin peut changer le **nom** et le **logo** de l’app (API `GET /branding`, admin `POST /admin/api/branding`). Les maquettes doivent prévoir un emplacement logo + titre, pas hardcoder uniquement le PNG actuel.

---

## 2. Ce que fait l’application (fonctionnel)

App **Flutter** (mobile + Chrome) + backend **Node/Express + PostgreSQL** + **Bitnob Lightning sandbox**.

### Parcours utilisateur

1. **Auth** — Inscription / connexion (nom, téléphone, mot de passe). Session persistée.
2. **Accueil (portefeuille)**  
   - Solde FCFA + équivalent SATS  
   - Actions : **Encaisser** · **Scanner** · **Recevoir** · **Reçus**  
   - Filtres transactions : Tout / Confirmés / Autres  
   - Bannière séquestre si fonds bloqués
3. **Encaisser (POS / TPE)**  
   - Mode **Sur place** : montant → QR Lightning Bitnob  
   - Mode **Livraison** : séquestre — argent gardé jusqu’au code de livraison (4 caractères)  
   - Partage lien `/pay/{référence}` (WhatsApp, SMS, etc.)  
   - Facture valide **24 h**, **paiement unique** (pas de double pay)
4. **Recevoir** — QR / adresse `téléphone@raktak.cash` ; un autre compte scanne et envoie un montant (transfert **interne** ledger app, pas Bitnob)  
   - Feedback live : validation + fermeture QR quand l’argent arrive
5. **Scanner** — Payer une facture marchand **ou** une adresse Recevoir  
6. **Reçus** — Historique : entrées en **vert (+)**, sorties en **rouge (−)** ; bilan Reçu / Payé séparés  
7. **Profil** (4ᵉ onglet) — Avatar, solde, stats, adresse Recevoir, connexion, déconnexion  

### Admin
- KPIs comptes / soldes  
- Suspendre / créditer un compte  
- **Apparence** : changer nom + logo de l’app  

### Distinction importante (discours démo)
| Flux | Rail |
|------|------|
| Encaisser / lien `/pay` / facture Lightning | **Bitnob** (sandbox) |
| Recevoir ↔ Scanner (P2P entre comptes app) | **Ledger RAK TAK CASH** uniquement |

---

## 3. Navigation (structure UI actuelle)

```
Bottom nav (4)
├── Accueil     (wallet)
├── Encaisser   (POS)
├── Reçus       (history)
└── Profil      (ex-réglages)
```

Écrans / sheets notables :
- Login / Register  
- Carte solde bleue (gradient)  
- Bottom sheets : Recevoir (QR), Paiement acheteur, Reçu détail, Partage  
- Page web `/pay/:ref` (QR PC / boutons mobile)  

---

## 4. Design system actuel (code)

### Couleurs (`AppColors`)

| Token | Hex | Usage |
|-------|-----|--------|
| primary | `#0052FF` | CTA, liens, marque |
| primaryDark | `#003BB5` | Gradient |
| sapphire | `#0A2540` | Fond chrome / textes forts |
| secondary | `#00D2FF` | Accent |
| lightningGold | `#FFD166` | Accents “or” |
| amber | `#F59E0B` | En attente / séquestre |
| success | `#10B981` | Reçu / OK |
| error | `#EF4444` | Payé / erreur |
| whatsapp | `#25D366` | Mode livraison |
| background | `#F8FAFC` | Fond app |
| card | `#FFFFFF` | Cartes |
| border | `#E2E8F0` | Bordures |
| textPrimary | `#0F172A` | Titres |
| textSecondary | `#64748B` | Secondaire |

**Gradient solde :** `#0052FF` → `#003BB5` → `#0A2540` (haut-gauche → bas-droite).

### Style UI actuel
- Fintech “neobank” clair (pas dark mode par défaut)  
- Cartes blanches, coins ~18–28 px  
- Typo Material (pas de police custom expressive encore)  
- Icônes Material Rounded  
- Largeur max ~480 px sur Chrome (simulation téléphone)  

### Logo — direction visuelle
- Icône : carré arrondi bleu + **éclair** (négatif) + **flèche jaune** montante  
- Wordmark stack : RAK (bleu foncé) / TAK (bleu vif) / CASH (jaune)  
- Peut s’afficher sur fond noir (lockup) ou sur UI claire (login)

---

## 5. Public & ton

- **Cible :** commerçants (boutique, livraison WhatsApp), acheteurs, diaspora  
- **Promesse :** payer / encaisser vite, peu cher, sans carte classique ; confiance livraison (séquestre)  
- **Ton :** clair, africain, confiant, moderne — **pas** “crypto casino”, pas violet néon générique  
- **Langue UI :** français (Sénégal)  

---

## 6. Ce que l’IA design peut / doit produire

### Prioritaire
1. **Rafraîchir l’UI** Accueil / Encaisser / Reçus / Profil autour du logo RAK TAK CASH (bleu + jaune)  
2. **Écran login** hero logo + nom  
3. **Landing / pitch** 1 écran pour le jury (problème → solution → 3 parcours)  
4. **Icônes app** (launcher Android) dérivées du logo  
5. **Variants logo** : fond clair, fond sombre, icône seule, favicon  

### Optionnel
- Illustration “livraison sécurisée” / “TPE Lightning”  
- Motion : solde qui monte, QR validé  
- Guide style 1 page (couleurs, typo, composants)  

### Contraintes techniques
- Mobile-first, largeur ~390–480  
- Garder les **4 onglets** et les flux métier (ne pas inventer un 5ᵉ produit)  
- Prévoir emplacement **logo dynamique** (admin)  
- Accessibilité : contrastes OK (jaune sur blanc = attention)  

---

## 7. Phrase courte pour générer des maquettes

> « RAK TAK CASH — app fintech Lightning pour commerçants au Sénégal. Logo bleu et jaune (éclair + flèche). UI claire type neobank : Accueil solde, Encaisser QR, Reçus +/−, Profil. Modes sur place et livraison avec séquestre. Français, moderne, confiance. »

---

## 8. Stack (pour contexte, pas pour redesigner le code)

- Flutter + Material  
- Backend Express / Postgres / Bitnob sandbox  
- Deep link technique : `paychain://pay/{ref}` (interne ; le branding affiché reste RAK TAK CASH)  
- Adresse Recevoir : `{phone}@raktak.cash`  

---

## 9. Fichiers utiles dans le repo

```
hackathon_mobile/assets/logo_rak_tak_cash.png
hackathon_mobile/assets/Logo Rak Tak Cash bleu et jaune.png
hackathon_mobile/lib/core/constants/app_colors.dart
hackathon_backend/public/logo_default.png
hackathon_backend/public/admin.html          # panel branding
BRIEF_DESIGN_IA.md                           # ce fichier
README.md
```

---

*Brief généré pour continuité design IA · produit RAK TAK CASH · Code & Chain Dakar 2026*
