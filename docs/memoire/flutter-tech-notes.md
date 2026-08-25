---
name: flutter-tech-notes
description: "Points techniques Flutter/Supabase non-évidents (schémas de tables, pièges API) — référence détaillée"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 1094ad61-3536-4f38-a312-7a097ec9bbfb
---

Notes accumulées (beaucoup recoupent CLAUDE.md ; ici = détails schéma + pièges).

## API / lints
- `inFilter()` (pas `in_()`) — postgrest 2.7.0 ; `.count(CountOption.exact)` chaîné.
- `CardThemeData` (pas `CardTheme`) — Flutter 3.44 ; `.withValues(alpha:)` (pas `withOpacity`).
- `PostgresChangeEvent` nécessite `import 'package:realtime_client/realtime_client.dart'`.
- `skipLoadingOnReload:true` + `skipLoadingOnRefresh:true` dans `AsyncValue.when` → refresh sans spinner.
- `dart:ui as ui` si conflit `Path` avec `flutter_map` (exporte `Path<LatLng>`).
- `FutureProvider.autoDispose.family<T,String>` pour providers paramétrés avec cache.
- Pas de ticker 60s — Realtime Supabase suffit. Border-radius 8px boutons/inputs, 12px cartes.
- `service_role` JAMAIS dans Flutter.

## Syncfusion BarSeries — RÈGLE ABSOLUE
`primaryXAxis: CategoryAxis` ← `xValueMapper` (String) ; `primaryYAxis: NumericAxis` ← `yValueMapper` (double). Inverser = crash runtime `String is not a subtype of num`. BarSeries transpose visuellement mais les mappings restent x=catégorie/y=valeur.

## AdminStatCard overflow
Toujours `maxLines:2` + `TextOverflow.ellipsis` sur label ET subtitle → évite RenderFlex bottom overflow.

## Schémas de tables (live)
- `profiles` : id(=auth uid), group_id?, school_id, role(enum user_role, PAS de 'utilisateur'), access_profile_id?, first_name/last_name NOT NULL, phone, employee_number, is_active, last_login, avatar_url, fcm_token. **PAS de colonne email** (vit dans auth.users → RPC `get_group_users`/`get_platform_admins`). Admin groupe = role='admin_groupe' AND group_id=X AND is_active.
- `student_tutors` (pas `guardians`).
- `announcements.is_published` (pas `status`).
- `public.messages` : id, group_id, sender_id, recipient_id, subject?, body, is_read, read_at, parent_message_id, is_archived, created_at, updated_at (PAS topic/inserted_at). group_id/sender_id/recipient_id/body NOT NULL. RLS insert `msg_insert` = `is_super_admin() OR (group_id=auth_group_id() AND sender_id=auth.uid())`.
- `notifications` : id, group_id, recipient_id, type, title, body, data(jsonb), is_read, read_at, sent_at, fcm_message_id, created_at, updated_at. **PAS de user_id**. group_id+recipient_id+type+title+body NOT NULL → 1 notif = 1 ligne/destinataire. RLS `notif_access`.
- `audit_logs` : id, group_id, school_id, user_id, user_role(enum), action(varchar libre), table_name(varchar), record_id, old_values, new_values, ip_address(inet), user_agent, created_at. ⚠️ résoudre l'acteur via `profiles(id,first_name,last_name)` — PAS profiles(email). RLS scope group_id.
- `group_settings` (par groupe, admin_groupe) : PK group_id, colonnes general/notifications/security jsonb NOT NULL + updated_by/updated_at. Écriture = upsert `onConflict:'group_id'` via `AdminSettingsService`. RLS SELECT=groupe, INSERT/UPDATE=`is_admin_groupe() AND group_id=auth_group_id()`. Pas de settings globale plateforme.
- `group_invoices` NOT NULL : group_id, invoice_number, amount_xaf, period_start, period_end, status, created_by, created_at, updated_at. RLS write = `is_super_admin()`.

## Finance
- Enum `payment_method` = mtn_money, airtel_money, visa, especes ; `invoice_status` = pending, paid, overdue, cancelled.
- **Reçus = factures payées** : un reçu n'est PAS une table — ligne `group_invoices` avec status='paid' (paid_at, payment_method, payment_reference, receipt_number='REC-...'). Voir `recordInvoicePayment()` + `unpaidInvoicesProvider`.
- Service PDF officiel : `lib/features/super_admin/services/financial_pdf_service.dart` → `ReceiptPdfService`+`InvoicePdfService` (pattern `subscription_pdf_service.dart` : emblème logo.svg, bandeau tricolore, footer). Chrome partagé staff = `core/services/official_pdf_kit.dart` (`OfficialPdfKit`) + aperçu `core/widgets/pdf_preview_dialog.dart` (`showPdfPreviewDialog`).

## Système éducatif (cycles/filières/niveaux)
`education_cycles` / `education_programs` (filières) / `education_levels` (program_id NULL = niveau général) + jonctions `school_cycles` / `school_education_programs` / `school_education_levels`. group_id NULL = référentiel global (RLS : non modifiable admin_groupe ; cycles = write super_admin). Seedé : 5 cycles, 16 niveaux généraux, 21 filières FP, 63 niveaux FP. ⚠️ `school_levels` (catalogue, FK classes.level_id) et `school_programs` (SYLLABI subject/level/title/content) PRÉEXISTENT avec un AUTRE sens → d'où `school_education_*` pour les jonctions ; NE PAS toucher les 2 anciennes.
