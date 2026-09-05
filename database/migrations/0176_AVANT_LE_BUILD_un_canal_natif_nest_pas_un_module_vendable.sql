-- ════════════════════════════════════════════════════════════════════════════
--  0176 — UN CANAL NATIF N'EST PAS UN MODULE VENDABLE
--
--  ── LE DÉFAUT, MESURÉ LE 2026-09-03 ───────────────────────────────────────
--  La table `modules` portait une catégorie COMMUNICATION avec trois modules :
--  `annonces`, `messagerie`, `evenements`. Les CINQ profils d'accès
--  (Comptabilité, Direction, Enseignant, Secrétariat, Vie scolaire) les avaient
--  en lecture — 35 lignes dans `profile_permissions`.
--
--  Or la sidebar du personnel construit ses sections DEPUIS CETTE TABLE, puis
--  ajoute par-dessus la section native « COMMUNICATION ». Chaque agent de
--  chaque école voyait donc :
--
--     COMMUNICATION            <- venue de la base
--        Annonces              -> /user/m/annonces      (hôte générique)
--        Messagerie            -> /user/m/messagerie    (hôte générique)
--        Événements            -> /user/m/evenements    (hôte générique)
--     ...
--     COMMUNICATION            <- native, épinglée
--        Annonces & Agenda     -> /user/annonces        (le vrai écran)
--        Messagerie            -> /user/messagerie      (le vrai écran)
--
--  Deux sections du même nom, « Messagerie » deux fois — et les trois entrées
--  du haut menaient à `/user/m/<slug>`, l'hôte des modules « accordés mais pas
--  encore bâtis ». Un agent qui cliquait sur la première Messagerie ouvrait
--  une page vide. `annonces`, `messagerie` et `evenements` ne figurent pas
--  dans `_moduleRoutes` : la retombée était donc silencieuse et systématique.
--
--  ── ⚠️ LA CAUSE EST DANS LE MODÈLE, PAS DANS L'ÉCRAN ─────────────────────
--  La communication est « tissu natif, jamais vendu, non désactivable » — le
--  code le dit, le test `toute_page_ecole_est_un_module_test` l'exempte. Un
--  canal natif qui figure AUSSI au catalogue vendable est une contradiction :
--  il serait alors coupé par un plan, par un profil d'accès, et par le
--  hard-lock d'impayé (ADR-0009). Une école qui ne peut plus être jointe par
--  sa hiérarchie n'est pas une école en retard de paiement : c'est une école
--  coupée.
--
--  Corriger l'affichage aurait laissé la contradiction en base, prête à
--  ressortir au prochain écran qui lit `modules`.
--
--  ── ⚠️ `evenements` NE PERD RIEN ─────────────────────────────────────────
--  Vérifié : `Routes.evenements` mène à `StaffAnnouncementsScreen(initialTab: 1)`
--  — l'onglet Agenda du MÊME écran que « Annonces & Agenda », atteignable d'un
--  geste depuis le fil. Le module ne donnait accès à rien de plus, et son
--  entrée menait à une coquille.
--
--  ── ON DÉSACTIVE, ON NE SUPPRIME PAS ─────────────────────────────────────
--  `plan_modules` et `profile_permissions` référencent ces modules. Les
--  supprimer emporterait des lignes en cascade sur tous les groupes et
--  laisserait un trou dans l'historique des droits. `is_active = false` suffit :
--  les requêtes de la sidebar filtrent déjà sur `COALESCE(m.is_active, 1) <> 0`,
--  et la catégorie devenue vide disparaît d'elle-même.
--
--  ── ORDRE : AVANT LE BUILD. Réversible (remettre is_active). ─────────────
-- ════════════════════════════════════════════════════════════════════════════

-- ── 1. Les trois canaux quittent le catalogue vendable ─────────────────────
UPDATE public.modules
   SET is_active = false,
       updated_at = NOW()
 WHERE slug IN ('annonces', 'messagerie', 'evenements')
   AND is_active;

-- ── 2. La liste réservée, en UN endroit ────────────────────────────────────
--  ⚠️ Doit rester identique à `kSlugsCanauxNatifs` dans
--  `lib/core/constants/canaux_natifs.dart`. `canaux_natifs_test.dart` compare
--  les deux : c'est cette divergence-là qui a créé le doublon.
CREATE OR REPLACE FUNCTION public.slugs_canaux_natifs()
RETURNS text[]
LANGUAGE sql IMMUTABLE
SET search_path = public, pg_temp
AS $fn$
  SELECT ARRAY['annonces', 'messagerie', 'evenements']::text[]
$fn$;

COMMENT ON FUNCTION public.slugs_canaux_natifs() IS
  'Slugs occupes par un canal natif de communication. Un module ne peut pas les porter : il serait coupe par un plan, un profil ou un impaye, alors que ces canaux ne se coupent jamais.';

-- ── 3. Le verrou : on ne réactive pas un canal natif ───────────────────────
--  Sans lui, la correction ne tient que jusqu'au prochain qui recoche la case
--  dans l'écran des modules — et le doublon revient, silencieusement, chez
--  tous les agents de toutes les écoles.
CREATE OR REPLACE FUNCTION public.fn_module_pas_un_canal_natif()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NEW.is_active AND NEW.slug = ANY (public.slugs_canaux_natifs()) THEN
    RAISE EXCEPTION
      'Le slug « % » est un canal natif de communication : il ne peut pas etre un module vendable. Voir migration 0176.',
      NEW.slug
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS trg_module_pas_un_canal_natif ON public.modules;
CREATE TRIGGER trg_module_pas_un_canal_natif
  BEFORE INSERT OR UPDATE OF is_active, slug ON public.modules
  FOR EACH ROW EXECUTE FUNCTION public.fn_module_pas_un_canal_natif();

COMMENT ON TRIGGER trg_module_pas_un_canal_natif ON public.modules IS
  'Empeche un canal natif (annonces, messagerie, evenements) de revenir au catalogue vendable : c''est ce doublon qui affichait DEUX sections COMMUNICATION a chaque agent, dont une menant a des pages vides.';
