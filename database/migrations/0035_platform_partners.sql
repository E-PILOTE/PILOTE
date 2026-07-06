-- 0035_platform_partners.sql
-- Placements PARTENAIRES sur la vitrine des postes partagés (Phase 3b).
-- Double garde-fou : (1) curation super_admin (liste blanche, catégorie fermée
-- côté app) ; (2) opt-in par GROUPE (school_groups.partner_display_enabled,
-- défaut false, piloté par admin_groupe). Diffusion globale via PowerSync
-- (bucket global_catalog) ; l'affichage n'a lieu que si le groupe a opté in.
--
-- Cette migration ne modélise AUCUN flux financier : la vitrine n'est que
-- l'affichage. Un éventuel volet contractuel/facturation est hors périmètre.

CREATE TABLE IF NOT EXISTS platform_partners (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name        text NOT NULL,
  logo_url    text,                                     -- Storage `partner-logos`
  website_url text,                                     -- informatif (non cliquable hors-ligne)
  category    text NOT NULL DEFAULT 'institutionnel',   -- enum applicatif fermé
  is_active   boolean NOT NULL DEFAULT true,
  sort_order  integer NOT NULL DEFAULT 0,
  starts_at   timestamptz,
  ends_at     timestamptz,
  created_by  uuid REFERENCES auth.users(id),
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE platform_partners ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS pp_super_all ON platform_partners;
CREATE POLICY pp_super_all ON platform_partners
  FOR ALL USING (is_super_admin()) WITH CHECK (is_super_admin());

DROP POLICY IF EXISTS pp_read_active ON platform_partners;
CREATE POLICY pp_read_active ON platform_partners
  FOR SELECT USING (is_active = true);

COMMENT ON TABLE platform_partners IS
  'Partenaires institutionnels/éducatifs curatés par le super_admin, affichés '
  'sur la vitrine des postes des groupes ayant opté in (partner_display_enabled).';

-- Opt-in par groupe (piloté par admin_groupe ; défaut = rien ne s''affiche).
ALTER TABLE school_groups
  ADD COLUMN IF NOT EXISTS partner_display_enabled boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN school_groups.partner_display_enabled IS
  'Le groupe autorise l''affichage des encarts partenaires sur ses postes '
  '(opt-in explicite admin_groupe). Défaut false.';
