-- ════════════════════════════════════════════════════════════════════════════
--  LA RELANCE S'ARRÊTAIT LE JOUR OÙ ELLE DEVENAIT UTILE
--
--  ── CE QUI SE PASSAIT (mesuré en production, 2026-09-04) ───────────────────
--  `emit_subscription_reminders()` prévenait à 30, 15, 7, 1 et 0 jour de
--  l'échéance. Puis, littéralement :
--
--      if v_days_left < 0 or v_days_left > v_max then
--        continue;
--
--  Le lendemain de l'échéance, PLUS RIEN. Or c'est exactement là que le sujet
--  commence : l'accès n'est pas coupé le jour J, il l'est à la fin du délai de
--  grâce — quinze jours pendant lesquels le client travaille normalement,
--  croit son abonnement en ordre, et ne reçoit plus un mot. Le seizième jour,
--  la création d'écoles et de comptes s'arrête sans que personne n'ait été
--  prévenu depuis deux semaines.
--
--  ── ET LE FONDATEUR N'ÉTAIT JAMAIS AU COURANT ──────────────────────────────
--  Les notifications partaient aux seuls `admin_groupe` DU GROUPE concerné.
--  Personne, côté plateforme, n'apprenait qu'un client venait d'échoir : il
--  fallait ouvrir la page Abonnements et le remarquer. Un client qui lâche est
--  la seule information de ce système qui vaille un réveil.
--
--  ── CE QUE FAIT CETTE MIGRATION ────────────────────────────────────────────
--   1. Trois relances APRÈS l'échéance : J+1, J+7, et le dernier jour de grâce.
--      Elles disent ce qui reste à perdre et quand — pas « renouvelez ».
--   2. Le fondateur est notifié deux fois : quand un client échoit (J+1), et
--      quand sa grâce expire (créations suspendues). Route `/super/abonnements`.
--   3. Passé la grâce, on se TAIT. Une relance quotidienne indéfinie se filtre
--      mentalement en trois jours, et emporte les vraies avec elle.
--
--  ── ⚠️ POURQUOI DES SEUILS NÉGATIFS ────────────────────────────────────────
--  `subscription_reminder_log` a pour clé (group_id, subscription_end,
--  threshold) : c'est elle qui garantit qu'une relance ne part qu'une fois.
--  Les relances d'après-échéance s'y inscrivent en NÉGATIF (-1, -7, -grâce), ce
--  qui réutilise la garde existante sans lui ajouter de colonne. La colonne est
--  un `integer` sans contrainte de signe — vérifié avant d'écrire ceci.
--
--  ── ⚠️ LE DÉLAI DE GRÂCE NE SE RECOPIE PAS ─────────────────────────────────
--  Il se lit dans `platform_settings`, à l'endroit exact d'où
--  `get_subscription_settings()` le publie déjà à l'application (défaut 15).
--  Une constante de plus ici, et le jour où le fondateur le change, la base et
--  l'écran ne parleraient plus du même délai.
--
--  ── CE QUI RESTE HORS DE CE MÉCANISME ──────────────────────────────────────
--  Les ministères (`administre_referentiel_national`) : leur terme est celui de
--  leur licence, ils n'expirent pas (0183). Et les abonnements ANNULÉS : un
--  client qui a résilié n'a pas à être relancé, il a déjà décidé.
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.emit_subscription_reminders()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_settings   jsonb;
  v_enabled    boolean;
  v_thresholds int[];
  v_max        int;
  v_grace      int;
  g            record;
  v_days_left  int;
  v_retard     int;
  v_end        date;
  v_target     int;
  v_title      text;
  v_body       text;
  v_emitted    int := 0;
  v_alertes    int := 0;
