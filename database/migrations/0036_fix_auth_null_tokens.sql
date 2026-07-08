-- 0036_fix_auth_null_tokens.sql
-- ─────────────────────────────────────────────────────────────────────────────
-- BUG : les comptes créés par create_admin_user / create_school_user avaient des
-- colonnes token à NULL dans auth.users (confirmation_token, recovery_token,
-- email_change, email_change_token_new, …). GoTrue les scanne en `string` (pas
-- sql.NullString) → au login : 500 "Database error querying schema", que l'app
-- Flutter reclasse en AuthRetryableFetchException → message "Pas de connexion
-- internet". 106 comptes bloqués (dont l'admin_groupe paul@epilote.cg).
--
-- Ce fichier : (1) répare les lignes existantes, (2) corrige les 3 fonctions de
-- création pour insérer '' au lieu de laisser NULL.
-- ─────────────────────────────────────────────────────────────────────────────

-- (1) ── Réparation des données existantes ──────────────────────────────────
update auth.users set
  confirmation_token         = coalesce(confirmation_token, ''),
  recovery_token             = coalesce(recovery_token, ''),
  email_change               = coalesce(email_change, ''),
  email_change_token_new     = coalesce(email_change_token_new, ''),
  email_change_token_current = coalesce(email_change_token_current, ''),
  phone_change               = coalesce(phone_change, ''),
  phone_change_token         = coalesce(phone_change_token, ''),
  reauthentication_token     = coalesce(reauthentication_token, '')
where confirmation_token is null
   or recovery_token is null
   or email_change is null
   or email_change_token_new is null
   or email_change_token_current is null
   or phone_change is null
   or phone_change_token is null
   or reauthentication_token is null;

