-- ════════════════════════════════════════════════════════════════════════════
--  0158 — L'AGRÉMENT SE SAISIT SUR LE GROUPE ; LA TUTELLE LIT SON RÉSEAU
--
--  ════════════════════════════════════════════════════════════════════════
--  PARTIE 1 — L'AGRÉMENT EST UNE MENTION, PAS UNE PROCÉDURE
--  ════════════════════════════════════════════════════════════════════════
--
--  ⚠️ CE QUE CETTE PLATEFORME NE FAIT PAS. Elle ne DÉLIVRE aucun agrément, ne
--  l'instruit pas, ne le valide pas, ne l'expire pas. L'agrément est accordé
--  par la commission du ministère, hors de tout logiciel. Ici on ENREGISTRE
--  une mention administrative — comme un numéro SIRET sur une facture.
--
--  Il n'y a donc NI workflow, NI statut calculé, NI blocage. Trois colonnes de
--  saisie, et rien de plus. Toute règle qui s'appuierait dessus pour refuser
--  quelque chose à une école serait une règle inventée par nous.
--
--  ── À QUOI ELLES SERVENT, HONNÊTEMENT ─────────────────────────────────────
--   1. IMPRIMER. Un établissement privé porte son numéro d'agrément sur ses
--      attestations et ses bulletins. Sans le champ, l'école le tape à la main
--      dans un pied de page, ou l'oublie.
--   2. COMPTER. « Combien d'écoles privées de ma tutelle ont déclaré un
--      agrément ? » est la première question d'un ministère devant un réseau
--      privé.
--   Rien d'autre pour l'instant. Et c'est peu — le champ n'a de valeur que le
--   jour où quelqu'un le remplit.
--
--  ── AU GROUPE, ET L'ÉCOLE EN HÉRITE ───────────────────────────────────────
--  Décision du fondateur, et elle est cohérente avec le reste : c'est déjà le
--  traitement de `group_type` (0060) et de `tutelle` (0153). Un groupe privé
--  congolais est une personne morale unique ; c'est elle qui est agréée.
--
--  ⚠️ L'héritage est un DÉCLENCHEUR, pas une contrainte. Si un groupe se
--  révèle porter des agréments distincts par établissement (deux sites, deux
--  dossiers), la colonne existe sur `schools` et il suffira de cesser de la
--  réécrire. Aucune migration de données ne sera nécessaire.
--
--  ════════════════════════════════════════════════════════════════════════
--  PARTIE 2 — CE QUE LE MINISTÈRE VOIT DE SON RÉSEAU
--  ════════════════════════════════════════════════════════════════════════
--
--  Un ministère porte DEUX casquettes que le modèle confondait :
--   • EXPLOITANT — il possède ses écoles (relation `schools.group_id`) ;
--   • TUTELLE    — il supervise TOUTES les écoles de son ministère, y compris
--                  celles qu'il ne possède pas (relation `schools.tutelle`).
--
--  Fait mesuré : le MEPSA ne voit aujourd'hui que 14 des 25 écoles placées
--  sous sa tutelle. Onze lui échappent — quatre publiques dans d'autres
--  groupes, sept privées.
--
--  ── POURQUOI DES RPC ET PAS UN ÉLARGISSEMENT DES POLITIQUES ───────────────
--  Ouvrir le SELECT de vingt tables à « ou si je suis le ministère de cette
--  tutelle » multiplierait par vingt les occasions de se tromper, et une
--  erreur là ouvre des données d'élèves. Une RPC `SECURITY DEFINER` décide en
--  UN endroit, lisible, ce qui sort — et ce qui ne sort pas.
--
--  ── ⚠️ LA LIGNE QUI NE DOIT PAS BOUGER ────────────────────────────────────
--  ÉTABLISSEMENTS : tout. Identité, implantation, offre, agrément, effectifs.
--  PERSONNES      : des AGRÉGATS. Aucune de ces fonctions ne rend le nom d'un
--                   élève, ni une note, ni une absence, ni un paiement.
--
--  Une seule exception nominative, et elle est administrative : le CHEF
--  D'ÉTABLISSEMENT. C'est l'interlocuteur officiel de la tutelle, sa fonction
--  est publique, et un ministère qui ne sait pas qui dirige une école de son
--  réseau ne peut ni la convoquer ni lui écrire.
--
--  Ce que les RPC NE rendent PAS non plus, et volontairement : le plan
--  d'abonnement, le statut de paiement, le tarif. La relation commerciale
--  entre un groupe privé et E-PILOTE ne regarde pas son ministère.
--
--  ── ORDRE : AVANT LE BUILD. Additive. ─────────────────────────────────────
-- ════════════════════════════════════════════════════════════════════════════

-- ── 1. Le type d'agrément ───────────────────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'agrement_type') THEN
    CREATE TYPE public.agrement_type AS ENUM ('provisoire', 'definitif');
  END IF;
END $$;

-- ── 2. Les trois colonnes, sur le groupe puis sur l'école ───────────────────
ALTER TABLE public.school_groups
  ADD COLUMN IF NOT EXISTS agrement_numero text,
  ADD COLUMN IF NOT EXISTS agrement_type   public.agrement_type,
  ADD COLUMN IF NOT EXISTS agrement_date   date;

