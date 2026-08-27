-- ════════════════════════════════════════════════════════════════════════════
--  0130 — LES PIÈCES D'UN ENFANT ET SA FAMILLE
--
--  `student_documents` (actes de naissance, certificats, photos, pièces
--  d'examen et de stage) et `student_tutors` (les parents et responsables :
--  noms, téléphones, liens de parenté, adresses) n'avaient qu'une politique
--  `FOR ALL` vérifiant l'appartenance à l'école. Tout membre du personnel
--  pouvait donc ajouter, modifier et SUPPRIMER la pièce d'identité d'un enfant
--  ou le contact de sa mère.
--
--  Ce sont des données personnelles de MINEURS et de tiers non employés par
--  l'école. Elles ne relèvent d'aucun drapeau `auth_sync_*` — ceux-ci couvrent
--  le médical, la discipline et la finance : rien ne les protégeait.
--
--  ── LES MODULES SE DÉDUISENT DES ÉCRANS QUI ÉCRIVENT (leçon 0116) ──────────
--    student_documents ← `documents`    : documents_screen, documents_provider,
--                                         student_documents_provider
--                      ← `inscriptions` : add_inscription_screen (pièces du
--                                         dossier), inscriptions_screen
--                      ← `eleves`       : eleves_screen
--                      ← `examens`      : exam_dossier_actions (pièces du
--                                         dossier de candidature)
--                      ← `stages`       : stage_documents, stage_file_dialog
--
--    student_tutors    ← `inscriptions` : add_inscription_screen,
--                                         inscriptions_edit
--                      ← `eleves`       : eleves_edit
--                      ← `annuaire`     : annuaire_form, annuaire_detail
--
--  ⚠️ CINQ modules pour les pièces, TROIS pour les tuteurs. En oublier un
--  casserait le parcours correspondant par un 42501 — code fatal, lot PowerSync
--  entier jeté. C'est le piège 0114/0116 : la liste se relève des appels, elle
--  ne se devine pas du nom de la table.
--
--  ⚠️ La LECTURE reste à l'échelle de l'école : le secrétariat doit pouvoir
--  chercher une pièce ou un contact sans connaître la classe de l'enfant.
--
--  ── VÉRIFIÉ APRÈS COUP (production, transaction annulée) ───────────────────
--      PROFIL         ajoute une pièce élève   supprime un tuteur
--      Direction      OUI                      OUI
--      Secrétariat    OUI                      OUI
--      Enseignant     refusé                   non
--      Vie scolaire   refusé                   non
-- ════════════════════════════════════════════════════════════════════════════

-- ─── student_documents ──────────────────────────────────────────────────────
DROP POLICY IF EXISTS student_documents_tenant ON student_documents;

CREATE POLICY student_documents_select ON student_documents FOR SELECT USING (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id()))));

CREATE POLICY student_documents_insert ON student_documents FOR INSERT
WITH CHECK (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe())
           OR (school_id = (SELECT auth_school_id())
               AND (SELECT auth_module_permet(
                      ARRAY['documents', 'inscriptions', 'eleves',
                            'examens', 'stages'], 'create'))))));

CREATE POLICY student_documents_update ON student_documents FOR UPDATE USING (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe())
           OR (school_id = (SELECT auth_school_id())
               AND (SELECT auth_module_permet(
                      ARRAY['documents', 'inscriptions', 'eleves',
                            'examens', 'stages'], 'update'))))))
WITH CHECK (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id()))));

CREATE POLICY student_documents_delete ON student_documents FOR DELETE USING (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe())
           OR (school_id = (SELECT auth_school_id())
               AND (SELECT auth_module_permet(
                      ARRAY['documents', 'inscriptions', 'eleves',
                            'examens', 'stages'], 'delete'))))));

-- ─── student_tutors ─────────────────────────────────────────────────────────
DROP POLICY IF EXISTS student_tutors_tenant ON student_tutors;

CREATE POLICY student_tutors_select ON student_tutors FOR SELECT USING (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id()))));

CREATE POLICY student_tutors_insert ON student_tutors FOR INSERT WITH CHECK (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe())
           OR (school_id = (SELECT auth_school_id())
               AND (SELECT auth_module_permet(
                      ARRAY['inscriptions', 'eleves', 'annuaire'], 'create'))))));

CREATE POLICY student_tutors_update ON student_tutors FOR UPDATE USING (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe())
           OR (school_id = (SELECT auth_school_id())
               AND (SELECT auth_module_permet(
                      ARRAY['inscriptions', 'eleves', 'annuaire'], 'update'))))))
WITH CHECK (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id()))));

CREATE POLICY student_tutors_delete ON student_tutors FOR DELETE USING (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe())
           OR (school_id = (SELECT auth_school_id())
               AND (SELECT auth_module_permet(
                      ARRAY['inscriptions', 'eleves', 'annuaire'], 'delete'))))));
