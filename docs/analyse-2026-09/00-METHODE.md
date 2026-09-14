# Analyse modulaire E-PILOTE — socle commun aux agents

> **Lis ce fichier EN ENTIER avant d'ouvrir une seule ligne de code.**
> Il contient tout ce que tu n'as pas à redécouvrir, et la grille de sortie
> que tu dois remplir à la lettre. Douze autres agents remplissent la même
> grille sur d'autres périmètres : si tu improvises ton format, ton travail
> est inutilisable à la fusion.

Racine : `C:\E-PILOTE` · Code Flutter : `C:\E-PILOTE\epilote\lib`
Branche : `feat/ministere-de-tutelle`

⚠️ **`C:\PILOTE` est un dossier PÉRIMÉ** (ZIP de `main`, 5 juillet). Ne jamais
l'ouvrir, ne jamais le citer.

---

## 1. Le produit en six lignes

E-PILOTE CONGO v3.0 — SaaS **national** de gestion scolaire **offline-first**
pour la République du Congo (commande MEPSA + METP). Multi-tenant, plus de
1000 écoles publiques et privées visées. Déploiement national prévu
**1-2 octobre 2026**, Windows uniquement, par vagues.

C'est une **plateforme d'État**. Un chiffre faux ne reste pas à l'écran : il
part en rapport, en réunion, en décision. Sobriété, clarté et intégrité
priment sur le « joli mais bavard ».

---

## 2. LA règle d'architecture (non négociable)

Deux chemins de données selon le rôle :

| Rôle | Mode | API |
|---|---|---|
| `super_admin` | online | `supabase.from(...)` |
| `admin_groupe` | online (KPI temps réel) | `supabase.from(...)` |
| **Personnel scolaire** (tout le reste) | **offline-first PowerSync** | `db.watch()` / `db.execute()` **uniquement** |

Fonction de référence : `isStaffRole(role)` dans
`lib/services/powersync/powersync_service.dart`.

**Mesuré le 2026-09-08 : 0 violation** — aucun `supabase.from()` dans
`students`, `classes`, `structure`, `evaluation`, `examens`, `staff`,
`vie_scolaire`, `finance`, `user`, `stages`. Ne perds pas de temps à
re-vérifier globalement.

⚠️ **Correction du 2026-09-09.** Ce socle annonçait « une seule exception : la
création d'agents ». **C'est plus large.** `features/staff/providers/agent_creation_provider.dart`
appelle **cinq** RPC Supabase — `contexte_creation_agent` (l. 258),
`creer_agent_ecole` (l. 298), `corriger_fiche_agent` (l. 339),
`renseigner_statut_agent` (l. 370), `annuler_enregistrement_agent` (l. 387) :
c'est **tout le cycle de vie de l'agent** qui exige le réseau.

C'est **légitime et bien traité** — un compte de connexion vit dans
`auth.users`, hors PowerSync, et la RLS `profiles_update` interdit à une
direction d'écrire dans la fiche d'un autre agent : un UPDATE passé par
PowerSync serait rejeté et **emporterait le lot entier, silencieusement**. La
dégradation hors ligne est explicite (`ContexteCreationAgent.horsLigne`,
distinct de `autorise`). Une règle énoncée trop étroitement finit par être
invoquée contre du code correct : c'est le périmètre ci-dessus qui fait foi.

Si tu trouves un appel en ligne **hors de ce cycle**, c'est une trouvaille —
prouve-la.

Rôles réels de l'enum `user_role` : `enseignant`, `secretaire`, `cpe`,
`comptable`, `surveillant`, `directeur`, `proviseur`, `parent`, `eleve`,
`infirmier`, `responsable_cantine`, `super_admin`, `admin_groupe`.
⛔ **La valeur `'utilisateur'` n'existe pas** et la constante
`AppConstants.roleUtilisateur` a été retirée. Un test échoue si elle revient.

---

## 3. État réel du produit (vérifié, ne pas re-débattre)

