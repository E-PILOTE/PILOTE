-- ════════════════════════════════════════════════════════════════════════════
--  0187 — COUPER L'ACCÈS D'UN GROUPE, ET LE RÉTABLIR
--
--  ── LA DEMANDE, APRÈS DISCUSSION ──────────────────────────────────────────
--  J'avais objecté qu'une licence suspendue ne devait couper personne (C4 du
--  0160). Le fondateur a maintenu et tranché : « je voudrais quand même un
--  moyen d'annuler une licence et d'empêcher le ministère d'accéder à la
--  plateforme, au cas où les modalités de paiement ne seraient pas
--  respectées ». C'est sa décision, et elle se défend : sans aucun levier, un
--  marché de quarante millions ne se recouvre qu'au tribunal.
--
--  ── ⚠️ POURQUOI CE N'EST PAS UN STATUT DE LICENCE ─────────────────────────
--  Le levier existe, mais il reste SÉPARÉ du cycle de vie du marché, et c'est
--  la seule chose que j'ai refusé de céder :
--
--   • Une licence suspendue ne coupe TOUJOURS rien. Elle sort du revenu, elle
--     s'affiche avec son motif, elle appelle une conversation.
--   • Couper l'accès est un SECOND geste, explicite, nommé, motivé, tracé.
--
--  Les lier ferait de chaque suspension comptable une coupure d'État — et
--  personne ne suspendrait plus rien de peur de fermer un ministère. Deux
--  gestes, deux décisions : c'est ce qui rend le second utilisable.
--
--  ── CE QUE LA COUPURE FAIT VRAIMENT ───────────────────────────────────────
--  1. CÔTÉ SERVEUR — `auth_peut_superviser()` rend FAUX. Un seul point de
--     passage, et il commande les quatre choses qu'une licence achète :
--       `tutelle_groupes()`     — la vue sur le réseau
--       `tutelle_ecoles()`      — ses établissements
--       `tutelle_destinataires()` — à qui écrire
--       `circulaire_publier()`  — descendre une note au réseau
--     C'est exactement le périmètre du marché qui n'est pas payé. Rien de
--     plus, rien de moins.
--  2. CÔTÉ ÉCRAN — l'espace du groupe se ferme sur une page qui DIT le motif
--     et par où passer pour rétablir.
--
--  ── ⚠️ CE QUE LA COUPURE NE FAIT PAS ──────────────────────────────────────
--  Elle ne touche NI les écoles du réseau (ce sont d'autres groupes, qui ont
--  payé, eux), NI les élèves, NI la synchronisation hors ligne du personnel
--  d'un établissement. Couper un enseignant de Kinkala parce qu'un mandat
--  ministériel traîne au Trésor punirait une école pour la dette d'une autre
--  administration.
--
--  ⚠️ ET ELLE NE DÉTRUIT RIEN. Les données restent, la synchro reprend à
--  l'identique au rétablissement. C'est une porte fermée, pas un effacement.
--
--  ── ORDRE : AVANT LE BUILD ────────────────────────────────────────────────
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ── 1. L'état, sur le groupe ───────────────────────────────────────────────
ALTER TABLE public.school_groups
  ADD COLUMN IF NOT EXISTS acces_suspendu       boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS acces_suspendu_motif text,
  ADD COLUMN IF NOT EXISTS acces_suspendu_le    timestamptz,
  ADD COLUMN IF NOT EXISTS acces_suspendu_par   uuid
    REFERENCES public.profiles(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.school_groups.acces_suspendu IS
  'Acces de l''espace de ce groupe coupe par E-PILOTE Congo (impaye). '
  'DISTINCT du statut de sa licence : une licence suspendue ne coupe rien. '
  'N''affecte ni les ecoles du reseau (autres groupes), ni la synchro du '
  'personnel d''etablissement.';

COMMENT ON COLUMN public.school_groups.acces_suspendu_motif IS
  'Lu par le groupe sur sa page de blocage. Obligatoire : une porte fermee '
  'sans explication est un appel telephonique garanti.';

CREATE INDEX IF NOT EXISTS idx_school_groups_acces_suspendu
  ON public.school_groups (acces_suspendu) WHERE acces_suspendu;

-- ── 2. Le point de passage unique ──────────────────────────────────────────
--  ⚠️ UNE SEULE FONCTION À MODIFIER, et elle commande les quatre RPC de
--  tutelle. C'est ce qui rend la coupure réelle côté serveur sans toucher à
--  vingt politiques RLS — et ce qui garantit qu'on ne peut pas l'oublier
--  quelque part.
CREATE OR REPLACE FUNCTION public.auth_peut_superviser()
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
  SELECT public.is_super_admin()
      OR (
        public.is_admin_groupe()
        AND public.auth_group_administre_referentiel()
        -- Accès coupé pour impayé : la supervision s'arrête ici (0187).
        AND NOT COALESCE(
              (SELECT g.acces_suspendu
                 FROM public.school_groups g
                WHERE g.id = public.auth_group_id()), false)
      )
$fn$;

COMMENT ON FUNCTION public.auth_peut_superviser() IS
  'Droit de superviser un reseau : super_admin, ou admin d''un groupe qui '
  'administre le referentiel national ET dont l''acces n''est pas coupe pour '
  'impaye (0187). Point de passage unique de tutelle_groupes, tutelle_ecoles, '
  'tutelle_destinataires et circulaire_publier.';

-- ── 3. Couper ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.suspendre_acces_groupe(
  p_group_id uuid,
  p_motif    text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE v_nom text; v_motif text;
BEGIN
  IF NOT is_super_admin() THEN
    RAISE EXCEPTION 'Acces refuse'
      USING ERRCODE = '42501',
            HINT = 'Seule E-PILOTE Congo coupe l''accès d''un groupe.';
  END IF;

  v_motif := NULLIF(btrim(COALESCE(p_motif, '')), '');
  IF v_motif IS NULL THEN
    RAISE EXCEPTION 'Motif obligatoire'
      USING ERRCODE = '23514',
            HINT = 'Ce texte est la SEULE chose que le groupe lira en '
                   'ouvrant l''application. Une porte fermée sans explication '
                   'est un appel téléphonique garanti.';
  END IF;

  SELECT name INTO v_nom FROM public.school_groups WHERE id = p_group_id;
  IF v_nom IS NULL THEN
    RAISE EXCEPTION 'Groupe introuvable' USING ERRCODE = 'P0002';
  END IF;

  UPDATE public.school_groups
     SET acces_suspendu       = true,
         acces_suspendu_motif = v_motif,
         acces_suspendu_le    = now(),
         acces_suspendu_par   = auth.uid(),
         updated_at           = now()
   WHERE id = p_group_id;

  RETURN jsonb_build_object('success', true, 'groupe', v_nom, 'motif', v_motif);
END;
$fn$;

-- ── 4. Rétablir ────────────────────────────────────────────────────────────
--  ⚠️ Pas de motif exigé ici, et c'est délibéré : on ne met JAMAIS de
--  friction sur le geste qui rouvre. Le risque d'un accès rétabli trop vite
--  est nul ; celui d'un accès qui reste fermé faute d'avoir su remplir un
--  champ ne l'est pas.
CREATE OR REPLACE FUNCTION public.retablir_acces_groupe(p_group_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE v_nom text;
BEGIN
  IF NOT is_super_admin() THEN
    RAISE EXCEPTION 'Acces refuse' USING ERRCODE = '42501';
  END IF;

  SELECT name INTO v_nom FROM public.school_groups WHERE id = p_group_id;
  IF v_nom IS NULL THEN
    RAISE EXCEPTION 'Groupe introuvable' USING ERRCODE = 'P0002';
  END IF;

  UPDATE public.school_groups
     SET acces_suspendu       = false,
         acces_suspendu_motif = NULL,
         acces_suspendu_le    = now(),
         acces_suspendu_par   = auth.uid(),
         updated_at           = now()
   WHERE id = p_group_id;

  RETURN jsonb_build_object('success', true, 'groupe', v_nom);
END;
$fn$;

REVOKE ALL ON FUNCTION public.suspendre_acces_groupe(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.retablir_acces_groupe(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.suspendre_acces_groupe(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.retablir_acces_groupe(uuid) TO authenticated;

-- ── 5. Le groupe lit sa propre coupure ─────────────────────────────────────
--  Les trois colonnes appartiennent à `school_groups`, que le groupe lit déjà
--  pour lui-même. Rien à rouvrir — noté pour que personne ne cherche une
--  politique manquante.

COMMIT;
