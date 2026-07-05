-- 0030_subscription_reminders_robust.sql
-- Durcissement du moteur de rappels d'échéance (audit 2026-07-05) :
--   (#1) RATTRAPAGE des jours manqués. On n'émet plus sur égalité stricte
--        (days_left = seuil) — un cron manqué le jour d'un seuil perdait le
--        rappel à jamais. On émet désormais sur « seuil FRANCHI (days_left <=
--        seuil) ET non encore journalisé pour ce cycle », en n'émettant qu'UNE
--        notification (le seuil le plus urgent) et en consommant silencieusement
--        les seuils supérieurs franchis → pas de rafale sur un groupe apparu en
--        cours de bracket, mais aucun rappel définitivement perdu.
--   (#4) Compteur d'émissions + RAISE NOTICE (tracé dans cron.job_run_details).
--   (#5) Purge de rétention du ledger (cycles > 2 ans).
-- Redéfinit UNIQUEMENT la fonction (table subscription_reminder_log + job cron
-- inchangés ; le job appelle la fonction par son nom, il prend la nouvelle def).

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
  v_max        int;
  g            record;
  v_days_left  int;
  v_end        date;
  v_target     int;
  v_title      text;
  v_body       text;
  v_emitted    int := 0;
begin
  -- (#5) Rétention : purge les cycles anciens (garde le ledger propre à l'échelle).
  delete from subscription_reminder_log where notified_at < now() - interval '2 years';

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

  select max(t) into v_max from unnest(v_thresholds) t;

  for g in
    select id, name, subscription_end::date as sub_end
    from school_groups
    where subscription_end is not null
  loop
    v_end := g.sub_end;
    v_days_left := v_end - current_date;

    -- Hors fenêtre : déjà expiré (géré par hard-lock/bandeaux) ou trop loin.
    if v_days_left < 0 or v_days_left > v_max then
      continue;
    end if;

    -- Seuil cible = plus PETIT seuil FRANCHI (days_left <= seuil) NON encore
    -- journalisé pour ce cycle. Null → déjà couvert (idempotent).
    select min(t) into v_target
    from unnest(v_thresholds) t
    where v_days_left <= t
      and not exists (
        select 1 from subscription_reminder_log l
        where l.group_id = g.id and l.subscription_end = v_end and l.threshold = t
      );

    if v_target is null then
      continue;
    end if;

    -- Consomme TOUS les seuils franchis non journalisés (cible + supérieurs) pour
    -- éviter une rafale ultérieure ; on n'émettra qu'UNE notif (le seuil cible).
    insert into subscription_reminder_log(group_id, subscription_end, threshold)
    select g.id, v_end, t
    from unnest(v_thresholds) t
    where v_days_left <= t
      and not exists (
        select 1 from subscription_reminder_log l
        where l.group_id = g.id and l.subscription_end = v_end and l.threshold = t
      )
    on conflict (group_id, subscription_end, threshold) do nothing;

    -- Libellé basé sur le NOMBRE RÉEL de jours restants (rattrapage inclus).
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

    -- Une notification par admin_groupe (chemin cloche online).
    -- data.route → deep-link exploité par notifications_drawer.dart.
    insert into notifications(group_id, recipient_id, type, title, body, data, sent_at)
    select g.id, p.id, 'subscription', v_title, v_body,
           jsonb_build_object(
             'route', '/admin/abonnement',
             'threshold', v_target,
             'days_left', v_days_left,
             'subscription_end', v_end
           ),
           now()
    from profiles p
    where p.group_id = g.id and p.role = 'admin_groupe';

    v_emitted := v_emitted + 1;
  end loop;

  -- (#4) Observabilité : tracé dans cron.job_run_details.return_message.
  raise notice 'subscription reminders: % groupe(s) notifié(s)', v_emitted;
end;
$fn$;
