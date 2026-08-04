-- ════════════════════════════════════════════════════════════════════════════
--  0095 — LE PAIEMENT CONNAÎT SON ANNÉE
--
--  `student_payments` n'avait aucune colonne d'année, et aucune requête n'en
--  filtrait : à la rentrée 2027, les versements de 2026 auraient compté comme
--  payés. À l'échelle nationale, c'est une falsification comptable silencieuse.
--
--  Le tableau de bord contournait le manque par une jointure sur
--  `class_enrollments` — ce qui faisait DISPARAÎTRE de ses totaux tout paiement
--  sans inscription rattachée, à commencer par les frais d'examen
--  (`savePayment` accepte un `enrollment_id` nul).
--
--  La table est vide (0 ligne) : le NOT NULL est gratuit, aucune reprise.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

ALTER TABLE student_payments
  ADD COLUMN IF NOT EXISTS academic_year_id uuid REFERENCES academic_years(id);

ALTER TABLE student_payments
  ALTER COLUMN academic_year_id SET NOT NULL;

CREATE INDEX IF NOT EXISTS idx_student_payments_academic_year
  ON student_payments (academic_year_id);

-- Un encaissement se retrouve par école ET par année : c'est la requête de
-- toutes les pages Finance.
CREATE INDEX IF NOT EXISTS idx_student_payments_school_year
  ON student_payments (school_id, academic_year_id);

COMMIT;
