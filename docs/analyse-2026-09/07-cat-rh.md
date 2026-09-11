# RESSOURCES HUMAINES — analyse

**Slug catégorie** : `rh` · **Modules** : 4
**Code** : `features/staff/` — 25 fichiers, 7 665 lignes, 13 écrans
**Date** : 2026-09-09 · analyse conduite directement (sans agent)

## A. Vue d'ensemble de la catégorie

Quatre modules qui tiennent l'agent : qui il est (`personnel`), s'il est là
(`presences-personnel`), quand il s'absente (`conges`), et ce qu'il touche
(`paie`).

**C'est la catégorie la mieux outillée de l'espace école** sur l'axe
documentaire : deux services PDF (bulletin de paie, attestation de travail),
un export CSV, trois écrans branchés sur l'aperçu partagé. `paie_screen.dart`
est **le seul écran de la plateforme à cocher les 9 critères de profondeur**.

**Le défaut de la catégorie** n'est pas dans les modules, il est **entre** eux :
les absences du personnel et les retenues sur salaire ne se parlent pas, et les
congés n'ont aucun solde.

---

## B. Fiche par module

### Personnel — `personnel`

| | |
|---|---|
| Route | `/user/personnel` · `PersonnelScreen` (395 l.) + `personnel_views` (441 l.) + `personnel_cycle_kpis` (331 l.) + `personnel_dossier_sheet` (476 l.) + `personnel_dossier_forms` (484 l.) + `agent_fiche_dialog` (466 l.) + `agent_creation_dialog` (453 l.) |
| Tables | `profiles` (**pas** `staff_members`), `staff_career`, `staff_diplomas` |
| Périmètre | `own_school` uniquement (0 profil `own_classes`) — clause non nécessaire |
| Profondeur UI | **L2** (7/9) — manquent : action primaire, détail *(faux négatif : le détail passe par `agent_fiche_dialog`)* |
| Sortie | ✅ **annuaire PDF + CSV** (`personnel_export_service.dart`) · ✅ **attestation de travail** (`attestation_travail_pdf_service.dart`) |

**Ce qu'il fait** — l'annuaire, le dossier de l'agent (carrière, diplômes), la
création d'agent, la correction de fiche, l'annulation d'enregistrement.

**⚠️ Précision importante sur la règle offline-first.** Le socle de cette
analyse énonçait « la création d'agents est le **seul geste** en ligne de
l'espace école ». C'est **plus large que cela** : `agent_creation_provider.dart`
appelle **cinq** RPC Supabase —
`contexte_creation_agent` (l. 258), `creer_agent_ecole` (l. 298),
`corriger_fiche_agent` (l. 339), `renseigner_statut_agent` (l. 370),
`annuler_enregistrement_agent` (l. 387). C'est **tout le cycle de vie de
l'agent** qui exige le réseau, pas un geste isolé.

C'est **légitime et bien fait** : un compte de connexion vit dans `auth.users`,
hors PowerSync, et la RLS `profiles_update` interdit à une direction d'écrire
dans la fiche d'un autre agent — un UPDATE passé par PowerSync serait rejeté et
**emporterait le lot entier, silencieusement**. Le fichier le dit lui-même
(l. 30-35). Et la dégradation est traitée avec soin : `ContexteCreationAgent`
porte un champ `horsLigne` **distinct** de `autorise`, avec le commentaire
« on ne dit pas à un directeur qu'il n'a pas le droit alors qu'il est seulement
hors réseau » (l. 211-214). C'est exactement la doctrine appliquée.

**À corriger dans la documentation, pas dans le code** : le socle
(`00-METHODE.md` §2) sous-estime le périmètre de l'exception.

**Ce qui manque**
- Rien de majeur. C'est le module le plus complet de la catégorie.
- Un chef ne crée jamais un chef : garde-fou **côté serveur** (mig. 0091), ce
  qui est la bonne place — l'écran ne fait que le rappeler.

---

### Présences Personnel — `presences-personnel`

| | |
|---|---|
| Route | `/user/presences-personnel` · `PresencesPersonnelScreen` (424 l.) |
| Tables | `staff_attendance` |
| Profondeur UI | **L1** (5/9) — manquent : tri, action primaire, détail, sortie |
| Sortie | **aucune** |

**Ce qu'il fait** — pointe la présence d'un agent à une date
(`setStaffAttendance`), en série (`setStaffAttendanceBulk`), efface un pointage.

