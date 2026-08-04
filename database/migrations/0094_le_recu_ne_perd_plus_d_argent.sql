-- ════════════════════════════════════════════════════════════════════════════
--  0094 — LE REÇU NE PERD PLUS D'ARGENT
--
--  Deux corrections sur student_payments.
--
--  1. L'unicité du numéro de reçu était NATIONALE. Combinée à un numéro qui
--     recommençait toutes les 16 minutes, elle transformait chaque collision en
--     23505 — code que le connecteur PowerSync traite comme définitif : la
--     transaction était abandonnée et l'encaissement perdu. L'unicité descend
--     au niveau où elle a un sens comptable : l'établissement.
--
--  2. Un paiement se SUPPRIMAIT (DELETE sec). Sur de l'argent public on
--     n'efface pas, on annule : la ligne reste, avec son auteur et son motif.
--     Le remboursement, lui, existait comme statut sans rien pour le porter.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ── 1. Unicité par établissement ─────────────────────────────────────────────
ALTER TABLE student_payments
  DROP CONSTRAINT IF EXISTS student_payments_receipt_number_key;

CREATE UNIQUE INDEX IF NOT EXISTS uniq_payment_receipt_per_school
  ON student_payments (school_id, receipt_number)
  WHERE receipt_number IS NOT NULL;

-- ── 2. Annulation plutôt que suppression ─────────────────────────────────────
ALTER TABLE student_payments
  ADD COLUMN IF NOT EXISTS cancelled_at         timestamptz,
  ADD COLUMN IF NOT EXISTS cancelled_by         uuid REFERENCES profiles(id),
  ADD COLUMN IF NOT EXISTS cancellation_reason  text;

-- Un paiement annulé sans motif ne vaut pas mieux qu'un paiement effacé :
-- personne ne saurait dire pourquoi la caisse ne tombe pas juste.
ALTER TABLE student_payments
  DROP CONSTRAINT IF EXISTS chk_payment_cancellation;
ALTER TABLE student_payments
  ADD CONSTRAINT chk_payment_cancellation CHECK (
    status <> 'cancelled'
    OR (cancelled_at IS NOT NULL
        AND cancellation_reason IS NOT NULL
        AND length(btrim(cancellation_reason)) > 0)
  );

-- ── 3. Le remboursement gagne un contenu ─────────────────────────────────────
ALTER TABLE student_payments
  ADD COLUMN IF NOT EXISTS refunded_amount_xaf integer,
  ADD COLUMN IF NOT EXISTS refunded_at         timestamptz,
  ADD COLUMN IF NOT EXISTS refunded_by         uuid REFERENCES profiles(id),
  ADD COLUMN IF NOT EXISTS refund_reason       text;

-- On ne rembourse jamais plus qu'on n'a encaissé.
ALTER TABLE student_payments
  DROP CONSTRAINT IF EXISTS chk_payment_refund_amount;
ALTER TABLE student_payments
  ADD CONSTRAINT chk_payment_refund_amount CHECK (
    refunded_amount_xaf IS NULL
    OR (refunded_amount_xaf > 0 AND refunded_amount_xaf <= amount_xaf)
  );

COMMIT;
