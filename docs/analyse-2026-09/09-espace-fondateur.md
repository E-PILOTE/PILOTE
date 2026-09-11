# ESPACE FONDATEUR — `super_admin` — analyse

**Périmètre** : `features/super_admin/` — 156 fichiers, 44 106 lignes, 122 écrans
**Routes** : 23 constantes `/super/*` · **Mode** : online, Supabase direct
**Date** : 2026-09-09 · analyse conduite directement (sans agent)

> **Périmètre déclaré.** 44 106 lignes ne se lisent pas intégralement. J'ai
> balayé mécaniquement les 156 fichiers et lu en profondeur ce que le socle et
> la mémoire projet désignent : les zéros menteurs, la règle du chiffre unique,
> la doctrine documentaire, l'anti-redondance.
> **Zones non couvertes en lecture profonde** : `ai_screen.dart` (1 102 l.),
> `national_map_screen.dart` (808 l.), `payment_methods_screen.dart` (791 l.),
> `tickets_screen.dart` (652 l.).

## A. Vue d'ensemble

L'espace de l'éditeur du SaaS : le parc de groupes scolaires, les
administrateurs, le catalogue de modules, les plans, les abonnements, la
facturation, l'économie, la carte nationale, le support, les versions.
PowerSync n'est **pas** connecté pour ce rôle — c'est la règle, pas un défaut.

**Ce qui va bien, et qui mérite d'être dit** : les défauts les plus graves que
la mémoire projet documente ici ont été **réellement purgés**.
`grep` sur les pourcentages littéraux de type « 99,7 % » / « SLA 99,5 % » dans
les 44 106 lignes → **0 candidat**. Les constantes inventées du tableau de bord
fondateur ne sont plus là. C'est une correction qui a tenu.

**Ce qui reste** : 26 marqueurs d'inachèvement, 37 `catch (_) {}`, 14 fichiers
> 500 lignes, et — trouvé et corrigé aujourd'hui — cinq écrans qui annonçaient
un enregistrement réussi alors que rien n'avait été écrit.

---

## B. Fiche par écran *(échantillon raisonné)*

### Les cinq aperçus avant impression — `admins`, `groups`, `modules`, `plans`, `subscriptions`

| | |
|---|---|
| Fichiers | `*/[objet]_print_preview.dart` — 5 modales, ~300 lignes chacune |
| Sortie | ✅ aperçu maison (`PdfPreview`, `allowPrinting: false`) puis impression système |

**⛔ Défaut trouvé et CORRIGÉ le 2026-09-09.** Le bouton « Télécharger PDF »
appelle `downloadXxx()`, qui tente d'abord le sélecteur de fichier, puis se
replie sur le dossier Documents, et **renvoie `null` si les deux échouent**.
Les cinq écrans affichaient alors :

> ✓ **PDF généré** *(bandeau vert, icône coche)*

alors que **rien n'avait été écrit nulle part**. L'utilisateur fermait la
fenêtre et cherchait ensuite un fichier qui n'existait pas. Les cinq disent
désormais l'échec en rouge et nomment le recours.

**Dette restante, non corrigée** : ces cinq modales font ~300 lignes chacune là
où `showPdfPreviewDialog` existe. Les unifier changerait l'aspect de cinq
écrans du fondateur — **décision produit, pas correction**. C'est aussi pour
cela que les 5 `Printing.layoutPdf(` de cet espace ne sont **pas** des
violations de doctrine : l'utilisateur a vu le document avant que la boîte
système ne s'ouvre (cf. `22-transversal-documents.md` §1-C).

---

### Reçus et Factures — `receipts_screen.dart` (1 150 l.), `factures/facture_detail.dart`

**⛔ Défaut trouvé et CORRIGÉ le 2026-09-09** — trois boutons « Imprimer »
appelaient `Printing.layoutPdf` **directement, sans aucun aperçu**, sur un
**reçu** et une **facture**. Sur un poste Windows dont l'imprimante par défaut
est « Microsoft Print to PDF », le geste produisait un fichier que personne
n'avait vu. Ce sont désormais `ReceiptPdfService.apercuRecu` et
`InvoicePdfService.apercuFacture`, qui passent par l'aperçu partagé.

`receipts_screen.dart` à **1 150 lignes** reste le deuxième plus gros fichier
de l'espace.

---

### Économie & Abonnements — `economie_screen.dart` (643 l.), `subscriptions`, `plans`

