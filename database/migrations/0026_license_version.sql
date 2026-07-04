-- 0026_license_version.sql
-- Compteur de version de licence MONOTONE, autoritaire côté serveur (ADR-0005).
-- Remplace la source INTERIM epoch(updated_at) de la fonction license-issuer.
-- Additif et sûr : n'impacte rien tant que la fonction n'est pas déployée.

ALTER TABLE school_groups
  ADD COLUMN IF NOT EXISTS license_version bigint NOT NULL DEFAULT 0;

-- Incrément atomique + retour de la nouvelle valeur. Appelé par l'Edge Function
-- (service role) à chaque émission de licence. SECURITY DEFINER : réservé au
-- back-office/fonction, jamais exposé au client de personnel.
CREATE OR REPLACE FUNCTION next_license_version(p_group uuid)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v bigint;
BEGIN
  UPDATE school_groups
     SET license_version = license_version + 1
   WHERE id = p_group
  RETURNING license_version INTO v;
  RETURN v;  -- NULL si le groupe n'existe pas (la fonction gère)
END;
$$;
