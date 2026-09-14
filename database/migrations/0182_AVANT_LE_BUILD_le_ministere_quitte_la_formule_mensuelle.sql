-- ════════════════════════════════════════════════════════════════════════════
--  0182 — LE MINISTÈRE QUITTE LA FORMULE MENSUELLE
--
--  ── LA RÈGLE, DITE PAR LE FONDATEUR ───────────────────────────────────────
--  « Un ministère est rattaché à une LICENCE. Un groupe scolaire privé est
--    rattaché à un PLAN MENSUEL. »
--
--  Deux natures de client, deux relations commerciales. Les plans mensuels ne
--  disparaissent pas — ils sont le revenu de la plateforme, et cinq groupes
--  privés en vivent. Ce qui change, c'est que les DEUX ministères en sortent.
--
--  ── L'ÉTAT AVANT, MESURÉ ──────────────────────────────────────────────────
--  Les deux ministères portaient « Institutionnel — 40 000 XAF/mois », le même
--  plan que deux groupes privés (EDEC, Savorgnan de Brazza). Trois
--  conséquences, toutes fausses :
--
--   1. REVENU. Le KPI fait `revenus += monthlyEquivalent(...)` sur tout groupe
--      ACTIF. Les deux ministères injectaient donc **80 000 XAF/mois de revenu
--      fantôme** que personne ne facture ainsi — pendant que les montants réels
--      de `tutelle_licences` n'étaient comptés NULLE PART.
--   2. ÉCHÉANCE. `subscription_end` valait 30/09/2026 pour le METP : le KPI
--      « expire bientôt » (≤ 30 jours) allait le signaler comme un client sur
--      le départ. Un ministère n'expire pas, sa licence court.
--   3. LECTURE. Le ministère lit « Plan Institutionnel, 40 000 XAF/mois » sur
--      son propre tableau de bord. Ce n'est pas sa relation avec E-PILOTE.
--
--  ── ⚠️ LE PIÈGE QUI A FAILLI COÛTER LES 32 MODULES ────────────────────────
--  LES MODULES SONT ACCORDÉS PAR LE PLAN (`plan_modules`), pas par le groupe.
--  « Institutionnel » en accorde **32** — le catalogue entier. Créer un plan
--  « Licence » vide et y basculer les ministères leur aurait retiré TOUS leurs
--  modules dans la seconde, sans un message. Les 32 lignes sont donc recopiées
--  ici, depuis Institutionnel, AVANT tout rattachement.
--
--  ── CE QUE LE PLAN « LICENCE » EST, ET N'EST PAS ──────────────────────────
--  Il est le SUPPORT du rattachement : `school_groups.plan_id` est NOT NULL, il
--  faut bien pointer quelque part, et tous les écrans qui affichent un plan
--  doivent lire « Licence de tutelle » au lieu d'un tarif mensuel.
--
--  Il n'est PAS le contrat. Le montant, la durée, l'avance, les règlements, la
--  référence du marché et le signataire vivent dans `tutelle_licences` (0160) —
--  parce qu'une licence se négocie et se révise par avenant, ce qu'un tarif de
--  catalogue ne sait pas représenter. `price_xaf = 0` dit exactement cela : ce
--  plan ne porte aucun prix, il en désigne un ailleurs.
--
--  ── LE GARDE ──────────────────────────────────────────────────────────────
--  La règle du fondateur devient une contrainte, dans les DEUX sens :
--   • un groupe qui administre le référentiel national DOIT être sur `licence` ;
--   • un groupe sur `licence` DOIT être un ministère — on ne place pas un
--     client privé sur un plan à 0 XAF, ce serait le revenu qui part.
--
--  ── ORDRE : AVANT LE BUILD ────────────────────────────────────────────────
--  Le garde entre en vigueur immédiatement ; les deux ministères sont conformes
--  à la fin de cette migration, et l'écran des groupes n'écrit `plan_id` que
--  depuis un chemin en ligne.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ── 1. Le plan support ──────────────────────────────────────────────────────
INSERT INTO public.subscription_plans
  (name, slug, price_xaf, billing_period, max_schools, max_students, max_staff,
   module_count, is_public_plan, is_active, description)
