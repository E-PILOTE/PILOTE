-- ════════════════════════════════════════════════════════════════════════════
--  LE JOURNAL D'AUDIT EST-IL VIVANT ? — à rejouer après toute migration
--  touchant `fn_audit_metier`, `audit_logs`, ou une table auditée.
--
--  Ne modifie rien durablement : tout se passe dans une transaction close par
--  ROLLBACK. Peut donc tourner sur la production.
--
--  Usage :
--    psql "$DATABASE_URL" -f database/checks/0171_le_journal_d_audit_est_vivant.sql
--
--  ── POURQUOI SONDER PLUTÔT QUE RELIRE ──────────────────────────────────────
--  `fn_audit_metier` se termine par `EXCEPTION WHEN OTHERS THEN RETURN NULL`.
--  C'est délibéré et c'est le bon choix : un audit qui LÈVE ferait abandonner
--  l'écriture métier de l'école — le remède serait pire. Mais la contrepartie
--  est qu'une panne d'audit est TOTALEMENT SILENCIEUSE, et définitive. Le jour
--  où une colonne est retirée ou une contrainte ajoutée, le journal cesse
--  d'enregistrer et rien, nulle part, ne le dit.
--
--  Relire le code ne suffit pas : le 2026-09-01, les dix déclencheurs
--  `trg_audit_metier` étaient bien en place et pourtant QUATRE ne couvraient
--  qu'un verbe sur deux (0170). Seule une écriture réelle, sous une identité
--  réelle, le montre.
--
--  ── CE QUE LA SONDE DISTINGUE, ET POURQUOI C'EST ESSENTIEL ─────────────────
--  Une première version confondait deux résultats très différents :
--    • l'UPDATE touche 0 ligne (la RLS l'écarte) → normal pour un référentiel ;
--    • l'UPDATE touche 1 ligne et rien n'est audité → TROU.
--  Sans `ROW_COUNT`, les deux se lisent « pas de trace ». D'où les trois
--  colonnes ci-dessous.
--
--  ⚠️ Le changement porté est sur `created_at` : c'est la seule colonne
--  commune aux quatorze tables que le déclencheur ne neutralise PAS
--  (`fn_audit_metier` retire `updated_at` du diff, pas `created_at`).
--
--  ── RÉSULTAT DU 2026-09-01, APRÈS 0170 (identité DIRECTEUR) ────────────────
--    écrit ET audité (6) : bulletins, class_enrollments, class_subjects,
--                          evaluations, grades, students
--    écrit SANS trace (0)
--    RLS écarte      (1) : school_levels  (référentiel de groupe — attendu)
--    sans ligne visible (7)
--
--  Avant 0170, `class_enrollments` et `evaluations` étaient « écrit sans
--  trace » : changer la classe d'un élève ou le COEFFICIENT d'une évaluation
--  — donc des moyennes, donc des bulletins — ne laissait rien.
--
--  ── ⚠️ LA LIMITE ───────────────────────────────────────────────────────────
--  Sept tables sur quatorze n'ont aucune ligne visible pour l'identité sondée
--  et ne sont donc PAS testées. « Aucun trou » vaut pour les tables peuplées.
-- ════════════════════════════════════════════════════════════════════════════
\set ON_ERROR_STOP on
BEGIN;

DO $audit$
DECLARE
  -- Les tables portant un déclencheur qui écrit dans `audit_logs`.
  tables text[] := ARRAY[
    'bulletins','class_enrollments','class_subjects','discipline_incidents',
    'evaluations','fee_structures','grades','payroll','school_levels',
    'student_payments','students','timetable_exceptions','timetable_slots',
    'timetable_versions'];
  t text; v_dir uuid; v_id uuid; n0 int; n1 int; lignes int;
  traces text[] := '{}'; trous text[] := '{}'; ecartees text[] := '{}';
  vides text[] := '{}'; refus text[] := '{}';
BEGIN
  -- Le DIRECTEUR : le rôle scolaire le mieux doté.
  SELECT id INTO v_dir FROM profiles
   WHERE role = 'directeur' AND school_id IS NOT NULL AND is_active
   ORDER BY created_at LIMIT 1;
  IF v_dir IS NULL THEN
    RAISE EXCEPTION 'Sonde aveugle : aucun directeur actif rattaché à une école.';
  END IF;

  FOREACH t IN ARRAY tables LOOP
    -- Le comptage se fait hors RLS : le directeur ne voit pas tout le journal.
    PERFORM set_config('role', 'postgres', true);
    SELECT count(*) INTO n0 FROM audit_logs;

    PERFORM set_config('request.jwt.claims',
      json_build_object('sub', v_dir, 'role', 'authenticated')::text, true);
    PERFORM set_config('role', 'authenticated', true);

    lignes := -1;
    BEGIN
      EXECUTE format('SELECT id FROM %I LIMIT 1', t) INTO v_id;
      IF v_id IS NULL THEN vides := vides || t; CONTINUE; END IF;
      EXECUTE format(
        'UPDATE %I SET created_at = created_at + interval ''1 second'' WHERE id = $1', t)
        USING v_id;
      GET DIAGNOSTICS lignes = ROW_COUNT;
    EXCEPTION WHEN OTHERS THEN
      refus := refus || t; CONTINUE;   -- lever est le BON comportement
    END;

    PERFORM set_config('role', 'postgres', true);
    SELECT count(*) INTO n1 FROM audit_logs;

    IF    lignes = 0 THEN ecartees := ecartees || t;  -- la RLS l'écarte
    ELSIF n1 > n0    THEN traces   := traces   || t;  -- écrit ET audité
    ELSE                  trous    := trous    || t;  -- ⚠️ écrit SANS trace
    END IF;
  END LOOP;

  RAISE NOTICE 'ecrit ET audite (%)  : %',
    coalesce(array_length(traces,1),0), array_to_string(traces, ', ');
  RAISE NOTICE 'ECRIT SANS TRACE (%) : %   <- tout ce qui apparait ici est un TROU',
    coalesce(array_length(trous,1),0), array_to_string(trous, ', ');
  RAISE NOTICE 'RLS ecarte (%)       : %',
    coalesce(array_length(ecartees,1),0), array_to_string(ecartees, ', ');
  RAISE NOTICE 'refus bruyant (%)    : %',
    coalesce(array_length(refus,1),0), array_to_string(refus, ', ');
  RAISE NOTICE 'sans ligne visible (%) : %   <- NON TESTEES',
    coalesce(array_length(vides,1),0), array_to_string(vides, ', ');
END;
$audit$;

ROLLBACK;
