-- ════════════════════════════════════════════════════════════════════════════
--  CHASSE AUX REFUS MUETS — à rejouer après toute migration touchant la RLS.
--
--  Ne modifie rien durablement : tout se passe dans une transaction close par
--  ROLLBACK. Peut donc tourner sur la production.
--
--  Usage :
--    psql "$DATABASE_URL" -f database/checks/0166_refus_muets_de_la_rls.sql
--
--  ── LA FAUTE QU'IL CHERCHE ─────────────────────────────────────────────────
--  Un UPDATE ou un DELETE que le `USING` d'une politique écarte ne lève PAS
--  d'erreur : il touche ZÉRO ligne et PostgREST répond 204. L'écran affiche
--  « supprimé ». Hors ligne, c'est pire : la ligne disparaît du poste, le
--  serveur la garde, et elle REVIENT à la synchro suivante — « je l'ai
--  supprimé et il est revenu ».
--
--  Trouvée cinq fois entre le 2026-08-30 et le 2026-08-31 (migrations 0154,
--  0155, 0157, et deux fois en auditant la tutelle). D'où ce contrôle.
--
--  ── ⚠️ CE QU'UN REFUS MUET N'EST PAS ───────────────────────────────────────
--  Ce n'est PAS un défaut en soi. Une table de référentiel du groupe DOIT
--  refuser la suppression au personnel d'école. Le défaut, c'est le refus muet
--  PLUS un écran qui propose le geste.
--
--  Ce script ne fait donc que la moitié SQL du travail. La seconde moitié se
--  fait au dépôt, et elle est indispensable :
--
--      cd epilote
--      for t in <tables listées ci-dessous>; do
--        echo "── $t"; grep -rn "DELETE FROM $t\b" lib/ --include=*.dart
--      done
--
--  Une table listée ici ET trouvée par le grep = un défaut à corriger.
--  Une table listée ici et absente du grep = la RLS fait son travail.
--
--  ── ⚠️ LA LIMITE, QU'IL FAUT CONNAÎTRE ─────────────────────────────────────
--  Une table SANS ligne visible pour l'identité sondée n'est PAS testée. Au
--  2026-08-31, 50 des 86 tables synchronisées étaient dans ce cas (base de
--  démonstration). Le résultat « rien trouvé » vaut donc pour les tables
--  peuplées, pas pour le schéma entier. Le rejouer sur une base réelle en
--  couvrira davantage — c'est précisément pourquoi il est rejouable.
--
--  ── RÉSULTAT DU 2026-08-31 ─────────────────────────────────────────────────
--  permis 6 · lèvent 3 · sans ligne visible 50 · MUETS 8 :
--    academic_years, access_profiles, departments, profiles, school_cycles,
--    school_holidays, school_levels, trimesters
--  Croisé avec le dépôt : une seule (`school_holidays`) a un chemin de
--  suppression hors ligne — et l'écran l'interdit déjà pour les lignes
--  nationales (cadenas « Férié légal fixé par le groupe »). Aucun défaut.
-- ════════════════════════════════════════════════════════════════════════════
\set ON_ERROR_STOP on
BEGIN;

DO $audit$
DECLARE
  tables text[] := ARRAY[
    'academic_years','access_profiles','announcement_comments',
    'announcement_reactions','announcements','attendance_entries',
    'attendance_records','budget_lines','bulletin_subject_lines','bulletins',
    'canteen_records','class_enrollments','class_subjects','classes',
    'competence_grades','conversation_members','conversations','departments',
    'discipline_incidents','evaluations','events','exam_candidates','expenses',
    'fee_structures','grades','infirmary_visits','internship_companies',
    'internships','issued_documents','leave_requests','lesson_entries',
    'library_items','library_loans','messages','notifications','payroll',
    'profiles','rooms','saved_announcements','school_cycles','school_holidays',
    'school_levels','school_periods','school_programs','sequences',
    'staff_attendance','staff_career','staff_diplomas','staff_photo_requests',
    'stories','story_views','student_documents','student_orientations',
    'student_payments','student_transfers','student_tutors','students',
    'subjects','support_ticket_messages','support_tickets',
    'teacher_availability','teacher_subjects','timetable_exceptions',
    'timetable_slots','transmission_items','transmissions','trimesters'];
  t text; v_dir uuid; v_id uuid; n int;
  muets text[] := '{}'; bruyants int := 0; permis int := 0; vides int := 0;
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
    BEGIN
      EXECUTE format('SELECT id FROM %I LIMIT 1', t) INTO v_id;
      IF v_id IS NULL THEN vides := vides + 1; CONTINUE; END IF;
      EXECUTE format('DELETE FROM %I WHERE id = $1', t) USING v_id;
      GET DIAGNOSTICS n = ROW_COUNT;
      IF n > 0 THEN permis := permis + 1;
      ELSE            muets := muets || t;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      -- Lever est le BON comportement : le poste l'apprend.
      bruyants := bruyants + 1;
    END;
  END LOOP;

  RAISE NOTICE 'permis=% levent=% sans_ligne_visible=%', permis, bruyants, vides;
  RAISE NOTICE 'MUETS (% table(s)) : %',
    coalesce(array_length(muets, 1), 0), array_to_string(muets, ', ');
  RAISE NOTICE 'Croiser chacune avec : grep -rn "DELETE FROM <table>" epilote/lib';
END;
$audit$;

ROLLBACK;