begin
  delete from subscription_reminder_log where notified_at < now() - interval '2 years';

  select data into v_settings from platform_settings where id = 1;

  v_enabled := coalesce((v_settings->>'notif_subscription_expiry')::boolean, true);
  if not v_enabled then
    return;
  end if;

  -- Même source que `get_subscription_settings()` : un seul délai de grâce.
  begin
    v_grace := coalesce(nullif(btrim(v_settings->>'grace_days'), '')::int, 15);
  exception when others then
    v_grace := 15;
  end;
  if v_grace < 1 then
    v_grace := 15;
  end if;

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
    select sg.id,
           sg.name,
           sg.subscription_end::date        as sub_end,
           sg.subscription_status::text     as statut
    from school_groups sg
    where sg.subscription_end is not null
      -- Un ministère n'expire pas : son terme est celui de sa licence (0183).
      and not coalesce(sg.administre_referentiel_national, false)
  loop
    v_end := g.sub_end;
    v_days_left := v_end - current_date;

    -- ══════════════════ AVANT L'ÉCHÉANCE ══════════════════════════════════
    if v_days_left >= 0 then
      if v_days_left > v_max then
        continue;
      end if;

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

      insert into subscription_reminder_log(group_id, subscription_end, threshold)
      select g.id, v_end, t
      from unnest(v_thresholds) t
      where v_days_left <= t
        and not exists (
          select 1 from subscription_reminder_log l
          where l.group_id = g.id and l.subscription_end = v_end and l.threshold = t
        )
      on conflict (group_id, subscription_end, threshold) do nothing;

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
      continue;
    end if;

    -- ══════════════════ APRÈS L'ÉCHÉANCE ══════════════════════════════════
    -- C'est la partie qui n'existait pas. Le client travaille encore : il a
    -- `v_grace` jours avant que la création d'écoles et de comptes ne cesse.
    v_retard := -v_days_left;

    -- Un abonnement résilié n'est pas un impayé : le client a décidé.
    if g.statut = 'cancelled' then
      continue;
    end if;

    -- Trois jalons, et le silence après. J+1 (« c'est passé »), J+7 (« la
    -- moitié du délai est consommée »), fin de grâce (« c'est coupé »).
    if v_retard <> 1 and v_retard <> 7 and v_retard <> v_grace then
      continue;
    end if;

    -- Seuil NÉGATIF : la même clé unique garantit une seule relance par jalon.
    insert into subscription_reminder_log(group_id, subscription_end, threshold)
    values (g.id, v_end, -v_retard)
    on conflict (group_id, subscription_end, threshold) do nothing;
    if not found then
      continue;
    end if;

    if v_retard >= v_grace then
      v_title := 'Abonnement échu : créations suspendues';
      v_body  := format(
        'Votre abonnement a expiré le %s et le délai de grâce de %s jours est '
        || 'écoulé : la création d''écoles et de comptes est suspendue. La '
        || 'gestion courante et les exports restent accessibles.',
        to_char(v_end, 'DD/MM/YYYY'), v_grace);
    else
      v_title := format('Abonnement expiré depuis %s jour%s',
                        v_retard, case when v_retard > 1 then 's' else '' end);
      v_body  := format(
        'Votre abonnement a expiré le %s. Il reste %s jour%s avant la '
        || 'suspension de la création d''écoles et de comptes ; la gestion '
        || 'courante et les exports restent accessibles.',
        to_char(v_end, 'DD/MM/YYYY'),
        v_grace - v_retard,
        case when v_grace - v_retard > 1 then 's' else '' end);
    end if;

    insert into notifications(group_id, recipient_id, type, title, body, data, sent_at)
    select g.id, p.id, 'subscription', v_title, v_body,
           jsonb_build_object(
             'route', '/admin/abonnement',
             'threshold', -v_retard,
             'days_left', v_days_left,
             'subscription_end', v_end
           ),
           now()
    from profiles p
    where p.group_id = g.id and p.role = 'admin_groupe';

    -- ── Et le fondateur, qui n'apprenait rien ────────────────────────────
    -- Deux moments seulement : le client vient d'échoir, et sa grâce est
    -- consommée. La route mène là où il peut agir.
    if v_retard = 1 or v_retard >= v_grace then
      insert into notifications(group_id, recipient_id, type, title, body, data, sent_at)
      select g.id, p.id, 'subscription',
             case when v_retard = 1
                  then format('Client échu : %s', g.name)
                  else format('Client suspendu : %s', g.name)
             end,
             case when v_retard = 1
                  then format(
                    'L''abonnement de « %s » a expiré le %s. Il lui reste %s '
                    || 'jours de grâce avant la suspension des créations.',
                    g.name, to_char(v_end, 'DD/MM/YYYY'), v_grace)
                  else format(
                    'Les %s jours de grâce de « %s » sont écoulés : la création '
                    || 'd''écoles et de comptes y est suspendue.',
                    v_grace, g.name)
             end,
             jsonb_build_object(
               'route', '/super/abonnements',
               'group_id', g.id,
               'threshold', -v_retard,
               'days_left', v_days_left,
               'subscription_end', v_end
             ),
             now()
      from profiles p
      where p.role = 'super_admin';
      v_alertes := v_alertes + 1;
    end if;

    v_emitted := v_emitted + 1;
  end loop;

  raise notice 'relances abonnement : % groupe(s) notifié(s), % alerte(s) plateforme',
    v_emitted, v_alertes;
end;
$function$;

-- La fonction est appelée par pg_cron (job « subscription-reminders », 06:00) et
-- par personne d'autre : rien ne justifie de l'exposer à la clé publique.
REVOKE EXECUTE ON FUNCTION public.emit_subscription_reminders()
  FROM PUBLIC, anon, authenticated;
