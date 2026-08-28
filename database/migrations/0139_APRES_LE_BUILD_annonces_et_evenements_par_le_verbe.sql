-- ════════════════════════════════════════════════════════════════════════════
--  0139 — ⚠️ NE PAS APPLIQUER AVANT LA PUBLICATION DU BUILD ⚠️
--
--  Cette migration durcit la RLS de `announcements` et `events`. Le build qui
--  porte les gardes correspondants (`exigerDroitComm`, migration 0138) N'EST
--  PAS ENCORE PUBLIÉ aux écoles.
--
--  L'appliquer maintenant rendrait la publication FATALE pour tout profil sans
--  le verbe : la base refuse en 42501, code fatal pour le connecteur PowerSync,
--  qui appelle `transaction.complete()` et JETTE LE LOT ENTIER en attente sur
--  le poste. C'est exactement la règle de `docs/DEPLOIEMENT_ORDRE.md` : les
--  deux moitiés bougent ensemble, ou l'écart devient un lot perdu.
--
--  ORDRE : pousser les commits → publier le build → appliquer CE fichier.
--
--  ── CE QU'ELLE CORRIGE ────────────────────────────────────────────────────
--  `announcements` et `events` n'ont qu'un `FOR ALL` sur l'appartenance à
--  l'école : la base laisse donc n'importe quel membre du personnel publier au
--  nom de l'établissement et supprimer la publication d'un autre.
--
--  L'écran, lui, gardait déjà — mais par le RÔLE (`AppConstants.directionRoles`
--  = proviseur, directeur, secrétaire), en dur. Une école ne pouvait ni confier
--  la publication à quelqu'un d'autre, ni la retirer à un adjoint ; et un
--  appel direct à l'API avec un jeton de personnel passait sans rien.
--
--  Depuis 0138, les modules `annonces` et `evenements` existent et reproduisent
--  ce partage par défaut. La base peut donc enfin exiger le même verbe que
--  l'écran.
--
--  ── `school_id IS NULL` RESTE LISIBLE ─────────────────────────────────────
--  Les annonces du GROUPE (`school_id IS NULL`) doivent rester visibles de
--  toutes ses écoles : la politique de lecture les conserve explicitement.
--  L'écriture, elle, exige `school_id = auth_school_id()` — une école ne peut
--  pas publier au nom du groupe.
-- ════════════════════════════════════════════════════════════════════════════

DO $migration$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT * FROM (VALUES
      ('announcements', 'annonces',   'announce_write', 'announce_select'),
      ('events',        'evenements', 'events_tenant',  NULL)
    ) AS v(t, slug, ancienne_write, ancienne_select)
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I', r.ancienne_write, r.t);
    IF r.ancienne_select IS NOT NULL THEN
      EXECUTE format('DROP POLICY IF EXISTS %I ON %I', r.ancienne_select, r.t);
    END IF;

    -- Lecture : inchangée. `school_id IS NULL` = annonce du groupe.
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

COMMENT ON TABLE announcements IS
  'Publications de l''établissement. Écriture gardée par le verbe du module '
  '`annonces` depuis la migration 0139 : jusque-là, la seule appartenance à '
  'l''école suffisait à publier et à supprimer la publication d''un autre.';
