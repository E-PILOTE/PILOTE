-- ════════════════════════════════════════════════════════════════════════════
--  ARCHIVES DES PUBLICATIONS DE LA DEC — socle
--
--  ── CE QUE LA PLATEFORME EST, ET N'EST PAS ─────────────────────────────────
--  Elle produit la LISTE DES CANDIDATS transmise à la DEC. Elle ne produit
--  AUCUN résultat : la DEC organise l'épreuve, proclame les admis et publie
--  ses documents. En retour, la DSIC reçoit ces publications — sur papier, et
--  en PDF sur les canaux officiels.
--
--  D'où le rôle qui reste, et qui n'est pas mince : GARDIENNE. Aujourd'hui une
--  publication vit dans une boîte mail et un tiroir ; dans cinq ans, à la
--  question « sur quelle base a-t-on dit que cet élève était admis ? », il n'y
--  a plus rien. On archive donc la PIÈCE, puis les CHIFFRES qu'elle porte.
--
--  ── DEUX FAMILLES DE CHIFFRES, JAMAIS FONDUES ──────────────────────────────
--   • OFFICIEL  : saisi depuis la publication de la DEC, adossé au document.
--                 Fait autorité. JAMAIS calculé par nous.
--   • PLATEFORME: dérivé de ce que les écoles ont saisi dans exam_candidates,
--                 toujours accompagné de son TAUX DE COUVERTURE.
--  Les confondre décrédibiliserait tout le reste : une école ayant saisi 3
--  résultats sur 40 afficherait « 100 % de réussite ».
--
--  ── GRANULARITÉ (vérifiée sur les publications réelles) ────────────────────
--  La DEC publie par examen, par département ET **par établissement** — un
--  document par école, identifié par un CODE ÉTABLISSEMENT propre à la DEC
--  (format AAA…AIZ, > 170 écoles pour le seul BEPC de Brazzaville). Ce code
--  est la seule clé de jointure fiable entre le monde de la DEC et le nôtre :
--  rapprocher par le nom de l'école serait fragile.
-- ════════════════════════════════════════════════════════════════════════════

-- ── 1. Le code de l'école chez la DEC ───────────────────────────────────────
-- Nullable : une école peut exister chez nous avant d'être immatriculée à la
-- DEC. Unique dans le groupe seulement — deux ministères de tutelle peuvent
-- réutiliser les mêmes codes sans se télescoper.
alter table public.schools
  add column if not exists dec_code text;

comment on column public.schools.dec_code is
  'Code établissement attribué par la DEC (ex. « AAB »), tel qu''il figure sur '
  'ses publications. Clé de rapprochement avec nos écoles — jamais le nom.';

create unique index if not exists schools_dec_code_uniq
  on public.schools (group_id, dec_code)
  where dec_code is not null;

-- ── 2. La pièce archivée ────────────────────────────────────────────────────
create table if not exists public.exam_publications (
  id            uuid primary key default gen_random_uuid(),
  group_id      uuid not null references public.school_groups(id) on delete cascade,
  session_id    uuid not null references public.exam_sessions(id) on delete cascade,

  -- Périmètre couvert par le document, tel que la DEC l'a découpé.
  scope         text not null check (scope in ('national','departement','etablissement')),
  department    text,
  school_id     uuid references public.schools(id) on delete set null,
  -- Le code lu SUR le document. Conservé même quand school_id est renseigné :
  -- c'est ce que la pièce dit, et une pièce ne se réécrit pas.
  dec_school_code text,
  filiere_label text,
  cycle_code    text,

  title         text not null,
  -- Date de PROCLAMATION par la DEC ≠ date de réception à la DSIC. Confondre
  -- les deux daterait la proclamation du jour de la frappe (cf. mig 0053).
  published_at  date,
  received_at   timestamptz not null default now(),

  file_path     text not null,
  file_name     text not null,
  file_size     bigint,
  -- Empreinte du fichier : une archive dont on ne peut pas prouver
  -- l'intégrité n'est pas une archive.
  file_sha256   text,
  page_count    integer,

  notes         text,
  deposited_by  uuid references public.profiles(id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),

  constraint exam_publications_scope_coherent check (
    (scope = 'national'      and department is null and school_id is null and dec_school_code is null)
 or (scope = 'departement'   and department is not null and school_id is null)
 or (scope = 'etablissement' and (school_id is not null or dec_school_code is not null))
  )
);

comment on table public.exam_publications is
  'Publications de la DEC archivées par la DSIC (le document lui-même). '
  'La plateforme ne les interprète pas : elle les conserve et les rend '
  'consultables. Aucune extraction automatique — une lecture ratée écrirait '
  'un faux résultat sur le dossier d''un élève.';

create index if not exists exam_publications_group_session_idx
  on public.exam_publications (group_id, session_id);
create index if not exists exam_publications_school_idx
  on public.exam_publications (school_id) where school_id is not null;