**Ce qui manque**
- ⛔ **Aucun lien avec la Paie.** `PayrollLine` porte bien un champ
  `deductions` (`payroll_provider.dart:48`), et ce module enregistre les
  absences — **rien ne relie les deux**. Le comptable relit l'écran des
  présences et retape la retenue à la main. C'est la définition d'une donnée
  saisie deux fois, avec deux chances de se tromper.
- **Aucun état mensuel de présence du personnel** : ni pour l'agent, ni pour la
  direction, ni pour la tutelle.
- Écran le plus pauvre de la catégorie : pas de tri, pas de fiche agent
  accessible depuis le pointage.

---

### Congés — `conges`

| | |
|---|---|
| Route | `/user/conges` · `CongesScreen` (479 l.) + `conges_form` (209 l.) |
| Tables | `leave_requests` |
| Profondeur UI | **L2** (8/9) — manque : sortie |
| Sortie | **aucune** |

**Ce qu'il fait** — dépôt d'une demande (`saveLeaveRequest`), instruction
(`reviewLeaveRequest`), approbation en série (`approveLeaveBulk`), suppression.

**Ce qui manque**
- ⛔ **Aucun solde de congés.** Vérifié :
  `grep -niE "solde|quota|droit|balance|reliquat" leave_provider.dart conges_screen.dart`
  ne rend qu'une seule ligne — et c'est le **type** de congé « sans solde »
  (l. 22), pas un décompte. Il n'existe donc ni droit acquis, ni jours restants,
  ni plafond. Un agent peut demander soixante jours ; rien ne dit qu'il n'y a
  droit qu'à trente, et l'instructeur approuve à l'aveugle. Pour une
  administration d'État, c'est le manque de fond de ce module.
- ⛔ **Aucune décision écrite.** Une approbation de congé est un acte : l'agent
  doit pouvoir présenter son autorisation d'absence. Elle ne quitte pas
  l'écran.
- Pas d'état des absences en cours à une date donnée (qui est absent
  aujourd'hui ?), alors que c'est la question du chef d'établissement le matin.

---

### Paie — `paie`

| | |
|---|---|
| Route | `/user/paie` · `PaieScreen` (496 l.) + `paie_form` (233 l.) |
| Tables | `payroll` (SENSIBLE, `sync_finance`) |
| Profondeur UI | **L3 (9/9)** — le seul écran de la plateforme à tout cocher |
| Sortie | ✅ **bulletin de paie PDF** (`payroll_pdf_service.dart`, 262 l.) |

**Ce qu'il fait** — bulletins par période (base + primes − retenues = net),
statut de paiement, confirmation unitaire et en série
(`confirmPayrollBulk`), et **report d'une période sur la suivante**
(`carryOverPayroll`) — le geste qui évite de ressaisir 40 bulletins chaque
mois. C'est de la bonne conception métier.

**Ce qui manque**
- Le champ `deductions` est saisi à la main, sans lien avec
  `presences-personnel` (cf. ci-dessus).
- Pas d'**état de paie consolidé** (le journal du mois, tous agents) — seul le
  bulletin individuel sort. C'est la pièce que le comptable joint à sa
  déclaration.

---

## C. Relations entre les modules DE cette catégorie

```
  personnel ──(staffDirectoryProvider : l'annuaire des agents)──┬─► conges
        │                                                       ├─► paie
        │                                                       └─► presences-personnel
        │
        └──► attestation de travail PDF ✅   annuaire PDF + CSV ✅

  presences-personnel ─╳► paie.deductions      ← LIEN MANQUANT
  conges              ─╳► presences-personnel  ← LIEN MANQUANT (un congé approuvé
                                                 devrait pointer l'absence)
  paie ──► bulletin PDF ✅
```

`personnel` est le **socle** : les trois autres modules lisent son annuaire.
Ce partage est propre — un seul provider (`staffDirectoryProvider`), quatre
consommateurs. En revanche **les trois modules périphériques ne se parlent
pas entre eux**, alors qu'ils décrivent le même fait : l'agent n'est pas là.

## D. Synthèse de la catégorie

### D.1 Fonctionnalités manquantes — vue consolidée

