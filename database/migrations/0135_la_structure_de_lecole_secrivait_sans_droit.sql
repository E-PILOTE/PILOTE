-- ════════════════════════════════════════════════════════════════════════════
--  0135 — LA STRUCTURE DE L'ÉCOLE S'ÉCRIVAIT SANS DROIT
--
--  Dix tables du domaine Structure n'avaient qu'une politique `FOR ALL` sur la
--  seule appartenance à l'école : l'emploi du temps, le cahier de textes, les
--  salles, les périodes, les vacances, les programmes, les disponibilités des
--  professeurs — et les seuils de passage.
--
--    school_levels (175)   ⚠️ `pass_mark` et `deliberation_floor` : la moyenne
--                          de passage et le seuil de délibération. Les changer,
--                          c'est décider qui passe et qui redouble. Tout membre
--                          du personnel pouvait les réécrire, sans trace.
--    school_holidays (126) les jours non ouvrés — donc les jours où l'appel
--                          n'est pas dû et où l'emploi du temps ne tourne pas.
--    school_programs (1)   les programmes officiels.
--    timetable_slots       l'emploi du temps de toutes les classes.
--    timetable_versions    la version publiée qui fait foi.
--    timetable_exceptions  les séances déplacées ou annulées.
--    lesson_entries        le cahier de textes.
--    rooms, school_periods, teacher_availability — la configuration de l'EDT.
--
--  ── CE QUE LE RELEVÉ A CORRIGÉ DANS MON PROPRE COMPTE ─────────────────────
--  `academic_years`, `trimesters` et `sequences` figuraient dans mon tableau
--  comme « FOR ALL ». Elles portent bien une politique `FOR ALL` — mais
--  RESTREINTE à `is_super_admin() OR is_admin_groupe()` (`*_write_ministry`).
--  Elles étaient déjà correctes ; mon classement les regardait par la forme et
--  non par le contenu. Elles ne sont pas touchées ici.
--
--  ── LES MODULES SE DÉDUISENT DES ÉCRANS QUI ÉCRIVENT (leçon 0116) ──────────
--  Relevé par les APPELS des fonctions d'écriture, pas par les imports :
--
--    rooms                ← `emploi-du-temps` : edt_rooms_tab
--    school_periods       ← `emploi-du-temps` : edt_periods_tab, edt_periods_form
--    teacher_availability ← `emploi-du-temps` : edt_availability_tab
--    school_holidays      ← `emploi-du-temps` : edt_calendar_tab
--    timetable_slots      ← `emploi-du-temps` : emploi_du_temps_actions/_form
--    timetable_versions   ← `emploi-du-temps` : emploi_du_temps_actions
--    timetable_exceptions ← `emploi-du-temps` : emploi_du_temps_screen
--    lesson_entries       ← `cahier-textes`   : cahier_textes_screen
--    school_programs      ← `programmes`      : programmes_screen
--
--  ⚠️ `school_calendar_screen` IMPORTE `school_holidays_provider` mais n'appelle
--  AUCUNE de ses fonctions d'écriture : il ne fait que lire. Lui ouvrir un droit
--  d'écriture aurait été une porte accordée à personne. Un import n'est pas une
--  écriture — seule la vérification des appels le dit.
--
--  ⚠️ `school_levels` N'A AUCUN ÉCRIVAIN HORS LIGNE (vérifié : zéro `INSERT` /
--  `UPDATE` / `DELETE` dans tout le Dart). Elle se configure depuis l'espace
--  admin groupe, en ligne. On la traite donc comme `trimesters` : lecture pour
--  l'école, écriture réservée. Aucun écran ne peut recevoir de 42501, puisque
--  aucun écran n'écrit.
--
--  ⚠️ `school_holidays_read_national` (SELECT sur les lignes `school_id IS
--  NULL`) est CONSERVÉE : les vacances nationales doivent rester lisibles par
--  toutes les écoles du groupe. Et le `WITH CHECK` d'écriture exige
--  `school_id = auth_school_id()` : une école ne peut pas se déclarer de
--  vacances nationales.
--
--  ── VÉRIFIÉ APRÈS COUP (production, transaction annulée) ──────────────────
--  Voir le bloc joint à la migration.
-- ════════════════════════════════════════════════════════════════════════════

-- ─── Les neuf tables gardées par le verbe de leur module ────────────────────
DO $migration$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT * FROM (VALUES
      ('rooms',                'emploi-du-temps'),
      ('school_periods',       'emploi-du-temps'),
      ('teacher_availability', 'emploi-du-temps'),
      ('timetable_slots',      'emploi-du-temps'),
      ('timetable_versions',   'emploi-du-temps'),
      ('timetable_exceptions', 'emploi-du-temps'),
      ('school_holidays',      'emploi-du-temps'),
      ('lesson_entries',       'cahier-textes'),
      ('school_programs',      'programmes')
    ) AS v(t, slug)
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

-- ─── school_levels : lecture pour l'école, écriture réservée ────────────────
DROP POLICY IF EXISTS school_levels_tenant ON school_levels;

CREATE POLICY school_levels_select ON school_levels FOR SELECT USING (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id()))));

CREATE POLICY school_levels_write_ministry ON school_levels FOR ALL
USING (
  (SELECT is_super_admin())
  OR ((SELECT is_admin_groupe()) AND group_id = (SELECT auth_group_id())))
WITH CHECK (
  (SELECT is_super_admin())
  OR ((SELECT is_admin_groupe()) AND group_id = (SELECT auth_group_id())));

COMMENT ON COLUMN school_levels.pass_mark IS
  'Moyenne de passage du niveau. Écriture réservée à l''admin groupe depuis la '
  'migration 0135 : jusque-là, tout membre du personnel de l''école pouvait la '
  'réécrire, et décider ainsi qui passe et qui redouble.';
