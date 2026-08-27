-- ════════════════════════════════════════════════════════════════════════════
--  0126 — UN ÉLÈVE ET SON INSCRIPTION S'ÉCRIVENT AVEC UN DROIT
--
--  `students` (9 106 lignes) et `class_enrollments` (9 106) n'avaient qu'UNE
--  politique `FOR ALL` vérifiant l'appartenance à l'école. N'importe quel
--  membre du personnel pouvait donc, côté serveur, créer un élève, le
--  désinscrire, changer sa classe, l'exonérer de 100 % des frais, ou le
--  SUPPRIMER. Ce sont les deux plus grosses tables du produit, et celles dont
--  tout le reste dépend : les notes, les bulletins, les paiements, l'appel.
--
--  Ces deux modules avaient pourtant été déclarés « complets » : le contrôle
--  d'accès vivait dans l'écran, pas dans la base.
--
--  ── LA LISTE DES MODULES SE DÉDUIT DES ÉCRANS QUI ÉCRIVENT (leçon 0116) ────
--  Relevé exhaustif des appelants, et non du nom des tables :
--
--    students          ← `eleves`       : eleves_edit, eleves_actions_parts
--                      ← `inscriptions` : add_inscription_screen,
--                                         inscriptions_edit, import_eleves
--
--    class_enrollments ← `inscriptions` : add_inscription, inscriptions_actions
--                                         (valider/rejeter/radier/supprimer),
--                                         inscriptions_edit, exoneration_card,
--                                         import_eleves
--                      ← `eleves`       : eleves_actions_parts (changer de
--                                         classe, sortie, retour en validation)
--                      ← `conseils`     : passage_screen — passage_provider,
--                                         non_revenus_provider ET
--                                         cloture_examen_provider (décision de
--                                         passage, réinscription)
--                      ← `transferts`   : transfers_provider
--                      ← `discipline`   : discipline_provider (EXCLUSION :
--                                         status → 'withdrawn')
--
--  ⚠️ N'admettre que `inscriptions` aurait cassé DEUX parcours réels, et de la
--  pire façon — 42501, code FATAL, lot PowerSync entier jeté :
--    • la Vie scolaire, qui exclut un élève sans détenir `inscriptions` ;
--    • l'enseignant en conseil de classe, qui pose une décision de passage.
--  C'est exactement le piège de 0114, corrigé par 0116.
--
--  ── VÉRIFIÉ APRÈS COUP (production, transactions annulées) ─────────────────
--      PROFIL         lit  modifie élève  EXCLUT  décision passage  SUPPRIME
--      Direction      237  oui            oui     oui               (FK 23503)
--      Secrétariat    237  oui            oui     oui               (FK 23503)
--      Vie scolaire   237  non            oui     oui               non
--      Enseignant     237  non            oui     oui               non
--      Comptabilité   331  non            non     non               non
--                          (et l'exonération à 100 % : refusée aussi)
--
--  Le refus prend la forme « 0 ligne » — le USING masque la ligne — et non
--  42501 : aucun lot PowerSync n'est détruit.
--
--  ⚠️ RÉSIDU ASSUMÉ, NOMMÉ. Une politique porte sur la TABLE, pas sur la
--  COLONNE. Un enseignant détenteur de `conseils.update` franchit donc le
--  verrou de `class_enrollments` et pourrait écrire, par l'API, d'autres
--  colonnes que la décision de passage — l'écran, lui, ne le propose pas.
--  Fermer cela demande un déclencheur associant chaque COLONNE à ses modules ;
--  se tromper de correspondance ferait taire silencieusement une écriture
--  légitime, ce qui serait pire que le résidu. À traiter comme un chantier
--  propre, pas en passant.
--
--  ⚠️ La LECTURE reste à l'échelle de l'école : le périmètre par classe vit
--  dans l'application (`classesForModuleProvider`), et un secrétariat doit
--  voir toute l'école.
-- ════════════════════════════════════════════════════════════════════════════

-- ─── students ───────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS students_tenant ON students;

CREATE POLICY students_select ON students
  FOR SELECT
  USING (
    (SELECT is_super_admin())
    OR (group_id = (SELECT auth_group_id())
        AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id())))
  );

CREATE POLICY students_insert ON students
  FOR INSERT
  WITH CHECK (
    (SELECT is_super_admin())
    OR (group_id = (SELECT auth_group_id())
        AND ((SELECT is_admin_groupe())
             OR (school_id = (SELECT auth_school_id())
                 AND (SELECT auth_module_permet(
                        ARRAY['eleves', 'inscriptions'], 'create')))))
  );

CREATE POLICY students_update ON students
  FOR UPDATE
  USING (
    (SELECT is_super_admin())
    OR (group_id = (SELECT auth_group_id())
        AND ((SELECT is_admin_groupe())
             OR (school_id = (SELECT auth_school_id())
                 AND (SELECT auth_module_permet(
                        ARRAY['eleves', 'inscriptions'], 'update')))))
  )
  WITH CHECK (
    (SELECT is_super_admin())
    OR (group_id = (SELECT auth_group_id())
        AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id())))
  );

CREATE POLICY students_delete ON students
  FOR DELETE
  USING (
    (SELECT is_super_admin())
    OR (group_id = (SELECT auth_group_id())
        AND ((SELECT is_admin_groupe())
             OR (school_id = (SELECT auth_school_id())
                 AND (SELECT auth_module_permet(
                        ARRAY['eleves', 'inscriptions'], 'delete')))))
  );

-- ─── class_enrollments ──────────────────────────────────────────────────────
DROP POLICY IF EXISTS class_enrollments_tenant ON class_enrollments;

CREATE POLICY enrollments_select ON class_enrollments
  FOR SELECT
  USING (
    (SELECT is_super_admin())
    OR (group_id = (SELECT auth_group_id())
        AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id())))
  );

CREATE POLICY enrollments_insert ON class_enrollments
  FOR INSERT
  WITH CHECK (
    (SELECT is_super_admin())
    OR (group_id = (SELECT auth_group_id())
        AND ((SELECT is_admin_groupe())
             OR (school_id = (SELECT auth_school_id())
                 AND (SELECT auth_module_permet(
                        ARRAY['inscriptions', 'eleves', 'conseils',
                              'transferts', 'discipline'], 'create')))))
  );

CREATE POLICY enrollments_update ON class_enrollments
  FOR UPDATE
  USING (
    (SELECT is_super_admin())
    OR (group_id = (SELECT auth_group_id())
        AND ((SELECT is_admin_groupe())
             OR (school_id = (SELECT auth_school_id())
                 AND (SELECT auth_module_permet(
                        ARRAY['inscriptions', 'eleves', 'conseils',
                              'transferts', 'discipline'], 'update')))))
  )
  WITH CHECK (
    (SELECT is_super_admin())
    OR (group_id = (SELECT auth_group_id())
        AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id())))
  );

CREATE POLICY enrollments_delete ON class_enrollments
  FOR DELETE
  USING (
    (SELECT is_super_admin())
    OR (group_id = (SELECT auth_group_id())
        AND ((SELECT is_admin_groupe())
             OR (school_id = (SELECT auth_school_id())
                 AND (SELECT auth_module_permet(
                        ARRAY['inscriptions', 'eleves'], 'delete')))))
  );