La mémoire projet documente ici le défaut le plus coûteux de la plateforme : le
revenu mensuel affiché **120 000 F sur un écran et 184 000 F sur un autre**,
parce que cinq points de calcul utilisaient le tarif d'affiche
(`monthlyPriceOfPlanRow`) au lieu de la vraie assiette.

**Vérifié le 2026-09-09** : la règle tient. `mensualiteGroupe()` dans
`core/utils/tarif_ecoles.dart` est le point de calcul unique, et un test
refuse qu'un fichier de `lib/features/` rappelle `monthlyPriceOfPlanRow`.
**Rien à corriger.**

⚠️ Rappel qui reste vrai : **le prix d'un groupe suit son nombre d'écoles**
(mig. 0159). Ne jamais afficher `price_xaf` seul, ni calculer un MRR par
`tarif × abonnés`.

---

### Tableau de bord — `super_dashboard_provider.dart` (773 l.)

C'est ici que vivaient les **9 `catch (_) {}`** et les constantes inventées.
Le balayage d'aujourd'hui n'en trouve **aucune** dans ce fichier. La correction
a tenu.

---

### Paramètres — `settings_screen.dart` (**1 197 l., le plus gros de l'espace**)

Non lu en profondeur. **Point de vigilance** : c'est exactement le genre
d'écran où les « cases qui ne font rien » s'accumulent, et la mémoire projet en
a déjà trouvé (conservation des données, 4 réglages). À auditer en priorité
lors d'une passe dédiée, avec la méthode des deux côtés (`grep` Dart **et**
`pg_proc`).

---

## C. Relations avec le reste de la plateforme

```
  super_admin ──► catalogue `modules` ──► plans ──► ce que chaque groupe possède
        │
        ├──► administrateurs (RPC `get_platform_admins` — l'email vit dans auth.users)
        ├──► facturation / abonnements ──► admin_groupe (l'écran Abonnement du réseau)
        ├──► versions ──► parc Windows (`features/updates/`)
        └──► communication (module transverse, PAS une copie)

  ⛔ super_admin ne peuple PAS le référentiel d'examens : c'est le MINISTÈRE
     (faille SECURITY DEFINER fermée, 0070/0071)
```

## D. Synthèse

### D.1 Fonctionnalités manquantes

| # | Écran | Manque | Preuve | Impact | Effort |
|---|---|---|---|---|---|
| 1 | `settings_screen` | Audit « case morte » jamais fait sur 1 197 lignes | non lu en profondeur ; précédent avéré sur la conservation des données | Réglages annoncés, peut-être sans effet | **M** |
| 2 | `dunning_panel.dart:21` | Distinction « aucun impayé » / « lecture ratée » | `valueOrNull ?? const []` sur le panneau de relance | « Personne à relancer » affiché comme un fait | **XS** |
| 3 | les 5 aperçus | Unification sur `showPdfPreviewDialog` | ~300 l. × 5 de chrome maison | Dette de duplication | **M** — décision produit |

### D.2 Doublons et redondances

| # | Constat | Verdict |
|---|---|---|
| 1 | 5 modales d'aperçu maison ~300 l. chacune vs `showPdfPreviewDialog` | Duplication réelle, **assumée pour l'instant** |
| 2 | Communication : `super_admin` **importe** `features/communication/` | ✅ Pas de copie par espace |
| 3 | Le revenu mensuel : 5 points de calcul ramenés à un | ✅ **Résolu et gardé par un test** |

### D.3 Données partagées

| Donnée | Producteur | Consommateurs | Contrat | Risque |
|---|---|---|---|---|
| `modules`, `module_categories` | `super_admin` | **toute la plateforme** — sidebar, profils d'accès, plans | Le catalogue est la taxonomie | Un slug changé casse `_kPresets` (seul fichier qui les code en dur) |
| `subscription_plans`, `plan_modules` | `super_admin` | verrou 2 de la cascade d'accès | `module_count` exact | Un module retiré d'un plan disparaît de 1 000 écoles |
| `school_groups` | `super_admin` | `admin_groupe`, `tutelle` | ⚠️ La table `subscriptions` **n'existe pas** — la vérité est ici | — |
| `school_groups.admin_email` | `super_admin` | écran Abonnements | ⚠️ Colonne de **CONTACT**, jamais l'identifiant de connexion | 8 admins, 8 adresses affichées, 0 correspondance — corrigé via `get_platform_admins()` |
| versions / `build_number` | `super_admin` | parc Windows | Comparer l'**ENTIER**, jamais la chaîne | Mise à jour qui ne part pas |