-- ── 3. Les chiffres officiels portés par la publication ─────────────────────
create table if not exists public.exam_official_results (
  id             uuid primary key default gen_random_uuid(),
  group_id       uuid not null references public.school_groups(id) on delete cascade,
  session_id     uuid not null references public.exam_sessions(id) on delete cascade,
  -- La pièce qui prouve ces chiffres. Nullable le temps qu'elle soit déposée,
  -- mais un chiffre sans source doit se voir comme tel à l'écran.
  publication_id uuid references public.exam_publications(id) on delete set null,

  scope          text not null check (scope in ('national','departement','etablissement')),
  department     text,
  school_id      uuid references public.schools(id) on delete cascade,
  filiere_label  text,

  -- ⚠️ Le taux officiel se calcule sur les PRÉSENTS, pas sur les inscrits.
  -- BAC technique et professionnel 2025 : 7 681 admis / 15 843 présents
  -- (16 070 inscrits) = 48,48 %. Les absents sortent du dénominateur.
  registered     integer check (registered  >= 0),
  present        integer check (present     >= 0),
  admitted       integer check (admitted    >= 0),
  -- Certaines publications ne donnent QUE le pourcentage, sans effectifs
  -- (classement départemental du Bac général). On le stocke alors tel quel :
  -- on ne fabrique pas les effectifs manquants.
  pass_rate      numeric(5,2) check (pass_rate between 0 and 100),

  source_label   text,
  published_at   date,
  recorded_by    uuid references public.profiles(id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),

  constraint exam_official_scope_coherent check (
    (scope = 'national'      and department is null and school_id is null)
 or (scope = 'departement'   and department is not null and school_id is null)
 or (scope = 'etablissement' and school_id is not null)
  ),
  -- Un enregistrement sans aucun chiffre exploitable n'a pas lieu d'être.
  constraint exam_official_has_figures check (
    (present is not null and admitted is not null) or pass_rate is not null
  ),
  -- On ne peut pas admettre plus de candidats qu'il n'y en avait présents.
  constraint exam_official_admitted_le_present check (
    present is null or admitted is null or admitted <= present
  )
);

comment on table public.exam_official_results is
  'Chiffres OFFICIELS relevés sur les publications de la DEC. Saisis, jamais '
  'calculés par la plateforme. Le taux porte sur les PRÉSENTS.';

-- Une seule ligne officielle par périmètre et par session : deux chiffres
-- officiels contradictoires seraient pires que pas de chiffre du tout.
create unique index if not exists exam_official_results_uniq
  on public.exam_official_results (
    session_id, scope,
    coalesce(department, ''),
    coalesce(school_id, '00000000-0000-0000-0000-000000000000'::uuid),
    coalesce(filiere_label, '')
  );

create index if not exists exam_official_results_group_idx
  on public.exam_official_results (group_id, session_id);

-- ── 4. Taux effectif : ce qui est publié l'emporte sur ce qui est déduit ────
-- Quand la publication donne les effectifs, le taux s'en déduit ; quand elle
-- ne donne qu'un pourcentage, c'est lui qui fait foi. La règle vit en base
-- pour que Dart et SQL ne puissent pas diverger.
create or replace function public.official_pass_rate(
  p_present integer, p_admitted integer, p_rate numeric
) returns numeric
language sql immutable as $$
  select case
    when p_present is not null and p_present > 0 and p_admitted is not null
      then round(p_admitted::numeric / p_present * 100, 2)
    else p_rate
  end;
$$;

-- ── 5. RLS ──────────────────────────────────────────────────────────────────
alter table public.exam_publications    enable row level security;
alter table public.exam_official_results enable row level security;

drop policy if exists exam_publications_select on public.exam_publications;
create policy exam_publications_select on public.exam_publications
  for select using (is_super_admin() or group_id = auth_group_id());

-- Le dépôt est un acte de la DSIC : elle centralise les publications reçues.
-- Une école ne dépose pas — elle lit ce qui la concerne (policy de select).
drop policy if exists exam_publications_write on public.exam_publications;
create policy exam_publications_write on public.exam_publications
  for all
  using      (is_super_admin() or (is_admin_groupe() and group_id = auth_group_id()))
  with check (is_super_admin() or (is_admin_groupe() and group_id = auth_group_id()));

drop policy if exists exam_official_select on public.exam_official_results;
create policy exam_official_select on public.exam_official_results
  for select using (is_super_admin() or group_id = auth_group_id());

drop policy if exists exam_official_write on public.exam_official_results;
create policy exam_official_write on public.exam_official_results
  for all
  using      (is_super_admin() or (is_admin_groupe() and group_id = auth_group_id()))
  with check (is_super_admin() or (is_admin_groupe() and group_id = auth_group_id()));

-- ── 6. Stockage des pièces ──────────────────────────────────────────────────
-- Bucket PRIVÉ : une publication nominative de résultats ne s'expose pas sur
-- une URL devinable.
insert into storage.buckets (id, name, public)
values ('exam-publications', 'exam-publications', false)
on conflict (id) do nothing;

drop policy if exists exam_pub_files_read on storage.objects;
create policy exam_pub_files_read on storage.objects
  for select to authenticated
  using (bucket_id = 'exam-publications');

drop policy if exists exam_pub_files_write on storage.objects;
create policy exam_pub_files_write on storage.objects
  for insert to authenticated
  with check (bucket_id = 'exam-publications' and (is_super_admin() or is_admin_groupe()));

drop policy if exists exam_pub_files_delete on storage.objects;
create policy exam_pub_files_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'exam-publications' and (is_super_admin() or is_admin_groupe()));
