# Mémoire projet — RAK TAK CASH

> Hackathon **Code & Chain Dakar 2026** · Développeur : Idrissa Coulibaly (@le-missionnaire221)

## Document pour l’IA design

**→ Utiliser en priorité : [`BRIEF_DESIGN_IA.md`](./BRIEF_DESIGN_IA.md)**  
Il contient l’identité, tous les parcours, la palette, le logo, les contraintes UI et le brief collable pour continuer le design.

## Résumé produit

**RAK TAK CASH** = paiements Lightning pour commerçants (Sénégal / Afrique de l’Ouest).

| Module | Rôle |
|--------|------|
| Accueil | Solde FCFA/SATS, actions Encaisser / Scanner / Recevoir / Reçus, filtres |
| Encaisser | TPE sur place (QR Bitnob) ou livraison (séquestre + code) + lien `/pay` |
| Recevoir | QR `phone@raktak.cash` — transfert entre comptes app |
| Scanner | Payer facture ou adresse Recevoir |
| Reçus | Historique +/− (vert / rouge) |
| Profil | Identité, stats, adresse, connexion |
| Admin | Comptes, crédits, **nom + logo** de l’app |

- Factures : **1 paiement**, validité **24 h**  
- Bitnob = factures Lightning marchand · P2P Recevoir = ledger interne  
- API : https://hackathon-code-chain.onrender.com  

## Repo

- `hackathon_backend/` — Express, Postgres, Bitnob, `/pay`, admin, `/branding`  
- `hackathon_mobile/` — Flutter  
- Logo : `hackathon_mobile/assets/logo_rak_tak_cash.png`  

## Suite design

Donner `BRIEF_DESIGN_IA.md` + le fichier logo PNG à l’IA pour mockups, landing jury, icône launcher, harmonisation bleu/jaune.
