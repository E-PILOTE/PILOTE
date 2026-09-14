# ESPACE TUTELLE — le ministère — analyse

**Périmètre** : `features/tutelle/` — 14 fichiers, 4 216 lignes
**Mode** : online (le rôle de tutelle est porté par un `admin_groupe`)
**Date** : 2026-09-09 · analyse conduite directement (sans agent)

> **Note de périmètre — une collision de nom à écarter d'abord.**
> `features/cartes/` (11 fichiers, 2 756 l.) **n'est PAS** la cartographie
> nationale : c'est le module de catalogue `cartes` = **cartes scolaires des
> élèves** (`import_photos_*`, `appariement_photos`, `cartes_actions`), qui
> appartient à la catégorie SCOLARITÉ et est traité dans `01-cat-scolarite.md`.
>
> La cartographie vit ailleurs :
> `super_admin/screens/national_map_screen.dart` (808 l.) pour la carte
> nationale, `admin_groupe/screens/regional/` (~3 000 l.) pour la vue
> régionale. **`00-CATALOGUE.md` se trompait sur ce point — corrigé le
> 2026-09-09.**

## A. Vue d'ensemble

Le ministère (MEPSA / METP) supervise un **réseau de GROUPES**, pas d'écoles
directement. C'est l'espace du **commanditaire** : la démo nationale et le
déploiement du 1ᵉʳ octobre en dépendent.

**C'est le périmètre le plus sain de toute la plateforme.**

| Mesure | Valeur |
|---|---|
| Fichiers > 500 lignes | **0** (le plus gros : 442) |
| `catch (_) {}` | **0** |
| `valueOrNull ?? const []` | **0** |
| Marqueurs d'inachèvement | **0** |
| Producteurs PDF | 2, tous deux sur `OfficialPdfKit` |
| Écrans avec aperçu partagé | 3 |
| `Printing.layoutPdf(` | 0 |

Quatre indicateurs à zéro sur les quatre familles de défauts que cette analyse
traque. Sur 4 216 lignes, c'est le seul domaine dans ce cas.

---

## B. Fiche par écran

### Réseau sous tutelle — `tutelle_reseau_screen.dart` (442 l.)

| | |
|---|---|
| Vues | `tutelle_reseau_views.dart` (306 l.), `tutelle_groupes_vue.dart` (332 l.), `tutelle_ecoles_vue.dart` (246 l.) |
| Détails | `tutelle_groupe_detail.dart` (396 l.), `tutelle_ecole_detail.dart` (288 l.) |
| Provider | `tutelle_reseau_provider.dart` (367 l.) + `tutelle_filtres.dart` (357 l.) |
| Sortie | ✅ `showPdfPreviewDialog` (l. 272) sur `tutelle_pdf_service` / `tutelle_fiche_pdf_service` |

**✅ Le piège des deux périmètres est traité.** `ReseauSupervise` distingue
bien trois ensembles — `ecoles` (le réseau supervisé), `ecolesPropres` (les
établissements que le ministère exploite lui-même, **exclus** de la
supervision : on ne se supervise pas soi-même), et `toutesLesEcoles` qui les
réunit (`tutelle_reseau_provider.dart:310,319,323`).

