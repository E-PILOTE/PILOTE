-- ════════════════════════════════════════════════════════════════════════════
--  0131 — LA VIE SCOLAIRE ÉCRIVAIT SANS VERBE
--
--  Les six tables des modules Vie scolaire n'avaient qu'une politique `FOR ALL`.
--  Deux d'entre elles portaient un drapeau de sensibilité, les quatre autres
--  rien du tout :
--
--    discipline_incidents  drapeau `sync_discipline` — mais UN SEUL verbe pour
--                          lire, écrire ET SUPPRIMER. Quiconque pouvait voir
--                          une sanction pouvait l'effacer. Même erreur de
--                          catégorie que `audit_logs` (0127) : un registre que
--                          l'intéressé peut faire disparaître n'est pas un
--                          registre.
--    infirmary_visits      drapeau `sync_medical` — idem, sur du médical.
--    canteen_records       rien.
--    library_items         rien.
--    library_loans         rien.
--    student_orientations  rien — l'orientation décide de la suite d'une
--                          scolarité.
--
--  Les six tables sont VIDES aujourd'hui (relevé du 2026-08-28). C'est
--  exactement le bon moment : gater une table vide ne coûte rien, et
--  `class_subjects` à 3 904 lignes a demandé deux migrations (0128, 0129).
--
--  ── LES MODULES SE DÉDUISENT DES ÉCRANS QUI ÉCRIVENT (leçon 0116) ──────────
--  Relevé exhaustif : chacune de ces tables n'a QU'UN SEUL fichier écrivain, et
--  chaque écrivain appartient à un seul module. Aucune ambiguïté ici — c'est
--  rare, et c'est ce qui rend cette migration sûre.
--
--    discipline_incidents ← `discipline`   : discipline_provider.dart
--    infirmary_visits     ← `infirmerie`   : infirmerie_provider.dart
--    canteen_records      ← `cantine`      : cantine_provider.dart
--    library_items        ← `bibliotheque` : biblio_provider.dart
--    library_loans        ← `bibliotheque` : biblio_provider.dart
--    student_orientations ← `orientation`  : orientation_provider.dart
--
--  ⚠️ `discipline_provider.prononcerExclusion` écrit aussi `class_enrollments`
--  (fermeture de l'inscription après une exclusion définitive). Vérifié :
--  `enrollments_insert` admet déjà `discipline`, et `enrollments_update` n'a
--  pas de garde par module. Rien à faire — mais il fallait le vérifier, sinon
--  42501, code fatal, lot PowerSync entier jeté en silence.
--
--  ── LE DRAPEAU ET LE VERBE SE COMPOSENT, ILS NE SE REMPLACENT PAS ──────────
--  Le drapeau (`sync_discipline`, `sync_medical`) dit : « cette personne a le
--  droit de VOIR du disciplinaire / du médical ». C'est lui qui commande aussi
--  la SYNCHRO — les sync-rules s'en servent pour décider si la donnée descend
--  sur l'appareil. On n'y touche donc pas : la lecture reste au drapeau seul.
--  Le verbe du module dit : « et elle a le droit de l'écrire / de l'effacer ».
--  Les deux se posent en ET sur les écritures.
--
--  ⚠️ POURQUOI CE « ET » NE PEUT PAS PRODUIRE DE 42501. Le drapeau est DÉRIVÉ
--  par `trg_profiles_sensitive_flags` de `discipline.can_read` (resp.
--  `infirmerie.can_read`). Un profil qui possède `discipline.create` sans
--  `can_read` n'atteint pas l'écran : `ModuleScaffold` le masque sur `can_read`
--  (verrou 3). Il n'y a donc aucun chemin applicatif où le verbe est accordé et
--  le drapeau absent. Le « ET » ferme une porte dérobée sans jamais fermer une
--  porte utilisée.
--
--  ── VÉRIFIÉ APRÈS COUP (production, transaction annulée) ───────────────────
--  Voir le bloc de vérification joint à la migration.
-- ════════════════════════════════════════════════════════════════════════════

-- ─── discipline_incidents (sensible : drapeau + verbe) ──────────────────────
DROP POLICY IF EXISTS discipline_incidents_tenant ON discipline_incidents;

CREATE POLICY discipline_incidents_select ON discipline_incidents FOR SELECT
USING (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe())
           OR (school_id = (SELECT auth_school_id())
               AND (SELECT auth_sync_discipline())))));

CREATE POLICY discipline_incidents_insert ON discipline_incidents FOR INSERT
WITH CHECK (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe())
           OR (school_id = (SELECT auth_school_id())
               AND (SELECT auth_sync_discipline())
               AND (SELECT auth_module_permet(ARRAY['discipline'], 'create'))))));

CREATE POLICY discipline_incidents_update ON discipline_incidents FOR UPDATE
USING (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe())
           OR (school_id = (SELECT auth_school_id())
               AND (SELECT auth_sync_discipline())
               AND (SELECT auth_module_permet(ARRAY['discipline'], 'update'))))))
WITH CHECK (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id()))));

CREATE POLICY discipline_incidents_delete ON discipline_incidents FOR DELETE
USING (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe())
           OR (school_id = (SELECT auth_school_id())
               AND (SELECT auth_sync_discipline())
               AND (SELECT auth_module_permet(ARRAY['discipline'], 'delete'))))));

-- ─── infirmary_visits (sensible : drapeau + verbe) ──────────────────────────
DROP POLICY IF EXISTS infirmary_visits_tenant ON infirmary_visits;