SELECT
  'Licence de tutelle', 'licence', 0, 'annuel', -1, -1, -1,
  (SELECT count(*) FROM public.plan_modules pm
     JOIN public.subscription_plans p ON p.id = pm.plan_id
    WHERE p.slug = 'institutionnel'),
  true, true,
  'Rattachement des ministeres de tutelle. Ce plan ne porte AUCUN prix : les '
  'conditions reelles (montant, duree, avance, reglements, reference de marche, '
  'signataire) vivent dans tutelle_licences. Ne jamais y rattacher un groupe '
  'prive : ce serait sortir un client payant du revenu mensuel.'
WHERE NOT EXISTS (
  SELECT 1 FROM public.subscription_plans WHERE slug = 'licence');

-- ── 2. Les modules, recopiés d'Institutionnel ───────────────────────────────
--  ⚠️ AVANT le rattachement. L'ordre n'est pas cosmétique : basculer d'abord,
--  c'est laisser les ministères sans un seul module le temps de deux requêtes.
INSERT INTO public.plan_modules (plan_id, module_id)
SELECT lic.id, pm.module_id
  FROM public.plan_modules pm
  JOIN public.subscription_plans src
    ON src.id = pm.plan_id AND src.slug = 'institutionnel'
 CROSS JOIN LATERAL (
   SELECT id FROM public.subscription_plans WHERE slug = 'licence') AS lic
 WHERE NOT EXISTS (
   SELECT 1 FROM public.plan_modules x
    WHERE x.plan_id = lic.id AND x.module_id = pm.module_id);

-- ── 3. Le garde AVANT le rattachement ───────────────────────────────────────
DO $garde$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n
    FROM public.plan_modules pm
    JOIN public.subscription_plans p ON p.id = pm.plan_id
   WHERE p.slug = 'licence';
  IF n = 0 THEN
    RAISE EXCEPTION
      'Le plan Licence de tutelle n''accorde aucun module : y basculer les '
      'ministeres leur retirerait tout. La recopie depuis Institutionnel a '
      'echoue.';
  END IF;
END;
$garde$;

-- ── 4. Les deux ministères y passent ────────────────────────────────────────
UPDATE public.school_groups g
   SET plan_id = (SELECT id FROM public.subscription_plans WHERE slug = 'licence'),
       -- Le terme d'un ministère est celui de sa LICENCE, pas d'un abonnement
       -- mensuel. Laisser cette date le ferait apparaître dans « expire
       -- bientôt » et dans les bandeaux d'échéance.
       subscription_end = NULL,
       updated_at = now()
 WHERE g.administre_referentiel_national;

-- ── 5. La règle devient une contrainte ──────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_ministere_sur_licence()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE v_slug text;
BEGIN
  SELECT slug::text INTO v_slug
    FROM public.subscription_plans WHERE id = NEW.plan_id;

  IF NEW.administre_referentiel_national AND v_slug IS DISTINCT FROM 'licence' THEN
    RAISE EXCEPTION
      'Un ministere de tutelle ne se facture pas au mois'
      USING ERRCODE = '23514',
            HINT = 'Un ministère de tutelle est rattaché au plan « Licence de '
                   'tutelle », et ses conditions réelles se saisissent dans '
                   'Économie › Licences. Les formules mensuelles sont '
                   'réservées aux groupes scolaires privés.';
  END IF;

  IF v_slug = 'licence' AND NOT NEW.administre_referentiel_national THEN
    RAISE EXCEPTION
      'Le plan Licence de tutelle est reserve aux ministeres'
      USING ERRCODE = '23514',
            HINT = 'Ce plan ne porte aucun prix : y rattacher un groupe privé '
                   'le sortirait du revenu mensuel de la plateforme. '
                   'Choisissez une formule mensuelle.';
  END IF;

  RETURN NEW;
END;
$fn$;

COMMENT ON FUNCTION public.fn_ministere_sur_licence() IS
  'Deux natures de client, deux relations : ministere -> plan licence (contrat '
  'dans tutelle_licences), groupe prive -> plan mensuel (revenu de la '
  'plateforme). La contrainte vaut dans les deux sens.';

DROP TRIGGER IF EXISTS trg_ministere_sur_licence ON public.school_groups;
CREATE TRIGGER trg_ministere_sur_licence
  BEFORE INSERT OR UPDATE OF plan_id, administre_referentiel_national
  ON public.school_groups
  FOR EACH ROW EXECUTE FUNCTION public.fn_ministere_sur_licence();

COMMIT;
