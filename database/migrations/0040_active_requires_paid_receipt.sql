-- 0040 — « Actif » DOIT être adossé à un reçu payé (protection du revenu)
--
-- Constat (audit du workflow abonnement) : `school_groups.subscription_status`
-- pouvait passer à 'active' SANS aucun reçu payé — le super_admin l'édite à la
-- main (`_setStatus` / `_save`). Un groupe pouvait donc être actif (et, comme
-- l'entitlement online en dérive, écrire librement) sans jamais avoir payé.
--
-- Règle métier posée ici, à la SOURCE : on ne peut ACTIVER un groupe que si
--   • son plan est GRATUIT (price_xaf = 0), ou
--   • il existe un REÇU PAYÉ (group_invoices.status='paid') dont la période
--     couvre l'échéance accordée (period_end >= subscription_end).
--
-- Le contrôle ne porte QUE sur la TRANSITION vers 'active' (OLD ≠ active) :
-- éditer un groupe déjà actif (téléphone, adresse…) reste libre, et on ne
-- rejoue pas la règle sur l'historique. `mark_invoice_paid` reste le chemin
-- d'activation normal : il marque la facture payée AVANT d'activer le groupe,
-- donc le reçu existe quand ce trigger s'exécute.
--
-- ⚠️ Ceci n'entrave PAS la synchro offline du personnel (règle C4) : c'est un
-- garde-fou d'ÉCRITURE sur le statut, pas un gate de disponibilité des modules.

-- ① Anomalie de données : Bethel (plan gratuit) est actif sans période. Un plan
--    gratuit se renouvelle quand même annuellement → on lui pose une échéance.
UPDATE school_groups
   SET subscription_start = COALESCE(subscription_start, CURRENT_DATE),
       subscription_end   = COALESCE(subscription_end,
                                     (CURRENT_DATE + INTERVAL '1 year')::date),
       updated_at         = NOW()
 WHERE subscription_status = 'active'::subscription_status
   AND subscription_end IS NULL;

-- ② Le garde-fou.
CREATE OR REPLACE FUNCTION public.fn_guard_active_requires_payment()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_price integer;
BEGIN
  -- Uniquement la BASCULE vers 'active' (pas les éditions d'un groupe actif).
  IF NEW.subscription_status <> 'active'::subscription_status
     OR OLD.subscription_status = 'active'::subscription_status THEN
    RETURN NEW;
  END IF;

  SELECT price_xaf INTO v_price FROM subscription_plans WHERE id = NEW.plan_id;

  -- Plan gratuit → activation libre (mais une échéance reste requise).
  IF v_price IS NULL OR v_price = 0 THEN
    IF NEW.subscription_end IS NULL THEN
      NEW.subscription_end := (COALESCE(NEW.subscription_start, CURRENT_DATE)
                               + INTERVAL '1 year')::date;
    END IF;
    RETURN NEW;
  END IF;

  -- Plan payant → échéance obligatoire ET reçu payé qui la couvre.
  IF NEW.subscription_end IS NULL THEN
    RAISE EXCEPTION 'Activation refusée : échéance manquante pour un plan payant.';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM group_invoices gi
     WHERE gi.group_id = NEW.id
       AND gi.status   = 'paid'::invoice_status
       AND gi.period_end >= NEW.subscription_end
  ) THEN
    RAISE EXCEPTION
      'Activation refusée : aucun reçu payé ne couvre cette période. '
      'Enregistrez le paiement de la facture pour activer les modules.';
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_guard_active_requires_payment ON public.school_groups;
CREATE TRIGGER trg_guard_active_requires_payment
  BEFORE UPDATE ON public.school_groups
  FOR EACH ROW EXECUTE FUNCTION fn_guard_active_requires_payment();