CREATE POLICY infirmary_visits_select ON infirmary_visits FOR SELECT USING (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe())
           OR (school_id = (SELECT auth_school_id())
               AND (SELECT auth_sync_medical())))));

CREATE POLICY infirmary_visits_insert ON infirmary_visits FOR INSERT WITH CHECK (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe())
           OR (school_id = (SELECT auth_school_id())
               AND (SELECT auth_sync_medical())
               AND (SELECT auth_module_permet(ARRAY['infirmerie'], 'create'))))));

CREATE POLICY infirmary_visits_update ON infirmary_visits FOR UPDATE USING (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe())
           OR (school_id = (SELECT auth_school_id())
               AND (SELECT auth_sync_medical())
               AND (SELECT auth_module_permet(ARRAY['infirmerie'], 'update'))))))
WITH CHECK (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id()))));

CREATE POLICY infirmary_visits_delete ON infirmary_visits FOR DELETE USING (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe())
           OR (school_id = (SELECT auth_school_id())
               AND (SELECT auth_sync_medical())
               AND (SELECT auth_module_permet(ARRAY['infirmerie'], 'delete'))))));

-- ─── canteen_records ────────────────────────────────────────────────────────
DROP POLICY IF EXISTS canteen_records_tenant ON canteen_records;

CREATE POLICY canteen_records_select ON canteen_records FOR SELECT USING (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id()))));

CREATE POLICY canteen_records_insert ON canteen_records FOR INSERT WITH CHECK (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe())
           OR (school_id = (SELECT auth_school_id())
               AND (SELECT auth_module_permet(ARRAY['cantine'], 'create'))))));

CREATE POLICY canteen_records_update ON canteen_records FOR UPDATE USING (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe())
           OR (school_id = (SELECT auth_school_id())
               AND (SELECT auth_module_permet(ARRAY['cantine'], 'update'))))))
WITH CHECK (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id()))));

CREATE POLICY canteen_records_delete ON canteen_records FOR DELETE USING (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe())
           OR (school_id = (SELECT auth_school_id())
               AND (SELECT auth_module_permet(ARRAY['cantine'], 'delete'))))));

-- ─── library_items ──────────────────────────────────────────────────────────
DROP POLICY IF EXISTS library_items_tenant ON library_items;

CREATE POLICY library_items_select ON library_items FOR SELECT USING (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id()))));

CREATE POLICY library_items_insert ON library_items FOR INSERT WITH CHECK (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe())
           OR (school_id = (SELECT auth_school_id())
               AND (SELECT auth_module_permet(ARRAY['bibliotheque'], 'create'))))));

-- ⚠️ `update` et NON `delete` pour le stock : rendre un livre décrémente
-- `available_quantity` par un UPDATE. Un agent qui prête et reçoit des retours
-- a besoin d'`update`, pas du droit de supprimer une fiche du catalogue.
CREATE POLICY library_items_update ON library_items FOR UPDATE USING (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe())
           OR (school_id = (SELECT auth_school_id())
               AND (SELECT auth_module_permet(ARRAY['bibliotheque'], 'update'))))))
WITH CHECK (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id()))));

CREATE POLICY library_items_delete ON library_items FOR DELETE USING (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe())
           OR (school_id = (SELECT auth_school_id())
               AND (SELECT auth_module_permet(ARRAY['bibliotheque'], 'delete'))))));

-- ─── library_loans ──────────────────────────────────────────────────────────
DROP POLICY IF EXISTS library_loans_tenant ON library_loans;

CREATE POLICY library_loans_select ON library_loans FOR SELECT USING (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id()))));

CREATE POLICY library_loans_insert ON library_loans FOR INSERT WITH CHECK (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe())
           OR (school_id = (SELECT auth_school_id())
               AND (SELECT auth_module_permet(ARRAY['bibliotheque'], 'create'))))));

CREATE POLICY library_loans_update ON library_loans FOR UPDATE USING (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe())
           OR (school_id = (SELECT auth_school_id())
               AND (SELECT auth_module_permet(ARRAY['bibliotheque'], 'update'))))))
WITH CHECK (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id()))));

CREATE POLICY library_loans_delete ON library_loans FOR DELETE USING (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe())
           OR (school_id = (SELECT auth_school_id())
               AND (SELECT auth_module_permet(ARRAY['bibliotheque'], 'delete'))))));

-- ─── student_orientations ───────────────────────────────────────────────────
DROP POLICY IF EXISTS student_orientations_tenant ON student_orientations;

CREATE POLICY student_orientations_select ON student_orientations FOR SELECT
USING (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id()))));

CREATE POLICY student_orientations_insert ON student_orientations FOR INSERT
WITH CHECK (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe())
           OR (school_id = (SELECT auth_school_id())
               AND (SELECT auth_module_permet(ARRAY['orientation'], 'create'))))));

CREATE POLICY student_orientations_update ON student_orientations FOR UPDATE
USING (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe())
           OR (school_id = (SELECT auth_school_id())
               AND (SELECT auth_module_permet(ARRAY['orientation'], 'update'))))))
WITH CHECK (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id()))));

CREATE POLICY student_orientations_delete ON student_orientations FOR DELETE
USING (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe())
           OR (school_id = (SELECT auth_school_id())
               AND (SELECT auth_module_permet(ARRAY['orientation'], 'delete'))))));
