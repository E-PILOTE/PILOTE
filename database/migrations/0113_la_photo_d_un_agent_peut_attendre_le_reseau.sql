-- ════════════════════════════════════════════════════════════════════════════
--  0113 — LA PHOTO D'UN AGENT PEUT ATTENDRE LE RÉSEAU
--
--  ── LE PROBLÈME ────────────────────────────────────────────────────────────
--  Tout l'espace école écrit hors ligne. Sauf la photo d'un agent — et pas par
--  paresse : `profiles_update` n'autorise que `is_super_admin()`,
--  `is_admin_groupe()` du groupe, ou `id = auth.uid()`. Un DIRECTEUR qui
--  corrige la fiche d'un autre agent n'entre dans aucune des trois. Un UPDATE
--  d'`avatar_url` poussé par PowerSync reviendrait en `42501`, code que le
--  connecteur tient pour fatal, et emporterait le LOT ENTIER : les notes et les
--  paiements écrits dans la même fenêtre.
--
--  D'où `corriger_fiche_agent` (0091), en ligne par construction. Correct — mais
--  cela laissait le chef d'établissement sans photo tant qu'il n'avait pas de
--  réseau, dans un pays où c'est l'état normal d'une partie des écoles.
--
--  ── LA FORME RETENUE : UNE DEMANDE, PAS UNE ÉCRITURE ───────────────────────
--  L'école n'écrit pas dans `profiles` : elle DÉPOSE UNE DEMANDE dans une table
--  qui lui appartient, synchronisée comme le reste. Le serveur l'applique.
--
--  On ne relâche donc aucun droit : l'autorité reste exactement celle de
--  `corriger_fiche_agent`, vérifiée ici avec `auth.uid()` — qui, lors d'une
--  remontée PowerSync, EST bien l'agent qui a fait le geste, puisque le
--  connecteur téléverse avec son jeton.
--
--  La ligne déposée est aussi sa propre trace : qui a demandé quoi, quand, et
--  ce que le serveur en a fait.
--
--  ── ⚠️ LE TRIGGER NE LÈVE JAMAIS ───────────────────────────────────────────
--  C'est LA règle de ce fichier. Une exception remontée à PostgREST devient un
--  code d'erreur que le connecteur juge fatal : il abandonne la transaction
--  entière — donc tout ce que l'école avait écrit dans la même fenêtre. On
--  aurait reproduit, par le remède, la panne qu'on soigne.
--
--  Un refus s'INSCRIT donc dans la ligne (`refus`), `applied_at` reste nul, et
--  la demande redescend sur le poste avec sa raison. Rien n'est perdu, rien
--  n'est appliqué, et l'agent peut le lire.
--
--  ── CONTREPARTIES HORS BASE (obligatoires) ─────────────────────────────────
--   · `powersync_schema.dart` — déclarer la table locale ;
--   · `sync-rules.yaml` — l'ajouter au bucket `by_school`, puis DÉPLOYER ;
--   · côté écran, préférer la demande EN ATTENTE à `profiles.avatar_url` :
--     hors ligne le serveur n'a rien écrit, et l'agent qui vient de prendre la
--     photo ne la verrait pas — c'est-à-dire croirait son geste raté.
--
--  La publication `powersync` est `FOR ALL TABLES` : rien à y ajouter.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ── 1. La table des demandes ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.staff_photo_requests (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id     uuid NOT NULL REFERENCES public.school_groups(id) ON DELETE CASCADE,
  school_id    uuid NOT NULL REFERENCES public.schools(id),
  profile_id   uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,

  -- L'adresse publique visée. NULL avec `effacer` = retrait de la photo.
  avatar_url   text,
  effacer      boolean NOT NULL DEFAULT false,

  -- Informatif : l'AUTORITÉ, elle, se lit dans `auth.uid()` au moment où la
  -- demande atteint le serveur. Un client ne se déclare pas lui-même habilité.
  requested_by uuid REFERENCES public.profiles(id),

  applied_at   timestamptz,
  refus        text,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.staff_photo_requests IS
  'Demandes de changement de photo d''agent, déposables HORS LIGNE. Le serveur '
  'les applique par trigger, avec l''autorité de corriger_fiche_agent (0091). '
  'Ne jamais écrire profiles.avatar_url par PowerSync : la RLS le refuserait '
  'et le lot entier serait abandonné.';

COMMENT ON COLUMN public.staff_photo_requests.refus IS
  'Renseigné quand la demande n''a PAS été appliquée. Le trigger ne lève '
  'jamais : une exception ferait abandonner le lot PowerSync entier.';

CREATE INDEX IF NOT EXISTS idx_staff_photo_requests_school
  ON public.staff_photo_requests (school_id);
CREATE INDEX IF NOT EXISTS idx_staff_photo_requests_profile
  ON public.staff_photo_requests (profile_id, created_at DESC);

-- ── 2. Le périmètre, au motif standard ──────────────────────────────────────
ALTER TABLE public.staff_photo_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS staff_photo_requests_tenant ON public.staff_photo_requests;
CREATE POLICY staff_photo_requests_tenant ON public.staff_photo_requests
  FOR ALL
  USING (
    (SELECT is_super_admin())
    OR (group_id = (SELECT auth_group_id())
        AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id())))
  )
  WITH CHECK (
    (SELECT is_super_admin())
    OR (group_id = (SELECT auth_group_id())
        AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id())))
  );

