-- ════════════════════════════════════════════════════════════════════════════
--  0084 — LE MOTIF DE DÉPART REMONTE JUSQU'À L'ÉCRAN
--
--  `get_group_users` est le seul chemin par lequel l'espace groupe voit ses
--  agents (l'email vit dans `auth.users`, hors de portée de PostgREST). Sans
--  ces deux colonnes, la migration 0083 aurait écrit un motif que personne
--  n'aurait jamais lu.
--
--  ⚠️ La liste de colonnes est un CONTRAT avec `AdminUser.fromMap`. Elle est
--  reconstruite ici à l'identique, plus `departure_motif` et `departure_date` :
--  un `RETURNS TABLE` ne s'étend pas, il se remplace.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

DROP FUNCTION IF EXISTS get_group_users(uuid);

CREATE FUNCTION get_group_users(p_group_id uuid)
RETURNS TABLE(
  id uuid, email text, role text, first_name text, last_name text, phone text,
  employee_number text, is_active boolean, school_id uuid, school_name text,
  access_profile_id uuid, access_profile_name text,
  last_login timestamptz, created_at timestamptz,
  gender text, date_of_birth date, address text, birth_place text,
  employment_status text, grade text, echelon text, category text,
  speciality text, hire_date date,
  departure_motif text, departure_date date
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'auth', 'pg_temp'
AS $$
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
           p.departure_motif, p.departure_date
    FROM   public.profiles p
    JOIN   auth.users u                   ON u.id  = p.id
    LEFT   JOIN public.schools s          ON s.id  = p.school_id
    LEFT   JOIN public.access_profiles ap ON ap.id = p.access_profile_id
    WHERE  p.group_id = p_group_id
      AND  p.role NOT IN ('super_admin', 'admin_groupe')
    ORDER  BY p.created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION get_group_users(uuid) TO authenticated;

COMMIT;