- **102 routes** câblées, **1 seul placeholder** : `/user/espace-parent`
  (le rôle `parent` n'a pas son espace). Voir `00-INVENTAIRE.md`.
- 7 constantes de routes déclarées mais non câblées → à qualifier.
- `super_admin` : 19 pages livrées. `admin_groupe` : 12 écrans livrés.
  **Espace personnel scolaire : LIVRÉ** (~48 routes `/user/*` réelles).
- 1 007 fichiers Dart, 282 000 lignes, 20 domaines `features/`.
- **Catalogue live : 9 catégories · 35 modules** (32 actifs). Les 32 actifs ont
  TOUS une route dédiée — aucun ne tombe sur `/user/m/:slug`. Voir
  `00-CATALOGUE.md`, qui est **l'unité de suivi de toute cette analyse**.
- 54 services PDF/export existent déjà.

⚠️ Le `CLAUDE.md` du dépôt contient une section « État d'avancement » qui a
menti pendant des mois. Ne conclus **jamais** sur l'avancement sans ouvrir
`app_router.dart` ou `00-INVENTAIRE.md`.

---

## 4. Doctrine documents : export, aperçu, impression

C'est un axe **de conformité**, pas d'ajout. L'infrastructure existe :

| Brique | Fichier | Rôle |
|---|---|---|
| `OfficialPdfKit` | `core/services/official_pdf_kit.dart` | chrome officiel partagé (bandeau tricolore, en-tête RÉPUBLIQUE DU CONGO, pied paginé, blocs KPI/cadre/table) |
| `PdfIssuer` | `core/services/pdf_issuer.dart` | l'émetteur est l'**établissement**, jamais l'éditeur du logiciel |
| `showPdfPreviewDialog` | `core/widgets/pdf_preview_dialog.dart` | aperçu in-app → Imprimer / Enregistrer |
| `FicheDetail` | `core/widgets/fiche_detail_model.dart` + `core/services/fiche_detail_pdf.dart` | une fiche de KPI est une **donnée** : même objet à l'écran et au PDF |

**Les cinq règles :**

1. ⛔ **`Printing.layoutPdf` est BANNI des écrans.** Il ouvre la boîte système ;
   sur un poste où l'imprimante par défaut est « Microsoft Print to PDF », le
   geste produit un fichier que personne n'a vu. Tout passe par
   `showPdfPreviewDialog`. *(Cherche `Printing.layoutPdf(` **avec la
   parenthèse** : plusieurs fichiers le NOMMENT dans un commentaire qui
   explique sa suppression.)*
2. **`OfficialPdfKit.tableSection`, jamais une table à la main.** Sans son
   découpage en blocs, une section longue fait boucler `MultiPage` jusqu'à
   `TooManyPagesException` — pas un document tronqué, **aucun document**.
3. **On imprime CE QUI EST À L'ÉCRAN.** Filtre actif ⇒ document filtré, et le
   PDF porte la mention « vue filtrée ».
4. **Polices embarquées, jamais téléchargées** (`PdfGoogleFonts` = accents
   perdus hors ligne).
5. `pw.Page` et non `MultiPage` pour les attestations (`AttestationKit`) ;
   `pw.FractionallySizedBox` n'existe pas dans le paquet `pdf`.

**Trois survivances déjà repérées** (à confirmer, ne pas recompter) :
`features/admin_groupe/services/admin_year_pdf_service.dart:336`,
`features/structure/services/programmes_pdf_service.dart:214`,
`features/super_admin/services/admin_pdf_service.dart:423`.

Adoption mesurée : 49 fichiers utilisent le kit, 53 l'aperçu, pour 54 services
PDF. **L'écart est ta zone de chasse.**

---

## 5. Les deux travers de famille du produit

À chercher activement dans ton périmètre — ils reviennent partout :

**A. La case qui ne fait rien.** Un réglage s'enregistre et *rien ne le lit*.
Vérification obligatoire des DEUX côtés : `grep -rn "<champ>" lib/` **en
excluant l'écran qui le propose**. Occurrences passées : conservation des
données (4 réglages), onglet Sécurité du groupe (6 réglages), carte
« Sécurité » de Mon profil (3 lignes constantes).

**B. Le zéro menteur.** Une lecture échoue, un `catch (_) {}` avale, la mesure
reste à 0, l'écran l'affiche comme un fait. Occurrences passées : 9
`catch (_) {}` du tableau de bord fondateur, « Sync réussie 99,7 % » et
« SLA 99,5 % » (constantes inventées), `select('id').length` plafonné à 1 000
par PostgREST affiché « 1.0 K élèves ».

La règle : l'affichage doit devenir **« — »**, jamais 0, et un bandeau nomme
les mesures manquantes **avant** les chiffres. Une protection annoncée mais
absente est **pire** que son absence.

Tests gardiens : `zero_nest_pas_je_ne_sais_pas_test.dart`,
`une_case_qui_ne_fait_rien_test.dart`.

---

## 6. Doctrine anti-redondance (pour ta section « doublons »)

**Chaque donnée a UN seul foyer.** Usage / adoption / volumes = Dashboard &
Rapports. Gouvernance d'accès = écran du module. Un écran de détail **fait
l'action de son rôle**, il ne réaffiche pas des stats vues ailleurs.
Préférer **1 action utile à 4 cartes décoratives**.

Modèle de référence : consoles Microsoft 365 / Google Workspace / Okta —
par-application = gouvernance d'accès + config ; analytics d'usage =
centralisés, jamais répétés par app.

**Précédent à connaître** : le revenu mensuel affichait 120 000 F sur un écran
et 184 000 F sur un autre (35 % d'écart), parce que **cinq points de calcul**
utilisaient `monthlyPriceOfPlanRow` (tarif d'affiche) au lieu de la vraie
assiette. « Quand deux écrans affichent la même chose, ils doivent la lire au
même endroit — sinon c'est le fondateur qui arbitre entre ses propres écrans. »

Autre source unique connue : **le barème de mentions** vit *uniquement* dans
`lib/core/utils/mention.dart` (`mentionFor`). Il avait dérivé de 2 points en
double exemplaire. Toute recopie est une trouvaille.

**Attention au faux positif.** Un doublon *légitime* existe : `communication/`
et `profil/` sont des **modules transverses scope-aware** — un seul code, le
périmètre est déduit du rôle. Les routes `/super/profil`, `/admin/profil` et
`/user/profil` mènent au **même écran** : c'est voulu, ce n'est pas un doublon.
`audit/` suit le même modèle.

---

## 7. Conventions de code

- **Cible ≤ 500 lignes par fichier Dart** (alerte à 400). Au-delà, découper par
  responsabilité, jamais au milieu d'un widget.
- ⚠️ Quand on découpe un écran, **les tests de source doivent suivre dans le
  même commit**, sinon les sondes deviennent vertes-mais-aveugles.
- `inFilter()` (pas `in_()`), `.count(CountOption.exact)`, `CardThemeData`
  (pas `CardTheme`), `.withValues(alpha:)` (pas `withOpacity`).
- `student_tutors` (pas `guardians`) ; `announcements.is_published` (pas
  `status`) ; `profiles` n'a **pas** de colonne `email`.
- Syncfusion `BarSeries` : `CategoryAxis` ← `xValueMapper` (String),
  `NumericAxis` ← `yValueMapper` (double). Inverser = crash.
- `service_role` **jamais** dans Flutter.

---

## 8. Barème de profondeur UI (à appliquer, pas à réinventer)

Le fondateur signale « des pages basiques et pauvres ». Transforme ce jugement
en mesure. Pour chaque écran, coche :

| # | Critère | Comment le vérifier |
|---|---|---|
| 1 | Recherche / filtre si la liste peut dépasser ~20 lignes | présence d'un `TextField` de recherche ou d'un kit de filtres |
| 2 | Tri des colonnes ou de la liste | `sort`, `DataColumn.onSort`, un menu de tri |
| 3 | État vide **explicite et utile** (pas un écran blanc) | un widget d'état vide qui dit quoi faire |
| 4 | État de chargement distinct de l'état vide | `AsyncValue.loading` traité |
| 5 | État d'erreur visible — **pas un zéro menteur** | `AsyncValue.error` traité, pas de `catch (_) {}` |
| 6 | Compteur de résultats | « 42 élèves » quelque part |
| 7 | Action primaire évidente | un bouton d'action clair, pas seulement de la lecture |
| 8 | Accès au détail (fiche / modale) | navigation ou `showDialog` vers un détail |
| 9 | Sortie PDF/export **si la donnée est officielle** | cf. §4 |
| 10 | Fichier ≤ 500 lignes | `wc -l` |

**Note** : `L0` = 0-3 critères (tableau nu) · `L1` = 4-6 · `L2` = 7-8 ·
`L3` = 9-10 (écran abouti).

Un écran de **saisie** ou de **réglage** n'est pas noté sur 1/2/6 — dis-le
plutôt que de le pénaliser à tort.

---

## 9. L'unité d'analyse est le MODULE, pas le dossier

⚠️ **Lis `00-CATALOGUE.md` avant tout.** La plateforme a sa propre taxonomie,
tenue en base (`module_categories` → `modules`) :
**9 catégories · 35 modules** (32 actifs + 3 Communication natifs).

C'est **cette** taxonomie qui structure l'analyse — pas les dossiers
`features/` du code. Les deux ne se recoupent pas :

- un dossier sert plusieurs modules : `features/students/` porte à lui seul
  Élèves, Inscriptions, Transferts, Documents et Annuaire ;
- un module s'étale sur plusieurs dossiers ;
- et il y a déjà des **désalignements** : le module `orientation` est rangé
  dans la catégorie **SCOLARITÉ** en base, mais son code vit dans
  `features/vie_scolaire/`. Signale chaque cas de ce genre que tu croises.

`00-CATALOGUE.md` te donne, pour chacun des 35 modules : slug, route, classe
d'écran et fichier. **Pars de là.**

## 10. Grille de sortie — OBLIGATOIRE

Écris **un seul fichier** : `C:\E-PILOTE\docs\analyse-2026-09\<TON-FICHIER>.md`
(le nom t'est donné dans ta mission). Reprends cette structure **à
l'identique** : d'abord une **fiche par module**, puis les sections de synthèse
de la catégorie. Une section vide se remplit par « Néant » — jamais supprimée.

````markdown
# <CATÉGORIE> — analyse

**Slug catégorie** : `xxx` · **Modules** : N
**Code concerné** : `features/a/`, `features/b/`
**Date** : 2026-09-08

## A. Vue d'ensemble de la catégorie (10 lignes max)
Ce que la catégorie couvre, et sa cohérence : les N modules forment-ils un
tout, ou y a-t-il un intrus / un manque évident ?

---

## B. Fiche par module

> Une sous-section `### <Nom du module> — \`slug\`` par module. Ordre du
> catalogue. Pour CHACUN, dans cet ordre :

### <Nom du module> — `slug`

| | |
|---|---|
| Route | `/user/xxx` |
| Écran | `XxxScreen` — `features/.../xxx_screen.dart` (N lignes) |
| Tables lues | ... |
| Tables écrites | ... |
| Profondeur UI | **L0..L3** — critères manquants : n° 1, 5, 9 (cf. §8) |
| Sortie document | aucune / conforme / non conforme (détail en D.4) |

**Ce que le module fait** — 3 lignes.

**Ce qui manque** — liste à puces, chaque point avec sa preuve
`fichier:ligne` ou la commande `grep` qui prouve l'absence, et l'impact métier.

**Ce qui est en double** — chaque point avec les DEUX emplacements
`fichier:ligne` et le foyer proposé. « Néant » si rien.

**Ce que ce module partage** — ce qu'il produit pour les autres, ce qu'il
consomme des autres. Nomme les modules par leur slug, y compris hors catégorie.

---

## C. Relations entre les modules DE cette catégorie
Comment ils s'enchaînent, ce qu'ils se passent, et où la chaîne casse.
Un schéma en texte est bienvenu.

## D. Synthèse de la catégorie

### D.1 Fonctionnalités manquantes — vue consolidée
| # | Module | Manque | Preuve | Impact métier | Effort |
|---|---|---|---|---|---|

### D.2 Doublons et redondances — vue consolidée
| # | Modules concernés | Ce qui est dupliqué | A (`fichier:ligne`) | B (`fichier:ligne`) | Nature | Foyer proposé |
|---|---|---|---|---|---|---|

### D.3 Données partagées HORS catégorie
| Donnée / table | Module producteur | Modules consommateurs (slug) | Contrat implicite | Risque si rompu |
|---|---|---|---|---|

### D.4 Conformité export / aperçu / impression
| Module | Sortie ? | `OfficialPdfKit` ? | `showPdfPreviewDialog` ? | `Printing.layoutPdf(` ? | Verdict |
|---|---|---|---|---|---|

### D.5 Cases mortes et zéros menteurs
| # | Module | Type | `fichier:ligne` | Ce que l'écran prétend | Ce qui se passe vraiment |
|---|---|---|---|---|---|

### D.6 Dette de structure
Fichiers > 500 lignes, avec la couture de découpe proposée.

### D.7 Désalignements catalogue ↔ code
Module rangé dans une catégorie mais codé ailleurs, slug absent du catalogue,
route non gardée, etc.

## E. Les cinq choses à faire en premier
Liste ordonnée. Pour chacune : le module, le gain, l'effort, le fichier
d'entrée.
````

**Un agent d'espace d'administration** (Fondateur / Réseau / Tutelle) ou de
socle transverse n'a pas de modules de catalogue : il remplace la section B par
une fiche **par écran**, en gardant exactement les mêmes rubriques, et conserve
C, D et E à l'identique.

---

## 11. Règles de travail — la qualité tient à ça

1. **Aucune affirmation sans preuve.** Chaque ligne de tableau porte un
   `fichier:ligne`, ou la commande `grep` qui prouve une absence. Une
   affirmation invérifiable sera supprimée à la fusion — donc autant ne pas
   l'écrire.
2. **Lecture seule.** Tu ne modifies AUCUN fichier de `epilote/`. Tu écris
   uniquement ton rapport dans `docs/analyse-2026-09/`.
3. **Ne re-dérive pas ce socle.** Les faits des §2-§7 sont vérifiés. Si tu
   crois en contredire un, c'est peut-être une trouvaille : dis-le
   explicitement avec ta preuve, ne le corrige pas en silence.
4. **Distingue « manquant » de « ailleurs ».** Avant de déclarer une
   fonctionnalité absente, cherche-la dans les autres domaines
   (`grep -rn` sur tout `lib/`). Beaucoup de « manques » sont en réalité des
   fonctions rangées dans un module transverse.
5. **Priorise par le métier, pas par la beauté du code.** Une école congolaise
   qui fait sa rentrée hors ligne le 1er octobre est l'arbitre. « Ce qui casse
   une rentrée » > « ce qui casse un bulletin » > « ce qui casse un rapport »
   > « ce qui gêne l'œil ».
6. **Sois bref sur ce qui va bien.** Le rapport sert à décider quoi faire, pas
   à féliciter. Un module sain se résume en trois lignes.
7. **Si ton périmètre est trop gros pour être lu entièrement**, dis-le en tête
   de rapport, explique ta stratégie d'échantillonnage, et signale la zone que
   tu n'as pas couverte. Un trou déclaré est exploitable ; un trou masqué ne
   l'est pas.

## 12. Mémoire projet

161 fiches dans `C:\Users\HP\.claude\projects\C--E-PILOTE\memory\`
(index : `MEMORY.md`). **Consulte l'index** et ouvre les 3-5 fiches qui
concernent ton périmètre avant de conclure — beaucoup de « trouvailles »
évidentes y sont déjà documentées comme décisions assumées. Citer une fiche
qui contredit ta conclusion vaut mieux que la répéter.