-- ── 3. L'application, avec l'autorité de `corriger_fiche_agent` ─────────────
CREATE OR REPLACE FUNCTION public.appliquer_demande_photo_agent()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_moi   profiles%ROWTYPE;
  v_cible profiles%ROWTYPE;
BEGIN
  -- Toute sortie de cette fonction est un RETURN NEW. Jamais un RAISE.
  NEW.applied_at := NULL;
  NEW.refus      := NULL;

  SELECT * INTO v_moi   FROM profiles WHERE id = auth.uid();
  SELECT * INTO v_cible FROM profiles WHERE id = NEW.profile_id;

  IF v_cible.id IS NULL THEN
    NEW.refus := 'Agent introuvable.';
    RETURN NEW;
  END IF;
  IF v_cible.role IN ('eleve', 'parent') THEN
    NEW.refus := 'Cette fiche n''est pas celle d''un agent.';
    RETURN NEW;
  END IF;

  -- Mot pour mot l'autorité de `corriger_fiche_agent` (migration 0091).
  IF NOT (
       is_super_admin()
    OR (is_admin_groupe() AND v_cible.group_id = auth_group_id())
    OR (est_chef_etablissement()
        AND v_cible.school_id IS NOT NULL
        AND v_cible.school_id = v_moi.school_id)
    OR NEW.profile_id = auth.uid()
  ) THEN
    NEW.refus := 'Vous ne pouvez corriger que les fiches des agents de votre '
                 'établissement.';
    RETURN NEW;
  END IF;

  -- Une photo doit venir de NOTRE espace de stockage. Cette adresse s'affiche
  -- sur chaque écran qui montre l'agent : en accepter une quelconque
  -- reviendrait à y laisser poser un mouchard.
  IF NOT NEW.effacer THEN
    IF NEW.avatar_url IS NULL THEN
      NEW.refus := 'Aucune photo transmise.';
      RETURN NEW;
    END IF;
    IF NEW.avatar_url !~ '^https://[a-z0-9.-]+/storage/v1/object/public/avatars/' THEN
      NEW.refus := 'Photo refusée : adresse hors de l''espace de stockage.';
      RETURN NEW;
    END IF;
  END IF;

  UPDATE profiles
     SET avatar_url = CASE WHEN NEW.effacer THEN NULL ELSE NEW.avatar_url END,
         updated_at = now()
   WHERE id = NEW.profile_id;

  INSERT INTO audit_logs (group_id, school_id, user_id, user_role, action,
                          table_name, record_id, new_values)
  VALUES (v_cible.group_id, v_cible.school_id, auth.uid(), v_moi.role,
          'CORRECTION_AGENT', 'profiles', NEW.profile_id,
          jsonb_build_object('photo',
            CASE WHEN NEW.effacer THEN 'effacée' ELSE 'remplacée' END,
            'hors_ligne', true));

  NEW.applied_at := now();
  RETURN NEW;
END;
$fn$;

COMMENT ON FUNCTION public.appliquer_demande_photo_agent() IS
  'Applique une demande de photo déposée hors ligne. NE LÈVE JAMAIS : un refus '
  's''inscrit dans `refus`, sans quoi PowerSync abandonnerait le lot entier.';

DROP TRIGGER IF EXISTS trg_appliquer_demande_photo_agent
  ON public.staff_photo_requests;
CREATE TRIGGER trg_appliquer_demande_photo_agent
  BEFORE INSERT ON public.staff_photo_requests
  FOR EACH ROW EXECUTE FUNCTION public.appliquer_demande_photo_agent();

COMMIT;