C'est la correction du défaut mesuré à l'écran : le METP affichait
« Départements couverts : **0** » juste sous « 12 établissements couverts »,
parce que les fiches territoriales lisaient `ecoles` (vide pour un ministère
qui n'a que des écoles propres) au lieu de `toutesLesEcoles`. **Vérifié
présent.**

⚠️ **Le contrat reste subtil et non gardé par un test** : à chaque nouvelle
fiche territoriale, il faut choisir le bon des trois ensembles. Le périmètre de
**tutelle** n'est pas celui de la **licence** — la licence couvre les écoles
propres, la supervision non.

---

### Messagerie de tutelle — `tutelle_message_dialog.dart` (226 l.) + `tutelle_message_destinataires.dart` (248 l.) + `tutelle_destinataires_provider.dart` (73 l.)

⛔ **La circulaire a été SUPPRIMÉE** (migration 0174) : la tutelle écrit
désormais à son réseau **par la messagerie**. Ces trois fichiers sont le
sélecteur de destinataires de cet envoi.

⚠️ **Conséquence non résolue, et c'est le manque de fond de cet espace** : une
instruction de tutelle est un **acte administratif**, et elle ne peut ni
s'imprimer, ni s'archiver, ni s'opposer. Un fil de discussion ne se classe pas.
Voir `08-cat-communication.md` D.1 #1 — le manque est le même vu des deux
côtés, ce qui le confirme.

⚠️ `director_id` est **NULL partout** : le chef d'établissement se résout par
le **RÔLE** (mig. 0175), pas par cette colonne.

---

### Documents de tutelle — `tutelle_pdf_service.dart` (340 l.), `tutelle_fiche_pdf_service.dart` (356 l.), `tutelle_pdf_commun.dart` (225 l.)

✅ **Conformes.** `OfficialPdfKit.loadFonts` / `loadLogo` / `headerFor` /
`footer` / `titleBlock` / `kpiGrid`, un `tutelle_pdf_commun.dart` qui factorise
ce que les deux services partagent, et l'émetteur pris de
`OfficialPdfKit.issuer` — donc le **ministère**, jamais E-PILOTE.

C'est le meilleur exemple de la doctrine documentaire appliquée : un chrome
partagé, un commun local, aucun contournement.

---

## C. Relations avec le reste de la plateforme

```
   MINISTÈRE (enum, PAS un groupe parent — AXE A)
        │  index unique 0178 : UN SEUL rôle de tutelle par ministère
        │  suppression refusée en base (0179)
        │
        ├──► supervise des GROUPES ──► admin_groupe ──► écoles
        │       ⚠️ ReseauSupervise.ecoles EXCLUT les écoles propres
        │
        ├──► écrit par la MESSAGERIE (0174, la circulaire est supprimée)
        │       └─╳► aucune archive opposable
        │
        ├──► plan `licence` à 0 XAF, SANS `subscription_end` (0181-0183)
        │       ⚠️ le NULL d'échéance est la SEULE chose qui empêche
        │          un ministère de passer en lecture seule
        │
        └──► référentiel d'EXAMENS (le ministère peuple, pas le super_admin —
             faille SECURITY DEFINER fermée 0070/0071)
```

## D. Synthèse

### D.1 Fonctionnalités manquantes

| # | Manque | Preuve | Impact | Effort |
|---|---|---|---|---|
| 1 | **Archive opposable d'une instruction de tutelle** | 0 sortie dans `features/communication/` ; la circulaire est supprimée (0174) | Un acte d'État qui ne se classe pas | **M** |
| 2 | Test gardien sur le choix `ecoles` / `ecolesPropres` / `toutesLesEcoles` | aucun test ne nomme ces trois getters | Le défaut « Départements couverts : 0 » peut revenir à la prochaine fiche | **S** |
| 3 | Test gardien sur le NULL de `subscription_end` du plan `licence` | 0181-0183 posent la règle en base, rien ne la protège côté client | Un ministère basculerait en lecture seule | **S** |

### D.2 Doublons et redondances

**Néant.** `tutelle_pdf_commun.dart` factorise explicitement ce que les deux
services PDF partagent — c'est l'inverse d'un doublon.

### D.3 Données partagées

| Donnée | Producteur | Consommateurs | Contrat | Risque |
|---|---|---|---|---|
| `ReseauSupervise` | `tutelle` | fiches territoriales, couverture de licence | ⚠️ **Trois ensembles distincts**, choisir le bon | « Départements couverts : 0 » sous « 12 établissements » |
| plan `licence` (0 XAF, `subscription_end` NULL) | `super_admin` | `tutelle`, `subscription_access_provider` | Le NULL est la garantie | Un ministère en lecture seule ; et **les modules viennent du PLAN** — 32 ont failli disparaître |
| messages de tutelle | `tutelle` | `messagerie` (module transverse) | Une instruction est un message | Pas d'archive |
| référentiel d'examens | **ministère** | `examens` (espace école), `admin_groupe` | Le super_admin est opérateur SaaS, il ne peuple pas | Faille SECURITY DEFINER (fermée) |
| secteur (public/privé) ≠ caractère (catholique/islamique/protestant) | `super_admin` (0180) | `tutelle` | **Deux notions séparées depuis 0180** | Les reconfondre |

### D.4 Conformité export / aperçu / impression

| Mesure | Valeur | Verdict |
|---|---|---|
| Producteurs PDF | 2 | tous deux sur `OfficialPdfKit` ✅ |
| Aperçu partagé | 3 écrans | ✅ |
| `Printing.layoutPdf(` | 0 | ✅ |
| Commun factorisé | `tutelle_pdf_commun.dart` | ✅ |

**Conformité totale.** À citer comme le modèle pour les catégories qui n'ont
aucune sortie (Vie scolaire, Communication).

### D.5 Cases mortes et zéros menteurs

**Néant sur les quatre indicateurs** : 0 `catch (_) {}`, 0 `valueOrNull ??`,
0 constante inventée, 0 marqueur d'inachèvement. Le seul domaine de la
plateforme dans ce cas.

### D.6 Dette de structure

**Aucun fichier > 500 lignes.** Le plus gros est `tutelle_reseau_screen.dart` à
442. Sur 14 fichiers et 4 216 lignes, conformité totale à la règle du projet.

### D.7 Désalignements catalogue ↔ code

1. ⛔ **`00-CATALOGUE.md` rangeait `features/cartes/` sous l'espace Tutelle.**
   **Faux, et corrigé le 2026-09-09** : ce dossier est le module de catalogue
   `cartes` (cartes scolaires des élèves, catégorie SCOLARITÉ). La collision
   est purement lexicale. La cartographie est dans
   `super_admin/screens/national_map_screen.dart` et
   `admin_groupe/screens/regional/`.
2. **L'espace Tutelle n'a aucune route propre** : il vit dans `/admin/*`, parce
   que le rôle de tutelle est porté par un `admin_groupe` dont le groupe est
   marqué ministère (AXE A : le ministère est un **enum**, pas un groupe
   parent). Cohérent, mais invisible du routeur — d'où la difficulté à le
   compter dans l'inventaire des pages.
3. **La cartographie nationale et régionale n'est pas dans `features/tutelle/`**
   alors qu'elle est, métier, un **outil de tutelle** (la vue régionale est
   d'ailleurs fermée aux groupes privés). Rangement discutable, à signaler,
   pas à corriger — le coût du déplacement dépasserait le gain.

## E. Les cinq choses à faire en premier

1. **Donner une archive opposable aux instructions de tutelle.** C'est le seul
   manque de fond de cet espace, et il est confirmé des deux côtés (ici et dans
   `08-cat-communication.md`). Une instruction d'État qui ne se classe pas
   n'engage personne.
   *Effort : M · Entrée : `features/tutelle/widgets/tutelle_message_dialog.dart`.*

2. **Poser un test gardien sur les trois ensembles de `ReseauSupervise`.** Le
   défaut « Départements couverts : 0 » a été corrigé une fois ; rien
   n'empêche la prochaine fiche territoriale de relire le mauvais getter.
   *Effort : S.*

3. **Poser un test gardien sur le NULL de `subscription_end`** du plan
   `licence`. C'est la seule chose qui empêche un ministère de basculer en
   lecture seule, et elle ne vit qu'en base.
   *Effort : S.*

4. **Décider du rangement de la cartographie.** Métier, c'est un outil de
   tutelle ; code, elle est éclatée entre `super_admin` et `admin_groupe`.
   Choix à assumer et à noter, dans un sens ou dans l'autre.
   *Effort : XS pour décider.*

5. **Prendre cet espace comme modèle documentaire.** 2 services PDF, un commun
   factorisé, l'émetteur pris du ministère, l'aperçu obligatoire, zéro
   contournement, zéro fichier hors norme. C'est ce que Vie scolaire et
   Communication devraient copier.
   *Effort : nul — c'est une décision de méthode.*