COMMENT ON COLUMN public.school_groups.agrement_numero IS
  'Numero d''agrement delivre par la commission du ministere de tutelle. SAISI, jamais calcule : la plateforme n''instruit ni ne valide aucun agrement.';

ALTER TABLE public.schools
  ADD COLUMN IF NOT EXISTS agrement_numero text,
  ADD COLUMN IF NOT EXISTS agrement_type   public.agrement_type,
  ADD COLUMN IF NOT EXISTS agrement_date   date;

COMMENT ON COLUMN public.schools.agrement_numero IS
  'COPIE denormalisee de school_groups.agrement_numero, tenue par declencheur. Ne pas ecrire ici depuis l''application.';

-- ── 3. L'héritage, exactement comme la tutelle ──────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_school_herite_agrement()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE g record;
BEGIN
  SELECT agrement_numero, agrement_type, agrement_date INTO g
    FROM public.school_groups WHERE id = NEW.group_id;
  -- ⚠️ On n'écrase PAS par NULL : un groupe qui n'a pas encore saisi son
  -- agrément ne doit pas effacer celui qu'une école porterait déjà.
  IF g.agrement_numero IS NOT NULL THEN
    NEW.agrement_numero := g.agrement_numero;
    NEW.agrement_type   := g.agrement_type;
    NEW.agrement_date   := g.agrement_date;
  END IF;
  RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS trg_school_herite_agrement ON public.schools;
CREATE TRIGGER trg_school_herite_agrement
  BEFORE INSERT OR UPDATE OF group_id ON public.schools
  FOR EACH ROW EXECUTE FUNCTION public.fn_school_herite_agrement();

CREATE OR REPLACE FUNCTION public.fn_groupe_propage_agrement()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NEW.agrement_numero IS NOT NULL
     AND (OLD.agrement_numero IS DISTINCT FROM NEW.agrement_numero
          OR OLD.agrement_type IS DISTINCT FROM NEW.agrement_type
          OR OLD.agrement_date IS DISTINCT FROM NEW.agrement_date) THEN
    UPDATE public.schools
       SET agrement_numero = NEW.agrement_numero,
           agrement_type   = NEW.agrement_type,
           agrement_date   = NEW.agrement_date
     WHERE group_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS trg_groupe_propage_agrement ON public.school_groups;
CREATE TRIGGER trg_groupe_propage_agrement
  AFTER UPDATE OF agrement_numero, agrement_type, agrement_date
  ON public.school_groups
  FOR EACH ROW EXECUTE FUNCTION public.fn_groupe_propage_agrement();

-- ── 4. Qui a le droit de superviser ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.auth_peut_superviser()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
  SELECT public.is_super_admin()
      OR (public.is_admin_groupe() AND public.auth_group_administre_referentiel())
$fn$;

COMMENT ON FUNCTION public.auth_peut_superviser() IS
  'Porte d''entree des RPC de tutelle. Le super_admin voit tout ; un ministere voit SA tutelle ; tout autre groupe ne voit rien.';

