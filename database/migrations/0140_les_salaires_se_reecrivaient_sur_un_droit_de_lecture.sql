-- ════════════════════════════════════════════════════════════════════════════
--  0140 — LES SALAIRES SE RÉÉCRIVAIENT SUR UN DROIT DE LECTURE
--
--  Cinq tables des ressources humaines n'avaient qu'une politique `FOR ALL`,
--  et deux gardes différentes — toutes deux insuffisantes :
--
--    payroll          `sync_finance`   les bulletins de salaire
--    staff_career     `sync_finance`   la carrière (postes, échelons)
--    staff_diplomas   `sync_finance`   les diplômes
--    leave_requests   RIEN             les demandes de congé ET leur validation
--    staff_attendance RIEN             la présence des agents
--
--  ── LES DEUX SANS AUCUNE GARDE ────────────────────────────────────────────
--  `leave_requests` et `staff_attendance` n'étaient bornées que par
--  l'appartenance à l'école. Tout membre du personnel pouvait donc APPROUVER
--  SA PROPRE demande de congé, et se marquer présent un mois entier. La
--  présence des agents alimente la paie : ce n'est pas un registre décoratif.
--
--  ── LES TROIS GARDÉES PAR UN DRAPEAU QUI DIT « LIRE » ─────────────────────
--  `auth_sync_finance()` ne lit qu'un booléen dérivé, recalculé par
--  `trg_profiles_sensitive_flags` :
--
--      sync_finance = can_read sur l'un de
--        {depenses, budget, personnel, presences-personnel, conges, paie}
--
--  C'est un droit de LECTURE. Il servait à décider qu'on peut RÉÉCRIRE un
--  bulletin de salaire. Concrètement : un profil qui ouvre « Présences
--  Personnel » pour savoir qui est là obtenait `sync_finance = true`, et
--  pouvait de là réécrire les salaires de tout l'établissement. Même mécanique
--  que la caisse, corrigée en 0136 — le relevé de ce jour-là n'était pas allé
--  jusqu'aux RH.
--
--  ── LES MODULES SE DÉDUISENT DES ÉCRANS QUI ÉCRIVENT (leçon 0116) ─────────
--  Relevé par les APPELS :
--
--    payroll          ← `paie`                : paie_screen, paie_form
--    leave_requests   ← `conges`              : conges_screen, conges_form
--    staff_attendance ← `presences-personnel` : presences_personnel_screen
--    staff_career     ← `personnel`           : personnel_dossier_sheet/forms
--    staff_diplomas   ← `personnel`           : personnel_dossier_sheet/forms
--
--  ⚠️ `staff_photo_requests` N'EST PAS TOUCHÉE. Elle est alimentée par
--  l'enregistrement d'un agent, dont l'autorisation est décidée PAR LE SERVEUR
--  (`contexte_creation_agent` / `creer_agent_ecole`, SECURITY DEFINER). Lui
--  imposer en plus `personnel.create` refuserait la photo à quelqu'un que le
--  serveur vient d'autoriser à créer l'agent. Ce qui n'a pas d'écrivain
--  client-side n'a pas besoin d'une porte client-side.
--
--  ── AUCUN ÉCRAN NE PEUT RECEVOIR DE 42501 ─────────────────────────────────
--  Vérifié avant d'écrire : `paie_screen`, `conges_screen` et
--  `personnel_dossier_sheet` lisent déjà `create`, `update` et `delete`
--  séparément. `presences_personnel_screen` ne lisait que `create` alors que
--  pointer fait aussi des UPDATE — corrigé dans le même commit, avant cette
--  migration.
--
--  ── `USING` PLUTÔT QUE `WITH CHECK` ───────────────────────────────────────
--  Pour l'UPDATE et le DELETE, le verbe est porté par `USING` : sans le droit,
--  la ligne n'est pas VUE par l'ordre, qui touche zéro ligne au lieu de lever.
--  Un 42501 est fatal au connecteur PowerSync — il jette le lot entier.
-- ════════════════════════════════════════════════════════════════════════════

DO $migration$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT * FROM (VALUES
      ('payroll',          'paie',                true),
      ('staff_career',     'personnel',           true),
      ('staff_diplomas',   'personnel',           true),
      ('leave_requests',   'conges',              false),
      ('staff_attendance', 'presences-personnel', false)
    ) AS v(t, slug, sensible)
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I', r.t || '_tenant', r.t);

    -- Lecture : inchangée. `sync_finance` reste ce qu'il est — un droit de
    -- lecture — là où il gardait déjà la lecture.
    EXECUTE format($f$
      CREATE POLICY %I ON %I FOR SELECT USING (
        (SELECT is_super_admin())
        OR (group_id = (SELECT auth_group_id())
            AND ((SELECT is_admin_groupe())
                 OR (school_id = (SELECT auth_school_id())
                     AND (%s)))))$f$,
      r.t || '_select', r.t,
      CASE WHEN r.sensible THEN '(SELECT auth_sync_finance())' ELSE 'true' END);

    EXECUTE format($f$
      CREATE POLICY %I ON %I FOR INSERT WITH CHECK (
        (SELECT is_super_admin())
        OR (group_id = (SELECT auth_group_id())
            AND ((SELECT is_admin_groupe())
                 OR (school_id = (SELECT auth_school_id())
                     AND (SELECT auth_module_permet(ARRAY[%L], 'create'))))))$f$,
      r.t || '_insert', r.t, r.slug);

    EXECUTE format($f$
      CREATE POLICY %I ON %I FOR UPDATE USING (
        (SELECT is_super_admin())
        OR (group_id = (SELECT auth_group_id())
            AND ((SELECT is_admin_groupe())
                 OR (school_id = (SELECT auth_school_id())
                     AND (SELECT auth_module_permet(ARRAY[%L], 'update'))))))
      WITH CHECK (
        (SELECT is_super_admin())
        OR (group_id = (SELECT auth_group_id())
            AND ((SELECT is_admin_groupe())
                 OR school_id = (SELECT auth_school_id()))))$f$,
      r.t || '_update', r.t, r.slug);

    EXECUTE format($f$
      CREATE POLICY %I ON %I FOR DELETE USING (
        (SELECT is_super_admin())
        OR (group_id = (SELECT auth_group_id())
            AND ((SELECT is_admin_groupe())
                 OR (school_id = (SELECT auth_school_id())
                     AND (SELECT auth_module_permet(ARRAY[%L], 'delete'))))))$f$,
      r.t || '_delete', r.t, r.slug);
  END LOOP;
END
$migration$;

COMMENT ON TABLE payroll IS
  'Bulletins de salaire. Écriture gardée par le verbe du module `paie` depuis '
  'la migration 0140 : jusque-là, le drapeau `sync_finance` — dérivé du droit '
  'de LECTURE sur six modules, dont « Présences Personnel » — suffisait à les '
  'réécrire.';

COMMENT ON TABLE leave_requests IS
  'Demandes de congé et leur validation. Écriture gardée par le verbe du '
  'module `conges` depuis la migration 0140 : jusque-là, tout membre du '
  'personnel de l''école pouvait approuver sa propre demande.';
