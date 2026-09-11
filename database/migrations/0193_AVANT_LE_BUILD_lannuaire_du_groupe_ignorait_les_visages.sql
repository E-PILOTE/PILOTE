-- ════════════════════════════════════════════════════════════════════════════
--  L'ANNUAIRE DU GROUPE IGNORAIT LES VISAGES
--
--  ── CE QUI MANQUAIT (2026-09-05) ──────────────────────────────────────────
--  `get_group_users` est la SEULE porte par laquelle l'espace admin_groupe voit
--  son personnel : `profiles` n'a pas de colonne `email`, la liste passe donc
--  par cette fonction SECURITY DEFINER qui joint `auth.users`. Elle rendait
--  vingt-six colonnes — jusqu'au motif de départ et à l'échelon — mais PAS
--  `avatar_url`.
--
--  Conséquences, toutes silencieuses :
--    • la liste des utilisateurs affichait des initiales alors que la photo
--      existait en base ;
--    • le formulaire d'édition ne pouvait pas montrer la photo actuelle, donc
--      pas la remplacer ni la retirer ;
--    • et personne, dans cet espace, ne pouvait poser la photo d'un agent à sa
--      création — alors que `avatar_url` est lue par l'annuaire, la messagerie,
--      le fil d'annonces ET l'écran-verrou des postes partagés, où l'on choisit
--      son visage dans une grille avant de travailler.
--
--  ── POURQUOI UN DROP/CREATE ───────────────────────────────────────────────
--  Ajouter une colonne au TABLE de retour change la signature de retour :
--  PostgreSQL refuse un simple CREATE OR REPLACE. Le DROP est donc obligatoire,
--  et il est sûr ici — aucune vue, aucun déclencheur, aucune autre fonction ne
--  dépend de celle-ci ; seul le client Dart l'appelle.
--
--  ⚠️ La garde d'accès est reconduite À L'IDENTIQUE. C'est la ligne qui
--  empêche un administrateur de groupe de lire l'annuaire d'un autre client.
-- ════════════════════════════════════════════════════════════════════════════

DROP FUNCTION IF EXISTS public.get_group_users(uuid);

CREATE FUNCTION public.get_group_users(p_group_id uuid)
RETURNS TABLE(
  id uuid, email text, role text, first_name text, last_name text,
  phone text, employee_number text, is_active boolean,
  school_id uuid, school_name text,
  access_profile_id uuid, access_profile_name text,
  last_login timestamp with time zone, created_at timestamp with time zone,
  gender text, date_of_birth date, address text, birth_place text,
  employment_status text, grade text, echelon text, category text,
  speciality text, hire_date date,
  departure_motif text, departure_date date,
  avatar_url text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
BEGIN
  IF NOT (is_super_admin() OR (is_admin_groupe() AND p_group_id = auth_group_id())) THEN
    RAISE EXCEPTION 'Accès refusé : administrateur du groupe requis';
  END IF;

  RETURN QUERY
    SELECT p.id, u.email::text, p.role::text,
           p.first_name::text, p.last_name::text, p.phone::text,
           p.employee_number::text, p.is_active,
           p.school_id, s.name::text,
           p.access_profile_id, ap.name::text,
           p.last_login, p.created_at,
           p.gender::text, p.date_of_birth, p.address::text, p.birth_place::text,
           p.employment_status::text, p.grade::text, p.echelon::text,
           p.category::text, p.speciality::text, p.hire_date,
           p.departure_motif, p.departure_date,
           -- La nouveauté, et la seule : le visage de la personne.
           p.avatar_url::text
    FROM   public.profiles p
    JOIN   auth.users u                   ON u.id  = p.id
    LEFT   JOIN public.schools s          ON s.id  = p.school_id
    LEFT   JOIN public.access_profiles ap ON ap.id = p.access_profile_id
    WHERE  p.group_id = p_group_id
      AND  p.role NOT IN ('super_admin', 'admin_groupe')
    ORDER  BY p.created_at DESC;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_group_users(uuid) TO authenticated;