-- ── 5. Les groupes du réseau ────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.tutelle_groupes()
RETURNS TABLE (
  group_id uuid, nom text, secteur text, departement text,
  email text, telephone text, adresse text, logo_url text,
  annee_creation int, actif boolean, cree_le timestamptz,
  agrement_numero text, agrement_type text, agrement_date date,
  nb_ecoles bigint, nb_ecoles_actives bigint,
  nb_eleves bigint, nb_filles bigint, nb_personnel bigint, nb_classes bigint,
  nb_ecoles_agreees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE v_tutelle public.tutelle_enum;
BEGIN
  IF NOT public.auth_peut_superviser() THEN
    RAISE EXCEPTION 'Reserve a la tutelle' USING ERRCODE = '42501';
  END IF;
  -- Le super_admin n'a pas de groupe, donc pas de tutelle : il voit tout.
  v_tutelle := CASE WHEN public.is_super_admin()
                    THEN NULL ELSE public.auth_group_tutelle() END;

  RETURN QUERY
  -- ⚠️ UN CAST SUR CHAQUE COLONNE, TEXTUELLE COMME NUMÉRIQUE. `RETURNS TABLE`
  -- exige le type EXACT : `varchar(200)` n'est pas `text`, `smallint` n'est pas
  -- `integer`. Et PL/pgSQL ne le vérifie qu'à L'EXÉCUTION — la fonction se crée
  -- sans un mot, puis échoue en 42804 au premier appel. Deux passes ont été
  -- nécessaires ici : ne pas retirer ces casts en les croyant décoratifs.
  SELECT sg.id, sg.name::text, sg.group_type::text, sg.department::text,
         sg.admin_email::text, sg.phone::text, sg.address::text, sg.logo_url::text,
         sg.founded_year::int, sg.is_active, sg.created_at,
         sg.agrement_numero::text, sg.agrement_type::text, sg.agrement_date,
         count(s.id),
         count(s.id) FILTER (WHERE s.is_active),
         coalesce(sum(e.n_eleves), 0)::bigint,
         coalesce(sum(e.n_filles), 0)::bigint,
         coalesce(sum(e.n_personnel), 0)::bigint,
         coalesce(sum(e.n_classes), 0)::bigint,
         count(s.id) FILTER (WHERE s.agrement_numero IS NOT NULL)
    FROM public.school_groups sg
    JOIN public.schools s ON s.group_id = sg.id
    LEFT JOIN LATERAL (
      SELECT
        (SELECT count(*) FROM public.students st
          WHERE st.school_id = s.id AND st.is_active) AS n_eleves,
        -- `gender` est un ENUM {M,F} : le comparer en texte casserait au
        -- premier appel. Vérifié en base avant d'être écrit.
        (SELECT count(*) FROM public.students st
          WHERE st.school_id = s.id AND st.is_active AND st.gender = 'F')
          AS n_filles,
        (SELECT count(*) FROM public.profiles p
          WHERE p.school_id = s.id AND p.is_active
            AND p.role NOT IN ('super_admin', 'parent', 'eleve')) AS n_personnel,
        (SELECT count(*) FROM public.classes c
          WHERE c.school_id = s.id AND c.is_active) AS n_classes
    ) e ON true
   WHERE (v_tutelle IS NULL OR s.tutelle = v_tutelle)
   GROUP BY sg.id
   ORDER BY sg.name;
END;
$fn$;

COMMENT ON FUNCTION public.tutelle_groupes() IS
  'Un groupe par ligne, pour le reseau de la tutelle. AUCUNE donnee nominative d''eleve. AUCUNE donnee d''abonnement : ce qu''un groupe prive paie a E-PILOTE ne regarde pas son ministere.';

-- ── 6. Les écoles du réseau ─────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.tutelle_ecoles(p_group_id uuid DEFAULT NULL)
RETURNS TABLE (
  school_id uuid, group_id uuid, groupe_nom text,
  nom text, code text, secteur text,
  type_etablissement text, type_etablissement_court text,
  departement text, ville text, arrondissement text,
  latitude double precision, longitude double precision,
  capacite int, actif boolean, annee_creation int,
  telephone text, courriel text,
  chef_etablissement text,
  agrement_numero text, agrement_type text, agrement_date date,
  nb_eleves bigint, nb_filles bigint, nb_personnel bigint, nb_classes bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE v_tutelle public.tutelle_enum;
BEGIN
  IF NOT public.auth_peut_superviser() THEN
    RAISE EXCEPTION 'Reserve a la tutelle' USING ERRCODE = '42501';
  END IF;
  v_tutelle := CASE WHEN public.is_super_admin()
                    THEN NULL ELSE public.auth_group_tutelle() END;

  RETURN QUERY
  -- Voir l'avertissement ci-dessus : tout ce qui est textuel est casté.
  SELECT s.id, s.group_id, sg.name::text,
         s.name::text, s.school_code::text, s.school_type::text,
         it.name::text, it.short_name::text,
         s.department::text, s.city::text, s.arrondissement::text,
         s.latitude::double precision, s.longitude::double precision,
         s.capacity::int, s.is_active, s.founded_year::int,
         s.phone::text, s.email::text,
         -- ⚠️ SEULE donnée nominative de tout ce fichier : le chef
         -- d'établissement est l'interlocuteur officiel de la tutelle.
         nullif(trim(coalesce(d.first_name, '') || ' ' || coalesce(d.last_name, '')), '')::text,
         s.agrement_numero::text, s.agrement_type::text, s.agrement_date,
         (SELECT count(*) FROM public.students st
           WHERE st.school_id = s.id AND st.is_active),
         (SELECT count(*) FROM public.students st
           WHERE st.school_id = s.id AND st.is_active AND st.gender = 'F'),
         (SELECT count(*) FROM public.profiles p
           WHERE p.school_id = s.id AND p.is_active
             AND p.role NOT IN ('super_admin', 'parent', 'eleve')),
         (SELECT count(*) FROM public.classes c
           WHERE c.school_id = s.id AND c.is_active)
    FROM public.schools s
    JOIN public.school_groups sg ON sg.id = s.group_id
    LEFT JOIN public.institution_types it ON it.id = s.institution_type_id
    LEFT JOIN public.profiles d ON d.id = s.director_id
   WHERE (v_tutelle IS NULL OR s.tutelle = v_tutelle)
     AND (p_group_id IS NULL OR s.group_id = p_group_id)
   ORDER BY sg.name, s.name;
END;
$fn$;

COMMENT ON FUNCTION public.tutelle_ecoles(uuid) IS
  'Une ecole par ligne, pour le reseau de la tutelle. Effectifs AGREGES ; seule donnee nominative : le chef d''etablissement.';

REVOKE ALL ON FUNCTION public.tutelle_groupes() FROM public, anon;
REVOKE ALL ON FUNCTION public.tutelle_ecoles(uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.tutelle_groupes() TO authenticated;
GRANT EXECUTE ON FUNCTION public.tutelle_ecoles(uuid) TO authenticated;
