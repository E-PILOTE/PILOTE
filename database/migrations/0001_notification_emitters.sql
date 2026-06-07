-- ════════════════════════════════════════════════════════════════════════════
-- E-PILOTE CONGO — Émetteurs de notifications (triggers serveur)
-- ────────────────────────────────────────────────────────────────────────────
-- Les notifications NE sont JAMAIS saisies à la main : elles sont émises par la
-- base en réaction aux événements métier. Ce script crée un helper + des
-- triggers SECURITY DEFINER (contournent le RLS pour notifier d'autres comptes,
-- ex. les parents hors ligne).
--
-- Schéma vérifié sur la base LIVE (OpenAPI) le 2026-06-07 :
--   notifications(group_id, recipient_id, type, title, body, data jsonb, is_read,
--                 sent_at, created_at, updated_at)  — tous NOT NULL sauf data/timestamps
--   attendance_entries.status ∈ {present, absent, late}
--   bulletins.status ∈ {draft, submitted, validated, published}
--   student_payments.status ∈ {pending, confirmed, cancelled, refunded}
--   group_invoices.status ∈ {pending, paid, overdue, cancelled}
--
-- ⚠️ DÉPLOIEMENT : exécuter dans Supabase → SQL Editor (projet PILOTE
--    wqpdamlnrwgozfvzjjpo). Idempotent (réexécutable sans risque).
-- ════════════════════════════════════════════════════════════════════════════

-- ─── Helper : crée une notification (1 ligne = 1 destinataire) ────────────────
create or replace function public.emit_notification(
  p_group_id     uuid,
  p_recipient_id uuid,
  p_type         varchar,
  p_title        varchar,
  p_body         text,
  p_route        text default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_group_id is null or p_recipient_id is null then
    return;
  end if;
  insert into notifications(
    group_id, recipient_id, type, title, body, data,
    is_read, sent_at, created_at, updated_at)
  values (
    p_group_id, p_recipient_id, p_type, p_title, p_body,
    case when p_route is null or p_route = '' then '{}'::jsonb
         else jsonb_build_object('route', p_route) end,
    false, now(), now(), now());
end;
$$;

-- Résout le tuteur principal avec accès appli d'un élève (peut être NULL).
create or replace function public.primary_tutor_user(p_student_id uuid)
returns uuid
language sql
security definer
set search_path = public
as $$
  select user_id
  from student_tutors
  where student_id = p_student_id
    and user_id is not null
    and has_app_access = true
  order by is_primary_contact desc nulls last
  limit 1;
$$;

-- ════════════════════════════════════════════════════════════════════════════
-- 1) FACTURE GROUPE créée → notifie les admin_groupe du groupe
-- ════════════════════════════════════════════════════════════════════════════
create or replace function public.tg_notify_invoice()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare r record;
begin
  for r in
    select id from profiles
    where group_id = NEW.group_id and role = 'admin_groupe' and is_active = true
  loop
    perform emit_notification(
      NEW.group_id, r.id, 'invoice',
      'Nouvelle facture',
      'Facture ' || NEW.invoice_number || ' — ' ||
        to_char(NEW.amount_xaf, 'FM999G999G999') || ' FCFA à régler.',
      '/admin/abonnement');
  end loop;
  return NEW;
end;
$$;

drop trigger if exists trg_notify_invoice on group_invoices;
create trigger trg_notify_invoice
  after insert on group_invoices
  for each row execute function public.tg_notify_invoice();

-- ════════════════════════════════════════════════════════════════════════════
-- 2) PAIEMENT élève enregistré → notifie le tuteur (accusé de réception)
-- ════════════════════════════════════════════════════════════════════════════
create or replace function public.tg_notify_payment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare v_uid uuid;
begin
  v_uid := primary_tutor_user(NEW.student_id);
  if v_uid is not null then
    perform emit_notification(
      NEW.group_id, v_uid, 'payment',
      'Paiement enregistré',
      'Un paiement de ' || to_char(NEW.amount_xaf, 'FM999G999G999') ||
        ' FCFA a bien été enregistré.',
      null);
  end if;
  return NEW;
end;
$$;

drop trigger if exists trg_notify_payment on student_payments;
create trigger trg_notify_payment
  after insert on student_payments
  for each row execute function public.tg_notify_payment();

-- ════════════════════════════════════════════════════════════════════════════
-- 3) ABSENCE / RETARD saisi → notifie le tuteur
-- ════════════════════════════════════════════════════════════════════════════
create or replace function public.tg_notify_absence()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare v_uid uuid;
begin
  if NEW.status not in ('absent', 'late') then
    return NEW;
  end if;
  v_uid := primary_tutor_user(NEW.student_id);
  if v_uid is not null then
    perform emit_notification(
      NEW.group_id, v_uid, 'alert',
      case NEW.status when 'absent' then 'Absence signalée' else 'Retard signalé' end,
      case NEW.status
        when 'absent' then 'Votre enfant a été marqué absent.'
        else 'Votre enfant a été marqué en retard.' end,
      null);
  end if;
  return NEW;
end;
$$;

drop trigger if exists trg_notify_absence on attendance_entries;
create trigger trg_notify_absence
  after insert on attendance_entries
  for each row execute function public.tg_notify_absence();

-- ════════════════════════════════════════════════════════════════════════════
-- 4) BULLETIN publié → notifie le tuteur
-- ════════════════════════════════════════════════════════════════════════════
create or replace function public.tg_notify_bulletin()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare v_uid uuid;
begin
  if NEW.status = 'published' and OLD.status is distinct from NEW.status then
    v_uid := primary_tutor_user(NEW.student_id);
    if v_uid is not null then
      perform emit_notification(
        NEW.group_id, v_uid, 'system',
        'Bulletin disponible',
        'Le bulletin scolaire de votre enfant est désormais disponible.',
        null);
    end if;
  end if;
  return NEW;
end;
$$;

drop trigger if exists trg_notify_bulletin on bulletins;
create trigger trg_notify_bulletin
  after update on bulletins
  for each row execute function public.tg_notify_bulletin();

-- ════════════════════════════════════════════════════════════════════════════
-- Permissions (le helper est SECURITY DEFINER, owner = postgres → bypass RLS)
-- ════════════════════════════════════════════════════════════════════════════
revoke all on function public.emit_notification(uuid, uuid, varchar, varchar, text, text) from public;
revoke all on function public.primary_tutor_user(uuid) from public;
