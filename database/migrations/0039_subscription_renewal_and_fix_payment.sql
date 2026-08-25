-- 0039 — Réabonnement + correctif CRITIQUE de la confirmation de paiement
--
-- Trois défauts du workflow d'abonnement, corrigés ensemble.
--
-- ① CRITIQUE — `mark_invoice_paid` était CASSÉ. Sa notification finale insérait
--    dans `notifications` sans `recipient_id`, or cette colonne est NOT NULL →
--    la transaction ENTIÈRE échouait. Résultat : confirmer un paiement depuis
--    l'UI super_admin plantait toujours, aucun groupe ne pouvait être (ré)activé
--    en payant. Le modèle de notification est PAR DESTINATAIRE (recipient_id) →
--    on VENTILE la notif « paiement confirmé » à chaque admin_groupe du groupe.
--
-- ② Le renouvellement ne générait AUCUNE facture. Le trigger de facturation est
--    `AFTER INSERT` (création du groupe uniquement). Renouveler se faisait en
--    éditant `subscription_end` à la main → ni facture, ni reçu, ni trace de
--    revenu. Désormais `create_renewal_invoice()` émet une facture `pending`
--    que le super_admin confirme via `mark_invoice_paid` (chemin d'activation
--    unique). Les renouvellements passent donc par la facturation, comme les
--    premières souscriptions.
--
-- ③ L'admin_groupe ne pouvait pas se réabonner en libre-service (le bouton du
--    plan courant est désactivé, les factures en lecture seule). Il peut
--    maintenant appeler `create_renewal_invoice()` pour SON groupe : la fonction
--    est SECURITY DEFINER et autorise super_admin OU l'admin_groupe du groupe.

