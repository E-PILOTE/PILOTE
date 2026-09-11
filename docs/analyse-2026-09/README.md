# Analyse modulaire E-PILOTE — septembre 2026

Analyse complète de la plateforme **par catégorie et par module** : ce qui
manque, ce qui est en double, ce que les modules se partagent, l'état des
sorties documentaires (export / aperçu / impression), et ce qui ne tient pas à
l'échelle nationale.

**Unité de suivi : le MODULE du catalogue**, pas le dossier de code. Les deux
ne se recoupent pas.

> ✅ **ANALYSE TERMINÉE** — 17 rapports, 16 périmètres.
> ✅ **BACKLOG SOLDÉ au 2026-09-10** — §1 : 3 points sur 5 ; §2 : **11 sur 11**.
> Les deux points restants ne sont pas du code : déployer les sync-rules sur
> l'instance **Production** (jeton à refaire), et observer une fois la
> création des index locaux sur une machine d'entrée de gamme.
> 👉 **Si vous ne lisez qu'un fichier : [`99-SYNTHESE.md`](99-SYNTHESE.md).**
>
> ⚠️ Les rapports par catégorie décrivent l'état **au moment de l'analyse**.
> Pour savoir ce qui a été corrigé depuis, la synthèse fait foi — elle seule
> est tenue à jour.

---

## Les documents de référence (à lire en premier)

| Fichier | Contenu |
|---|---|
| [`00-METHODE.md`](00-METHODE.md) | Le socle : contexte produit, règle d'architecture, doctrine documents, les deux travers de famille, doctrine anti-redondance, barème de profondeur UI, **grille d'analyse imposée** |
| [`00-CATALOGUE.md`](00-CATALOGUE.md) | **La taxonomie de référence** : 9 catégories · 35 modules, avec slug ▸ route ▸ écran ▸ fichier pour chacun |
| [`00-INVENTAIRE.md`](00-INVENTAIRE.md) | Les 102 routes câblées, les placeholders, les constantes orphelines |

---

## Les rapports

### Modules du catalogue — l'espace école

| # | Catégorie | Modules | Rapport | État |
|---|---|---|---|---|
| 1 | SCOLARITÉ | 7 | [`01-cat-scolarite.md`](01-cat-scolarite.md) | ✅ **fait** |
| 2 | ENSEIGNEMENT | 6 | [`02-cat-enseignement.md`](02-cat-enseignement.md) | ✅ **fait** |
| 3 | ÉVALUATION | 4 | [`03-cat-evaluation.md`](03-cat-evaluation.md) | ✅ **fait** |
| 4-5 | EXAMENS · FORMATION PRO | 1 + 1 | [`04-cat-examens-formation-pro.md`](04-cat-examens-formation-pro.md) | ✅ **fait** |
| 6 | VIE SCOLAIRE | 5 | [`05-cat-vie-scolaire.md`](05-cat-vie-scolaire.md) | ✅ **fait** |
| 7 | FINANCE | 4 | [`06-cat-finance.md`](06-cat-finance.md) | ✅ **fait** |
| 8 | RESSOURCES HUMAINES | 4 | [`07-cat-rh.md`](07-cat-rh.md) | ✅ **fait** |
| 9 | COMMUNICATION *(natifs)* | 3 + 1 | [`08-cat-communication.md`](08-cat-communication.md) | ✅ **fait** |

### Espaces d'administration — hors catalogue

| # | Espace | Rapport | État |
|---|---|---|---|
| 9 | Fondateur — `super_admin` | [`09-espace-fondateur.md`](09-espace-fondateur.md) | ✅ **fait** |
| 10 | Réseau — `admin_groupe` | [`10-espace-reseau.md`](10-espace-reseau.md) | ✅ **fait** |
| 11 | Tutelle — ministère | [`11-espace-tutelle.md`](11-espace-tutelle.md) | ✅ **fait** |
| 12 | **Socle transverse** | [`12-socle-transverse.md`](12-socle-transverse.md) | ✅ **fait** |

### Passes transversales

| # | Sujet | Rapport | État |
|---|---|---|---|
| 20 | **Doublons entre catégories** | [`20-transversal-doublons.md`](20-transversal-doublons.md) | ✅ **fait** |
| 21 | **Flux de données inter-modules** | [`21-transversal-flux.md`](21-transversal-flux.md) | ✅ **fait** |
| 22 | **Conformité documents** | [`22-transversal-documents.md`](22-transversal-documents.md) | ✅ **fait** |
| 23 | **Verrou 4 — périmètre des données** | [`23-transversal-perimetre.md`](23-transversal-perimetre.md) | ✅ **fait** |
| 24 | **Tenir à l'échelle nationale** | [`24-transversal-echelle.md`](24-transversal-echelle.md) | ✅ **fait** |

### Synthèse

| Fichier | État |
|---|---|
| [`99-SYNTHESE.md`](99-SYNTHESE.md) — **backlog unique priorisé** | ✅ **fait** |

---

## Ce qui a été corrigé pendant l'analyse

L'analyse n'est pas restée un document. **33 corrections** ont été portées au
code, et **quatre nouveaux tests gardiens** posés (plus trois étendus) pour
qu'elles ne se défassent pas. `flutter analyze` : **0 issue** ·
`flutter test` : **2 471 tests, 0 échec**.

