-- ════════════════════════════════════════════════════════════════════════════
--  0177 — LE SOCLE NATIF N'EST PAS VENDABLE (généralisation de 0176)
--
--  ── CE QUE 0176 A CORRIGÉ, ET CE QU'IL A LAISSÉ OUVERT ────────────────────
--  0176 a retiré du catalogue trois modules — `annonces`, `messagerie`,
--  `evenements` — qui doublaient des canaux natifs, et posé un déclencheur qui
--  refuse de les rallumer. Il a corrigé LE cas constaté ; il n'a pas fermé LA
--  CLASSE de défauts.
--
--  La barre du personnel est la seule qui se construise DEPUIS CETTE TABLE.
--  Tout module dont le slug recouvre une page native y apparaît une seconde
--  fois — et, comme ces slugs sont absents de `_moduleRoutes`, la ligne mène à
--  `/user/m/<slug>`, l'hôte générique des modules pas encore bâtis : une page
--  vide. C'est exactement ce qui s'est produit avec la communication, et rien
--  n'empêchait aujourd'hui de recréer le même défaut avec `parametres`,
--  `support`, `audit`, `calendrier`, `rapports` ou `dashboard`.
--
--  ── ⚠️ RIEN N'EST DÉSACTIVÉ PAR CETTE MIGRATION ──────────────────────────
--  Vérifié avant écriture, sur les 35 modules du catalogue : AUCUN ne porte
--  l'un des six slugs ajoutés. On ferme une porte encore ouverte, on ne retire
--  rien à personne. Le bloc de contrôle plus bas échoue bruyamment si cette
--  vérification cesse d'être vraie — mieux vaut une migration qui refuse de
--  passer qu'un déclencheur qui bloquera un jour une mise à jour anodine.
--
--  ── LA LISTE EST ÉCRITE DEUX FOIS, ET C'EST ASSUMÉ ───────────────────────
--  Ici, et dans `lib/core/constants/socle_natif.dart` (`kSlugsReserves`). Un
--  déclencheur ne peut pas lire du Dart, et Flutter ne peut pas interroger un
--  catalogue au moment de compiler. `socle_natif_test.dart` compare les deux à
--  chaque exécution des tests : c'est cette divergence-là qui laisse un canal
--  natif redevenir un module.
--
--  ── ORDRE : AVANT LE BUILD. Réversible (rétablir 0176). ──────────────────
-- ════════════════════════════════════════════════════════════════════════════

-- ── 1. Aucun module actif ne doit déjà occuper un slug réservé ─────────────
DO $$
DECLARE
  conflits text;
BEGIN
  SELECT string_agg(slug, ', ' ORDER BY slug) INTO conflits
    FROM public.modules
   WHERE is_active
     AND slug IN ('annonces', 'messagerie', 'evenements', 'dashboard',
                  'calendrier', 'rapports', 'audit', 'support', 'parametres');

  IF conflits IS NOT NULL THEN
    RAISE EXCEPTION
      'Des modules ACTIFS portent des slugs que 0177 veut reserver : %. Decider d''abord de leur sort (page native ou module vendable) — les deux ne peuvent pas coexister sans doubler la barre du personnel.',
      conflits;
  END IF;
END
$$;

-- ── 2. La liste réservée, en UN endroit ────────────────────────────────────
--  ⚠️ Doit rester identique à `kSlugsReserves` dans
--  `lib/core/constants/socle_natif.dart`.
CREATE OR REPLACE FUNCTION public.slugs_natifs()
RETURNS text[]
LANGUAGE sql IMMUTABLE
SET search_path = public, pg_temp
AS $fn$
  SELECT ARRAY[
    -- Communication (0176) : `evenements` n'a pas de ligne de menu — l'agenda
    -- est un ONGLET de l'écran d'annonces — mais son slug reste pris.
    'annonces', 'messagerie', 'evenements',
    -- Bloc de tête
    'dashboard',
    -- Configs natives de la direction
    'calendrier', 'rapports',
    -- Bloc système
    'support', 'audit', 'parametres'
  ]::text[]
$fn$;

COMMENT ON FUNCTION public.slugs_natifs() IS
  'Slugs occupes par une page native de la plateforme. Un module ne peut pas les porter : il serait coupe par un plan, un profil ou un impaye, alors que ces pages ne se coupent jamais — et il doublerait la ligne native dans la barre du personnel, vers une page vide.';

-- ── 3. Le verrou lit la nouvelle liste ─────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_module_pas_un_canal_natif()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NEW.is_active AND NEW.slug = ANY (public.slugs_natifs()) THEN
    RAISE EXCEPTION
      'Le slug « % » appartient a une page native de la plateforme : il ne peut pas etre un module vendable. Voir migration 0177.',
      NEW.slug
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$fn$;

-- Le déclencheur lui-même est inchangé (0176) : BEFORE INSERT OR UPDATE OF
-- is_active, slug. On peut recréer un module au lieu de le rallumer — les deux
-- chemins doivent être couverts.

-- ── 4. L'ancienne fonction n'a plus d'appelant ─────────────────────────────
DROP FUNCTION IF EXISTS public.slugs_canaux_natifs();
