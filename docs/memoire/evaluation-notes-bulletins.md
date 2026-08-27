---
name: evaluation-notes-bulletins
description: "Module Évaluation COMPLET — Notes (évaluations+saisie), Bulletins (moyennes/rang/mention+PDF) ET Conseils de classe (délibération+distinctions+PV), offline, routes câblées"
metadata: 
  node_type: memory
  type: project
  originSessionId: 9b4ef359-e046-4e8e-b7b4-1eba29609363
---

✅ **2026-06-29 — Module ÉVALUATION livré (Notes + Bulletins).** Non commité ; analyze 0 / build linux ✓ / 5 tests unitaires verts. **PAS encore vérifié GUI** (env. sandbox bloque le TLS Supabase → login impossible ici, + timeout OpenGL HiDPI ; compensé par revue + tests purs).

**Catégorie Évaluation** (catalogue live, category_id `1348e824…`) = slugs `notes`, `bulletins`, `conseils`. Les 3 existent au catalogue. **Notes + Bulletins = FAITS** ; **`conseils` (Conseils de Classe) = reste à faire** (pas de table dédiée, workflow conseil = prochaine étape).

**Données : AUCUNE migration/déploiement nécessaire.** Tables `evaluations`/`grades`/`bulletins`/`bulletin_subject_lines` déjà en base, déjà dans le schéma PowerSync local ET déjà dans sync-rules déployées (vérifié). 100% offline (`db.watch`/`db.execute`). Enums live : `evaluation_type` (composition/devoir_surveille/sequence/examen/controle), `evaluation_status` (draft/submitted/validated/published). `get_mention()` live : Excellent≥16, Très Bien≥14, Bien≥12, Assez Bien≥10, Passable≥8, sinon Insuffisant.

**Page NOTES** (`/user/notes`, slug `notes`, route câblée remplace `_comingSoon`) : design plateforme (hero KPI → `ScopeDrilldownPanel` couverture cycle/niveau/classe « notes complètes » → filtres recherche+type+statut → liste). Une **évaluation** = classe×matière, barème `max_score`, coefficient, date, trimestre, type ; cycle de vie draft→submitted→validated→published (menu ⋯, transitions gâtées). **Feuille de saisie** = tiroir bas : 1 ligne/élève actif, champ note sur le barème (validation 0..max) OU bouton « absent », normalisé /20 affiché, moyenne /20 live en tête ; enregistrement offline immédiat (`upsertGrade` : note vide+pas absent = efface la ligne). Matière limitée au programme de la classe (`classProgramProvider`). Fichiers : `providers/evaluations_provider.dart`(232) + `eval_grades_provider.dart`(116) ; `screens/notes_screen.dart`(242, orchestrateur) + parts `_parts`(KPI/filtres)/`_list`(cartes+menu statut)/`_form`(création/édition, classe+matière verrouillées en édition)/`_grades`(saisie).

**Page BULLETINS** (`/user/bulletins`, slug `bulletins`, route câblée) : sélection **classe + trimestre** (trimestre courant par défaut) → calcul DEPUIS les notes → KPI (moyenne de classe, taux réussite ≥10, moyennes calculées) → barre d'action (Générer/Recalculer + Publier/Dépublier) → liste élèves **classée** (rang, moyenne /20 colorée, mention) → détail = bandeau synthèse + **tableau lignes-matières** (coef, moy/20, moy classe, rang) + **PDF officiel** (`BulletinPdfService`, chrome `OfficialPdfKit`+`showPdfPreviewDialog`, signatures prof/chef). **Calcul** (`bulletinComputationProvider` FutureProvider.family, offline, invalidé après génération) : moy matière = Σ(note/20×coef_éval)/Σcoef_éval (absents exclus) ; moy générale = Σ(moy_matière×coef_matière)/Σcoef_matière (coef = `class_subjects.coefficient`↔`subjects.coefficient`) ; rang général + rang par matière + moyenne de classe. **Génération** persiste `bulletins`+`bulletin_subject_lines` (upsert, statut draft) ; `setBulletinsStatus` bascule tout le lot classe×trimestre. Fichiers : `providers/bulletins_provider.dart`(417) ; `services/bulletin_pdf_service.dart`(183) ; `screens/bulletins_screen.dart`(164)+parts `_parts`(sélecteurs/KPI/action/ligne élève)/`_detail`(détail+PDF).

