-- ═══════════════════════════════════════════════════════════════════════════
--  0160 — LA LICENCE ANNUELLE DE TUTELLE, ET CE QUE COÛTE LA PLATEFORME
--
--  Deux sujets, une seule migration, parce qu'ils ne se comprennent que
--  ensemble : on ne fixe pas le prix d'une licence nationale sans savoir ce
--  que l'infrastructure coûte réellement chaque mois.
--
--  ── 1. `platform_costs` — CE QUE JE PAIE ─────────────────────────────────
--  Relevé 2026-08-31 : Supabase Pro 25 $/mois · PowerSync Cloud Pro 49 $/mois
--  (30 Go de synchro et 1 000 clients simultanés inclus, puis 1 $/Go et
--  30 $ par tranche de 1 000 clients).
--
--  ⚠️ LE MONTANT FAISANT FOI EST `montant_xaf` — ce que la banque a réellement
--  débité. `montant_origine` / `devise_origine` ne sont là que pour la mémoire.
--  Aucun taux de change n'est stocké et aucune conversion n'est calculée :
--  un taux figé en base devient faux le mois suivant et personne ne le voit.
--
--  ⚠️ Le poste qui surprendra : les CLIENTS SIMULTANÉS. Chaque appareil du
--  personnel qui a l'application ouverte en compte un. Une école à 8 postes
--  actifs, ce sont 8 clients ; 125 écoles saturent les 1 000 inclus. Le coût
--  ne suit donc PAS le nombre d'élèves, il suit le nombre d'appareils.
--
--  ⚠️ Et le plan gratuit n'est pas gratuit POUR NOUS : un groupe Découverte
--  consomme des clients simultanés et des Go synchronisés sans rien rapporter.
--  C'est le client le plus cher par franc encaissé — d'où le quota serré.
--
--  ── 2. `tutelle_licences` — CE QU'UN MINISTÈRE ACHÈTE ────────────────────
--  Un ministère paie DEUX choses distinctes, et les confondre est la faute à
--  ne pas commettre :
--    • ses PROPRES écoles      → abonnement ordinaire, grille du 0159 ;
--    • sa TUTELLE (voir et écrire à tout son réseau) → CETTE licence.
--  Si la licence couvrait aussi les écoles, plus aucun groupe privé ne paierait
--  jamais, et la plateforme deviendrait une société à un seul client — un
--  client qui change de ministre.
--
--  Le montant est LIBRE et modifiable à tout moment : un marché public se
--  négocie, se révise par avenant, et se règle en tranches. D'où
--  `montant_xaf` (dû), `avance_xaf` (avance de démarrage) et `montant_regle_xaf`
--  (encaissé) — trois nombres, pas un.
--
--  ⚠️ CETTE LICENCE NE COMMANDE RIEN. Elle n'ouvre ni ne ferme aucun accès :
--  c'est `school_groups.administre_referentiel_national` (migration 0155) qui
--  décide de la vue de tutelle. Une licence échue ne coupe donc pas un
--  ministère — on ne ferme pas l'État pour un mandat en retard, et de toute
--  façon un logiciel qui se venge d'un impayé perd le client ET le marché.
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

-- ── 1. Les coûts d'infrastructure ────────────────────────────────────────
DO $$ BEGIN
  CREATE TYPE public.cost_category AS ENUM
    ('base_de_donnees', 'synchronisation', 'stockage', 'domaine',
     'messagerie', 'boutique', 'autre');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS public.platform_costs (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  label           varchar(120)  NOT NULL,
  fournisseur     varchar(120),
  categorie       cost_category NOT NULL DEFAULT 'autre',
  montant_xaf     integer       NOT NULL DEFAULT 0,
  periodicite     billing_period NOT NULL DEFAULT 'mensuel',
  montant_origine numeric(12,2),
  devise_origine  varchar(8),
  is_active       boolean       NOT NULL DEFAULT true,
  started_on      date          NOT NULL DEFAULT CURRENT_DATE,
  ended_on        date,
  notes           text,
  created_by      uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at      timestamptz   NOT NULL DEFAULT NOW(),
  updated_at      timestamptz   NOT NULL DEFAULT NOW(),
  CONSTRAINT platform_costs_montant_positif CHECK (montant_xaf >= 0),
  CONSTRAINT platform_costs_dates_coherentes
    CHECK (ended_on IS NULL OR ended_on >= started_on)
);

