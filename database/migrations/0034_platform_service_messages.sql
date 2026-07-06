-- 0034_platform_service_messages.sql
-- Messages de service diffusés par le super_admin sur la VITRINE des postes
-- partagés (bandeau/carrousel de l'écran-verrou au repos). Synchronisés à tous
-- les postes via le bucket global `global_catalog` (donc lisibles hors-ligne).

CREATE TABLE IF NOT EXISTS platform_service_messages (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  body        text NOT NULL,
  is_active   boolean NOT NULL DEFAULT true,
  starts_at   timestamptz,   -- visible à partir de (null = immédiatement)
  ends_at     timestamptz,   -- visible jusqu'à (null = sans fin)
  created_by  uuid REFERENCES auth.users(id),
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE platform_service_messages ENABLE ROW LEVEL SECURITY;

-- super_admin : gestion complète (CRUD online).
DROP POLICY IF EXISTS psm_super_all ON platform_service_messages;
CREATE POLICY psm_super_all ON platform_service_messages
  FOR ALL USING (is_super_admin()) WITH CHECK (is_super_admin());

-- Lecture des messages actifs par tout utilisateur authentifié (préversion
-- admin_groupe). Le personnel scolaire, lui, les reçoit par PowerSync — les
-- sync-rules ne passent pas par la RLS.
DROP POLICY IF EXISTS psm_read_active ON platform_service_messages;
CREATE POLICY psm_read_active ON platform_service_messages
  FOR SELECT USING (is_active = true);

COMMENT ON TABLE platform_service_messages IS
  'Messages de service super_admin affichés sur la vitrine des postes partagés '
  '(carrousel de l''écran-verrou). Diffusion globale via PowerSync (offline).';