Les sept qui comptent le plus, avant le 1ᵉʳ octobre :

| # | Ce qui se passait | Correction |
|---|---|---|
| 1 | Le module **Cartes scolaires** servait l'identité **et le groupe sanguin** de tous les élèves de l'école à un enseignant en `own_classes` | Verrou 4 posé sur les deux requêtes |
| 2 | `/user/journal-audit` ouvrait le journal de **toute l'école** à n'importe quel agent — la barre le masquait, le routeur ne le gardait pas, et un test affirmait pourtant l'inverse | Garde de rôle + `garde_des_pages_de_direction_test` |
| 3 | Un transfert saisi depuis un compte mal rattaché emportait **tout le lot PowerSync** en attente (`22P02`, code fatal) | `isUsableId` + message d'identité |
| 4 | **1 matière sur 95** au catalogue : 94 portent `school_id IS NULL`. Le catalogue vide se propageait jusqu'au périmètre `own_classes` de chaque enseignant | Condition `OR (school_id IS NULL AND group_id = ?)` |
| 5 | Les rapports du réseau annonçaient **1 000 élèves** au lieu de **3 781**, et le recouvrement **moins d'un tiers** du réel : le plafond de PostgREST pris pour une mesure | 61 lectures paginées ou comptées + `mille_lignes_ne_sont_pas_le_total_test` |
| 6 | **Zéro index** sur les 89 tables du SQLite local : chaque filtre balayait la table entière avec un décodage JSON par ligne, sur une école qui porte déjà **38 544 notes** | 78 index + `index_local_powersync_test` |
| 7 | **Trois moteurs** calculaient la moyenne d'un élève, **deux lisaient le coefficient par défaut** au lieu de celui de la classe. Dormant (0 divergence sur 4 564 lignes) — donc corrigible sans reprise de données | Client corrigé + `coefficient_effectif_test` ; ⏳ **migration 0205 écrite, à appliquer** |

Détail complet : [`99-SYNTHESE.md`](99-SYNTHESE.md) §0.

---

## Ce qui était déjà établi avant les rapports

- **102 routes** câblées, **1 seul placeholder** (`/user/espace-parent` — le
  rôle `parent` n'a pas son espace). 7 constantes de routes non câblées.
- **32 modules actifs sur 32 ont une route dédiée** — aucun ne tombe sur le
  placeholder générique `/user/m/:slug`.
- **Règle d'architecture online/offline : 0 violation** dans les dix domaines
  de l'espace école.
- **Socle documentaire sain** : 41 fichiers produisent un PDF, **41** utilisent
  `OfficialPdfKit`. L'infrastructure n'était pas le problème.
- **116 `catch (_) {}`** dans 59 fichiers : le gisement du « zéro menteur ».
- **82 fichiers** dépassent la cible de 500 lignes — plafond tenu par un test
  à cliquet.
- **23 écrans de liste sur 90** n'offrent aucune sortie.

---

## Méthode

Les rapports 01 à 04 ont été produits par un agent par catégorie, tous nourris
du même socle et rendant la **même grille**. À partir du rapport 05, l'analyse
est conduite **directement**, sans agent — même socle, même grille.

Règle non négociable : **aucune affirmation sans preuve `fichier:ligne`**, la
commande `grep` qui prouve une absence, ou la requête SQL exécutée sur la base
de production.

### Corrections apportées à cette analyse elle-même

Un rapport qui ne se corrige pas est un rapport qu'on ne peut pas croire.

| Ce qui était annoncé | Ce qui est vrai | Où |
|---|---|---|
| « `features/cartes/` est la cartographie de tutelle » | C'est le module **cartes scolaires des élèves** (SCOLARITÉ) — collision lexicale | `00-CATALOGUE.md`, `11-espace-tutelle.md` |
| « 9 appels `Printing.layoutPdf` impriment à l'aveugle » | 5 vraies violations, 2 méthodes mortes, 5 derrière un aperçu maison | `22` §1 |
| « 9 fichiers téléchargent leurs polices » | **1** — et c'est la police d'émoji, pas celle du texte | `22` §2 |
| « 29 providers sans périmètre » | 1 défaut confirmé (`cartes`), le reste légitime ou à trancher | `23` |
| « `frais_screen` est pauvre (L1) » | Lecture seule **par décision** (mig. 0096) — accusation retirée | `06` §B |
| « 0 service PDF en Finance » | Le reçu existe et est conforme | `06` §D.4 |
| « La création d'agents est le seul geste en ligne » | **Cinq** RPC — tout le cycle de vie de l'agent | `00-METHODE.md` §2, `07` §B |
| « L'enforcement de licence est dormant » | Il est en **pilote depuis le 2026-07-04** ; le rollout est borné côté serveur | `12` §B |
| « **Deux** moteurs de moyenne » | **Trois** — `get_passage_merit()` en base est le troisième, et lit lui aussi le mauvais coefficient | `20` §B.1 |
| « `audit_data.dart` lit l'audit sans borne » | Il borne à 2 000 / 5 000 — mais **sans le dire**. Le défaut n'était pas l'absence de borne, c'était son silence | `24` §5 |
