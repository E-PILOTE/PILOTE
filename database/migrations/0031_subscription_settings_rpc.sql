-- 0031_subscription_settings_rpc.sql
-- Expose au chemin ONLINE (admin_groupe, super_admin) les réglages d'abonnement
-- NON sensibles, pilotables depuis le dashboard super_admin (platform_settings).
--
-- Contexte : RLS `platform_settings_select = is_super_admin()` → l'admin_groupe
-- ne peut PAS lire platform_settings (qui contient aussi bank_iban, emails, etc.).
-- Cette RPC SECURITY DEFINER ne renvoie QUE grace_days + reminder_days : la grâce
-- (délai avant lecture seule) et la cadence de rappel cessent d'être codées en dur
-- côté client — elles suivent le réglage super_admin. Fail-soft : défauts si absent.

create or replace function get_subscription_settings()
returns jsonb
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(
    (select jsonb_build_object(
       'grace_days',    coalesce((data->>'grace_days')::int, 15),
       'reminder_days', coalesce(nullif(btrim(data->>'notif_reminder_days'), ''), '30,15,7,1,0')
     )
     from platform_settings where id = 1),
    jsonb_build_object('grace_days', 15, 'reminder_days', '30,15,7,1,0')
  );
$$;

grant execute on function get_subscription_settings() to authenticated;
