-- ════════════════════════════════════════════════════════════════════════════
--  0150 — SAVOIR QUELLE VERSION TOURNE OÙ
--
--  ── LE TROU QUI A RENDU CETTE MIGRATION NÉCESSAIRE ─────────────────────────
--  `docs/DEPLOIEMENT_ORDRE.md` fait dépendre la migration 0146 d'une condition
--  écrite noir sur blanc : « tous les postes l'ont reçu ». Or RIEN, dans toute
--  la plateforme, n'enregistre la version installée sur un poste.
--  `build_number` n'existait que dans `app_releases` — c'est-à-dire ce qui est
--  PROPOSÉ au parc, jamais ce qui y est INSTALLÉ.
--
--  Une condition qu'on ne peut pas observer est une condition qu'on finira par
--  supposer. Et se tromper ici ne se voit pas : 0146 supprime une colonne que
--  les postes en retard envoient encore, PostgREST répond 42703, que
--  `_fatalResponseCodes` ne traite PAS comme fatal — le connecteur rejoue le
--  lot indéfiniment. Le poste cesse d'envoyer quoi que ce soit, pour toujours,
--  sans un mot à l'écran.
--
--  ── L'ABSENCE DE SIGNALEMENT EST LE SIGNAL ─────────────────────────────────
--  Les builds antérieurs à celui qui accompagne cette migration n'ont pas le
--  code pour se signaler : ils n'apparaîtront JAMAIS dans cette table. Un
--  profil qui n'y figure pas est donc soit sur une version ancienne, soit
--  jamais revenu. Les deux sont des risques pour 0146, et les compter ensemble
--  est la lecture prudente — celle qui refuse de conclure.
--
--  C'est pourquoi `parc_couverture()` rend `jamais_signale` comme un chiffre à
--  part entière, à afficher même à zéro. Un relevé qui ne montrerait que les
--  postes connus donnerait une couverture de 100 % le jour de sa mise en
--  service, alors qu'il ne sait encore rien de personne.
--
--  ── POURQUOI UNE RPC ET NON POWERSYNC ──────────────────────────────────────
--  Ce n'est pas une donnée de travail : personne ne la lit hors ligne, et elle
--  n'a rien à faire dans les buckets de synchronisation d'une école. Elle voyage
--  donc par une RPC en ligne, exactement là où le poste demande déjà « existe-
--  t-il une version plus récente ? » — même instant, même réseau, même silence
--  quand il n'y en a pas.
--
--  La table n'entre NI dans `powersync_schema.dart` NI dans `sync-rules.yaml`.
--
--  ── CE QU'ON NE STOCKE PAS, DÉLIBÉRÉMENT ───────────────────────────────────
--  Aucun identifiant d'appareil, aucune adresse IP, aucune caractéristique
--  matérielle. La question posée est « quelle version tourne », pas « qui est
--  derrière quel écran ». Une ligne par profil suffit à y répondre : si tous
--  les profils signalent ≥ N, alors tous les postes qu'ils utilisent sont ≥ N.
--
--  ⚠️ ORDRE DE DÉPLOIEMENT : AVANT LE BUILD. Si le client appelait une RPC
--  absente, l'appel échouerait — sans dommage, il est silencieux — mais le
--  relevé resterait vide en donnant l'illusion d'un parc muet.
-- ════════════════════════════════════════════════════════════════════════════