### D.4 Conformité export / aperçu / impression

| Constat | Chiffre |
|---|---|
| Producteurs PDF | 6 |
| Écrans avec aperçu partagé | 1 *(+ 5 aperçus maison)* |
| `Printing.layoutPdf(` actifs | **5** — tous **derrière** un aperçu maison, donc conformes sur le fond |
| Impressions aveugles corrigées aujourd'hui | **3** (reçu ×2, facture ×1) |
| Faux succès d'enregistrement corrigés aujourd'hui | **5** |

### D.5 Cases mortes et zéros menteurs

| # | Type | Constat |
|---|---|---|
| 1 | ✅ **Purgé** | 0 constante inventée dans 44 106 lignes (les « 99,7 % » et « SLA 99,5 % » ont disparu) |
| 2 | ⛔ **Corrigé aujourd'hui** | 5 écrans annonçaient « ✓ PDF généré » en vert sur un échec total d'enregistrement |
| 3 | ⚠️ Restant | **37 `catch (_) {}`**. Deux familles : le `networkImage()` des services PDF (logo/avatar indisponible hors ligne — **légitime**, « mieux vaut un document sans logo qu'un document qui n'existe pas ») et ceux des providers (`plans_provider` ×5, `subscriptions_provider` ×5, `modules_provider` ×6, `school_groups_provider` ×3) — **à qualifier** |
| 4 | ⚠️ | `dunning_panel.dart:21` — panneau de relance en `valueOrNull ?? const []` |

### D.6 Dette de structure

**14 fichiers > 500 lignes**, dont :

| Fichier | Lignes |
|---|---|
| `screens/settings_screen.dart` | **1 197** |
| `screens/receipts_screen.dart` | **1 150** |
| `screens/ai_screen.dart` | **1 102** |
| `screens/reports_screen.dart` | **1 043** |
| `screens/national_map_screen.dart` | 808 |
| `screens/payment_methods_screen.dart` | 791 |
| `providers/super_dashboard_provider.dart` | 773 |
| `services/financial_pdf_service.dart` | 667 |
| `screens/tickets_screen.dart` | 652 |
| `screens/economie_screen.dart` | 643 |
| `screens/economie/licence_detail.dart` | 624 |
| `services/group_pdf_service.dart` | 551 |

### D.7 Désalignements

1. **`ai_screen.dart` (1 102 l.) et la route `/super/ia`** subsistent, alors
   que la refonte du catalogue (2026-06-06) a **supprimé la catégorie `ia`** et
   ses modules (`rapport-ia`, `suggestions-ia`), au motif qu'ils sont *online*
   et contredisent l'offline-first. Le module a disparu du catalogue vendu aux
   écoles ; l'écran du fondateur est resté. **À qualifier** : outil interne
   assumé, ou reliquat ?
2. **23 constantes de routes `/super/*`** pour « 19 pages » annoncées. L'écart
   vient des sous-routes de messagerie (accueil, inbox, tickets, annonces,
   partenaires). Le compte de `CLAUDE.md` n'est pas faux, il est agrégé.
3. **26 marqueurs d'inachèvement** — le plus gros gisement après le réseau.

## E. Les cinq choses à faire en premier

1. **Auditer `settings_screen.dart` (1 197 l.) à la recherche de cases
   mortes**, avec la méthode des deux côtés. C'est le plus gros écran de
   l'espace, et le précédent (conservation des données, onglet Sécurité) montre
   que c'est là qu'elles se logent.
   *Effort : M.*

2. **Qualifier les 37 `catch (_) {}`** en séparant les `networkImage`
   (légitimes) des providers (`plans`, `subscriptions`, `modules`,
   `school_groups` — 19 à eux quatre).
   *Effort : M.*

3. **Trancher le sort de `ai_screen.dart`** : la catégorie `ia` a été retirée
   du catalogue pour cause d'incompatibilité offline-first, l'écran est resté.
   *Effort : XS pour décider, S pour exécuter.*

4. **Traiter `dunning_panel.dart:21`** — « personne à relancer » ne doit pas
   s'afficher quand la lecture n'a pas abouti. Sur du recouvrement, c'est la
   même famille que le décompte de la caisse.
   *Effort : XS.*

5. **Décider du sort des 5 modales d'aperçu maison.** Les unifier sur
   `showPdfPreviewDialog` retire ~1 500 lignes et un chrome divergent ; c'est
   une décision produit, pas une correction.
   *Effort : M.*