-- (2) ── Correction de la source : create_admin_user (8-arg, la seule qui INSERT ;
--        l'overload 7-arg délègue à celle-ci → inchangé) ──────────────────────
create or replace function public.create_admin_user(
  p_email text, p_password text, p_first_name text, p_last_name text,
  p_role user_role, p_group_id uuid default null, p_phone text default null,
  p_avatar_url text default null
) returns uuid
  language plpgsql security definer
  set search_path to 'public', 'auth', 'extensions', 'pg_temp'
as $function$
declare
  new_id uuid;
begin
  if not is_super_admin() then
    raise exception 'Permission refusée : super_admin requis';
  end if;
  if p_role not in ('super_admin', 'admin_groupe') then
    raise exception 'Rôle invalide : super_admin ou admin_groupe attendu';
  end if;
  if p_role = 'admin_groupe' and p_group_id is null then
    raise exception 'Un groupe scolaire est requis pour le rôle admin_groupe';
  end if;
  if exists (select 1 from auth.users where email = p_email) then
    raise exception 'Cet email est déjà utilisé';
  end if;

  new_id := gen_random_uuid();

  insert into auth.users (
    id, instance_id, email, encrypted_password, email_confirmed_at,
    role, aud, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data, is_super_admin,
    confirmation_token, recovery_token, email_change,
    email_change_token_new, email_change_token_current,
    phone_change, phone_change_token, reauthentication_token
  ) values (
    new_id,
    '00000000-0000-0000-0000-000000000000',
    p_email,
    crypt(p_password, gen_salt('bf')),
    now(),
    'authenticated', 'authenticated',
    now(), now(),
    jsonb_build_object('provider','email','providers',array['email']),
    jsonb_build_object('first_name',p_first_name,'last_name',p_last_name,'role',p_role::text),
    false,
    '', '', '', '', '', '', '', ''
  );

  insert into auth.identities (
    provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at
  ) values (
    new_id::text, new_id,
    jsonb_build_object('sub', new_id::text, 'email', p_email, 'email_verified', true, 'phone_verified', false),
    'email', now(), now(), now()
  );

  update profiles set
    first_name = p_first_name,
    last_name  = p_last_name,
    phone      = p_phone,
    group_id   = p_group_id,
    role       = p_role,
    avatar_url = p_avatar_url,
    updated_at = now()
  where id = new_id;

  return new_id;
end;
$function$;

-- (2b) ── create_school_user (9 args) ────────────────────────────────────────
create or replace function public.create_school_user(
  p_email text, p_password text, p_first_name text, p_last_name text,
  p_school_id uuid, p_role user_role, p_access_profile_id uuid default null,
  p_phone text default null, p_employee_number text default null
) returns uuid
  language plpgsql security definer
  set search_path to 'public', 'auth', 'extensions', 'pg_temp'
as $function$
declare
  new_id         uuid;
  v_school_group uuid;
begin
  if not (is_super_admin() or is_admin_groupe()) then
    raise exception 'Permission refusée : administrateur requis';
  end if;
  if p_role in ('super_admin', 'admin_groupe') then
    raise exception 'Rôle invalide pour un compte d''école';
  end if;
  select group_id into v_school_group from schools where id = p_school_id;
  if v_school_group is null then
    raise exception 'École introuvable';
  end if;
  if not is_super_admin() and v_school_group <> auth_group_id() then
    raise exception 'Permission refusée : cette école n''appartient pas à votre groupe';
  end if;
  if p_access_profile_id is not null
     and not exists (select 1 from access_profiles where id = p_access_profile_id and group_id = v_school_group) then
    raise exception 'Profil d''accès invalide pour ce groupe';
  end if;
  if exists (select 1 from auth.users where email = p_email) then
    raise exception 'Cet email est déjà utilisé';
  end if;

  new_id := gen_random_uuid();

  insert into auth.users (
    id, instance_id, email, encrypted_password, email_confirmed_at,
    role, aud, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data, is_super_admin,
    confirmation_token, recovery_token, email_change,
    email_change_token_new, email_change_token_current,
    phone_change, phone_change_token, reauthentication_token
  ) values (
    new_id, '00000000-0000-0000-0000-000000000000', p_email,
    crypt(p_password, gen_salt('bf')), now(),
    'authenticated', 'authenticated', now(), now(),
    jsonb_build_object('provider','email','providers',array['email']),
    jsonb_build_object('first_name',p_first_name,'last_name',p_last_name,'role',p_role::text),
    false, '', '', '', '', '', '', '', ''
  );

  insert into auth.identities (
    provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at
  ) values (
    new_id::text, new_id,
    jsonb_build_object('sub', new_id::text, 'email', p_email, 'email_verified', true, 'phone_verified', false),
    'email', now(), now(), now()
  );

  update profiles set
    first_name = p_first_name, last_name = p_last_name, phone = p_phone,
    group_id = v_school_group, school_id = p_school_id, role = p_role,
    access_profile_id = p_access_profile_id, employee_number = p_employee_number,
    updated_at = now()
  where id = new_id;

  return new_id;
end;
$function$;

-- (2c) ── create_school_user (13 args) ───────────────────────────────────────
create or replace function public.create_school_user(
  p_email text, p_password text, p_first_name text, p_last_name text,
  p_school_id uuid, p_role user_role, p_access_profile_id uuid default null,
  p_phone text default null, p_employee_number text default null,
  p_gender text default null, p_date_of_birth date default null,
  p_address text default null, p_birth_place text default null
) returns uuid
  language plpgsql security definer
  set search_path to 'public', 'auth', 'extensions', 'pg_temp'
as $function$
declare
  new_id         uuid;
  v_school_group uuid;
begin
  if not (is_super_admin() or is_admin_groupe()) then
    raise exception 'Permission refusée : administrateur requis';
  end if;
  if p_role in ('super_admin', 'admin_groupe') then
    raise exception 'Rôle invalide pour un compte d''école';
  end if;
  select group_id into v_school_group from schools where id = p_school_id;
  if v_school_group is null then
    raise exception 'École introuvable';
  end if;
  if not is_super_admin() and v_school_group <> auth_group_id() then
    raise exception 'Permission refusée : cette école n''appartient pas à votre groupe';
  end if;
  if p_access_profile_id is not null
     and not exists (select 1 from access_profiles where id = p_access_profile_id and group_id = v_school_group) then
    raise exception 'Profil d''accès invalide pour ce groupe';
  end if;
  if exists (select 1 from auth.users where email = p_email) then
    raise exception 'Cet email est déjà utilisé';
  end if;

  new_id := gen_random_uuid();

  insert into auth.users (
    id, instance_id, email, encrypted_password, email_confirmed_at,
    role, aud, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data, is_super_admin,
    confirmation_token, recovery_token, email_change,
    email_change_token_new, email_change_token_current,
    phone_change, phone_change_token, reauthentication_token
  ) values (
    new_id, '00000000-0000-0000-0000-000000000000', p_email,
    crypt(p_password, gen_salt('bf')), now(),
    'authenticated', 'authenticated', now(), now(),
    jsonb_build_object('provider','email','providers',array['email']),
    jsonb_build_object('first_name',p_first_name,'last_name',p_last_name,'role',p_role::text),
    false, '', '', '', '', '', '', '', ''
  );

  insert into auth.identities (
    provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at
  ) values (
    new_id::text, new_id,
    jsonb_build_object('sub', new_id::text, 'email', p_email, 'email_verified', true, 'phone_verified', false),
    'email', now(), now(), now()
  );

  update profiles set
    first_name = p_first_name, last_name = p_last_name, phone = p_phone,
    group_id = v_school_group, school_id = p_school_id, role = p_role,
    access_profile_id = p_access_profile_id, employee_number = p_employee_number,
    gender = p_gender, date_of_birth = p_date_of_birth, address = p_address,
    birth_place = p_birth_place, updated_at = now()
  where id = new_id;

  return new_id;
end;
$function$;