-- ── La table ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.app_installations (
  profile_id    uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  group_id      uuid REFERENCES public.school_groups(id) ON DELETE SET NULL,
  school_id     uuid REFERENCES public.schools(id) ON DELETE SET NULL,
  platform      text        NOT NULL,
  version       text        NOT NULL,
  build_number  integer     NOT NULL,
  first_seen_at timestamptz NOT NULL DEFAULT now(),
  last_seen_at  timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.app_installations IS
  'Quelle version de l''application chaque profil a utilisée en dernier. '
  'Écrite UNIQUEMENT par la RPC signaler_version(). Ne pas déclarer dans '
  'powersync_schema.dart ni dans sync-rules.yaml : donnée d''exploitation, '
  'pas donnée de travail.';

CREATE INDEX IF NOT EXISTS idx_app_installations_build
  ON public.app_installations (build_number);
CREATE INDEX IF NOT EXISTS idx_app_installations_group
  ON public.app_installations (group_id);
CREATE INDEX IF NOT EXISTS idx_app_installations_school
  ON public.app_installations (school_id);

-- ── RLS : lecture seulement, et jamais d'écriture directe ───────────────────
--  Aucune politique INSERT ni UPDATE : la table ne se remplit QUE par la RPC
--  SECURITY DEFINER ci-dessous, qui dérive profil / groupe / école de
--  `auth.uid()`. Un client ne peut donc ni écrire pour autrui, ni mentir sur
--  son périmètre.
ALTER TABLE public.app_installations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_installations_select ON public.app_installations;
CREATE POLICY app_installations_select ON public.app_installations
  FOR SELECT USING (
    public.is_super_admin()
    OR profile_id = auth.uid()
    OR (group_id IS NOT NULL AND group_id = public.auth_group_id())
  );

-- ── Se signaler ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.signaler_version(
  p_version  text,
  p_build    integer,
  p_platform text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
  -- Pas de session : rien à dire.
  IF auth.uid() IS NULL THEN
    RETURN;
  END IF;

  -- ⚠️ Un build à 0 ou nul signifie « je ne sais pas quelle version je suis »
  -- (PackageInfo muet). L'enregistrer ferait apparaître un poste éternellement
  -- en retard, et bloquerait 0146 pour une raison fausse. Mieux vaut ne rien
  -- écrire : il sera alors compté comme « jamais signalé », ce qui est la
  -- vérité.
  IF p_build IS NULL OR p_build <= 0 THEN
    RETURN;
  END IF;

  INSERT INTO public.app_installations AS a (
    profile_id, group_id, school_id, platform, version, build_number
  )
  VALUES (
    auth.uid(),
    public.auth_group_id(),
    public.auth_school_id(),
    COALESCE(NULLIF(btrim(p_platform), ''), 'inconnue'),
    COALESCE(NULLIF(btrim(p_version), ''), '—'),
    p_build
  )
  ON CONFLICT (profile_id) DO UPDATE SET
    group_id     = EXCLUDED.group_id,
    school_id    = EXCLUDED.school_id,
    platform     = EXCLUDED.platform,
    version      = EXCLUDED.version,
    build_number = EXCLUDED.build_number,
    last_seen_at = now();
END;
$fn$;

REVOKE ALL ON FUNCTION public.signaler_version(text, integer, text) FROM public;
GRANT EXECUTE ON FUNCTION public.signaler_version(text, integer, text) TO authenticated;

COMMENT ON FUNCTION public.signaler_version(text, integer, text) IS
  'Le poste dit quelle version il exécute. Appelée une fois par session, au '
  'même endroit que la vérification de mise à jour. Ne lève jamais côté '
  'client : un échec ne doit pas empêcher de travailler.';

-- ── Lire le parc : la répartition ───────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.parc_versions()
RETURNS TABLE (
  build_number       integer,
  version            text,
  platform           text,
  profils            bigint,
  dernier_signalement timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $fn$
  SELECT i.build_number,
         min(i.version)    AS version,
         i.platform,
         count(*)          AS profils,
         max(i.last_seen_at) AS dernier_signalement
  FROM public.app_installations i
  WHERE public.is_super_admin()
     OR (i.group_id IS NOT NULL AND i.group_id = public.auth_group_id())
  GROUP BY i.build_number, i.platform
  ORDER BY i.build_number DESC, i.platform;
$fn$;

REVOKE ALL ON FUNCTION public.parc_versions() FROM public;
GRANT EXECUTE ON FUNCTION public.parc_versions() TO authenticated;

-- ── Lire le parc : la couverture, y compris ce qu'on ignore ─────────────────
CREATE OR REPLACE FUNCTION public.parc_couverture(p_build_min integer)
RETURNS TABLE (
  a_jour          bigint,
  en_retard       bigint,
  jamais_signale  bigint,
  total_profils   bigint,
  plus_ancien     integer
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $fn$
  WITH perimetre AS (
    SELECT p.id
    FROM public.profiles p
    WHERE public.is_super_admin()
       OR (p.group_id IS NOT NULL AND p.group_id = public.auth_group_id())
  ),
  vus AS (
    SELECT i.profile_id, i.build_number
    FROM public.app_installations i
    JOIN perimetre pe ON pe.id = i.profile_id
  )
  SELECT
    count(*) FILTER (WHERE v.build_number >= p_build_min)                AS a_jour,
    count(*) FILTER (WHERE v.build_number <  p_build_min)                AS en_retard,
    (SELECT count(*) FROM perimetre) - (SELECT count(*) FROM vus)        AS jamais_signale,
    (SELECT count(*) FROM perimetre)                                     AS total_profils,
    min(v.build_number)::integer                                         AS plus_ancien
  FROM vus v;
$fn$;

REVOKE ALL ON FUNCTION public.parc_couverture(integer) FROM public;
GRANT EXECUTE ON FUNCTION public.parc_couverture(integer) TO authenticated;

COMMENT ON FUNCTION public.parc_couverture(integer) IS
  '⚠️ `jamais_signale` n''est pas un reste : c''est le chiffre qui décide. Les '
  'builds antérieurs à 0150 ne savent pas se signaler, donc un profil absent '
  'est soit sur une version ancienne, soit jamais revenu — deux risques pour '
  '0146. Ne jamais lire `a_jour` seul.';
