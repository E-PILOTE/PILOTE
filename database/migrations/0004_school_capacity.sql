-- 0004_school_capacity.sql
-- Ajoute une capacité d'accueil (places) optionnelle aux écoles, pour calculer
-- le taux d'occupation dans la Vue régionale (cockpit admin_groupe).
-- Additif, nullable, réversible (drop column). Aucune donnée existante touchée.

alter table public.schools
  add column if not exists capacity integer
  check (capacity is null or capacity >= 0);

comment on column public.schools.capacity is
  'Capacité d''accueil (nombre de places). NULL = non renseignée. '
  'Sert au taux d''occupation = effectif / capacity.';
