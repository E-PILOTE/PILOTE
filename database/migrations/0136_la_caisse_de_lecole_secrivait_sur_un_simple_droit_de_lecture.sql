-- ════════════════════════════════════════════════════════════════════════════
--  0136 — LA CAISSE DE L'ÉCOLE S'ÉCRIVAIT SUR UN SIMPLE DROIT DE LECTURE
--
--  `expenses` et `budget_lines` n'avaient qu'une politique `FOR ALL` composée
--  ainsi :
--
--      school_id = auth_school_id() AND auth_sync_finance()
--
--  Or `auth_sync_finance()` ne lit qu'un DRAPEAU :
--
--      SELECT COALESCE((SELECT sync_finance FROM profiles
--                        WHERE id = auth.uid()), false)
--
--  Ce drapeau est DÉRIVÉ du droit de LECTURE sur les modules de finance — même
--  mécanique que `sync_medical` (infirmerie) et `sync_discipline`. Il dit
--  « cette personne peut voir la caisse », et il servait à décider qu'elle peut
--  la RÉÉCRIRE. Lire les dépenses de l'école et pouvoir en créer, en modifier
--  et en supprimer étaient donc le même droit.
--
--  Aucun profil du catalogue livré n'en profite aujourd'hui — « Comptabilité »
--  et « Direction » détiennent create + update sur les deux modules. Mais un
--  profil d'accès se compose PAR GROUPE, et c'est tout l'objet de la table
--  `access_profiles` : le jour où une école crée « Économat — consultation »,
--  ce profil pourrait effacer une ligne de dépense sans que rien ne l'arrête.
--  Un droit qui n'est pas exprimé n'est pas un droit accordé : c'est un droit
--  qu'on a oublié de refuser.
--
--  ── LES MODULES SE DÉDUISENT DES ÉCRANS QUI ÉCRIVENT (leçon 0116) ──────────
--  Relevé par les APPELS, pas par les imports. Chaque table n'a qu'un écrivain,
--  et il est unique :
--
--    budget_lines ← `budget`   : budget_form (saveBudgetLine),
--                                budget_screen (deleteBudgetLine)
--    expenses     ← `depenses` : depenses_form (saveExpense),
--                                depenses_screen (deleteExpense)
--
--  Aucun autre chemin : ni Edge Function, ni espace admin groupe, ni paie.
--
--  ── AUCUN ÉCRAN NE PEUT RECEVOIR DE 42501 ─────────────────────────────────
--  Vérifié avant d'écrire cette migration : les deux écrans lisent DÉJÀ
--  `create`, `update` et `delete` séparément, et les composent tous les trois
--  avec `yearReadOnlyProvider`. La moitié applicative était en place ; c'est la
--  moitié base qui manquait. Les deux bougent donc ensemble, comme l'exige
--  `docs/DEPLOIEMENT_ORDRE.md`.
--
--  ── `USING` PLUTÔT QUE `WITH CHECK` ───────────────────────────────────────
--  Pour l'UPDATE et le DELETE, le verbe est porté par `USING` : sans le droit,
--  la ligne n'est pas VUE par l'ordre, qui touche zéro ligne au lieu de lever.
--  Un 42501 est fatal au connecteur PowerSync — il jette le lot entier. On ne
--  fait lever la base que là où c'est inévitable : l'INSERT.
-- ════════════════════════════════════════════════════════════════════════════

DO $migration$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT * FROM (VALUES
      ('budget_lines', 'budget'),
      ('expenses',     'depenses')
    ) AS v(t, slug)
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I', r.t || '_tenant', r.t);

    -- Lecture : le drapeau de finance suffit — c'est bien ce qu'il exprime.
    EXECUTE format($f$
      CREATE POLICY %I ON %I FOR SELECT USING (
        (SELECT is_super_admin())
        OR (group_id = (SELECT auth_group_id())
            AND ((SELECT is_admin_groupe())
                 OR (school_id = (SELECT auth_school_id())
                     AND (SELECT auth_sync_finance())))))$f$,
      r.t || '_select', r.t);

    EXECUTE format($f$
      CREATE POLICY %I ON %I FOR INSERT WITH CHECK (
        (SELECT is_super_admin())
        OR (group_id = (SELECT auth_group_id())
            AND ((SELECT is_admin_groupe())
                 OR (school_id = (SELECT auth_school_id())
                     AND (SELECT auth_sync_finance())
                     AND (SELECT auth_module_permet(ARRAY[%L], 'create'))))))$f$,
      r.t || '_insert', r.t, r.slug);

    EXECUTE format($f$
      CREATE POLICY %I ON %I FOR UPDATE USING (
        (SELECT is_super_admin())
        OR (group_id = (SELECT auth_group_id())
            AND ((SELECT is_admin_groupe())
                 OR (school_id = (SELECT auth_school_id())
                     AND (SELECT auth_sync_finance())
                     AND (SELECT auth_module_permet(ARRAY[%L], 'update'))))))
      WITH CHECK (
        (SELECT is_super_admin())
        OR (group_id = (SELECT auth_group_id())
            AND ((SELECT is_admin_groupe())
                 OR (school_id = (SELECT auth_school_id())
                     AND (SELECT auth_sync_finance())))))$f$,
      r.t || '_update', r.t, r.slug);

    EXECUTE format($f$
      CREATE POLICY %I ON %I FOR DELETE USING (
        (SELECT is_super_admin())
        OR (group_id = (SELECT auth_group_id())
            AND ((SELECT is_admin_groupe())
                 OR (school_id = (SELECT auth_school_id())
                     AND (SELECT auth_sync_finance())
                     AND (SELECT auth_module_permet(ARRAY[%L], 'delete'))))))$f$,
      r.t || '_delete', r.t, r.slug);
  END LOOP;
END
$migration$;

COMMENT ON TABLE expenses IS
  'Dépenses de l''école. Écriture gardée par le verbe du module `depenses` '
  'depuis la migration 0136 : jusque-là, le seul drapeau `sync_finance` — '
  'dérivé du droit de LECTURE — suffisait à créer, modifier et supprimer.';

COMMENT ON TABLE budget_lines IS
  'Lignes budgétaires de l''école. Écriture gardée par le verbe du module '
  '`budget` depuis la migration 0136 (voir `expenses`).';
