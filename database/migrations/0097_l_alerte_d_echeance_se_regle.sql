-- ════════════════════════════════════════════════════════════════════════════
--  0097 — L'ALERTE D'ÉCHÉANCE SE RÈGLE, ET NE MENT PLUS
--
--  Trois corrections d'un même système, l'abonnement vu par l'admin de groupe.
--
--  1. FENÊTRE D'ALERTE RÉGLABLE (`subscription_alert_days`, défaut 7)
--     Le bandeau « votre abonnement expire bientôt » s'allumait à 30 jours,
--     codés en dur côté Flutter. Un mois d'alerte quotidienne sur toutes les
--     pages : on cesse de la voir bien avant qu'elle devienne vraie. La RPC
--     `get_subscription_settings` expose désormais `alert_days` à côté de
--     `grace_days`, et le client le lit — plus aucun seuil en dur.
--
--  2. RAPPELS ALIGNÉS (défaut `30,15,7,1,0` → `7,1,0`)
--     Le cron notifiait à J-30 alors que le bandeau, lui, restera éteint
--     jusqu'à J-7. Une cloche qui sonne pour une alerte invisible envoie
--     l'admin chercher un problème qui ne s'affiche nulle part. Les deux
--     réglages restent INDÉPENDANTS (on peut vouloir prévenir tôt et alerter
--     tard) — seuls leurs défauts s'accordent.
--
--  3. LE TEXTE NE PROMET PLUS UNE SUSPENSION QUI N'EXISTE PAS
--     Le corps du rappel disait « éviter la suspension de l'accès aux
--     modules ». Aucune suspension de modules n'est implémentée : ni
--     `activeModulesProvider` (personnel, offline) ni les sync-rules ne lisent
--     `subscription_status`. Le gel réel se limite à la création d'écoles et
--     d'utilisateurs par l'admin de groupe (soft-gate assumé, cf.
--     ABONNEMENT_LICENCE_ARCHITECTURE.md). Annoncer une coupure qui ne vient
--     jamais apprend aux écoles à ignorer les rappels suivants.
-- ════════════════════════════════════════════════════════════════════════════

