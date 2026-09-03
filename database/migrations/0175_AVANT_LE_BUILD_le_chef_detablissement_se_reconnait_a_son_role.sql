-- ════════════════════════════════════════════════════════════════════════════
--  0175 — LE CHEF D'ÉTABLISSEMENT SE RECONNAÎT À SON RÔLE
--
--  ── LE DÉFAUT ─────────────────────────────────────────────────────────────
--  `tutelle_ecoles` (0158) résout le chef d'établissement par
--  `schools.director_id`. Mesuré le 2026-09-03 : cette colonne est **NULL sur
--  la totalité des écoles** — les onze placées sous la tutelle du MEPSA hors
--  ministère comme les autres. Pourtant chacune a bien UN chef actif, rattaché
--  par `profiles.school_id` avec le rôle `directeur` ou `proviseur`.
--
--  Conséquence : la colonne « chef d'établissement » que 0158 justifie sur dix
--  lignes — « l'interlocuteur officiel de la tutelle », « un ministère qui
--  ignore qui dirige une école de son réseau ne peut ni la convoquer ni lui
--  écrire » — affichait « Non désigné » PARTOUT. La fiche d'établissement, la
--  liste du réseau, la fiche de groupe et les trois documents PDF portaient
--  tous la même mention vide. La donnée existait ; c'est la jointure qui
--  regardait au mauvais endroit.
--
--  ── ⚠️ LA DÉSIGNATION EXPLICITE PRIME QUAND ELLE EXISTE ──────────────────
--  On ne remplace pas `director_id` par le rôle : on le PRÉFÈRE quand il est
--  renseigné, et l'on retombe sur le rôle sinon. Le jour où un établissement
--  désigne formellement son chef — deux proviseurs, une intérimaire — cette
--  désignation doit l'emporter sur une déduction.
--
--  ⚠️ Et `is_active` est exigé : un chef parti reste dans `profiles`, il ne
--  doit pas continuer à figurer comme interlocuteur d'un ministère.
--
--  ── ⚠️ LA SIGNATURE NE BOUGE PAS ─────────────────────────────────────────
--  Même `RETURNS TABLE`, mêmes colonnes, même ordre. Seule la résolution du
--  chef change. Le client Dart (`TutelleEcole.fromRow`) n'a rien à modifier —
--  et c'est la condition pour qu'une correction de ce genre soit sûre.
--
--  ── ORDRE : AVANT LE BUILD. Aucune donnée touchée. ───────────────────────
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.tutelle_ecoles(p_group_id uuid DEFAULT NULL::uuid)
RETURNS TABLE (
  school_id uuid, group_id uuid, groupe_nom text,
  nom text, code text, secteur text,
  type_etablissement text, type_etablissement_court text,
  departement text, ville text, arrondissement text,
  latitude double precision, longitude double precision,
  capacite integer, actif boolean, annee_creation integer,
  telephone text, courriel text,
  chef_etablissement text,
  agrement_numero text, agrement_type text, agrement_date date,
  nb_eleves bigint, nb_filles bigint, nb_personnel bigint, nb_classes bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_tutelle public.tutelle_enum;
BEGIN
  IF NOT public.auth_peut_superviser() THEN
    RAISE EXCEPTION 'Reserve a la tutelle' USING ERRCODE = '42501';
  END IF;
  v_tutelle := CASE WHEN public.is_super_admin()
                    THEN NULL ELSE public.auth_group_tutelle() END;

  RETURN QUERY
  SELECT s.id, s.group_id, sg.name::text,
         s.name::text, s.school_code::text, s.school_type::text,
         it.name::text, it.short_name::text,
         s.department::text, s.city::text, s.arrondissement::text,
         s.latitude::double precision, s.longitude::double precision,
         s.capacity::int, s.is_active, s.founded_year::int,
         s.phone::text, s.email::text,
         d.chef,
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
    -- ⚠️ LE CHEF : désignation explicite d'abord, rôle ensuite.
    --
    -- `director_id` n'est tenu nulle part (0 école sur 37 au 2026-09-03) ;
    -- s'y fier seul vidait la colonne. Le rôle, lui, est renseigné partout.
    -- L'ordre de tri fait le reste : `p.id = s.director_id` en tête quand la
    -- désignation existe, sinon le plus ancien des chefs actifs de l'école.
    LEFT JOIN LATERAL (
      SELECT nullif(trim(coalesce(p.first_name, '') || ' ' ||
                         coalesce(p.last_name, '')), '')::text AS chef
        FROM public.profiles p
       WHERE p.is_active
         AND (p.id = s.director_id
              OR (p.school_id = s.id
                  AND p.role IN ('directeur', 'proviseur')))
       ORDER BY (p.id = s.director_id) DESC, p.created_at
       LIMIT 1
    ) d ON true
   WHERE (v_tutelle IS NULL OR s.tutelle = v_tutelle)
     AND (p_group_id IS NULL OR s.group_id = p_group_id)
   ORDER BY sg.name, s.name;
END;
$function$;

COMMENT ON FUNCTION public.tutelle_ecoles(uuid) IS
  'Une ecole par ligne, pour le reseau de la tutelle. Effectifs AGREGES ; seule donnee nominative : le chef d''etablissement, resolu par designation explicite (schools.director_id) puis, a defaut, par le ROLE directeur/proviseur rattache a l''ecole. La colonne director_id n''est tenue nulle part : s''y fier seul vidait la mention (0175).';
