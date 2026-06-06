-- ─── E-PILOTE CONGO — Configuration Supabase pour PowerSync ─────────────────
-- Exécuter UNE FOIS dans Supabase SQL Editor
-- (Dashboard → SQL Editor → New query)
--
-- Ce script :
--  1. Crée le rôle powersync_role avec privilèges de réplication
--  2. Accorde SELECT sur toutes les tables
--  3. Crée la publication PostgreSQL pour la réplication logique

-- ── 1. Rôle de réplication PowerSync ─────────────────────────────────────────
-- ⚠️  Remplacer 'MOT_DE_PASSE_ICI' par un mot de passe sécurisé
--     et le noter dans powersync/.env → SUPABASE_DB_PASSWORD

CREATE ROLE powersync_role
  WITH REPLICATION BYPASSRLS LOGIN
  PASSWORD 'MOT_DE_PASSE_ICI';

-- ── 2. Accorder les permissions SELECT ───────────────────────────────────────
-- Tables principales du schéma E-PILOTE
GRANT SELECT ON ALL TABLES IN SCHEMA public TO powersync_role;

-- Pour les futures tables créées
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT ON TABLES TO powersync_role;

-- ── 3. Publication pour la réplication logique ────────────────────────────────
-- Toutes les tables du schéma public seront répliquées
CREATE PUBLICATION powersync FOR ALL TABLES;

-- ── Vérification ─────────────────────────────────────────────────────────────
SELECT rolname, rolreplication FROM pg_roles WHERE rolname = 'powersync_role';
SELECT pubname, puballtables FROM pg_publication WHERE pubname = 'powersync';