| # | Module | Manque | Preuve | Impact | Effort |
|---|---|---|---|---|---|
| 1 | `conges` | **Solde de congés** (droit acquis, restant, plafond) | `grep -niE "solde\|quota\|droit\|balance" leave_provider.dart` → 1 seul hit, et c'est le TYPE « sans solde » | L'instructeur approuve sans savoir s'il y a droit | **M** (+ colonne en base) |
| 2 | `presences-personnel` → `paie` | Lien absences → retenues | `PayrollLine.deductions` existe (`payroll_provider.dart:48`) ; aucune référence croisée | Donnée saisie deux fois, sur du salaire | **M** |
| 3 | `conges` | Décision d'autorisation d'absence écrite | `grep "showPdfPreviewDialog" conges_*` → 0 | L'agent n'a aucun papier à présenter | **S** |
| 4 | `presences-personnel` | État mensuel de présence | idem | Ni pour l'agent, ni pour la direction, ni pour la tutelle | **M** |
| 5 | `paie` | Journal de paie consolidé du mois | seul le bulletin individuel sort | La pièce jointe à la déclaration | **S** |
| 6 | `conges` | « Qui est absent aujourd'hui ? » | aucune vue par date | La question du chef d'établissement chaque matin | **S** |
| 7 | `presences-personnel` | Tri, accès à la fiche agent depuis le pointage | `presences_personnel_screen.dart` — 5/9 au barème | Écran le plus pauvre de la catégorie | **S** |
| 8 | `conges` → `presences-personnel` | Un congé approuvé devrait pointer l'absence | aucune écriture croisée | Un agent en congé approuvé apparaît « non pointé » | **S** |

### D.2 Doublons et redondances

