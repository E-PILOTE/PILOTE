-- ════════════════════════════════════════════════════════════════════════════
--  0186 — ACTIVER, SUSPENDRE, REPRENDRE, RÉSILIER UNE LICENCE
--
--  ── L'ÉTAT AVANT, MESURÉ ──────────────────────────────────────────────────
--  Côté fondateur, une licence de quarante millions avait UNE seule action :
--  « Modifier ». Le statut était une liste déroulante au milieu d'un
--  formulaire, entre le montant et la référence de marché. Conséquences :
--
--   1. AUCUNE TRACE. `tutelle_licences` n'avait PAS de déclencheur d'audit,
--      alors que `fn_audit_metier` en surveille dix autres (notes, paiements,
--      élèves…). La ligne la plus chère de la base était la seule sans
--      historique : impossible de dire qui avait activé un marché, quand, ni
--      ce qu'il valait avant.
--   2. AUCUN MOTIF. Suspendre un marché public sans écrire pourquoi, c'est
--      une décision qu'on ne peut ni justifier ni contester trois mois plus
--      tard, quand le ministère demande des comptes.
--   3. AUCUNE RÈGLE. Une liste déroulante autorise TOUTES les transitions —
--      y compris ressusciter un marché résilié, ou activer une licence dont
--      le terme est passé.
--   4. ⚠️ REVENU DOUBLÉ. `mrrLicencesXaf` somme TOUTES les licences actives.
--      Deux licences actives et chevauchantes sur le même ministère — un
--      renouvellement activé avant le terme du précédent — comptaient DEUX
--      fois. Sur un marché à quarante millions, c'est 3,3 M/mois de revenu
--      qui n'existe pas, dans le seul tableau qui dit si la plateforme gagne
--      de l'argent.
--
--  ── ⚠️⚠️ CE QUE SUSPENDRE NE FAIT PAS, ET NE DOIT JAMAIS FAIRE ────────────
--  SUSPENDRE UNE LICENCE NE COUPE RIEN. Ni le ministère, ni son réseau, ni un
--  seul de ses modules. C'est écrit depuis 0160 et ce n'est pas un oubli :
--  « une licence échue ne coupe pas un ministère — on ne ferme pas l'État pour
--  un mandat en retard, et de toute façon un logiciel qui se venge d'un impayé
--  perd le client ET le marché ».
--
--  L'accès dépend de `school_groups.administre_referentiel_national` (0155), et
--  0183 garantit qu'un ministère n'a pas d'échéance d'abonnement. La suspension
--  est un état CONTRACTUEL : elle sort la licence du revenu, elle s'affiche des
--  deux côtés avec son motif, et elle appelle une conversation. Elle ne
--  s'exécute pas contre l'utilisateur.
--
--  Si un jour on veut vraiment fermer l'accès d'un ministère, ce sera une
--  décision explicite sur `administre_referentiel_national`, pas un effet de
--  bord d'un statut de facturation.
--
--  ── LA MACHINE À ÉTATS ────────────────────────────────────────────────────
--     brouillon ──activer──▶ active ──suspendre──▶ suspendue
--         │                   │  ▲                    │
--         │                   │  └─────reprendre──────┘
--         │                   │
--         │                   └──(le temps)──▶ echue ──avenant──▶ active
--         │                                                │
--         └──────────────résilier───────────────────────────┴──▶ resiliee
--
--  `resiliee` est TERMINAL. Un marché résilié ne revient pas : on en signe un
--  autre. C'est la seule règle qui n'a pas d'exception, et c'est voulu — sans
--  elle, « résilier » ne serait qu'un statut de plus, révocable d'un clic.
--
--  ── ORDRE : AVANT LE BUILD (après 0185, qui ajoute `suspendue`) ───────────
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ── 1. La décision laisse une trace sur la ligne elle-même ─────────────────
--  L'audit dit QUI et QUAND ; ces colonnes disent POURQUOI, et se lisent sans
--  ouvrir le journal — y compris par le ministère, qui a le droit de savoir
--  pourquoi son marché est suspendu.
ALTER TABLE public.tutelle_licences
  ADD COLUMN IF NOT EXISTS motif_statut      text,
  ADD COLUMN IF NOT EXISTS statut_change_le  timestamptz,
  ADD COLUMN IF NOT EXISTS statut_change_par uuid
    REFERENCES public.profiles(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.tutelle_licences.motif_statut IS
  'Pourquoi le statut a change. Obligatoire pour suspendre ou resilier : une '
  'decision sur un marche public sans motif ne se justifie ni ne se conteste.';

-- ── 2. Le journal, enfin ───────────────────────────────────────────────────
--  ⚠️ `fn_audit_metier` est générique : elle lit `group_id`, `school_id` et
--  `id` dans la ligne. `tutelle_licences` porte les deux premières clés utiles
--  (`school_id` est absente → NULL, ce que la fonction accepte). Rien à
--  adapter — il manquait seulement le déclencheur.
DROP TRIGGER IF EXISTS trg_audit_metier ON public.tutelle_licences;
CREATE TRIGGER trg_audit_metier
  AFTER DELETE OR UPDATE ON public.tutelle_licences
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_metier();

-- ── 3. Deux licences actives ne se chevauchent pas ─────────────────────────
--  ⚠️ LE GARDE DU REVENU. `mrrLicencesXaf` somme toutes les licences actives ;
--  deux périodes qui se recouvrent comptent deux fois le même mois.
--
--  Écrit en déclencheur et non en contrainte d'exclusion : celle-ci exigerait
--  l'extension `btree_gist`, absente de cette base. Installer une extension en
--  production pour un garde que trois lignes de PL/pgSQL expriment aussi bien
--  serait payer cher une élégance.
CREATE OR REPLACE FUNCTION public.fn_licence_active_sans_chevauchement()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE v_autre text;
BEGIN
  IF NEW.statut <> 'active'::licence_statut THEN
    RETURN NEW;
  END IF;

  SELECT format('« %s » (%s → %s)', l.intitule, l.date_debut, l.date_fin)
    INTO v_autre
    FROM public.tutelle_licences l
   WHERE l.group_id = NEW.group_id
     AND l.id <> NEW.id
     AND l.statut = 'active'::licence_statut
     AND l.date_debut <= NEW.date_fin
     AND l.date_fin   >= NEW.date_debut
   LIMIT 1;

  IF v_autre IS NOT NULL THEN
    RAISE EXCEPTION 'Deux licences actives se chevauchent sur ce ministere'
      USING ERRCODE = '23505',
            HINT = format('%s couvre déjà tout ou partie de cette période. '
                          'Deux licences actives sur les mêmes mois comptent '
                          'DEUX FOIS dans le revenu de la plateforme. '
                          'Suspendez ou clôturez la précédente avant '
                          'd''activer celle-ci.', v_autre);
  END IF;

  RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS trg_licence_active_sans_chevauchement
  ON public.tutelle_licences;
CREATE TRIGGER trg_licence_active_sans_chevauchement
  BEFORE INSERT OR UPDATE OF statut, date_debut, date_fin, group_id
  ON public.tutelle_licences
  FOR EACH ROW EXECUTE FUNCTION public.fn_licence_active_sans_chevauchement();

-- ── 4. Le geste : une transition, un motif, une trace ──────────────────────
CREATE OR REPLACE FUNCTION public.licence_changer_statut(
  p_licence_id uuid,
  p_statut     text,
  p_motif      text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  l        public.tutelle_licences%ROWTYPE;
  v_cible  licence_statut;
  v_motif  text;
BEGIN
  -- Décider du sort d'un marché national est un geste de la plateforme.
  IF NOT is_super_admin() THEN
    RAISE EXCEPTION 'Acces refuse'
      USING ERRCODE = '42501',
            HINT = 'Seule E-PILOTE Congo décide du statut d''une licence de '
                   'tutelle. Un ministère la consulte, il ne la modifie pas.';
  END IF;

  SELECT * INTO l FROM public.tutelle_licences WHERE id = p_licence_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Licence introuvable' USING ERRCODE = 'P0002';
  END IF;

  BEGIN
    v_cible := p_statut::licence_statut;
  EXCEPTION WHEN others THEN
    RAISE EXCEPTION 'Statut inconnu : %', p_statut USING ERRCODE = '22P02';
  END;

  IF v_cible = l.statut THEN
    RETURN jsonb_build_object('success', true, 'inchange', true,
                              'statut', l.statut::text);
  END IF;

  -- ── Un marché résilié ne revient pas ────────────────────────────────────
  IF l.statut = 'resiliee'::licence_statut THEN
    RAISE EXCEPTION 'Une licence resiliee ne se reactive pas'
      USING ERRCODE = '23514',
            HINT = 'La résiliation est définitive : elle clôt le marché. '
                   'Pour reprendre la relation, enregistrez une NOUVELLE '
                   'licence — l''historique de celle-ci doit rester lisible.';
  END IF;

  -- ── Le motif n'est pas optionnel quand on arrête quelque chose ──────────
  v_motif := NULLIF(btrim(COALESCE(p_motif, '')), '');
  IF v_cible IN ('suspendue'::licence_statut, 'resiliee'::licence_statut)
     AND v_motif IS NULL THEN
    RAISE EXCEPTION 'Motif obligatoire'
      USING ERRCODE = '23514',
            HINT = 'Suspendre ou résilier un marché public sans écrire '
                   'pourquoi, c''est une décision qu''on ne peut ni justifier '
                   'ni contester trois mois plus tard.';
  END IF;

  -- ── On n'active pas un marché déjà terminé ──────────────────────────────
  IF v_cible = 'active'::licence_statut AND l.date_fin < CURRENT_DATE THEN
    RAISE EXCEPTION 'Le terme de cette licence est deja passe'
      USING ERRCODE = '23514',
            HINT = format('Elle s''achevait le %s. Prolongez d''abord sa date '
                          'de fin par avenant, sinon elle repasserait « échue » '
                          'le jour même.', to_char(l.date_fin, 'DD/MM/YYYY'));
  END IF;

  UPDATE public.tutelle_licences
     SET statut            = v_cible,
         motif_statut      = v_motif,
         statut_change_le  = now(),
         statut_change_par = auth.uid(),
         updated_at        = now()
   WHERE id = p_licence_id;

  -- ⚠️ AUCUNE écriture sur school_groups ici, et il ne faut jamais en ajouter.
  -- Le statut d'un marché ne commande aucun accès (0160 C4, 0183).
  RETURN jsonb_build_object(
    'success', true,
    'statut', v_cible::text,
    'precedent', l.statut::text,
    'motif', v_motif);
END;
$fn$;

COMMENT ON FUNCTION public.licence_changer_statut(uuid, text, text) IS
  'Transition de statut d''une licence de tutelle, reservee au super_admin. '
  'Exige un motif pour suspendre ou resilier, refuse de ressusciter un marche '
  'resilie et d''activer un marche dont le terme est passe. N''OUVRE NI NE '
  'FERME AUCUN ACCES : une licence suspendue ne coupe pas un ministere.';

REVOKE ALL ON FUNCTION public.licence_changer_statut(uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.licence_changer_statut(uuid, text, text)
  TO authenticated;

-- ── 5. Le ministère lit le motif de sa propre suspension ───────────────────
--  La politique de lecture de 0160 porte sur la ligne entière : les trois
--  colonnes ajoutées en font partie. Rien à rouvrir — on le note pour que
--  personne ne croie qu'il manque une politique.

COMMIT;
