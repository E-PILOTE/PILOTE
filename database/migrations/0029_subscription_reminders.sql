-- 0029_subscription_reminders.sql
-- Notifications d'échéance d'abonnement (rappels avant hard-lock jour-même, ADR-0009).
-- Moteur SERVEUR pour les audiences ONLINE (admin_groupe). Le personnel école
-- (offline) est averti par un bandeau client dérivé de license.validTo — aucun
-- serveur, aucune sync-rule (C4 : la synchro n'est jamais gatée).

create extension if not exists pg_cron;

-- Ledger d'idempotence : un seuil (J-X) n'est émis qu'une fois par cycle
-- d'échéance (identifié par subscription_end). Un renouvellement change
-- subscription_end → nouveau cycle → les seuils se rejouent proprement.
create table if not exists subscription_reminder_log (
  group_id         uuid not null references school_groups(id) on delete cascade,
  subscription_end date not null,
  threshold        int  not null,
  notified_at      timestamptz not null default now(),
  primary key (group_id, subscription_end, threshold)
);

create or replace function emit_subscription_reminders()
returns void
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_settings   jsonb;
  v_enabled    boolean;
  v_thresholds int[];
  g            record;
  v_days_left  int;
  v_end        date;
  v_title      text;
  v_body       text;
begin
  select data into v_settings from platform_settings where id = 1;

  -- Garde master : le super_admin peut couper les rappels (défaut = activé).
  v_enabled := coalesce((v_settings->>'notif_subscription_expiry')::boolean, true);
  if not v_enabled then
    return;
  end if;

  -- Seuils depuis le champ texte 'notif_reminder_days' (CSV), défaut {30,15,7,1,0}.
  begin
    v_thresholds := (
      select array_agg(t::int)
      from regexp_split_to_table(
        coalesce(nullif(btrim(v_settings->>'notif_reminder_days'), ''), '30,15,7,1,0'),
        '\s*,\s*'
      ) as t
      where t ~ '^[0-9]+$'
    );
  exception when others then
    v_thresholds := array[30,15,7,1,0];
  end;
  if v_thresholds is null or array_length(v_thresholds, 1) is null then
    v_thresholds := array[30,15,7,1,0];
  end if;

  for g in
    select id, name, subscription_end::date as sub_end
    from school_groups
    where subscription_end is not null
  loop
    v_end := g.sub_end;
    v_days_left := v_end - current_date;

    if not (v_days_left = any(v_thresholds)) then
      continue;
    end if;

    -- Idempotence : réserve le seuil pour ce cycle. Déjà présent → on saute.
    insert into subscription_reminder_log(group_id, subscription_end, threshold)
    values (g.id, v_end, v_days_left)
    on conflict (group_id, subscription_end, threshold) do nothing;

    if not found then
      continue;
    end if;

    if v_days_left = 0 then
      v_title := 'Abonnement : expire aujourd''hui';
      v_body  := 'L''abonnement de votre groupe expire aujourd''hui. Renouvelez pour '
              || 'éviter la suspension de l''accès aux modules.';
    elsif v_days_left = 1 then
      v_title := 'Abonnement : expire demain';
      v_body  := 'L''abonnement de votre groupe expire demain. Pensez à renouveler.';
    else
      v_title := format('Abonnement : expire dans %s jours', v_days_left);
      v_body  := format('L''abonnement de votre groupe expire dans %s jours. '
              || 'Renouvelez pour maintenir l''accès aux modules.', v_days_left);
    end if;

    -- Une notification par admin_groupe du groupe (chemin cloche online).
    -- data.route → deep-link exploité par notifications_drawer.dart.
    insert into notifications(group_id, recipient_id, type, title, body, data, sent_at)
    select g.id, p.id, 'subscription', v_title, v_body,
           jsonb_build_object(
             'route', '/admin/abonnement',
             'threshold', v_days_left,
             'subscription_end', v_end
           ),
           now()
    from profiles p
    where p.group_id = g.id and p.role = 'admin_groupe';
  end loop;
end;
$fn$;

-- Planification quotidienne 06:00 UTC (~07:00 WAT, avant l'ouverture des écoles).
-- Idempotent : dé-planifie un éventuel job homonyme avant de (re)planifier.
select cron.unschedule(jobid) from cron.job where jobname = 'subscription-reminders';

select cron.schedule(
  'subscription-reminders',
  '0 6 * * *',
  $cron$select public.emit_subscription_reminders()$cron$
);