**Test** `test/evaluation_logic_test.dart` (5 verts) : seuils mention (bornes exactes alignées get_mention) + pondération (normalisation barème, moy matière par coef éval, moy générale par coef matière).

✅ **2026-06-29 (suite) — Page CONSEIL DE CLASSE livrée + boucle workflow.** Non commité ; analyze 0 / build linux ✓. **Décision clé : AUCUNE table dédiée ni déploiement** — la délibération est portée par la table `bulletins` (colonnes `decision` varchar, `teacher_comment`, `director_comment` VÉRIFIÉES live + enum `bulletin_status` draft/submitted/validated/published). 100% offline (UPDATE `bulletins`).
- **Page** `/user/conseils` (slug `conseils`, route câblée remplace le placeholder ; constante `Routes.conseils`, `module_routes`, `app_router` import+GoRoute). Layout calqué Bulletins : sélecteurs classe+trimestre → KPI (moyenne classe, délibérés N/M, distinctions, avertissements) → barre empilée **répartition des distinctions** → bandeau statut+actions → liste élèves classée → tiroir de **délibération** par élève (récap moyenne/rang/mention + chips distinction + appréciation, save offline immédiat).
- **6 distinctions** (`councilAwards`, code stocké dans `bulletins.decision`) : felicitations≥16 / encouragements≥14 / tableau_honneur≥12 / avertissement_travail<8 / avertissement_conduite / blame. `suggestedAward(avg)` propose (chip « proposé »), bouton **Pré-remplir** (`autofillAwards`, n'écrase jamais l'existant). **Synthèse de classe** = `director_comment` partagé (dialog). **Valider la délibération** = statut→`validated` (réutilise `setBulletinsStatus`) ; publication reste sur page Bulletins (séparation nette). **PV PDF** (`ConseilPdfService`, chrome `OfficialPdfKit` : tableau rang/élève/moy/mention/distinction/appréciation + synthèse + signatures président/PP/secrétaire).
- **Workflow cohérent 3 pages** : Notes (saisie) → Bulletins (générer=draft, calcul) → **Conseil** (distinctions+appréciations+synthèse, valide) → Bulletins (publier). Sortie du conseil **remontée sur le bulletin** : `StudentBulletin` enrichi (decision/councilAppreciation/directorComment chargés dans `bulletinComputationProvider`), carte « Conseil de classe » dans le détail bulletin + bloc décision/appréciation dans le **PDF bulletin**. `generateBulletins` (UPDATE ciblé) ne touche pas ces colonnes → recalcul préserve la délibération.
- **Fichiers** : `providers/conseils_provider.dart`(~290 : awards, `councilSessionProvider` family qui réutilise `bulletinComputationProvider`, `saveCouncilDecision`/`autofillAwards`/`saveCouncilSynthesis`) ; `screens/conseils_screen.dart`(~250 orchestrateur)+parts `conseils_parts.dart`(KPI/distrib/actions/ligne)+`conseils_deliberation.dart`(tiroir+chips) ; `services/conseil_pdf_service.dart`(~230). Catalogue live confirme les 3 slugs sous ÉVALUATION.

