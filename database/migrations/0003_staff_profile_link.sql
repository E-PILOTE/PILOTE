-- 0003_staff_profile_link.sql
-- Lien staff_members → profiles, nécessaire au périmètre data_scope = 'own_classes'
-- (résoudre « quel staff_member est l'utilisateur connecté » → ses teacher_subjects → ses classes).
-- Sans ce lien, own_classes retourne 0 classe (comportement sûr).
--
-- À appliquer via le pooler Supavisor (aws-1-eu-central-2:5432) :
--   PGPASSWORD=... psql -h aws-1-eu-central-2.pooler.supabase.com -p 5432 \
--     -U postgres.wqpdamlnrwgozfvzjjpo -d postgres -f 0003_staff_profile_link.sql
-- ⚠️ Puis ajouter `profile_id` au stream staff_members des sync-rules (SELECT sm.* le couvre)
--    et REDÉPLOYER via le dashboard PowerSync Cloud.

begin;

alter table public.staff_members
  add column if not exists profile_id uuid references public.profiles(id) on delete set null;

create index if not exists idx_staff_members_profile_id
  on public.staff_members(profile_id);

commit;
