---
name: super-dashboard-status
description: État complet du Super Admin — pages implémentées, routes câblées, logique métier, 0 erreurs
metadata: 
  node_type: memory
  type: project
  originSessionId: cf900063-f65b-41b2-9d16-fdd9bffe6e3c
---

## Super Admin — Pages implémentées ✅ (2026-05-31)

### Toutes les routes câblées (plus aucun placeholder)
| Route | Fichier écran | Provider |
|---|---|---|
| `/super/dashboard` | `super_dashboard_screen.dart` | `super_dashboard_provider.dart` |
| `/super/groupes` | `school_groups_screen.dart` | `school_groups_provider.dart` |
| `/super/administrateurs` | `administrators_screen.dart` | `administrators_provider.dart` |
| `/super/modules` | `modules_screen.dart` | `modules_provider.dart` |
| `/super/plans` | `plans_screen.dart` | `plans_provider.dart` |
| `/super/abonnements` | `subscriptions_screen.dart` | `subscriptions_provider.dart` |
| `/super/factures` | `invoices_screen.dart` | `invoices_provider.dart` |
| `/super/recus` | `receipts_screen.dart` | `receipts_provider.dart` |
| `/super/modes-paiement` | `payment_methods_screen.dart` | `payment_methods_provider.dart` |
| `/super/audit` | `audit_screen.dart` | `audit_provider.dart` |
| `/super/messagerie/annonces` | `announcements_screen.dart` | `announcements_provider.dart` |
| `/super/messagerie/messages` | `messages_screen.dart` | `messages_provider.dart` |
| `/super/messagerie/tickets` | `tickets_screen.dart` | `tickets_provider.dart` |
| `/super/notifications` | `notifications_screen.dart` | `notifications_provider.dart` |
| `/super/rapports` | `reports_screen.dart` | `reports_provider.dart` |
| `/super/carte` | `national_map_screen.dart` | `national_map_provider.dart` |
| `/super/ia` | `ai_screen.dart` | inline |
| `/super/parametres` | `settings_screen.dart` | StateProvider local |
| `/super/profil` | `profile_screen.dart` | Supabase auth direct |

### Caching — tous les providers ont ref.keepAlive()
Navigation = zéro rechargement. Providers avec keepAlive :
`invoicesProvider`, `receiptsProvider`, `reportsProvider`, `paymentMethodsProvider`,
`ticketsProvider`, `messagesProvider`, `notificationsProvider`, `nationalMapProvider`

Warmup dans `AppShell.initState` : `notificationsProvider` + `messagesProvider`

### Logique métier DB (migrations appliquées)
- **Trigger** `fn_auto_create_invoice` (AFTER INSERT on school_groups) :
  - Plan gratuit → groupe activé directement
  - Plan payant → facture `pending` créée automatiquement via `generate_invoice_number()`
- **RPC** `mark_invoice_paid(p_invoice_id, p_payment_method, p_payment_ref, p_notes)` → JSONB
  - Met à jour facture → `paid`, `paid_at`, `payment_method`
  - Active le groupe : `subscription_status = 'active'`
  - Crée notification dans `notifications`
  - Retourne `{success, receipt_number, group_id, amount_xaf}`
- **RPC** `get_group_module_access(p_group_id)` → TABLE
  - Colonnes : `module_id, module_name, module_slug, module_icon, category_id, category_name, is_accessible, access_reason`
  - `trial/active` → accessible, sinon → verrouillé
- **Backfill** : 7 groupes existants ont reçu leurs factures manquantes

### Factures — Flux de paiement complet
1. Bouton "Marquer payée" → `_PaymentConfirmDialog`
2. Dialog : montant XAF, 4 modes (especes/mtn_money/airtel_money/visa), référence, notes
3. Appel RPC `mark_invoice_paid`
4. Invalidation : `invoicesProvider`, `schoolGroupsProvider`, `notificationsProvider`
5. SnackBar avec numéro de reçu

### Reçus — Source de données
- Table `group_invoices` filtrée sur `status = 'paid'`
- `receiptNumber` calculé : `'REC-' + invoiceNumber.replaceFirst('INV-', '')`
- **5 reçus en base, total 3 200 000 XAF**

### Groupes — Onglet Abonnement
- `_SubscriptionTab` converti en `ConsumerWidget`
- Affiche modules du plan via `groupModuleAccessProvider(groupId)` (FutureProvider.family)
- Groupés par catégorie, badge ✓ vert / 🔒 gris, compteur accessible/total

### Notifications
- `NotificationsData` : total, unread, byType, todayCount, weekCount
- `notifBadgeProvider` : badge dynamique dans AppShell header
- Page : panneau KPIs gauche + timeline droite groupée par date
- `markNotificationRead` / `markAllNotificationsRead` via Supabase

### Messages — table public.messages (colonnes réelles)
`id, group_id, sender_id, recipient_id, subject, body, is_read, read_at, parent_message_id, is_archived, created_at, updated_at`
⚠️ PAS de colonne `topic` ni `inserted_at` (celles-là sont dans `realtime.messages`)

### Règles design appliquées
- Border-radius **8px universel** sur tous les boutons et champs de saisie
- Cards/containers peuvent avoir 12px, avatars 50%
- Couleurs : Navy `#1E3A5F`, Green `#009A44`, Gold `#FBBC04`

### Tables DB principales
- `group_invoices` : statuts `pending/paid/overdue/cancelled` (enum `invoice_status`)
- `payment_method` enum : `mtn_money/airtel_money/visa/especes`
- `subscription_status` enum : `trial/active/suspended/expired/cancelled`
- `notifications` : `id, group_id, type, title, body, is_read, read_at, sent_at, created_at`
- `school_groups` contient `plan_id`, `subscription_status`, `subscription_start/end`
