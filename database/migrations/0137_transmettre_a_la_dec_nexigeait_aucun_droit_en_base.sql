-- ════════════════════════════════════════════════════════════════════════════
--  0137 — TRANSMETTRE À LA DEC N'EXIGEAIT AUCUN DROIT EN BASE
--
--  `transmissions` et `transmission_items` n'avaient qu'un `FOR ALL` sur
--  l'appartenance à l'école. Or une transmission est l'ACTE OFFICIEL par lequel
--  l'établissement dépose sa liste de candidats auprès de la Direction des
--  Examens et Concours, et l'accusé de réception est la preuve que la DEC l'a
--  reçue. Ce sont des pièces, pas des notes de travail.
--
--  ── CE QUE L'APPLICATION EXIGE DÉJÀ, ET QUE LA BASE IGNORAIT ───────────────
--  Vérifié avant d'écrire cette migration (leçon 0116 — les APPELS, pas les
--  imports) : les deux seules écritures partent de `transmissions_panel`, et
--  l'écran lui passe `canValidate: canSubmit`, c'est-à-dire
--  `canProvider(examens, 'validate')`.
--
--    transmissions       ← `createTransmission`      (verbe `validate`)
--    transmissions       ← `acknowledgeTransmission` (verbe `validate`)
--    transmission_items  ← `createTransmission`      (verbe `validate`)
--
--  L'écran était donc juste ; la base ne redemandait rien. Aligner les deux ne
--  peut casser aucun parcours : quiconque atteint le bouton possède déjà le
--  verbe.
--
--  ⚠️ Aucun code Dart ne SUPPRIME une transmission — et c'est cohérent : une
--  pièce déposée ne s'efface pas, elle se rectifie (`corrects_id`). Le DELETE
--  est donc réservé à l'admin groupe, comme `school_levels` en 0135 : ce qui
--  n'a pas d'écrivain n'a pas besoin d'une porte.
--
--  ── `USING` PLUTÔT QUE `WITH CHECK` ───────────────────────────────────────
--  Pour l'UPDATE, le verbe est porté par `USING` : sans le droit, la ligne
--  n'est pas VUE par l'ordre, qui touche zéro ligne au lieu de lever. Un 42501
--  est fatal au connecteur PowerSync — il jette le lot entier.
-- ════════════════════════════════════════════════════════════════════════════

DO $migration$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT unnest(ARRAY['transmissions', 'transmission_items']) AS t
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I', r.t || '_tenant', r.t);

    EXECUTE format($f$
      CREATE POLICY %I ON %I FOR SELECT USING (
        (SELECT is_super_admin())
        OR (group_id = (SELECT auth_group_id())
            AND ((SELECT is_admin_groupe())
                 OR school_id = (SELECT auth_school_id()))))$f$,
      r.t || '_select', r.t);

    EXECUTE format($f$
      CREATE POLICY %I ON %I FOR INSERT WITH CHECK (
        (SELECT is_super_admin())
        OR (group_id = (SELECT auth_group_id())
            AND ((SELECT is_admin_groupe())
                 OR (school_id = (SELECT auth_school_id())
                     AND (SELECT auth_module_permet(ARRAY['examens'], 'validate'))))))$f$,
      r.t || '_insert', r.t);

    EXECUTE format($f$
      CREATE POLICY %I ON %I FOR UPDATE USING (
        (SELECT is_super_admin())
        OR (group_id = (SELECT auth_group_id())
            AND ((SELECT is_admin_groupe())
                 OR (school_id = (SELECT auth_school_id())
                     AND (SELECT auth_module_permet(ARRAY['examens'], 'validate'))))))
      WITH CHECK (
        (SELECT is_super_admin())
        OR (group_id = (SELECT auth_group_id())
            AND ((SELECT is_admin_groupe())
                 OR school_id = (SELECT auth_school_id()))))$f$,
      r.t || '_update', r.t);

    EXECUTE format($f$
      CREATE POLICY %I ON %I FOR DELETE USING (
        (SELECT is_super_admin())
        OR ((SELECT is_admin_groupe()) AND group_id = (SELECT auth_group_id())))$f$,
      r.t || '_delete', r.t);
  END LOOP;
END
$migration$;

COMMENT ON TABLE transmissions IS
  'Dépôt officiel de la liste de candidats auprès de la DEC. Écriture réservée '
  'au verbe `validate` du module `examens` depuis la migration 0137 ; la '
  'suppression est réservée à l''admin groupe (une pièce déposée se rectifie '
  'par `corrects_id`, elle ne s''efface pas).';
