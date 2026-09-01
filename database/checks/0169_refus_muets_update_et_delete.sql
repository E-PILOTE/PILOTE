-- ════════════════════════════════════════════════════════════════════════════
--  CHASSE AUX REFUS MUETS — UPDATE *ET* DELETE, sur TOUTES les tables synchro.
--  Remplace `0166`, qui ne sondait que DELETE et sur une liste partielle.
--
--  Ne modifie rien durablement : tout se passe dans une transaction close par
--  ROLLBACK. Peut donc tourner sur la production.
--
--  Usage :
--    psql "$DATABASE_URL" -f database/checks/0169_refus_muets_update_et_delete.sql
--
--  ── LA FAUTE QU'IL CHERCHE ─────────────────────────────────────────────────
--  Un UPDATE ou un DELETE que le `USING` d'une politique écarte ne lève PAS
--  d'erreur : il touche ZÉRO ligne et PostgREST répond 204. L'écran affiche
--  « enregistré ». Hors ligne c'est pire : la copie locale change, la remontée
--  ne touche rien, et la valeur d'origine revient à la synchro suivante —
--  « je l'ai modifié et c'est revenu ».
--
--  ── ⚠️ POURQUOI 0166 NE SUFFISAIT PAS, ET C'EST LE POINT ───────────────────
--  `0166` (2026-08-31) annonçait sonder « les 86 tables synchronisées ». Son
--  tableau en listait 67, et 87 descendent réellement sur les postes — relevé
--  le 2026-09-01 en parsant `powersync/config/sync-rules.yaml`. VINGT tables
--  n'avaient donc jamais été sondées, dont `audit_logs`, `schools`,
--  `school_groups`, `staff_members`, `payment_configs`, `profile_permissions`.
--
--  Et il ne sondait que DELETE, alors que le défaut d'origine — trouvé trois
--  fois le 2026-08-30 (0154, 0155, 0157) — était un UPDATE.
--
--  ⚠️ Une sonde qui annonce une couverture qu'elle n'a pas est pire qu'une
--  sonde absente : elle transforme « je n'ai pas regardé » en « j'ai regardé et
--  il n'y a rien ». La liste ci-dessous est désormais tenue par
--  `epilote/test/sync_rules_publient_le_schema_local_test.dart`, qui échoue si
--  elle s'écarte des sync-rules.
--
--  ── ⚠️ CE QU'UN REFUS MUET N'EST PAS ───────────────────────────────────────
--  Ce n'est PAS un défaut en soi. Un référentiel de groupe DOIT refuser
--  l'écriture au personnel d'école. Le défaut, c'est le refus muet PLUS un
--  écran qui propose le geste. D'où la seconde moitié, au dépôt :
--
--      cd epilote
--      for t in <tables muettes>; do
--        grep -rn "UPDATE $t\b"      lib/ --include=*.dart
--        grep -rn "DELETE FROM $t\b" lib/ --include=*.dart
--      done
--
--  ── RÉSULTAT DU 2026-09-01 (identité DIRECTEUR, le rôle scolaire le mieux doté)
--  87 tables énumérées · 58 sans ligne visible · 29 réellement testées.
--
--    UPDATE : permis 10 · lèvent  0 · MUETS 19
--    DELETE : permis  6 · lèvent  3 · MUETS 20   (= les 19 + `profiles`)
--
--  ⚠️ AUCUN UPDATE NE LÈVE, JAMAIS. Tout refus d'écriture est silencieux : la
--  seule protection réelle est que l'écran ne propose pas le geste.
--
--  Croisement fait sur les 87 : un seul chemin d'écriture hors ligne vise une
--  table muette — `school_holidays`, en UPDATE et en DELETE. Les deux sont
--  désormais gardés dans `school_holidays_provider.dart`, qui LÈVE
--  (`FerieNationalNonModifiable`) au lieu de laisser le serveur se taire.
--  **Aucun autre défaut.**
--
--  ── ⚠️ LA LIMITE, QU'IL FAUT CONNAÎTRE ─────────────────────────────────────
--  Une table SANS ligne visible pour l'identité sondée n'est PAS testée : 58
--  sur 87 ce jour-là. « Rien trouvé » vaut pour les tables peuplées, pas pour
--  le schéma. Le rejouer quand la base se remplit en couvrira davantage.
-- ════════════════════════════════════════════════════════════════════════════
\set ON_ERROR_STOP on
BEGIN;

