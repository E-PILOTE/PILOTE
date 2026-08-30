-- ════════════════════════════════════════════════════════════════════════════
--  0154 — L'ADMIN GROUPE PEUT ENFIN ENREGISTRER SES PROPRES RÉGLAGES
--
--  ── LE DÉFAUT, TROUVÉ EN POSANT LA TUTELLE SUR LE GROUPE ──────────────────
--  `school_groups` n'a qu'UNE politique UPDATE : `is_super_admin()`.
--  Or DEUX écrans de l'espace admin_groupe écrivent dans cette table :
--
--    • `bareme_passage_card.dart`  → promotion_pass_mark / _deliberation_floor
--    • `partner_opt_in_tile.dart`  → partner_display_enabled
--
--  Un UPDATE qui ne satisfait pas le USING d'une politique ne lève PAS
--  d'erreur : il met à jour ZÉRO ligne et PostgREST répond 204. L'écran
--  affiche donc « enregistré », et rien n'est enregistré.
--
--  ⚠️ MESURÉ, pas supposé. Sondé en base sous l'identité d'un admin_groupe
--  réel : `lignes_maj = 0`, `avant = 10.00`, `apres = 10.00`. Le barème de
--  passage — la barre au-dessus de laquelle un élève passe en classe
--  supérieure — était donc INMODIFIABLE par celui-là même à qui l'écran est
--  destiné, et le silence tenait lieu de confirmation.
--
--  ── LE REMÈDE, ET POURQUOI CELUI-LÀ ───────────────────────────────────────
--  Une politique UPDATE ne sait pas restreindre des COLONNES. Ouvrir
--  `school_groups` à l'admin_groupe sans garde lui donnerait aussi `plan_id`,
--  `subscription_status`, `is_active` et `tutelle` — c'est-à-dire le droit de
--  s'offrir le plan Premium et de changer de ministère.
--
--  On ajoute donc DEUX pièces indissociables :
--    1. une politique qui autorise l'admin_groupe sur SON groupe ;
--    2. un déclencheur BEFORE UPDATE qui REFUSE toute modification d'une
--       colonne hors de la liste blanche.
--
--  Alternative écartée : une RPC SECURITY DEFINER. Elle aurait exigé un
--  nouveau build pour que le parc en profite ; ici le build DÉJÀ DÉPLOYÉ se
--  met à fonctionner dès l'application de cette migration, sans une ligne de
--  Dart changée.
--
--  ── ⚠️ POURQUOI LA GARDE NE S'APPLIQUE QU'À UN UTILISATEUR IDENTIFIÉ ──────
--  `is_super_admin()` lit `profiles` par `auth.uid()`. Sous `service_role`
--  (Edge Functions), sous `postgres` (migrations) et dans un déclencheur
--  système, `auth.uid()` est NULL — la fonction rend donc FAUX pour des
--  chemins parfaitement légitimes. Garder sur `auth.uid() IS NOT NULL` évite
--  de bloquer les migrations avec le verrou censé protéger les groupes.
--
--  ── ⚠️ POURQUOI 42501 EST LE BON CODE D'ERREUR ────────────────────────────
--  42501 appartient à `_fatalResponseCodes` du connecteur PowerSync : un lot
--  qui le reçoit est ABANDONNÉ au lieu d'être rejoué sans fin. C'est ce qu'on
--  veut d'un refus de droit. Et le risque de rejeu ne se pose pas ici :
--  `school_groups` n'est écrite par AUCUN poste hors ligne (vérifié — aucun
--  `db.execute` sur cette table dans `lib/`), seulement en ligne par le
--  super_admin et l'admin_groupe.
--
--  ── ORDRE : AVANT LE BUILD ────────────────────────────────────────────────
--  Purement serveur, et CORRECTIVE du build déployé. Rien à attendre.
-- ════════════════════════════════════════════════════════════════════════════

-- ── 1. La liste blanche, en dur et commentée ────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_school_groups_garde_colonnes()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  interdite text;
BEGIN
  -- Chemins système : service_role, postgres, déclencheurs. Voir l'en-tête.
  IF auth.uid() IS NULL OR public.is_super_admin() THEN
    RETURN NEW;
  END IF;

  -- Colonnes qu'un admin_groupe règle légitimement sur SON groupe.
  --  • le barème de passage (migration 0107) : c'est une décision pédagogique
  --    du groupe, pas de la plateforme ;
  --  • l'affichage des partenaires (migration 0035) : opt-in du groupe ;
  --  • updated_at, que tout écrivain pose.
  SELECT k INTO interdite
    FROM jsonb_each(to_jsonb(NEW)) AS n(k, v)
    JOIN jsonb_each(to_jsonb(OLD)) AS o(k, v) USING (k)
   WHERE n.v IS DISTINCT FROM o.v
     AND k NOT IN ('promotion_pass_mark',
                   'promotion_deliberation_floor',
                   'partner_display_enabled',
                   'updated_at')
   LIMIT 1;

  IF interdite IS NOT NULL THEN
    RAISE EXCEPTION
      'Colonne % reservee au super_admin sur school_groups', interdite
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$fn$;

COMMENT ON FUNCTION public.fn_school_groups_garde_colonnes() IS
  'Garde-fou de colonnes : sans lui, la politique groups_update_reglages donnerait a un admin_groupe le droit de changer son plan, son statut d''abonnement et sa tutelle.';

DROP TRIGGER IF EXISTS trg_school_groups_garde_colonnes ON public.school_groups;
CREATE TRIGGER trg_school_groups_garde_colonnes
  BEFORE UPDATE ON public.school_groups
  FOR EACH ROW EXECUTE FUNCTION public.fn_school_groups_garde_colonnes();

-- ── 2. La politique, qui n'ouvre que SON groupe ─────────────────────────────
DROP POLICY IF EXISTS groups_update_reglages ON public.school_groups;
CREATE POLICY groups_update_reglages ON public.school_groups
  FOR UPDATE TO authenticated
  USING       (public.is_admin_groupe() AND id = public.auth_group_id())
  WITH CHECK  (public.is_admin_groupe() AND id = public.auth_group_id());

COMMENT ON POLICY groups_update_reglages ON public.school_groups IS
  'Complete groups_update (super_admin). Indissociable du declencheur trg_school_groups_garde_colonnes, qui restreint les COLONNES — ce qu''une politique ne sait pas faire.';
