-- ════════════════════════════════════════════════════════════════════════════
--  0143 — UN STAGE S'ÉCRIVAIT SANS DROIT
--
--  `internships` et `internship_companies` n'avaient qu'un `FOR ALL` sur
--  l'appartenance à l'école : tout membre du personnel pouvait enregistrer un
--  stage, en modifier l'évaluation, et DÉLIVRER OU RETIRER une attestation.
--
--  Ce n'est pas un registre décoratif. La note METP exige une attestation de
--  stage au dossier des baccalauréats techniques et professionnels : un élève
--  de Terminale sans attestation a un dossier IRRECEVABLE. Retirer une
--  attestation, c'est retirer à un enfant le droit de se présenter au bac.
--
--  ── LES MODULES SE DÉDUISENT DES ÉCRANS QUI ÉCRIVENT (leçon 0116) ─────────
--  Relevé par les APPELS. Un seul module, un seul fichier d'écriture :
--
--    internships           ← `stages` : stage_actions.dart, appelé par
--                            stages_screen, stage_form_dialog,
--                            stage_attestation_dialog, stage_file_dialog
--    internship_companies  ← `stages` : stage_actions.dart
--
--  ── L'ORDRE DE DÉPLOIEMENT EST RESPECTÉ ICI ───────────────────────────────
--  Vérifié AVANT d'écrire, et c'est la leçon coûteuse de la journée (voir
--  `0141`) : le build publié 3.3.0+20 garde la création par
--  `canProvider(stages, 'create')` — donc l'INSERT, seul chemin fatal, est
--  couvert. Les deux profils du catalogue qui ouvrent ce module (Direction et
--  Secrétariat) détiennent create + update + delete : aucun ne peut atteindre
--  un bouton que la base refusera.
--
--  L'écran n'offre aujourd'hui AUCUNE suppression (`deleteInternship` n'a pas
--  d'appelant) : la politique DELETE est donc écrite pour le jour où elle sera
--  câblée, sans rien exposer entre-temps.
--
--  ── `USING` PLUTÔT QUE `WITH CHECK` ───────────────────────────────────────
--  Pour l'UPDATE et le DELETE, le verbe est porté par `USING` : sans le droit,
--  la ligne n'est pas VUE par l'ordre, qui touche zéro ligne au lieu de lever.
--  Un 42501 est fatal au connecteur PowerSync — il jette le lot entier.
-- ════════════════════════════════════════════════════════════════════════════

DO $migration$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT unnest(ARRAY['internships', 'internship_companies']) AS t
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I', r.t || '_write', r.t);
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I', r.t || '_select', r.t);

    EXECUTE format($f$
      CREATE POLICY %I ON %I FOR SELECT USING (
        (SELECT is_super_admin())
        OR (group_id = (SELECT auth_group_id())
            AND ((SELECT is_admin_groupe())
                 OR school_id IS NULL
                 OR school_id = (SELECT auth_school_id()))))$f$,
      r.t || '_select', r.t);

    EXECUTE format($f$
      CREATE POLICY %I ON %I FOR INSERT WITH CHECK (
        (SELECT is_super_admin())
        OR (group_id = (SELECT auth_group_id())
            AND ((SELECT is_admin_groupe())
                 OR (school_id = (SELECT auth_school_id())
                     AND (SELECT auth_module_permet(ARRAY['stages'], 'create'))))))$f$,
      r.t || '_insert', r.t);

    EXECUTE format($f$
      CREATE POLICY %I ON %I FOR UPDATE USING (
        (SELECT is_super_admin())
        OR (group_id = (SELECT auth_group_id())
            AND ((SELECT is_admin_groupe())
                 OR (school_id = (SELECT auth_school_id())
                     AND (SELECT auth_module_permet(ARRAY['stages'], 'update'))))))
      WITH CHECK (
        (SELECT is_super_admin())
        OR (group_id = (SELECT auth_group_id())
            AND ((SELECT is_admin_groupe())
                 OR school_id = (SELECT auth_school_id()))))$f$,
      r.t || '_update', r.t);

    EXECUTE format($f$
      CREATE POLICY %I ON %I FOR DELETE USING (
        (SELECT is_super_admin())
        OR (group_id = (SELECT auth_group_id())
            AND ((SELECT is_admin_groupe())
                 OR (school_id = (SELECT auth_school_id())
                     AND (SELECT auth_module_permet(ARRAY['stages'], 'delete'))))))$f$,
      r.t || '_delete', r.t);
  END LOOP;
END
$migration$;

COMMENT ON COLUMN internships.attestation_issued_at IS
  'Date de délivrance de l''attestation de stage. Sans elle, le dossier de bac '
  'technique est irrecevable (note METP). Écriture gardée par le verbe du '
  'module `stages` depuis la migration 0143 : jusque-là, tout membre du '
  'personnel de l''école pouvait la délivrer ou la retirer.';
