-- ════════════════════════════════════════════════════════════════════════════
--  0106 — L'ALERTE D'ÉCHÉANCE PASSE À 5 JOURS, ET ATTEINT L'ÉCOLE
--
--  Suite directe de 0097, qui avait rendu la fenêtre d'alerte réglable sans
--  que personne ne l'ait jamais réglée : `platform_settings.data` ne contenait
--  aucune des trois clés, tout tournait sur les défauts. Trois décisions du
--  propriétaire, prises le 2026-08-14 :
--
--  1. LE BANDEAU S'ALLUME À J-5 (et non J-7)
--     Un bandeau présent sur toutes les pages est une pression, pas une
--     information : plus il dure, moins il se voit. Cinq jours restent
--     crédibles.
--
--  2. LA CLOCHE PRÉVIENT TÔT — 30, 15, 7, 1, 0
--     La contrepartie indispensable du point 1. Le METP paie 2 500 000 XAF par
--     circuit du Trésor : cinq jours de préavis ne suffisent pas à monter un
--     mandat. On sépare donc les deux rôles au lieu de les confondre —
--     PRÉVENIR tôt (notification datée, ponctuelle, qui ne fatigue pas) et
--     ALERTER tard (bandeau permanent, qui presse). L'échelle complète :
--
--         J-30 🔔   J-15 🔔   J-7 🔔   J-5 🟠 bandeau   J-1 🔔   J0 🔔
--         J+1 ⛔ hard-lock école      J+15 🔴 lecture seule groupe
--
--     Règle à ne plus casser : il doit toujours rester au moins un seuil de
--     rappel À L'INTÉRIEUR de la fenêtre du bandeau (ici 1 et 0), sinon le
--     canal cloche s'éteint précisément dans les jours qui comptent.
--
--  3. L'ÉCOLE VOIT LE MÊME AVERTISSEMENT QUE SON GROUPE
--     Jusqu'ici le personnel ne voyait un compte à rebours QUE si son groupe
--     détenait une licence signée — or l'émission est bornée par
--     `LICENSE_PILOT_GROUP_IDS`, donc pratiquement personne. Le poste école
--     est offline-first : il ne peut pas lire `platform_settings` (RLS
--     super_admin, table non synchronisée). Mais `school_groups` descend DÉJÀ
--     en entier sur chaque appareil (`SELECT * FROM school_groups WHERE
--     id = bucket.gid`). On y recopie donc la fenêtre d'alerte : un MIROIR,
--     pas une source. Le réglage voyage ainsi jusqu'au poste le plus isolé
--     sans toucher aux sync-rules, sans Edge Function et sans licence.
-- ════════════════════════════════════════════════════════════════════════════

-- ── 1 · Les valeurs décidées, posées pour de bon ────────────────────────────
-- Fusion (`||`), jamais écrasement : `data` porte d'autres réglages.
update platform_settings
   set data = coalesce(data, '{}'::jsonb) || jsonb_build_object(
         'subscription_alert_days', '5',
         'notif_reminder_days',     '30,15,7,1,0'
       )
 where id = 1;

-- ── 2 · Lecture unique et sûre du réglage ───────────────────────────────────
-- Un seul analyseur pour la base entière (RPC, cron, triggers) : un réglage
-- vide, non numérique ou nul retombe sur 5 au lieu d'éteindre l'alerte.
create or replace function public.effective_alert_days(p_data jsonb)
returns integer
language sql
immutable
as $function$
  select case
           when btrim(coalesce(p_data->>'subscription_alert_days', '')) ~ '^[0-9]+$'
            and btrim(p_data->>'subscription_alert_days')::int > 0
           then btrim(p_data->>'subscription_alert_days')::int
           else 5
         end;
$function$;

comment on function public.effective_alert_days(jsonb) is
  'Fenêtre d''alerte effective (jours AVANT échéance) lue dans platform_settings.data. '
  'Défaut 5. Analyseur UNIQUE — RPC, cron et triggers passent tous par ici.';

-- ── 3 · Réglages exposés au client online (défauts alignés) ─────────────────
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
       'alert_days',    public.effective_alert_days(data),
       'reminder_days', coalesce(nullif(btrim(data->>'notif_reminder_days'), ''), '30,15,7,1,0')
     )
     from platform_settings where id = 1),
    jsonb_build_object('grace_days', 15, 'alert_days', 5, 'reminder_days', '30,15,7,1,0')
  );
$function$;

comment on function public.get_subscription_settings() is
  'Réglages d''abonnement lisibles par tout utilisateur authentifié : '
  'grace_days (jours APRÈS échéance avant lecture seule), alert_days (jours '
  'AVANT échéance où le bandeau s''allume), reminder_days (seuils de rappel, CSV).';

-- ── 4 · Le cron prévient tôt (défauts 30,15,7,1,0) ──────────────────────────
-- Corps repris de 0097 à l'identique : SEULS les défauts changent. La
-- mécanique d'idempotence (ledger), de rattrapage (seuil FRANCHI non
-- journalisé) et d'anti-rafale (consommation des seuils supérieurs) est
-- inchangée — c'est elle qui rend l'ajout de 30 et 15 sans danger : un groupe
-- déjà à J-6 aujourd'hui ne recevra PAS les rappels J-30 et J-15 rétroactifs,
-- il recevra une seule notification, la plus urgente.
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

-- ── 5 · Le miroir qui porte le réglage jusqu'au poste école ─────────────────
alter table school_groups
  add column if not exists subscription_alert_days integer;

comment on column school_groups.subscription_alert_days is
  'MIROIR de platform_settings.data->>subscription_alert_days, recopié par '
  'trigger. Existe UNIQUEMENT pour atteindre les postes école hors ligne : '
  'school_groups est synchronisé par PowerSync, platform_settings non. '
  'La SOURCE DE VÉRITÉ reste platform_settings — ne jamais écrire ici à la main.';

-- Recopie du réglage courant sur les groupes existants.
update school_groups
   set subscription_alert_days = public.effective_alert_days(
         (select data from platform_settings where id = 1))
 where subscription_alert_days is distinct from public.effective_alert_days(
         (select data from platform_settings where id = 1));

-- Le super_admin change le réglage → tous les postes du pays suivent.
-- 1000 écoles = quelques centaines de lignes réécrites, PowerSync les pousse.
create or replace function public.fn_fanout_alert_days()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_days int := public.effective_alert_days(NEW.data);
begin
  update school_groups
     set subscription_alert_days = v_days
   where subscription_alert_days is distinct from v_days;
  return null;  -- AFTER trigger : valeur de retour ignorée.
end;
$function$;

drop trigger if exists trg_platform_settings_fanout_alert_days on platform_settings;
create trigger trg_platform_settings_fanout_alert_days
  after update on platform_settings
  for each row
  when (NEW.data->>'subscription_alert_days'
        is distinct from OLD.data->>'subscription_alert_days')
  execute function public.fn_fanout_alert_days();

-- Un groupe créé après coup hérite du réglage en vigueur (sinon il resterait
-- NULL et son école retomberait silencieusement sur le défaut compilé).
create or replace function public.fn_default_alert_days()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
begin
  if NEW.subscription_alert_days is null then
    NEW.subscription_alert_days := public.effective_alert_days(
      (select data from platform_settings where id = 1));
  end if;
  return NEW;
end;
$function$;

drop trigger if exists trg_school_groups_default_alert_days on school_groups;
create trigger trg_school_groups_default_alert_days
  before insert on school_groups
  for each row
  execute function public.fn_default_alert_days();