-- ─────────────────────────────────────────────────────────────────────────────
-- ① Correctif mark_invoice_paid : ventiler la notification par destinataire.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.mark_invoice_paid(
  p_invoice_id uuid,
  p_payment_method text,
  p_payment_ref text DEFAULT NULL,
  p_notes text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_group_id   UUID;
  v_plan_id    UUID;
  v_amount     INTEGER;
  v_period_end DATE;
  v_inv_number VARCHAR;
  v_status     invoice_status;
  v_rec_number VARCHAR;
BEGIN
  IF NOT is_super_admin() THEN
    RAISE EXCEPTION 'Accès refusé : seul le super administrateur peut enregistrer un paiement';
  END IF;

  SELECT group_id, plan_id, amount_xaf, period_end, invoice_number, status
    INTO v_group_id, v_plan_id, v_amount, v_period_end, v_inv_number, v_status
    FROM group_invoices WHERE id = p_invoice_id;

  IF v_group_id IS NULL THEN
    RAISE EXCEPTION 'Facture introuvable';
  END IF;
  IF v_status = 'paid'::invoice_status THEN
    RAISE EXCEPTION 'Facture déjà réglée';
  END IF;

  v_rec_number := 'REC-' || substring(v_inv_number from 5);

  UPDATE group_invoices SET
    status            = 'paid'::invoice_status,
    paid_at           = NOW(),
    payment_method    = p_payment_method::payment_method,
    payment_reference = p_payment_ref,
    receipt_number    = v_rec_number,
    notes             = COALESCE(p_notes, notes),
    updated_at        = NOW()
  WHERE id = p_invoice_id;

  -- Activation : le SEUL endroit qui pose status=active + subscription_end.
  UPDATE school_groups SET
    subscription_status = 'active'::subscription_status,
    subscription_start  = COALESCE(subscription_start, CURRENT_DATE),
    subscription_end    = v_period_end,
    is_active           = true,
    updated_at          = NOW()
  WHERE id = v_group_id;

  -- Notification VENTILÉE : une ligne par admin_groupe du groupe (recipient_id
  -- NOT NULL). Si le groupe n'a pas encore d'admin, 0 ligne — sans erreur.
  INSERT INTO notifications (group_id, recipient_id, type, title, body, is_read)
  SELECT v_group_id, p.id, 'payment',
         'Paiement confirmé — ' || v_rec_number,
         'Votre facture de ' || v_amount || ' XAF a été réglée. '
           || 'Votre abonnement est actif jusqu''au '
           || to_char(v_period_end, 'DD/MM/YYYY') || '.',
         false
    FROM profiles p
   WHERE p.group_id = v_group_id AND p.role = 'admin_groupe';

  RETURN jsonb_build_object(
    'success', true, 'receipt_number', v_rec_number,
    'group_id', v_group_id, 'amount_xaf', v_amount);
END;
$function$;

-- ─────────────────────────────────────────────────────────────────────────────
-- ② + ③ create_renewal_invoice : émet une facture de renouvellement.
--    Autorisé au super_admin OU à l'admin_groupe DE CE groupe (libre-service).
--    Idempotent : s'il existe déjà une facture impayée, on la renvoie plutôt
--    que d'en créer une seconde (l'admin peut recliquer sans risque de doublon).
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.create_renewal_invoice(p_group_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_plan_id    uuid;
  v_price      integer;
  v_cur_end    date;
  v_start      date;
  v_end        date;
  v_inv_number varchar;
  v_group_name text;
  v_existing   group_invoices%ROWTYPE;
BEGIN
  -- Garde-fou NULL : `x = NULL` vaut NULL (ni vrai ni faux) et laisserait
  -- filer la vérification d'autorisation. On l'écarte explicitement.
  IF p_group_id IS NULL THEN
    RAISE EXCEPTION 'Groupe non spécifié';
  END IF;

  -- Autorisation : super_admin, ou l'admin_groupe de CE groupe uniquement.
  IF NOT (is_super_admin()
          OR (is_admin_groupe() AND auth_group_id() = p_group_id)) THEN
    RAISE EXCEPTION 'Accès refusé';
  END IF;

  SELECT plan_id, subscription_end, name
    INTO v_plan_id, v_cur_end, v_group_name
    FROM school_groups WHERE id = p_group_id;

  IF v_plan_id IS NULL THEN
    RAISE EXCEPTION 'Aucun plan attribué — contactez la plateforme pour en choisir un.';
  END IF;

  SELECT price_xaf INTO v_price FROM subscription_plans WHERE id = v_plan_id;

  -- Nouvelle période : enchaîne sur la fin courante si encore future, sinon
  -- démarre aujourd'hui (pas de rétroactivité qui « brûlerait » des jours).
  v_start := GREATEST(COALESCE(v_cur_end, CURRENT_DATE), CURRENT_DATE);
  v_end   := (v_start + INTERVAL '1 year')::date;

  -- Plan gratuit : pas de facture, prolongation directe.
  IF v_price IS NULL OR v_price = 0 THEN
    UPDATE school_groups SET
      subscription_status = 'active'::subscription_status,
      subscription_start  = COALESCE(subscription_start, CURRENT_DATE),
      subscription_end    = v_end,
      is_active           = true,
      updated_at          = NOW()
    WHERE id = p_group_id;
    RETURN jsonb_build_object('success', true, 'free', true,
                              'period_end', v_end);
  END IF;

  -- Idempotence : une facture impayée existe déjà → on la renvoie.
  SELECT * INTO v_existing FROM group_invoices
   WHERE group_id = p_group_id
     AND status IN ('pending'::invoice_status, 'overdue'::invoice_status)
   ORDER BY created_at DESC LIMIT 1;

  IF v_existing.id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'success', true, 'already_pending', true,
      'invoice_id', v_existing.id,
      'invoice_number', v_existing.invoice_number,
      'amount_xaf', v_existing.amount_xaf,
      'period_start', v_existing.period_start,
      'period_end', v_existing.period_end);
  END IF;

  v_inv_number := generate_invoice_number();

  INSERT INTO group_invoices (
    group_id, invoice_number, amount_xaf,
    period_start, period_end, plan_id, status, created_by
  ) VALUES (
    p_group_id, v_inv_number, v_price,
    v_start, v_end, v_plan_id, 'pending'::invoice_status, auth.uid()
  );

  -- Prévenir les super_admins qu'un renouvellement est à encaisser (ventilé).
  -- group_id = le groupe demandeur (satisfait le NOT NULL).
  INSERT INTO notifications (group_id, recipient_id, type, title, body, is_read)
  SELECT p_group_id, p.id, 'subscription',
         'Renouvellement à encaisser',
         COALESCE(v_group_name, 'Un groupe')
           || ' a généré une facture de renouvellement de '
           || v_price || ' XAF (' || v_inv_number || ').',
         false
    FROM profiles p WHERE p.role = 'super_admin';

  RETURN jsonb_build_object(
    'success', true, 'created', true,
    'invoice_number', v_inv_number, 'amount_xaf', v_price,
    'period_start', v_start, 'period_end', v_end);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.create_renewal_invoice(uuid) TO authenticated;
