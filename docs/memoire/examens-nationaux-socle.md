---
name: examens-nationaux-socle
description: "Module Examens d'État : socle livré (migs 0042-0047, classe d'examen DÉRIVÉE par trigger), faits vérifiés du système congolais, et ce qui reste"
metadata: 
  node_type: memory
  type: project
  originSessionId: 3dd519ee-785a-464e-a27d-95c1a6fbc266
  modified: 2026-07-25T14:11:06.167Z
---

**Module Examens d'État — socle LIVRÉ** (2026-07-17, branche `feat/examens-nationaux`, commits `fbcc0c3` + `05e03fd`). Analyse fondatrice : `docs/superpowers/specs/2026-07-17-analyse-fonctionnelle-modules-examens.md`.

## MÀJ 2026-07-17 soir — vers la production (commits `b978d30`, `915c660`, `052f2be`)
- **super_admin / Sessions d'examen refondue** (`b978d30`) : grammaire page Administrateurs (KPI animés → graphique → filtres → tableau/cartes), chrome PARTAGÉ extrait dans `super_admin/widgets/list_chrome.dart` (`KpiGrid`, `ListFilterBar`, `ListResultHeader`, `ListShimmer`) — à réutiliser pour refondre les autres écrans hérités. GUI-vérifié.
- **Création d'examen national depuis l'UI** : aucune UI ne créait de `national_exam` (même bombe que les sessions — une réforme exigeait du SQL). Bouton « + » dans le formulaire de session → `national_exam_form_dialog.dart` (`createNationalExam`, order_index auto). Dropdown examen trié par `order_index` PÉDAGOGIQUE (pas `code`) + `menuMaxHeight`. GUI-vérifié (12 examens).
- **« Soumettre » — transmissions à la DEC** (`915c660`, **mig 0054 APPLIQUÉE prod**) : le geste ENGAGEANT/opposable. `transmissions` + `transmission_items` (snapshot figé + items requêtables). ⚠️ **UNIQUE(school_id, reference) RETIRÉE** — référence générée hors-ligne, une collision de séquence provoquerait la perte silencieuse (leçon n°1). Gaté `validate` (Directeur/Proviseur). Publication `powersync` = FOR ALL TABLES (inclusion auto). `assignLotNumbers` pure + 6 tests (lots ~50 DANS une classe).
- **Pont Examens↔Stages** (`052f2be`) : le dossier BAC_P/BAC_T exige `attestation_stage` ; le module Stages la produit. Le dossier lit `internships.attestation_issued_at` → pièce satisfaite PAR LE MODULE (source de vérité), plus de re-cochage manuel. `kStagePieceCode = 'attestation_stage'`.
- **Audit anti-perte-silencieuse PROPRE** : toutes les écritures offline (exam_candidates, transmissions, internships, internship_companies) couvrent les colonnes NOT NULL-sans-default ; FK vers tables synchronisées ; schéma local complet. Aucune correction nécessaire.
- ✅ **VÉRIFIÉ 2026-07-25 — sync-rules BIEN DÉPLOYÉES** (`powersync fetch config`, lecture seule) : config live **identique** au fichier local `powersync/config/sync-rules.yaml` — 84 tables / 86 règles, **0 manquante, 0 en trop**. `exam_sessions`, `exam_candidates`, `exam_centers`, `national_exams`, `transmissions`, `internships`, `internship_companies`, `education_programs`, `fee_structures`, `student_payments` toutes présentes. ⚠️ `exam_fees` **n'est pas une table** (juste `exam_fees_panel.dart` / `exam_fees_provider.dart` — les frais vivent sur `fee_structures`+`student_payments`). Donc **rien à redéployer** ; l'ancienne mention « sync-rules NON déployées (PS_ADMIN_TOKEN manquant) » était PÉRIMÉE. Commande de vérif : `PS_ADMIN_TOKEN=… npx --no-install powersync fetch config --output yaml` (cf. [[sync-config-divergence]]).
- **RESTE (historique)** : (a) déployer sync-rules au dashboard (transmissions ajoutées au bucket by_school — descente multi-postes ; remontée déjà OK sans deploy) ; (b) vérif GUI côté Directeur (Soumettre + dossier↔stage — pas de compte staff dispo cette session) ; (c) 317 tests, analyze 0, build Linux OK.

