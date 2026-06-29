-- 0024_get_group_users_rh.sql
-- La RPC get_group_users alimente le formulaire utilisateur admin_groupe. On y
-- ajoute le volet carrière RH (migration 0023) pour que l'admin renseigne
-- statut/grade/échelon/catégorie/spécialité/prise de service À LA SOURCE — ces
-- champs descendent ensuite dans le dossier RH offline de l'école.
-- Changement ADDITIF : 6 colonnes en fin de TABLE (aucune existante retirée).
-- DROP requis car la signature de retour (OUT params) change.

DROP FUNCTION IF EXISTS public.get_group_users(uuid);

CREATE OR REPLACE FUNCTION public.get_group_users(p_group_id uuid)
 RETURNS TABLE(
   id uuid, email text, role text, first_name text, last_name text, phone text,
   employee_number text, is_active boolean, school_id uuid, school_name text,
   access_profile_id uuid, access_profile_name text,
   last_login timestamp with time zone, created_at timestamp with time zone,
   gender text, date_of_birth date, address text, birth_place text,
   employment_status text, grade text, echelon text, category text,
   speciality text, hire_date date)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
begin
  if not (is_super_admin() or (is_admin_groupe() and p_group_id = auth_group_id())) then
    raise exception 'Accès refusé : administrateur du groupe requis';
  end if;

  return query
    select p.id,
           u.email::text,
           p.role::text,
           p.first_name::text,
           p.last_name::text,
           p.phone::text,
           p.employee_number::text,
           p.is_active,
           p.school_id,
           s.name::text,
           p.access_profile_id,
           ap.name::text,
           p.last_login,
           p.created_at,
           p.gender::text,
           p.date_of_birth,
           p.address::text,
           p.birth_place::text,
           p.employment_status::text,
           p.grade::text,
           p.echelon::text,
           p.category::text,
           p.speciality::text,
           p.hire_date
    from public.profiles p
    join auth.users u                   on u.id  = p.id
    left join public.schools s          on s.id  = p.school_id
    left join public.access_profiles ap on ap.id = p.access_profile_id
    where p.group_id = p_group_id
      and p.role not in ('super_admin', 'admin_groupe')
    order by p.created_at desc;
end;
$function$;
