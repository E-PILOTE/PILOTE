-- 0027_payment_confirmed.sql
-- C4 (stress-test 🔴) : ne JAMAIS émettre une licence plein terme sur un
-- paiement non confirmé. Signal de confirmation de paiement, à basculer par le
-- futur flux mobile-money (false à l'initiation, true à la confirmation).
--
-- Défaut TRUE : les groupes existants sont considérés confirmés → AUCUN
-- changement de comportement. Additif et sûr.

ALTER TABLE school_groups
  ADD COLUMN IF NOT EXISTS payment_confirmed boolean NOT NULL DEFAULT true;

COMMENT ON COLUMN school_groups.payment_confirmed IS
  'C4 : paiement confirmé ? false ⇒ l''Edge Function license-issuer plafonne '
  'valid_to à une fenêtre PROVISOIRE courte (LICENSE_PROVISIONAL_DAYS).';