✅ **2026-06-29 (refonte « pages riches » + COMMIT c6ba478).** User trouvait les 3 pages « pauvres » (Bulletins/Conseils = 2 déroulants ; Notes sans trimestre ni structure). Refonte alignée sur le **standard plateforme** (comme Documents/Annuaire) : **en-tête trimestre → KPI hero école → `ScopeDrilldownPanel` Cycle▸Niveau▸Classe → couverture par classe → ouverture d'une classe = espace de travail**. Nouveau `evaluationOverviewProvider(trimesterId)` (couverture par classe : élèves/générés/publiés/délibérés/évaluations + moyenne, depuis `classesProvider`+bulletins+evaluations) + `evaluation_overview_widgets.dart` partagé (EvalTrimesterHeader, EvalHeroKpis, EvalCoverageList[totalOf paramétrable], evalScopeUnits/evalClassUnits, EvalWorkflowGuide, EvalSectionLabel, EvalScopeChip). **Notes** : trimestre AJOUTÉ + panneau « structure » (1 unité/classe, métrique « Évaluées », TOUTES les classes visibles même à 0) + atelier classe (filtres+« Nouvelle »+feuille notes) ; form pré-rempli classe+trimestre. **Guide « comment ça marche » 3 étapes** sur les 3 pages (répond à « où saisir évaluation/notes ? »). **PIÈGE corrigé** : `ScopeDrilldownPanel` ne contient que les cycles/niveaux/classes AYANT des unités ; sélectionner une classe à 0 élève via une carte injectait une valeur absente → **assertion `DropdownButton` (crash rouge)**. Fix = découpler `_openClassId` (ouverture par carte) de `_scope` (sélection panneau, toujours valide). **VÉRIFIÉ GUI réel** (login OK ici en Directeur/Kinkala, PowerSync synchro) : overview riche + ouverture classe sans crash + form pré-rempli. Fichiers ≤500 (split `conseils_roster.dart`). analyze 0 / build ✓.

⚠️ 2 tests `admin_geo`/`congo_mask` échouent = **pré-existants, sans rapport** (données géo). Commit c6ba478 inclut aussi le build-out Enseignement (EDT/Cahier de textes) non commité car il partage le routeur. `modulesElements/` (dump SQL scratch) exclu.

**Reste** : commit ; brancher Notes/Bulletins/Conseils au Dashboard et à l'Espace Parent (lecture seule publiés) ; puis Vie scolaire (présences/discipline), Finance, RH. Voir [[scolarite-pages-classes-matieres-eleves]] (design partagé) et [[enseignement-emploi-du-temps]] (EDT complet).

## 🩸 AUDIT COMPLET DU MODULE — 2026-08-27 (5 axes)

Le module était déclaré « complet ». Il l'était en surface. Cinq défauts, dont
trois touchaient un document remis aux familles ou la perte de données.

### 1. Le rang du bulletin se lisait dans un tri
`rang = index + 1` sur une liste triée. Deux élèves à 14,50 recevaient 3 et 4.
Et `List.sort` n'est pas stable en Dart : le même élève pouvait être 3ᵉ sur un
poste et 4ᵉ sur un autre. Le projet appliquait DÉJÀ la bonne règle au rang
départemental d'une école — pas au bulletin.
→ `core/utils/rang.dart` : `rangDeCompetition(v, toutes) = 1 + (combien font
strictement mieux)`. Aucun tri, donc aucune dépendance à sa stabilité. Un élève
sans note n'est **pas classé** (pas dernier). Garde : `test/rang_test.dart`.

### 2. Un enseignant publiait les bulletins (migrations 0118/0119)
§8.3 « le directeur valide avant publication » ne vivait que dans l'écran, et
mal : « Publier » était gardé par `update`. Mesuré : l'enseignant lisait 8 514
notes, publiait ET supprimait des bulletins.
→ 0118 sépare lecture / écritures gâtées par module, `WITH CHECK` exigeant
`validate` pour `status='published'`. **0119 corrige mon propre helper** :
`auth_module_permet` retombait sur `can_read` dans son `ELSE`, donc accordait
`validate` à quiconque sait lire. Les droits connus sont désormais énumérés,
l'inconnu refusé.

### 3. « Publier » ne publiait RIEN (le pire des cinq)
`bulletins_screen._setStatus` gardait sur `_scope.classId`, alors que le
parcours que l'écran ENSEIGNE lui-même (« Ouvrez une classe » → carte
« Ouvrir ») renseigne `_openClassId` et laisse `_scope.classId` NUL. La fonction
rendait la main sans rien faire **et sans un message**. Le geste qui remet les
bulletins aux familles était inerte sur le seul chemin documenté. Seul le
déroulant du panneau marchait. `conseils_screen` appliquait déjà la bonne forme
(`_activeClassId`) — Bulletins était seul à diverger.

