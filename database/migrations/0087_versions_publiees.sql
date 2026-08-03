-- ════════════════════════════════════════════════════════════════════════════
--  0087 — LE PARC PEUT ÊTRE MIS À JOUR
--
--  ── CE QUI SE JOUE ─────────────────────────────────────────────────────────
--  Le 2 octobre, l'application part sur le territoire. À partir de là, le
--  moindre défaut trouvé par une école est DÉFINITIF tant qu'aucun chemin de
--  mise à jour n'existe : il faudrait retourner physiquement sur mille postes.
--  Cette table est ce qui transforme une livraison unique en une livraison
--  itérative — c'est-à-dire ce qui rend le déploiement rattrapable.
--
--  ── POURQUOI EN BASE, ET PAS UN FICHIER SUR UN SERVEUR ─────────────────────
--  Supabase est déjà joignable, déjà authentifié, déjà surveillé. Poser un
--  serveur de fichiers de plus, c'est une adresse de plus à maintenir, à
--  sécuriser et à expliquer à la DSIC. Le binaire, lui, reste où la CI le
--  publie ; la table ne porte que le POINTEUR et l'EMPREINTE.
--
--  ── L'EMPREINTE N'EST PAS UN ORNEMENT ──────────────────────────────────────
--  `sha256` est obligatoire. Une application qui télécharge un exécutable et le
--  lance sans vérifier ce qu'elle a reçu offre à quiconque intercepte la
--  liaison le droit d'installer ce qu'il veut sur mille postes de
--  l'administration. Le client REFUSE d'installer si l'empreinte diffère.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

CREATE TABLE IF NOT EXISTS app_releases (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Affiché à l'utilisateur (« 3.2.0 »).
  version       text NOT NULL,

  -- Ce qui DÉCIDE : un entier monotone. Comparer « 3.10.0 » et « 3.9.0 » comme
  -- des chaînes donne le mauvais résultat, et le jour où ça arrive, tout le
  -- parc croit être à jour.
  build_number  integer NOT NULL,

  platform      text NOT NULL DEFAULT 'windows',
  channel       text NOT NULL DEFAULT 'stable',

  download_url  text NOT NULL,
  sha256        text NOT NULL,
  size_bytes    bigint,

  -- Ce que l'école lit avant d'accepter. Une mise à jour qu'on ne sait pas
  -- décrire ne se fait pas installer.
  notes         text,

  -- En deçà, la version installée est trop ancienne pour continuer à
  -- fonctionner (rupture de schéma, par exemple). Laisser NULL par défaut :
  -- forcer une mise à jour coupe une école du travail en cours.
  min_build     integer,
  is_mandatory  boolean NOT NULL DEFAULT false,

  published_at  timestamptz NOT NULL DEFAULT now(),
  created_by    uuid REFERENCES profiles(id) ON DELETE SET NULL,

  CONSTRAINT app_releases_platform_check
    CHECK (platform IN ('windows', 'macos', 'linux')),
  CONSTRAINT app_releases_channel_check
    CHECK (channel IN ('stable', 'beta')),
  -- 64 caractères hexadécimaux, et rien d'autre. Une empreinte tronquée ou
  -- collée avec une espace ne protège plus de rien.
  CONSTRAINT app_releases_sha256_check
    CHECK (sha256 ~ '^[0-9a-f]{64}$'),
  CONSTRAINT app_releases_build_check CHECK (build_number > 0),

  UNIQUE (platform, channel, build_number)
);

CREATE INDEX IF NOT EXISTS idx_app_releases_courante
  ON app_releases (platform, channel, build_number DESC);

COMMENT ON TABLE app_releases IS
  'Versions publiées de l''application. La table ne porte que le pointeur et '
  'l''empreinte ; le binaire reste là où la CI le publie. Lecture ouverte à '
  'tout compte connecté — un poste doit pouvoir apprendre qu''il est en '
  'retard. Écriture réservée au super_admin.';

COMMENT ON COLUMN app_releases.sha256 IS
  'Empreinte SHA-256 de l''installateur. OBLIGATOIRE : le client refuse '
  'd''installer un fichier dont l''empreinte diffère.';

-- ── Droits ──────────────────────────────────────────────────────────────────
ALTER TABLE app_releases ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_releases_lecture  ON app_releases;
DROP POLICY IF EXISTS app_releases_ecriture ON app_releases;

-- Tout le monde lit : un poste d'école doit savoir qu'une correction existe,
-- quel que soit son rôle. Il n'y a rien de confidentiel dans un numéro de
-- version.
CREATE POLICY app_releases_lecture ON app_releases FOR SELECT
  USING (true);

-- Publier une version, c'est décider ce qui s'installe sur mille postes de
-- l'administration. Réservé à l'opérateur de la plateforme.
CREATE POLICY app_releases_ecriture ON app_releases FOR ALL
  USING (is_super_admin()) WITH CHECK (is_super_admin());

GRANT SELECT ON app_releases TO authenticated;

-- ── La version courante d'une plateforme ────────────────────────────────────
CREATE OR REPLACE FUNCTION derniere_version(
  p_platform text DEFAULT 'windows',
  p_channel  text DEFAULT 'stable'
) RETURNS app_releases
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT * FROM app_releases
   WHERE platform = p_platform AND channel = p_channel
   ORDER BY build_number DESC
   LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION derniere_version(text, text) TO authenticated;

COMMIT;