## MÀJ 2026-07-17 nuit — cockpit ministère + refonte écrans + sync-rules déployées (commits `79c82fd`, `84581da`)
- **✅ Sync-rules transmissions DÉPLOYÉES** (token PAT `jpt_…6a5a687d…`) : pré-vérif +2 tables (transmissions, transmission_items) / 0 retrait → deploy OK → 2 occurrences live vérifiées. Descente multi-postes débloquée.
- **`list_chrome.dart` promu → `core/widgets/`** (composant vraiment partagé : KpiGrid animé, ListFilterBar avec « + » dedans, ListResultHeader, ListShimmer). Les 2 espaces (super_admin + admin_groupe/ministère) le partagent.
- **Cockpit Examens du MINISTÈRE** (`admin_groupe`, online) : `admin_exams_provider` (agrégation nationale par école, RLS scope groupe déjà OK) + `admin_exams_screen` (route `/admin/examens`, nav « Examens nationaux » en tête PILOTAGE). 6 KPI dont **« Écoles à risque »** (`hasCandidatesNotTransmitted` = candidats mais rien transmis → année perdue après clôture). Comble le trou : le dashboard ministère ignorait totalement les examens. ⚠️ vérif GUI admin_groupe non faite (l'app était sur compte staff Aline).
- **Écrans école Examens + Stages au standard Administrateurs** : Stages refondu (KpiGrid 6, graphique par statut, filtres+« + », tableau/cartes dans `stages_views.dart`, **action groupée « Délivrer toutes les attestations dues »**). Examens landing (KpiGrid animé + graphique couverture effectif vs inscrits + shimmer).
- **Le user pilote en admin_groupe = groupe « Ministère de l'Enseignement Technique et Professionnel »** (14 écoles, 8 candidats, 1 session) — l'espace admin_groupe EST le cockpit ministériel en pratique. Compte staff de démo = **Aline M., Directeur, Collège Public de Kinkala**.
- ✅ **HYPOTHÈSE SIDEBAR DÉMENTIE** : examens/stages ont 42 lignes `profile_permissions` (can_read), le profil « Directeur » d'Aline les a, ET le plan Institutionnel de son groupe les inclut — elle a d'ailleurs atteint un écran Session d'examen en GUI. Donc PAS de bombe : les modules sont bien accessibles pour les profils migrés (0049). Les 28 profils/70 sans examens = ceux qui ne doivent pas l'avoir (parent/élève, plans sans examens). Le point 🔴 « HYPOTHÈSE NON CONFIRMÉE » plus haut est CLOS.

## Faits VÉRIFIÉS du système congolais (ne pas re-chercher)
- **CEPE** (Certificat d'Études Primaires **Élémentaires**) — PAS « CEP ». CM2. Session 2025 : 137 247 candidats, 606 centres, 87,81 % d'admis.
- **MEPSA** : CEPE · BEPC (3e) · **Concours d'entrée en 2nde** · Bac général (Tle).
- **METP** : BET · BEP · **BTF** (Brevet de Technicien Forestier) · CAP · CQP · Bac technique · Bac professionnel. Il y a **3 baccalauréats**, pas un.
- Âges max : **24** (bacs) · **20** (BET/CAP) · **21** (autres brevets). Inscriptions METP 2025-2026 : 8 déc. 2025 → 14 févr. 2026. BET 2026 : écrits 23→27 juin, pratiques 30 juin→4 juil. Dossier bac = diplôme antérieur légalisé + **attestation de stage**.
- **15 départements** (lois 25/26/27-2024 du 8 oct. 2024 : Djoué-Léfini/Odziba, Nkéni-Alima/Gamboma, Congo-Oubangui/Mossaka). Le « 15 » affiché par l'app est EXACT.
- **NON établi** (ne pas inventer) : série E = général ou technique ? · quelle filière pro → CAP/BEP/BTF/CQP ? · sigle **BEMG** ? · maillage réel des inspections.

## Décisions d'architecture (le pourquoi)
- **La classe d'examen est DÉRIVÉE, jamais saisie.** Un booléen par classe aurait imposé des dizaines de milliers de ressaisies pour une règle nationale et stable ; une case oubliée = candidats non inscrits. `exam_eligibility_rules` (cycle, niveau, filière, tutelle, datée) → trigger → `classes.exam_id`. Surcharge : `exam_override_id` / `exam_excluded`.
- **Résolution UNIQUEMENT en SQL** (`resolve_class_exam`, spécificité : groupe 4 > filière 2 > tutelle 1). Le client Dart LIT le dérivé — la rejouer en Dart divergerait à la 1ʳᵉ réforme. C'est pourquoi `test/examens_test.dart` ne teste PAS la résolution.
- **`classes.exam_status`** = `examen | passage | a_qualifier` (mig 0045). Révélé par la dérivation réelle : 6e/CE1/Tle-E étaient indistinguables. Une 6e est une classe de PASSAGE (normal) ; une Tle E est une ANOMALIE. Niveau terminal déduit du référentiel (`is_terminal_level`), pas codé en dur.
- **Règles à confiance HAUTE seulement.** Série E et filières pro laissées SANS règle → « à qualifier ». Une règle fausse inscrit au mauvais examen (irréparable) ; une règle absente se voit et se corrige.
- **Scission école ↔ ministère** (motif OpenEMIS Core vs Exams) : `exam_candidates` est le SEUL pivot (group_id/school_id → RLS école ; session_id/center_id → agrégation nationale). Stats nationales = cross-tenant, incompatibles avec l'isolation group_id → l'espace ministère reste à faire.
- Pas de FK vers `academic_years` (tenant-scopé) → `exam_sessions.year_label` texte.

## État réel vérifié en prod
14 écoles metp / 10 mepsa · 15 départements, 24/24 écoles rattachées · **12 classes d'examen** (8× 3e→BET, CM2→CEPE, 3× Tle A/C/D→Bac G), 32 passage, 0 anomalie · 80 élèves en classe BET · session BET 2025-2026 `open`. **La filière prime sur la tutelle** (écoles mixtes).

## ✅ Sync-rules DÉPLOYÉES (2026-07-17)
Token PAT fourni par le user (`‹PAT PowerSync révoqué›…`, cf. historique). Pré-vérif 8 ajouts / 0 retrait → deploy → post-vérif **82 tables live** (avant 74), les 8 présentes. Méthode : [[sync-config-divergence]].

## ✅ Module STAGES livré (mig 0048, commit `b3f03d7`)
`internships` + `internship_companies` (portée GROUPE : un partenaire sert plusieurs écoles → bucket `by_group`, pas `by_school`). Catégorie **FORMATION PROFESSIONNELLE** (5e) — l'analyse le rangeait à tort dans « logistique » : un stage est PÉDAGOGIQUE, et le METP (14/24 écoles) n'avait aucune catégorie. Valeur du module = l'ALERTE (croisement stages × classes d'examen → dossiers de bac bloqués), pas la liste. `has_internship_attestation()` = pont vers Examens.

**Catalogue vérifié — les 3 étages, 0 orphelin :** examens→`examens`→pro+inst · stages→`formation-pro`→pro+inst. Plans : gratuit 7 · premium 16 · **pro 28** · **inst. 30**. 8 catégories.

## 🔴 HYPOTHÈSE NON CONFIRMÉE — à trancher EN PREMIER
GUI (Aline, Directeur, Collège Public de Kinkala) : **ni EXAMENS ni FORMATION PRO dans la sidebar** — et Vie scolaire/Finance/RH manquent AUSSI (donc pas spécifique aux nouveaux modules).
**Hypothèse** : les presets de `admin_access_screen.dart` ne s'appliquent qu'à la CRÉATION d'un profil → un module ajouté au catalogue n'a **aucune ligne `profile_permissions`** pour les profils EXISTANTS → invisible pour tous.
**Enjeu revenu** : une école paie « pro » pour les Examens et ne voit rien tant qu'un admin n'a pas édité chaque profil.
**NON VÉRIFIÉ** (outil Bash indisponible). Requête de confirmation :
```sql
select m.slug, coalesce(pp.can_read::text,'AUCUNE LIGNE')
from modules m left join profile_permissions pp on pp.module_id=m.id
 and pp.profile_id=(select access_profile_id from profiles where first_name='Aline')
where m.slug in ('examens','stages','notes','bulletins');
-- + le plan du groupe (verrou 2) : examens/stages ne sont QUE dans pro/institutionnel
```
Si confirmé → migration accordant les nouveaux modules aux profils existants selon `access_profiles.role_type`, en miroir des presets. Ne PAS écrire ce correctif avant confirmation.

## ⚠️ RESTE À FAIRE
1. **Confirmer + corriger** l'hypothèse ci-dessus (le plus rentable).
2. Vérification GUI réelle des écrans Examens/Stages (jamais faite avec données).
3. Espace **ministère** (sessions/centres/n° candidat/résultats/stats nationales) **non commencé** — cross-tenant, super_admin, design d'après l'espace admin_groupe (demande explicite du user).
4. `inspections` VIDE (maillage inconnu) → stats « par inspection » indisponibles.
5. Doublon **`staff_members` (84) vs `profiles` (109)** non tranché.
6. Règles série E / filières pro → CAP-BEP-BTF-CQP : à valider MEPSA/METP.

Liens : [[catalogue-modules-v2]] (désormais 7 catégories / 29 modules), [[modules-acces-hierarchie]], [[verifier-base-live-vs-schema]].
