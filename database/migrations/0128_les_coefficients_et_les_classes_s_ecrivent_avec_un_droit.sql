-- ════════════════════════════════════════════════════════════════════════════
--  0128 — LES COEFFICIENTS, LES CLASSES ET LES CANDIDATS
--
--  Quatre tables encore en `FOR ALL` sur la seule appartenance à l'école :
--
--    class_subjects (3 904)  le COEFFICIENT d'une matière dans une classe.
--                            Le changer change toutes les moyennes générales,
--                            donc tous les bulletins, donc les rangs et les
--                            mentions. Silencieusement.
--    exam_candidates (2 126) l'inscription d'un élève au BEPC / au BAC.
--                            La retirer prive un enfant de son examen.
--    classes (494)           créer, renommer, archiver une classe.
--    subjects (62)           le catalogue des matières de l'école.
--
--  ── LES MODULES SE DÉDUISENT DES ÉCRANS QUI ÉCRIVENT (leçon 0116) ──────────
--    subjects        ← `matieres`  : subjects_provider (subjects_screen)
--    class_subjects  ← `matieres`  : class_subjects_provider, appelé par
--                                    subject_detail_dialog ← subjects_screen
--                    ← `conseils`  : class_rollover.dart:125 — la reconduction
--                                    d'année recopie les coefficients ; elle
--                                    part de passage_screen, slug `conseils`
--    classes         ← `classes`   : class_provider (classes_screen,
--                                    classe_detail_screen)
--                    ← `conseils`  : class_rollover.dart:92 (même reconduction)
--                    ← CHEF D'ÉTABLISSEMENT : `copySchoolClassesToYear`, depuis
--                      l'écran NATIF « Calendrier scolaire » (/user/calendrier)
--    exam_candidates ← `examens`   : exam_registration_provider,
--                                    exam_dossier_actions (exam_session_screen)
--
--  ⚠️ LE CALENDRIER SCOLAIRE N'EST PAS UN MODULE. `school_calendar_screen`
--  n'utilise pas `ModuleScaffold` : c'est un écran natif de configuration,
--  gardé par le RÔLE (`_kEditRoles = {proviseur, directeur}`) et non par le
--  catalogue. `auth_module_permet` ne peut donc pas le couvrir — d'où
--  `auth_est_chef_etablissement()`, qui reproduit exactement ce garde.
--  L'ignorer aurait cassé la préparation de la rentrée par un 42501, code
--  fatal, lot PowerSync entier jeté.
--
--  ⚠️ La LECTURE reste à l'échelle de l'école : le périmètre par classe vit
--  dans l'application.
--
--  ⚠️ La porte `conseils` ouverte ici est RESSERRÉE dès la migration suivante
--  (0129) : la vérification a montré qu'elle laissait tout enseignant créer des
--  classes et réécrire des coefficients.
-- ════════════════════════════════════════════════════════════════════════════

-- Le garde de l'écran natif « Calendrier scolaire », côté base.
CREATE OR REPLACE FUNCTION public.auth_est_chef_etablissement()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
  SELECT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND role IN ('directeur', 'proviseur')
  );
$fn$;

GRANT EXECUTE ON FUNCTION public.auth_est_chef_etablissement() TO authenticated;

COMMENT ON FUNCTION public.auth_est_chef_etablissement() IS
  'Reproduit en base le garde de l''écran natif « Calendrier scolaire » '
  '(`_kEditRoles = {proviseur, directeur}` dans school_calendar_screen.dart). '
  'Nécessaire parce que cet écran est HORS catalogue : aucun module ne le '
  'couvre. Migration 0128.';

-- ─── subjects ───────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS subjects_tenant ON subjects;

CREATE POLICY subjects_select ON subjects FOR SELECT USING (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id()))));

CREATE POLICY subjects_insert ON subjects FOR INSERT WITH CHECK (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe())
           OR (school_id = (SELECT auth_school_id())
               AND (SELECT auth_module_permet(ARRAY['matieres'], 'create'))))));

CREATE POLICY subjects_update ON subjects FOR UPDATE USING (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe())
           OR (school_id = (SELECT auth_school_id())
               AND (SELECT auth_module_permet(ARRAY['matieres'], 'update'))))))
WITH CHECK (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id()))));

CREATE POLICY subjects_delete ON subjects FOR DELETE USING (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe())
           OR (school_id = (SELECT auth_school_id())
               AND (SELECT auth_module_permet(ARRAY['matieres'], 'delete'))))));

-- ─── class_subjects ─────────────────────────────────────────────────────────
DROP POLICY IF EXISTS class_subjects_tenant ON class_subjects;

CREATE POLICY class_subjects_select ON class_subjects FOR SELECT USING (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id()))));

CREATE POLICY class_subjects_insert ON class_subjects FOR INSERT WITH CHECK (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe())
           OR (school_id = (SELECT auth_school_id())
               AND (SELECT auth_module_permet(
                      ARRAY['matieres', 'conseils'], 'create'))))));

CREATE POLICY class_subjects_update ON class_subjects FOR UPDATE USING (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe())
           OR (school_id = (SELECT auth_school_id())
               AND (SELECT auth_module_permet(
                      ARRAY['matieres', 'conseils'], 'update'))))))
WITH CHECK (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id()))));

CREATE POLICY class_subjects_delete ON class_subjects FOR DELETE USING (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe())
           OR (school_id = (SELECT auth_school_id())
               AND (SELECT auth_module_permet(ARRAY['matieres'], 'delete'))))));

-- ─── classes ────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS classes_tenant ON classes;

CREATE POLICY classes_select ON classes FOR SELECT USING (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id()))));

CREATE POLICY classes_insert ON classes FOR INSERT WITH CHECK (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe())
           OR (school_id = (SELECT auth_school_id())
               AND ((SELECT auth_module_permet(
                       ARRAY['classes', 'conseils'], 'create'))
                    OR (SELECT auth_est_chef_etablissement()))))));

CREATE POLICY classes_update ON classes FOR UPDATE USING (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe())
           OR (school_id = (SELECT auth_school_id())
               AND ((SELECT auth_module_permet(
                       ARRAY['classes', 'conseils'], 'update'))
                    OR (SELECT auth_est_chef_etablissement()))))))
WITH CHECK (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id()))));

CREATE POLICY classes_delete ON classes FOR DELETE USING (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe())
           OR (school_id = (SELECT auth_school_id())
               AND (SELECT auth_module_permet(ARRAY['classes'], 'delete'))))));

-- ─── exam_candidates ────────────────────────────────────────────────────────
DROP POLICY IF EXISTS exam_candidates_write ON exam_candidates;

CREATE POLICY exam_candidates_insert ON exam_candidates FOR INSERT WITH CHECK (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe())
           OR (school_id = (SELECT auth_school_id())
               AND (SELECT auth_module_permet(ARRAY['examens'], 'create'))))));

CREATE POLICY exam_candidates_update ON exam_candidates FOR UPDATE USING (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe())
           OR (school_id = (SELECT auth_school_id())
               AND (SELECT auth_module_permet(ARRAY['examens'], 'update'))))))
WITH CHECK (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id()))));

CREATE POLICY exam_candidates_delete ON exam_candidates FOR DELETE USING (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe())
           OR (school_id = (SELECT auth_school_id())
               AND (SELECT auth_module_permet(ARRAY['examens'], 'delete'))))));