### 4. « Recalculer » jetait le lot hors ligne
`generateBulletins` réécrivait TOUS les bulletins, publiés compris. Or (a) c'est
un document déjà remis aux familles, (b) la base le refuse à qui n'a pas
`validate` (0118) et **42501 est FATAL** pour le connecteur : lot entier jeté,
saisies hors ligne perdues sans un mot. Mesuré en production : 474 bulletins
publiés dans l'école témoin, refus confirmé pour le profil Enseignant.
→ Un bulletin publié n'est **jamais** recalculé ; `generateBulletins` renvoie un
`GenerationBulletins(calcules, publiesIntacts)` et les deux écrans disent ce
qu'ils n'ont pas fait (« dépubliez la classe pour les recalculer »).
Garde : `test/bulletin_publie_test.dart`.

### 5. « Valider » ne voulait rien dire (migration 0121)
Même défaut que #2, **un niveau plus haut, et c'est celui que la règle nomme** :
§8.3 s'intitule « Validation NOTES ». La chaîne brouillon → soumise → VALIDÉE →
PUBLIÉE était gardée de bout en bout par `update`. L'enseignant soumettait,
validait et publiait son propre travail. Et une évaluation « validée » restait
modifiable ET renotable.
→ 0121 : brouillon/soumise = à l'enseignant (`update`) ; validée/publiée = à la
direction (`validate`), y compris pour les `grades` (fonction
`evaluation_ouverte`) et pour le retour en arrière. **Le verrou d'après-validation
passe par le `USING`, pas le `WITH CHECK`** : l'UPDATE touche 0 ligne au lieu de
lever 42501 — mode d'échec sûr pour PowerSync. Vérifié en production (annulé) :
ENS soumet OUI / valide REFUS / publie REFUS / renote BLOQUÉ ; DIR tout OUI.
Garde : `test/evaluation_validee_test.dart`.

### 6. `GradeModel` : un fossile armé
`lib/data/models/grade_model.dart` décrivait une table `grades` disparue — neuf
champs inexistants (`value`, `sequence_id`, `trimester_id`, `grade_type`…),
trois champs réels manquants (`evaluation_id`, `score`, `is_absent`). `fromMap`
aurait levé sur la PREMIÈRE ligne venue. **Zéro appelant**, donc zéro test, donc
personne pour s'en apercevoir : exactement le piège dormant de
`AppConstants.roleUtilisateur`. **Supprimé.**

### Et 0120, au passage
`bulletin_subject_lines` n'exigeait que `bulletins` alors que sa table mère
accepte `bulletins` OU `conseils` (deux écrans génèrent). Aucun profil ne tombe
dans l'écart aujourd'hui — c'est la forme exacte du piège 0116, désamorcée
avant qu'un groupe ne crée un profil « Conseil de classe » sans `bulletins`.

## 📌 Ce qui reste OUVERT sur Évaluation, nommé

- **La lecture reste à l'échelle de l'ÉCOLE** (RLS). Le périmètre par classe vit
  dans l'application ; le porter en RLS casserait le conseil de classe, qui lit
  toute la classe. Écrit dans l'en-tête de 0118.
- **La base est plus stricte que le binaire déployé (build 20).** Sans
  conséquence — aucun établissement en service — mais 0118/0121 doivent partir
  avec la prochaine livraison, sinon un poste build 20 déclenche 42501 sur
  « Valider »/« Publier » et perd son lot.
- **§8.3 · notification push FCM : INEXISTANTE.** `firebase_core` /
  `firebase_messaging` sont COMMENTÉS dans `pubspec.yaml` ; `profiles.fcm_token`
  n'est jamais écrit. Les familles ne sont prévenues de rien.
- **§8.6 · mode séquentiel : configurable mais INERTE.** L'admin groupe crée les
  séquences (`set_current_sequence`) ; aucun écran du personnel ne rattache une
  évaluation à une séquence — `evaluations.sequence_id` n'est écrit nulle part.
- **§8.4 · rétention (bulletins 10 ans) : rien.** Aucune purge, aucun archivage
  daté — même famille que le « 5 ans » financier.
- **`bulletins.total_absences` / `total_lates` : écrits à 0 en dur**, jamais
  affichés. Les données existent (`attendance_records`/`attendance_entries`).
  Le bulletin officiel ne porte donc aucune absence.

Voir [[modules-acces-hierarchie]], [[catalogue-modules-v2]], [[powersync-status]].
