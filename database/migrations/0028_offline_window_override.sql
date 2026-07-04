-- 0028_offline_window_override.sql
-- G3 (stress-test) : fenêtre de confiance ADAPTATIVE plutôt que rigide (évite de
-- verrouiller une école honnête). Override optionnel par groupe/zone.
--   NULL  → défaut généreux (30 j, LICENSE_OFFLINE_WINDOW_DAYS).
--   valeur → fenêtre spécifique (ex. zone très peu connectée = plus long).
-- Un paiement NON confirmé raccourcit la fenêtre côté issuer (couplé à C4),
-- indépendamment de cet override.
--
-- Additif et sûr (nullable, aucun impact tant que non renseigné).

ALTER TABLE school_groups
  ADD COLUMN IF NOT EXISTS offline_window_days smallint;

COMMENT ON COLUMN school_groups.offline_window_days IS
  'G3 : override de la fenêtre de confiance (jours). NULL = défaut. '
  'Généreux par zone ; l''issuer raccourcit tout de même si paiement non confirmé.';