CREATE INDEX IF NOT EXISTS idx_platform_costs_actifs
  ON public.platform_costs (is_active, categorie);

COMMENT ON TABLE public.platform_costs IS
  'Couts d''exploitation de la plateforme. Donnee de fondateur : super_admin '
  'UNIQUEMENT, jamais visible d''un groupe scolaire.';
COMMENT ON COLUMN public.platform_costs.montant_xaf IS
  'Ce que la banque debite reellement, dans la periodicite. Fait foi.';

ALTER TABLE public.platform_costs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS platform_costs_super_admin ON public.platform_costs;
CREATE POLICY platform_costs_super_admin ON public.platform_costs
  FOR ALL TO authenticated
  USING (public.is_super_admin())
  WITH CHECK (public.is_super_admin());

DROP TRIGGER IF EXISTS trg_platform_costs_updated ON public.platform_costs;
CREATE TRIGGER trg_platform_costs_updated
  BEFORE UPDATE ON public.platform_costs
  FOR EACH ROW EXECUTE FUNCTION public.fn_update_updated_at();

-- Coût mensuel total, toutes périodicités ramenées au mois.
-- ⚠️ On ne SOMME jamais des montants de périodicités différentes sans les
-- ramener au mois : une licence annuelle et un abonnement mensuel additionnés
-- bruts donnent un chiffre qui ne veut rien dire.
CREATE OR REPLACE FUNCTION public.platform_monthly_cost_xaf()
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp AS $fn$
  SELECT COALESCE(SUM(
    (pc.montant_xaf::numeric / GREATEST(billing_period_months(pc.periodicite), 1))
  )::integer, 0)
  FROM platform_costs pc
  WHERE pc.is_active
    AND pc.started_on <= CURRENT_DATE
    AND (pc.ended_on IS NULL OR pc.ended_on >= CURRENT_DATE)
    AND is_super_admin();
$fn$;

-- ── 2. La licence de tutelle ─────────────────────────────────────────────
DO $$ BEGIN
  CREATE TYPE public.licence_statut AS ENUM
    ('brouillon', 'active', 'echue', 'resiliee');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS public.tutelle_licences (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id          uuid NOT NULL REFERENCES public.school_groups(id) ON DELETE CASCADE,
  tutelle           tutelle_enum NOT NULL,
  intitule          varchar(200) NOT NULL DEFAULT 'Licence annuelle de tutelle',
  date_debut        date NOT NULL,
  date_fin          date NOT NULL,
  montant_xaf       integer NOT NULL DEFAULT 0,
  avance_xaf        integer NOT NULL DEFAULT 0,
  montant_regle_xaf integer NOT NULL DEFAULT 0,
  statut            licence_statut NOT NULL DEFAULT 'brouillon',
  reference_marche  varchar(120),
  signataire        varchar(200),
  notes             text,
  created_by        uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at        timestamptz NOT NULL DEFAULT NOW(),
  updated_at        timestamptz NOT NULL DEFAULT NOW(),
  CONSTRAINT tutelle_licences_periode CHECK (date_fin > date_debut),
  CONSTRAINT tutelle_licences_montants CHECK (
    montant_xaf >= 0 AND avance_xaf >= 0 AND montant_regle_xaf >= 0
    AND avance_xaf <= montant_xaf)
);

CREATE INDEX IF NOT EXISTS idx_tutelle_licences_groupe
  ON public.tutelle_licences (group_id, date_fin DESC);

COMMENT ON TABLE public.tutelle_licences IS
  'Licence annuelle qu''un ministere achete pour SUPERVISER son reseau. '
  'Distincte de l''abonnement de ses propres ecoles. N''ouvre aucun acces : '
  'la vue de tutelle depend de school_groups.administre_referentiel_national.';
COMMENT ON COLUMN public.tutelle_licences.montant_regle_xaf IS
  'Encaisse a ce jour. Un marche public se regle en tranches ; le solde du '
  'est montant_xaf - montant_regle_xaf.';

ALTER TABLE public.tutelle_licences ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS tutelle_licences_super_admin ON public.tutelle_licences;
CREATE POLICY tutelle_licences_super_admin ON public.tutelle_licences
  FOR ALL TO authenticated
  USING (public.is_super_admin())
  WITH CHECK (public.is_super_admin());

