-- ════════════════════════════════════════════════════════════════════════════
--  0116 — CORRECTIF DE 0114 : TROIS ÉCRANS ENCAISSENT, PAS UN
--
--  ⚠️ 0114 exigeait le module `paiements-eleves` pour écrire un versement.
--  C'était FAUX, et la faute était de moi. L'encaissement ne se fait pas qu'à
--  la caisse :
--
--    • `finance/screens/paiements_form.dart`        → `paiements-eleves`
--    • `students/screens/inscriptions_frais_card.dart` → `inscriptions`
--    • `examens/widgets/exam_payment_dialog.dart`   → `examens`
--
--  Dans une école congolaise, **le versement FAIT l'inscription** : la carte
--  des frais encaisse et imprime le reçu devant la famille, sans quitter
--  l'écran. Or le profil Secrétariat n'a PAS `paiements-eleves` — il a
--  `inscriptions` et `examens`, tous deux en création.
--
--  Une secrétaire inscrivant un élève aurait donc reçu `42501`. Ce code fait
--  partie de ceux que `powersync_connector.dart` tient pour FATAUX : la
--  transaction ENTIÈRE est abandonnée. L'inscription, les notes et les
--  présences saisies dans la même fenêtre seraient parties avec le versement.
--  Le remède aurait coûté plus cher que le mal.
--
--  ── LE PRÉDICAT JUSTE ──────────────────────────────────────────────────────
--  Créer sur l'UN des trois modules. Mesuré à Ouésso après correction
--  (transaction annulée) :
--      Direction    → ENCAISSE
--      Secrétariat  → ENCAISSE
--      Enseignant×5 → refusé (42501)
--      Vie scolaire → refusé (42501)
--
--  Le gain de 0114 tient : sur les 276 comptes qui pouvaient écrire, 239
--  restent bloqués (202 enseignants + 37 surveillants). Les 37 secrétaires
--  gardent un droit qu'elles exercent réellement.
--
--  ── LEÇON, PLUS LARGE QUE CETTE TABLE ──────────────────────────────────────
--  Un droit d'écriture ne se déduit pas du nom d'un module. Il se déduit des
--  ÉCRANS qui écrivent. Chercher `savePayment` avant d'écrire la policy aurait
--  évité l'aller-retour — je ne l'avais fait qu'après.
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.auth_module_permet(p_slugs text[], p_action text)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT EXISTS (
    SELECT 1
      FROM profiles pr
      JOIN profile_permissions pp ON pp.profile_id = pr.access_profile_id
      JOIN modules m              ON m.id = pp.module_id
     WHERE pr.id = auth.uid()
       AND m.slug = ANY (p_slugs)
       AND CASE p_action
             WHEN 'create' THEN pp.can_create
             WHEN 'update' THEN pp.can_update
             WHEN 'delete' THEN pp.can_delete
             ELSE pp.can_read
           END
  );
$$;

COMMENT ON FUNCTION public.auth_module_permet(text[], text) IS
  'Variante multi-modules : trois ecrans encaissent (Paiements, carte des frais d une INSCRIPTION, frais d EXAMEN). Exiger le seul module Paiements renverrait 42501 a une secretaire qui inscrit -- code fatal pour le connecteur, lot entier perdu.';

DROP POLICY IF EXISTS payments_insert ON public.student_payments;
DROP POLICY IF EXISTS payments_update ON public.student_payments;
DROP POLICY IF EXISTS payments_delete ON public.student_payments;

CREATE POLICY payments_insert ON public.student_payments
  FOR INSERT WITH CHECK (
    group_id = (SELECT auth_group_id())
    AND ((SELECT is_admin_groupe())
         OR (school_id = (SELECT auth_school_id())
             AND (SELECT auth_module_permet(
                    ARRAY['paiements-eleves','inscriptions','examens'], 'create'))))
  );

CREATE POLICY payments_update ON public.student_payments
  FOR UPDATE USING (
    group_id = (SELECT auth_group_id())
    AND ((SELECT is_admin_groupe())
         OR (school_id = (SELECT auth_school_id())
             AND (SELECT auth_module_permet(
                    ARRAY['paiements-eleves','inscriptions','examens'], 'update'))))
  ) WITH CHECK (
    group_id = (SELECT auth_group_id())
    AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id()))
  );

CREATE POLICY payments_delete ON public.student_payments
  FOR DELETE USING (
    group_id = (SELECT auth_group_id())
    AND ((SELECT is_admin_groupe())
         OR (school_id = (SELECT auth_school_id())
             AND (SELECT auth_module_permet(
                    ARRAY['paiements-eleves','inscriptions','examens'], 'delete'))))
  );