DO $audit$
DECLARE
  -- ⚠️ Tenue par `sync_rules_publient_le_schema_local_test.dart` : toute table
  -- publiée par un bucket doit figurer ici, et réciproquement.
  tables text[] := ARRAY[
    'academic_years','access_profiles','announcement_comments',
    'announcement_reactions','announcements','attendance_entries',
    'attendance_records','audit_logs','budget_lines','bulletin_subject_lines',
    'bulletins','canteen_records','circulaire_destinataires',
    'class_enrollments','class_subjects','classes','competence_grades',
    'conversation_members','conversations','departments',
    'discipline_incidents','education_cycles','education_levels',
    'education_programs','evaluations','events','exam_candidates',
    'exam_centers','exam_eligibility_rules','exam_sessions','expenses',
    'fee_structures','grades','infirmary_visits','internship_companies',
    'internships','issued_documents','leave_requests','lesson_entries',
    'library_items','library_loans','messages','module_categories','modules',
    'national_exams','notifications','payment_configs','payroll',
    'plan_modules','platform_partners','platform_service_messages',
    'profile_permissions','profiles','rooms','saved_announcements',
    'school_cycles','school_groups','school_holidays','school_levels',
    'school_periods','school_programs','schools','sequences',
    'staff_attendance','staff_career','staff_diplomas','staff_members',
    'staff_photo_requests','stories','story_views','student_documents',
    'student_orientations','student_payments','student_transfers',
    'student_tutors','students','subjects','support_ticket_messages',
    'support_tickets','teacher_availability','teacher_subjects',
    'timetable_exceptions','timetable_slots','timetable_versions',
    'transmission_items','transmissions','trimesters'];
  t text; v_dir uuid; v_id uuid; n int; vides int := 0;
  u_permis text[] := '{}'; u_levent text[] := '{}'; u_muets text[] := '{}';
  d_permis text[] := '{}'; d_levent text[] := '{}'; d_muets text[] := '{}';
BEGIN
  -- Le DIRECTEUR : le rôle scolaire le mieux doté. Ce qu'il ne peut pas faire,
  -- personne de l'école ne le peut.
  SELECT id INTO v_dir FROM profiles
   WHERE role = 'directeur' AND school_id IS NOT NULL AND is_active
   ORDER BY created_at LIMIT 1;
  IF v_dir IS NULL THEN
    RAISE EXCEPTION 'Sonde aveugle : aucun directeur actif rattaché à une école.';
  END IF;

  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_dir, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);

  FOREACH t IN ARRAY tables LOOP
    EXECUTE format('SELECT id FROM %I LIMIT 1', t) INTO v_id;
    IF v_id IS NULL THEN vides := vides + 1; CONTINUE; END IF;

    -- UPDATE stricitement NEUTRE : la valeur ne change pas, mais le `USING`
    -- (qui rend visible) et le `WITH CHECK` (qui autorise) s'appliquent.
    BEGIN
      EXECUTE format('UPDATE %I SET id = id WHERE id = $1', t) USING v_id;
      GET DIAGNOSTICS n = ROW_COUNT;
      IF n > 0 THEN u_permis := u_permis || t;
      ELSE            u_muets  := u_muets  || t;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      u_levent := u_levent || t;   -- lever est le BON comportement
    END;

    BEGIN
      EXECUTE format('DELETE FROM %I WHERE id = $1', t) USING v_id;
      GET DIAGNOSTICS n = ROW_COUNT;
      IF n > 0 THEN d_permis := d_permis || t;
      ELSE            d_muets  := d_muets  || t;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      d_levent := d_levent || t;
    END;
  END LOOP;

  RAISE NOTICE 'tables enumerees=%  sans ligne visible=%  testees=%',
    array_length(tables, 1), vides, array_length(tables, 1) - vides;
  RAISE NOTICE 'UPDATE  permis=% levent=% MUETS=%',
    coalesce(array_length(u_permis,1),0), coalesce(array_length(u_levent,1),0),
    coalesce(array_length(u_muets,1),0);
  RAISE NOTICE '  muets : %', array_to_string(u_muets, ', ');
  RAISE NOTICE 'DELETE  permis=% levent=% MUETS=%',
    coalesce(array_length(d_permis,1),0), coalesce(array_length(d_levent,1),0),
    coalesce(array_length(d_muets,1),0);
  RAISE NOTICE '  muets : %', array_to_string(d_muets, ', ');
  RAISE NOTICE 'Croiser CHAQUE table muette avec :';
  RAISE NOTICE '  grep -rn "UPDATE <t>" epilote/lib ; grep -rn "DELETE FROM <t>" epilote/lib';
END;
$audit$;

ROLLBACK;
