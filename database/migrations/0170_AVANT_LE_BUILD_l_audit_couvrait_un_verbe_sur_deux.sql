-- ═══════════════════════════════════════════════════════════════════════════
--  0170 — L'AUDIT MÉTIER NE COUVRAIT QU'UN VERBE SUR DEUX, SELON LA TABLE
--
--  Relevé le 2026-09-01 en sondant le journal plutôt qu'en le relisant : sous
--  l'identité d'un DIRECTEUR, une modification réelle sur `class_enrollments`
--  et sur `evaluations` réussit et ne laisse AUCUNE trace.
--
--  ── CE QUE `trg_audit_metier` COUVRAIT VRAIMENT ──────────────────────────
--  | table                | audité                    |
--  |----------------------|---------------------------|
--  | bulletins            | DELETE OR UPDATE          |
--  | discipline_incidents | DELETE OR UPDATE          |
--  | grades               | DELETE OR UPDATE          |
--  | payroll              | DELETE OR UPDATE          |
--  | student_payments     | DELETE OR UPDATE          |
--  | students             | DELETE OR UPDATE          |
--  | class_enrollments    | **DELETE seulement**      |
--  | evaluations          | **DELETE seulement**      |
--  | class_subjects       | **UPDATE seulement**      |
--  | school_levels        | **UPDATE seulement**      |
--
--  ⚠️ Les deux manques les plus graves sont des UPDATE, et ce sont les deux
--  qui déplacent des résultats :
--   • `class_enrollments` — changer un élève de classe ne laissait rien ;
--   • `evaluations` — changer le COEFFICIENT ou la matière d'une évaluation
--     déplace des moyennes, donc des bulletins, sans la moindre trace. Une
--     note se corrige au vu de tous (`grades` est audité) ; le poids de
--     l'épreuve, lui, se corrigeait dans l'ombre.
--
--  ── POURQUOI C'EST UNE DÉRIVE ET NON UN CHOIX ────────────────────────────
--  Les déclencheurs EDT du même dépôt sont COMPLETS
--  (`AFTER INSERT OR DELETE OR UPDATE`, fonction `log_edt_audit`). Le projet
--  sait donc écrire un audit complet ; `trg_audit_metier` a simplement été
--  posé table par table, et quatre fois sur dix la liste des verbes a glissé.
--
--  ── ⚠️ POURQUOI ON N'AJOUTE PAS `INSERT` ─────────────────────────────────
--  `fn_audit_metier` lit `OLD` et calcule un diff : sur un INSERT, `OLD` est
--  nul, l'insertion dans `audit_logs` échouerait — et son
--  `EXCEPTION WHEN OTHERS THEN RETURN NULL` avalerait l'échec. On obtiendrait
--  un audit qui paraît couvrir l'INSERT et n'écrit rien : pire que l'absence.
--  Auditer les créations demande de modifier la FONCTION, pas les
--  déclencheurs — question distincte, délibérément laissée ouverte.
--
--  ── ⚠️ LE DANGER DORMANT QUI RESTE ───────────────────────────────────────
--  `EXCEPTION WHEN OTHERS THEN RETURN NULL` : le jour où l'insertion d'audit
--  cassera (colonne retirée, contrainte ajoutée), elle cassera EN SILENCE et
--  pour toujours. Le faire lever serait pire — l'écriture métier de l'école
--  serait abandonnée. La parade est de rendre la panne OBSERVABLE :
--  `database/checks/0171_le_journal_d_audit_est_vivant.sql`, rejouable.
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

-- Les six déjà complets sont recréés à l'identique : un seul endroit décrit
-- désormais la règle, au lieu de dix décisions éparses.
DROP TRIGGER IF EXISTS trg_audit_metier ON public.bulletins;
CREATE TRIGGER trg_audit_metier AFTER DELETE OR UPDATE ON public.bulletins
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_metier();

DROP TRIGGER IF EXISTS trg_audit_metier ON public.discipline_incidents;
CREATE TRIGGER trg_audit_metier AFTER DELETE OR UPDATE ON public.discipline_incidents
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_metier();

DROP TRIGGER IF EXISTS trg_audit_metier ON public.grades;
CREATE TRIGGER trg_audit_metier AFTER DELETE OR UPDATE ON public.grades
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_metier();

DROP TRIGGER IF EXISTS trg_audit_metier ON public.payroll;
CREATE TRIGGER trg_audit_metier AFTER DELETE OR UPDATE ON public.payroll
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_metier();

DROP TRIGGER IF EXISTS trg_audit_metier ON public.student_payments;
CREATE TRIGGER trg_audit_metier AFTER DELETE OR UPDATE ON public.student_payments
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_metier();

DROP TRIGGER IF EXISTS trg_audit_metier ON public.students;
CREATE TRIGGER trg_audit_metier AFTER DELETE OR UPDATE ON public.students
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_metier();

-- ── Les quatre qui manquaient un verbe ──────────────────────────────────────
DROP TRIGGER IF EXISTS trg_audit_metier ON public.class_enrollments;
CREATE TRIGGER trg_audit_metier AFTER DELETE OR UPDATE ON public.class_enrollments
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_metier();

DROP TRIGGER IF EXISTS trg_audit_metier ON public.evaluations;
CREATE TRIGGER trg_audit_metier AFTER DELETE OR UPDATE ON public.evaluations
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_metier();

DROP TRIGGER IF EXISTS trg_audit_metier ON public.class_subjects;
CREATE TRIGGER trg_audit_metier AFTER DELETE OR UPDATE ON public.class_subjects
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_metier();

DROP TRIGGER IF EXISTS trg_audit_metier ON public.school_levels;
CREATE TRIGGER trg_audit_metier AFTER DELETE OR UPDATE ON public.school_levels
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_metier();

COMMIT;