-- ── 1 + 2 · Réglages exposés au client ──────────────────────────────────────
-- RLS-safe : la RPC ne rend QUE ces trois nombres, jamais le reste de
-- `platform_settings` (qui contient des réglages d'intégration).
create or replace function public.get_subscription_settings()
returns jsonb
language sql
stable security definer
set search_path to 'public'
as $function$
  select coalesce(
    (select jsonb_build_object(
       'grace_days',    coalesce(nullif(btrim(data->>'grace_days'), '')::int, 15),
       'alert_days',    coalesce(nullif(btrim(data->>'subscription_alert_days'), '')::int, 7),
       'reminder_days', coalesce(nullif(btrim(data->>'notif_reminder_days'), ''), '7,1,0')
     )
     from platform_settings where id = 1),
    jsonb_build_object('grace_days', 15, 'alert_days', 7, 'reminder_days', '7,1,0')
  );
$function$;

comment on function public.get_subscription_settings() is
  'Réglages d''abonnement lisibles par tout utilisateur authentifié : '
  'grace_days (jours APRÈS échéance avant lecture seule), alert_days (jours '
  'AVANT échéance où le bandeau s''allume), reminder_days (seuils de rappel, CSV).';

-- ── 3 · Le rappel décrit ce qui va RÉELLEMENT se passer ─────────────────────
create or replace function public.emit_subscription_reminders()
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
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
  -- Rétention : purge les cycles anciens (garde le ledger propre à l'échelle).
  delete from subscription_reminder_log where notified_at < now() - interval '2 years';

  select data into v_settings from platform_settings where id = 1;

  -- Garde master : le super_admin peut couper les rappels (défaut = activé).
  v_enabled := coalesce((v_settings->>'notif_subscription_expiry')::boolean, true);
  if not v_enabled then
    return;
  end if;

  -- Seuils depuis le champ texte 'notif_reminder_days' (CSV), défaut {7,1,0}.
  begin
    v_thresholds := (
      select array_agg(t::int)
      from regexp_split_to_table(
        coalesce(nullif(btrim(v_settings->>'notif_reminder_days'), ''), '7,1,0'),
        '\s*,\s*'
      ) as t
      where t ~ '^[0-9]+$'
    );
  exception when others then
    v_thresholds := array[7,1,0];
  end;
  if v_thresholds is null or array_length(v_thresholds, 1) is null then
    v_thresholds := array[7,1,0];
  end if;

  select max(t) into v_max from unnest(v_thresholds) t;

  for g in
    select id, name, subscription_end::date as sub_end
    from school_groups
    where subscription_end is not null
  loop
    v_end := g.sub_end;
    v_days_left := v_end - current_date;

    -- Hors fenêtre : déjà expiré (géré par le bandeau) ou trop loin.
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
    -- Le corps décrit le soft-gate tel qu'il est implémenté : la création
    -- d'écoles et d'utilisateurs se ferme, la gestion courante et les exports
    -- restent ouverts. Ni plus, ni moins.
    if v_days_left = 0 then
      v_title := 'Abonnement : expire aujourd''hui';
      v_body  := 'L''abonnement de votre groupe expire aujourd''hui. Passé le '
              || 'délai de grâce, la création de nouvelles écoles et de nouveaux '
              || 'comptes sera suspendue ; la gestion courante et les exports '
              || 'resteront accessibles.';
    elsif v_days_left = 1 then
      v_title := 'Abonnement : expire demain';
      v_body  := 'L''abonnement de votre groupe expire demain. Renouvelez pour '
              || 'conserver la création d''écoles et de comptes.';
    else
      v_title := format('Abonnement : expire dans %s jours', v_days_left);
      v_body  := format('L''abonnement de votre groupe expire dans %s jours. '
              || 'Renouvelez pour conserver la création d''écoles et de comptes.',
              v_days_left);
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

  -- Observabilité : tracé dans cron.job_run_details.return_message.
  raise notice 'subscription reminders: % groupe(s) notifié(s)', v_emitted;
end;
$function$;

-- ── 4 · `module_count` compte ce que l'écran affiche ────────────────────────
-- Le compteur dénormalisé additionnait TOUS les `plan_modules`, sans regarder
-- `modules.is_active` — et son trigger ne se déclenchait que sur `plan_modules`.
-- Désactiver un module laissait donc la carte d'abonnement annoncer « 30
-- modules » pendant que la barre latérale n'en montrait que 29, indéfiniment.
create or replace function public.fn_sync_plan_module_count()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_plan uuid := coalesce(NEW.plan_id, OLD.plan_id);
begin
  update subscription_plans p
     set module_count = (
       select count(*) from plan_modules pm
       join modules m on m.id = pm.module_id
       where pm.plan_id = p.id and m.is_active
     )
   where p.id = v_plan;

  -- Un UPDATE qui déplace un lien d'un plan à l'autre touche DEUX plans.
  if TG_OP = 'UPDATE' and NEW.plan_id is distinct from OLD.plan_id then
    update subscription_plans p
       set module_count = (
         select count(*) from plan_modules pm
         join modules m on m.id = pm.module_id
         where pm.plan_id = p.id and m.is_active
       )
     where p.id = OLD.plan_id;
  end if;

  return null;  -- AFTER trigger : la valeur de retour est ignorée.
end;
$function$;

-- Resynchronise TOUS les plans quand un module change d'activité : c'est le
-- chaînon qui manquait, `plan_modules` ne bouge pas dans ce cas-là.
create or replace function public.fn_resync_plan_counts_on_module()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
begin
  update subscription_plans p
     set module_count = (
       select count(*) from plan_modules pm
       join modules m on m.id = pm.module_id
       where pm.plan_id = p.id and m.is_active
     )
   where exists (select 1 from plan_modules pm
                  where pm.plan_id = p.id and pm.module_id = NEW.id);
  return null;
end;
$function$;

drop trigger if exists trg_modules_active_sync_counts on modules;
create trigger trg_modules_active_sync_counts
  after update of is_active on modules
  for each row
  when (OLD.is_active is distinct from NEW.is_active)
  execute function public.fn_resync_plan_counts_on_module();

-- Rattrapage immédiat sur l'existant (aucune dérive constatée à ce jour ;
-- l'exécution est idempotente et coûte une passe sur 4 lignes).
update subscription_plans p
   set module_count = (
     select count(*) from plan_modules pm
     join modules m on m.id = pm.module_id
     where pm.plan_id = p.id and m.is_active
   )
 where p.module_count is distinct from (
     select count(*) from plan_modules pm
     join modules m on m.id = pm.module_id
     where pm.plan_id = p.id and m.is_active
   );
