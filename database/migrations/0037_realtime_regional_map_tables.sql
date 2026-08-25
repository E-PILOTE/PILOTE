-- 0037_realtime_regional_map_tables.sql
-- Active le temps réel de la Vue régionale (Tableau de bord admin_groupe → carte).
-- Cause racine (audit 2026-07-09) : le provider `adminRegionalProvider` s'abonne
-- correctement via onPostgresChanges sur `schools` et `students` (debounce 2 s →
-- invalidateSelf), mais ces tables — ainsi que `school_projects` — étaient ABSENTES
-- de la publication `supabase_realtime`. Conséquence : aucun événement n'atteignait
-- le client → la carte ne se rafraîchissait jamais en direct (perçu « temps réel
-- indisponible »). Même diagnostic que 0032 pour le domaine abonnement.
--
-- REPLICA IDENTITY FULL : requis pour filtrer le Realtime sur `group_id` (colonne
-- NON-PK) et recevoir l'ancienne ligne sur UPDATE/DELETE — sinon une école
-- désactivée/supprimée ou déplacée n'est pas notifiée à la bonne session.
-- Cf. mémoire realtime-publication-requirement.

do $$
begin
  -- Ajout idempotent à la publication (ignore si déjà présent).
  begin alter publication supabase_realtime add table schools;         exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table students;        exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table school_projects; exception when duplicate_object then null; end;
end $$;

alter table schools         replica identity full;
alter table students        replica identity full;
alter table school_projects replica identity full;