| # | Modules | Ce qui est dupliqué | Nature | Foyer |
|---|---|---|---|---|
| 1 | les 4 | **Néant sur l'annuaire** — un seul `staffDirectoryProvider`, quatre consommateurs. Exemplaire | — | — |
| 2 | `personnel` ↔ `annuaire` (SCOLARITÉ) | Le « kit d'annuaire » (barre d'outils au-dessus de la liste) | À trianguler avec `01-cat-scolarite.md` : celui-ci ne signale **pas** de recopie côté élèves, et `staff_kit.dart` (399 l.) est propre à la catégorie | Rien à faire — les deux annuaires partagent une **forme**, pas du code |
| 3 | `personnel_export_service.dart` | Contient **le PDF ET le CSV** dans un même fichier (165 l.) | Deux formats, une responsabilité (« sortir l'annuaire ») — assumé | — |

### D.3 Données partagées HORS catégorie

| Donnée | Producteur | Consommateurs | Contrat | Risque |
|---|---|---|---|---|
| `profiles` | **`personnel`** (via RPC serveur) | **toute la plateforme** — c'est la table d'identité | L'agent EST `profiles`, jamais `staff_members` | Se tromper de table = fiche fantôme |
| `profiles.access_profile_id` | `personnel` (création d'agent) | `myPermissionsProvider` → **la cascade des 4 verrous entière** | Un agent sans profil d'accès voit une sidebar vide | ⚠️ Le module RH gouverne ce que TOUS les autres modules montrent |
| `teacher_subjects.staff_id` | `matieres` (ENSEIGNEMENT) | `staff_directory_provider:134`, `staff_dossier_provider:73` | `staff_id` est un `profiles.id` | Le cycle d'un professeur est dérivé de ses affectations |
| `staff_career`, `staff_diplomas` | `personnel` | personne d'autre | — | ⚠️ `staff_affectations` est **hors PowerSync** (fiche `carriere-agent-mutation`) |
| attestation de travail | `personnel` | `registre_documents` (`attestation_travail`) | Toute délivrance est notée | Traçabilité ✅ |

### D.4 Conformité export / aperçu / impression

| Module | Sortie ? | `OfficialPdfKit` | `showPdfPreviewDialog` | `Printing.layoutPdf(` | Verdict |
|---|---|---|---|---|---|
| `personnel` | ✅ annuaire PDF + CSV, attestation de travail | ✅ (`personnel_export_service.dart:10`) | ✅ `personnel_screen`, `personnel_dossier_sheet` | non | **conforme** |
| `presences-personnel` | non | — | — | — | à créer |
| `conges` | non | — | — | — | à créer |
| `paie` | ✅ bulletin | ✅ | ✅ `paie_screen` | non | **conforme** |

**Deux modules sur quatre sortent un document conforme** — le meilleur ratio de
l'espace école. Et l'attestation de travail est **notée au registre des
documents émis**, ce qui la rend opposable.

### D.5 Cases mortes et zéros menteurs

| # | Module | Type | `fichier:ligne` | Prétend | Réalité |
|---|---|---|---|---|---|
| 1 | catégorie | — | — | — | **Aucun `catch (_) {}` dans les 7 665 lignes** |
| 2 | `conges`, `paie` | Zéro menteur *potentiel* | `conges_screen.dart:166`, `paie_screen.dart:177`, `conges_form.dart:112`, `paie_form.dart:105` | Listes d'agents | `staffDirectoryProvider.valueOrNull ?? const []` — un annuaire non lu se rend comme « aucun agent ». **Gravité moindre** : ces listes alimentent des sélecteurs et des filtres, pas des compteurs présentés comme des faits. **Non corrigé, à dessein** — mais à revoir si un KPI vient s'appuyer dessus |
| 3 | `presences-personnel` | Idem | `presences_personnel_screen.dart:149` | Marques de pointage | `marks.valueOrNull ?? const {}` → « personne n'est pointé ». **Plus gênant que les précédents** : le vide ici est indiscernable d'un pointage non commencé |

### D.6 Dette de structure

**Aucun fichier ne dépasse 500 lignes.** Le plus gros est `paie_screen.dart` à
496 — trois lignes sous la cible, et le seul écran L3 de la plateforme. Sur 25
fichiers et 7 665 lignes, la catégorie est conforme à la règle globale.

### D.7 Désalignements catalogue ↔ code

1. **Aucun désalignement de rangement** : les 4 modules du catalogue
   correspondent aux 4 écrans de `features/staff/`.
2. ⚠️ **Le socle de cette analyse était imprécis** : l'exception offline-first
   n'est pas « la création d'agents » mais **tout le cycle de vie de l'agent**
   (5 RPC). À corriger dans `00-METHODE.md` §2 et dans `CLAUDE.md`.
3. **Périmètre : 0 profil `own_classes` sur les 4 modules** (relevé live du
   2026-09-09). Cohérent : un annuaire de personnel ne se borne pas par
   classe. L'absence de `classScopeClause` dans `staff_directory_provider` et
   `staff_dossier_provider` n'est **pas** un trou — mais elle le deviendrait le
   jour où un profil `own_classes` serait posé sur `personnel`. **Un test de
   source devrait interdire cette combinaison plutôt que de la laisser
   possible.**
4. `conges` et `paie` n'ont que **7 lecteurs** en base contre 14 pour Finance :
   ce sont les modules les plus restreints de l'espace école. Cohérent avec
   leur sensibilité.

## E. Les cinq choses à faire en premier

1. **Donner un solde aux Congés.** Sans droit acquis ni reliquat, le module
   enregistre des demandes sans pouvoir les instruire. C'est le seul manque de
   la catégorie qui touche au **fond du métier** et non à sa sortie papier.
   *Gain : l'instruction cesse d'être aveugle · Effort : M (colonne en base +
   calcul) · Entrée : `features/staff/providers/leave_provider.dart`.*

2. **Relier les absences du personnel aux retenues de la Paie.** Le champ
   `deductions` existe, les absences existent, rien ne les joint. Sur du
   salaire, une double saisie est une double chance d'erreur.
   *Gain : supprime une ressaisie sur de l'argent · Effort : M · Entrée :
   `features/staff/providers/payroll_provider.dart:48` et
   `staff_attendance_provider.dart:62`.*

3. **L'autorisation d'absence écrite**, et le **journal de paie du mois**. Deux
   documents, un socle déjà maîtrisé par la catégorie (elle sort déjà bulletin
   et attestation). Les moins chers des cinq.
   *Gain : l'agent a son papier, le comptable a sa pièce · Effort : S · Entrée :
   `features/staff/screens/conges_screen.dart`, `paie_screen.dart`.*

4. **Traiter le `valueOrNull ?? const {}` du pointage**
   (`presences_personnel_screen.dart:149`) : « personne n'est pointé » et
   « je n'ai pas pu lire les pointages » ne doivent pas s'afficher pareil.
   *Gain : ferme le dernier zéro menteur gênant de la catégorie · Effort : XS.*

5. **Corriger le socle et `CLAUDE.md`** sur l'exception offline-first : c'est
   le cycle de vie complet de l'agent (5 RPC), pas un geste. Une règle
   d'architecture énoncée trop étroitement finit par être invoquée contre du
   code correct.
   *Gain : la règle centrale du projet dit la vérité · Effort : XS.*
