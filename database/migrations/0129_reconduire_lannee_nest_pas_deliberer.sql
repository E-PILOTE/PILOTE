-- ════════════════════════════════════════════════════════════════════════════
--  0129 — RECONDUIRE L'ANNÉE N'EST PAS DÉLIBÉRER
--
--  Suite immédiate de 0128, et correctif d'un choix que la vérification de
--  0128 a mis en évidence.
--
--  0128 admettait le module `conseils` en écriture sur `classes` et
--  `class_subjects`, parce que la reconduction d'année (`rolloverClasses`)
--  part de l'écran Passage, dont le slug est `conseils`. Or « Reconduire les
--  classes » CRÉE la structure de l'année suivante et recopie ses
--  coefficients : un acte d'établissement, pas un acte de professeur. Le
--  bouton était gardé par `conseils.update`, que tout enseignant possède.
--
--  Les deux moitiés bougent ensemble : l'écran réserve désormais le bouton à
--  `conseils.validate` (`passage_screen.dart`, `passage_parts.dart`), et la
--  base exige le même droit. Sans quoi un enseignant appuierait sur un bouton
--  que la base refuse — 42501, code fatal, lot PowerSync entier jeté.
--
--  Les autres portes ne bougent pas : `classes.create/update` pour la page
--  Classes, `matieres.*` pour les matières, et le chef d'établissement pour
--  l'écran natif Calendrier.
--
--  ⚠️ CE QUE CETTE MIGRATION NE CHANGE PAS, ET QUI EST UNE QUESTION DE
--  CONFIGURATION, PAS DE CODE : le profil « Enseignant » livré au catalogue
--  détient `matieres` create+update et `classes` create+update. Un enseignant
--  peut donc TOUJOURS changer un coefficient et créer une classe — non plus
--  par la porte `conseils`, mais par la sienne. Mesuré le 2026-08-27 :
--
--      PROFIL         rôle        change un coefficient  renomme  crée
--      Direction      directeur   oui                    oui      OUI
--      Secrétariat    secretaire  non                    non      refusé
--      Enseignant     enseignant  oui                    oui      OUI
--      Vie scolaire   surveillant non                    non      refusé
--
--  Le coefficient d'une matière fixe toutes les moyennes générales de la
--  classe. Qu'un professeur puisse le modifier est un choix de droits, pas un
--  défaut de RLS : il se tranche dans les profils d'accès de l'admin groupe.
--  Nommé ici pour qu'il soit décidé, et non subi.
-- ════════════════════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS classes_insert ON classes;
CREATE POLICY classes_insert ON classes FOR INSERT WITH CHECK (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe())
           OR (school_id = (SELECT auth_school_id())
               AND ((SELECT auth_module_permet(ARRAY['classes'], 'create'))
                    OR (SELECT auth_module_permet(ARRAY['conseils'], 'validate'))
                    OR (SELECT auth_est_chef_etablissement()))))));

DROP POLICY IF EXISTS classes_update ON classes;
CREATE POLICY classes_update ON classes FOR UPDATE USING (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe())
           OR (school_id = (SELECT auth_school_id())
               AND ((SELECT auth_module_permet(ARRAY['classes'], 'update'))
                    OR (SELECT auth_module_permet(ARRAY['conseils'], 'validate'))
                    OR (SELECT auth_est_chef_etablissement()))))))
WITH CHECK (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id()))));

DROP POLICY IF EXISTS class_subjects_insert ON class_subjects;
CREATE POLICY class_subjects_insert ON class_subjects FOR INSERT WITH CHECK (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe())
           OR (school_id = (SELECT auth_school_id())
               AND ((SELECT auth_module_permet(ARRAY['matieres'], 'create'))
                    OR (SELECT auth_module_permet(ARRAY['conseils'], 'validate')))))));

DROP POLICY IF EXISTS class_subjects_update ON class_subjects;
CREATE POLICY class_subjects_update ON class_subjects FOR UPDATE USING (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe())
           OR (school_id = (SELECT auth_school_id())
               AND ((SELECT auth_module_permet(ARRAY['matieres'], 'update'))
                    OR (SELECT auth_module_permet(ARRAY['conseils'], 'validate')))))))
WITH CHECK (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id()))));
