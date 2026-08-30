-- ════════════════════════════════════════════════════════════════════════════
--  0157 — RELANCER UN TICKET DOIT VRAIMENT LE ROUVRIR
--
--  ── LE DÉFAUT, MESURÉ ─────────────────────────────────────────────────────
--  `support_tickets` a trois politiques : lecture au périmètre du groupe,
--  insertion par le demandeur, et TOUT pour le super_admin. Aucune UPDATE
--  pour le demandeur.
--
--  Or `sendRequesterFollowUp` (`ticket_thread_provider.dart`) rouvre le ticket
--  quand son demandeur relance un dossier résolu ou fermé. Cet UPDATE ne
--  satisfaisait aucune politique — donc ZÉRO ligne, réponse 204, aucune
--  erreur. Sondé sous l'identité d'un admin_groupe réel :
--
--      relance_lignes_maj   = 0
--      statut_apres_relance = resolved
--
--  Le message de relance, lui, était bien enregistré (`support_ticket_messages`
--  a sa politique d'insertion). Résultat : l'école croit avoir relancé, son
--  message existe, et le ticket reste marqué RÉSOLU — donc il ne remonte dans
--  aucune file d'attente du support. La relance disparaît sans trace visible.
--
--  ── LE REMÈDE, ET SA LIMITE ───────────────────────────────────────────────
--  Même discipline qu'en 0154 : une politique PLUS un déclencheur de liste
--  blanche, parce qu'une politique ne sait pas restreindre des colonnes.
--
--  Le demandeur peut modifier TROIS colonnes, et rien d'autre :
--    • status       — et uniquement VERS `open` : rouvrir, jamais clore
--    • resolved_at  — remis à NULL, cohérent avec la réouverture
--    • updated_at
--
--  Il ne peut donc pas se donner la priorité « urgent », s'assigner un agent,
--  réécrire le sujet, ni fermer un ticket que le support garde ouvert.
--
--  Portée : le GROUPE, alignée sur la politique de LECTURE `group_own_tickets`.
--  Un groupe voit ses tickets ; qu'un autre de ses administrateurs puisse
--  relancer celui d'un collègue absent est le comportement attendu.
--
--  ── ⚠️ ORDRE : AVANT LE BUILD ─────────────────────────────────────────────
--  Purement serveur, et CORRECTIVE du build déployé : la relance se met à
--  fonctionner sans une ligne de Dart changée.
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.fn_support_tickets_garde_demandeur()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  interdite text;
BEGIN
  -- Chemins système (service_role, postgres, déclencheurs) et support.
  IF auth.uid() IS NULL OR public.is_super_admin() THEN
    RETURN NEW;
  END IF;

  SELECT k INTO interdite
    FROM jsonb_each(to_jsonb(NEW)) AS n(k, v)
    JOIN jsonb_each(to_jsonb(OLD)) AS o(k, v) USING (k)
   WHERE n.v IS DISTINCT FROM o.v
     AND k NOT IN ('status', 'resolved_at', 'updated_at')
   LIMIT 1;

  IF interdite IS NOT NULL THEN
    RAISE EXCEPTION
      'Colonne % reservee au support sur support_tickets', interdite
      USING ERRCODE = '42501';
  END IF;

  -- Rouvrir, jamais clore : seul le support décide qu'un dossier est réglé.
  IF NEW.status IS DISTINCT FROM OLD.status AND NEW.status <> 'open' THEN
    RAISE EXCEPTION
      'Un demandeur peut rouvrir un ticket, pas le passer a %', NEW.status
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$fn$;

COMMENT ON FUNCTION public.fn_support_tickets_garde_demandeur() IS
  'Garde de colonnes de la politique tickets_update_demandeur : sans lui, le demandeur pourrait se donner la priorite urgente, s''assigner un agent ou clore son propre ticket.';

DROP TRIGGER IF EXISTS trg_support_tickets_garde_demandeur ON public.support_tickets;
CREATE TRIGGER trg_support_tickets_garde_demandeur
  BEFORE UPDATE ON public.support_tickets
  FOR EACH ROW EXECUTE FUNCTION public.fn_support_tickets_garde_demandeur();

DROP POLICY IF EXISTS tickets_update_demandeur ON public.support_tickets;
CREATE POLICY tickets_update_demandeur ON public.support_tickets
  FOR UPDATE TO authenticated
  USING      (group_id = (SELECT public.auth_group_id()))
  WITH CHECK (group_id = (SELECT public.auth_group_id()));

COMMENT ON POLICY tickets_update_demandeur ON public.support_tickets IS
  'Alignee sur group_own_tickets (lecture). Indissociable du declencheur trg_support_tickets_garde_demandeur, qui limite aux colonnes status / resolved_at / updated_at et interdit toute cloture.';