-- Le ministère lit SON contrat — en lecture seule. Il l'a signé, il a le droit
-- de le relire ; il n'a pas celui d'en changer le montant.
DROP POLICY IF EXISTS tutelle_licences_lecture_groupe ON public.tutelle_licences;
CREATE POLICY tutelle_licences_lecture_groupe ON public.tutelle_licences
  FOR SELECT TO authenticated
  USING (public.is_admin_groupe() AND group_id = public.auth_group_id());

DROP TRIGGER IF EXISTS trg_tutelle_licences_updated ON public.tutelle_licences;
CREATE TRIGGER trg_tutelle_licences_updated
  BEFORE UPDATE ON public.tutelle_licences
  FOR EACH ROW EXECUTE FUNCTION public.fn_update_updated_at();

-- La tutelle est recopiée du groupe : la saisir à la main permettrait de créer
-- une licence MEPSA sur le groupe METP, et le contrat désignerait alors un
-- périmètre que la plateforme ne sert pas.
CREATE OR REPLACE FUNCTION public.fn_tutelle_licence_coherente()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $fn$
DECLARE v_tutelle tutelle_enum; v_supervise boolean; v_nom text;
BEGIN
  SELECT tutelle, administre_referentiel_national, name
    INTO v_tutelle, v_supervise, v_nom
    FROM school_groups WHERE id = NEW.group_id;

  IF v_tutelle IS NULL THEN
    RAISE EXCEPTION 'Le groupe % n''a pas de tutelle : une licence de tutelle '
      'n''a pas d''objet.', COALESCE(v_nom, '?') USING ERRCODE = '23514';
  END IF;

  IF NOT COALESCE(v_supervise, false) THEN
    RAISE EXCEPTION 'Le groupe % ne supervise aucun reseau '
      '(administre_referentiel_national = false) : lui vendre une licence de '
      'tutelle vendrait un acces qu''il n''a pas.', COALESCE(v_nom, '?')
      USING ERRCODE = '23514';
  END IF;

  NEW.tutelle := v_tutelle;
  RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS trg_tutelle_licence_coherente ON public.tutelle_licences;
CREATE TRIGGER trg_tutelle_licence_coherente
  BEFORE INSERT OR UPDATE OF group_id ON public.tutelle_licences
  FOR EACH ROW EXECUTE FUNCTION public.fn_tutelle_licence_coherente();

-- Deux licences ACTIVES qui se chevauchent sur le même groupe, ce sont deux
-- contrats pour la même période : on ne saurait plus lequel fait foi.
CREATE UNIQUE INDEX IF NOT EXISTS uq_tutelle_licence_active
  ON public.tutelle_licences (group_id, date_debut)
  WHERE statut = 'active';

COMMIT;

-- ═══════════════════════════════════════════════════════════════════════════
--  PARTIE 3 — LES DEUX COÛTS RÉELS, RELEVÉS LE 2026-08-31
--
--  Montants convertis à ~610 XAF/USD, ordre de grandeur ASSUMÉ : le XAF est
--  arrimé à l'euro (655,957), pas au dollar, donc le débit réel varie chaque
--  mois. Ces lignes sont un point de départ à corriger sur relevé bancaire —
--  d'où la note portée sur chacune.
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

INSERT INTO public.platform_costs
  (label, fournisseur, categorie, montant_xaf, periodicite,
   montant_origine, devise_origine, notes)
SELECT 'Supabase Pro', 'Supabase', 'base_de_donnees', 15250, 'mensuel',
       25.00, 'USD',
       'Socle 25 $/mois. Le calcul (compute), le disque et l''egress se '
       'facturent EN PLUS des l''echelle atteinte. A corriger sur releve.'
WHERE NOT EXISTS (SELECT 1 FROM public.platform_costs WHERE label = 'Supabase Pro');

INSERT INTO public.platform_costs
  (label, fournisseur, categorie, montant_xaf, periodicite,
   montant_origine, devise_origine, notes)
SELECT 'PowerSync Cloud Pro', 'PowerSync', 'synchronisation', 29890, 'mensuel',
       49.00, 'USD',
       'Socle 49 $/mois : 30 Go synchronises et 1 000 CLIENTS SIMULTANES '
       'inclus, puis 1 $/Go et 30 $ par tranche de 1 000 clients. Le poste '
       'qui decroche en premier est le nombre d''APPAREILS, pas d''eleves : '
       'a ~8 postes par ecole, 125 ecoles saturent l''inclus.'
WHERE NOT EXISTS (SELECT 1 FROM public.platform_costs WHERE label = 'PowerSync Cloud Pro');

COMMIT;
