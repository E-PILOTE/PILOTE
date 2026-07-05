-- 0032_realtime_subscription_tables.sql
-- Publie en Realtime les tables du domaine abonnement/notifications (audit UX
-- 2026-07-05). Cause racine découverte : la publication `supabase_realtime` ne
-- contenait que les 10 tables de communication ; `notifications`, `school_groups`,
-- `group_invoices`, `support_tickets` en étaient ABSENTES. Conséquences :
--   1. La cloche de notifications ne se mettait PAS à jour en direct → les rappels
--      d'échéance n'apparaissaient qu'au rechargement (bug du canal in-app).
--   2. Le realtime de `adminSubscriptionProvider` (page Abonnement) était mort →
--      désynchro bandeau/carte-plan observée en test visuel.
--
-- REPLICA IDENTITY FULL : requis pour filtrer le Realtime sur des colonnes NON-PK
-- (notifications.recipient_id, group_invoices.group_id, support_tickets.group_id)
-- et pour recevoir l'ancienne ligne (cf. mémoire realtime-publication-requirement).

do $$
begin
  -- Ajout idempotent à la publication (ignore si déjà présent).
  begin alter publication supabase_realtime add table notifications;   exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table school_groups;   exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table group_invoices;  exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table support_tickets; exception when duplicate_object then null; end;
end $$;

alter table notifications   replica identity full;
alter table school_groups   replica identity full;
alter table group_invoices  replica identity full;
alter table support_tickets replica identity full;
