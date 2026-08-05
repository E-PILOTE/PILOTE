---
name: staff-support-offline
description: Espace Support staff + refonte communication staff (pièces jointes, KPI, publication direction) 2026-06-12 — ⚠️ sync-rules PAS encore déployées (PAT requis)
metadata: 
  node_type: memory
  type: project
  originSessionId: 9a353d1e-8580-4225-ac0f-9f5e98c64bd7
---

## Refonte communication staff (2026-06-12, retour utilisateur « parité admin_groupe »)

- **Pièces jointes partout** (messages + annonces + événements) : colonne `attachments jsonb DEFAULT '[]'` ajoutée à `announcements`/`events` (migration `communication_attachments`) ; `messages.attachments` préexistait. Bucket Storage `communication-attachments` créé (public, write authenticated) ; `message-attachments` préexistant. Format partagé `[{name,url,mime,size,kind}]`, kind ∈ image|audio|video|file.
- **⚠️ Connecteur PowerSync** : `_decodeJsonbColumns()` dans `powersync_connector.dart` — toute colonne jsonb stockée en TEXT SQLite DOIT être `jsonDecode`ée avant l'upsert, sinon Postgres jsonb reçoit une CHAÎNE au lieu du tableau. Map `_jsonbColumns` : messages/announcements/events→attachments, notifications→data. À étendre pour toute future colonne jsonb synchronisée.
- **Module partagé** `communication/widgets/comm_attachments.dart` : `CommAttachmentView` (images inline CachedNetworkImage → cache offline ; audio/vidéo/docs en chips → url_launcher app externe), `CommAttachmentEditList`, `CommEmojiPicker`, `pickAndUploadAttachments()` (file_picker, max 25 Mo, message offline clair). `parseAttachments()` public dans messages_provider (List jsonb ET String TEXT local).
- **Publication direction offline-first** : `directionRoles` publie/modifie/supprime/épingle annonces + crée/modifie/supprime événements de SON école (RLS live `announce_write`/`events_tenant` = school_id=auth_school_id() — aucun changement DB requis). Actions locales `createSchoolAnnouncementLocal`/`createSchoolEventLocal` etc. Texte hors-ligne ✅ ; pièces jointes = internet requis (Storage).
- **Pages staff** : Annonces (KPI ×4, sélection multiple direction → épingler/dépingler/supprimer, menu carte, badge 📎), Événements (KPI ×4, menu gestion, formulaire date/heure/lieu/audience), Messagerie (KPI ×4, multi-sélection conversations → archiver/marquer lu, trombone+emoji fil ET composer, bulles avec pièces jointes), Support (donut Syncfusion statuts ≥1100px à côté des filtres).
- **Découpages règle 500** : announcements_feed_cards/form, events_feed_cards/form, messagerie_staff_inbox (part). 0 lint, build ✓.

✅ 2026-06-12 — Espace Support du personnel scolaire (symétrique admin_groupe), 100 % offline-first :
- `features/user/providers/staff_support_provider.dart` — `db.watch` sur `support_tickets WHERE submitted_by = uid` + `createStaffTicketLocal()` (insert local, upload à la sync).
- `features/user/screens/staff_support_screen.dart` (313 l.) + `widgets/staff_support_widgets.dart` (266 l. : TicketDetailDialog, CreateTicketDialog, ticketStatusInfo/PriorityInfo) — découpage règle 500 lignes.
- Route `/user/support`, sidebar SYSTÈME (personnel only, ni élève ni parent).
- RLS live vérifiée : `group_insert_tickets` autorise tout membre du groupe (submitted_by = auth.uid()) — aucune migration.
- `powersync_schema.dart` : table `support_tickets` ajoutée. `sync-rules.yaml` bucket `by_user` : `SELECT * FROM support_tickets WHERE submitted_by = bucket.uid`.

⚠️ **DÉPLOIEMENT EN ATTENTE** : sync-rules modifiées mais PAS déployées sur PowerSync Cloud — sans ça, support_tickets ne synchronise pas. Commande (depuis `powersync/`, PAT fourni par l'utilisateur) :
`PS_ADMIN_TOKEN=<pat> npx powersync deploy sync-config --instance-id 6a185941234fa2bf51a66757 --project-id 6a18593de63d960007e81e7b --sync-config-file-path config/sync-rules.yaml`

Aussi livré même session :
- Pleine largeur partout côté staff : suppression des `Center>ConstrainedBox` (1280 feeds annonces/événements, 960 profil/paramètres) ; annonces 3 colonnes ≥1750px.
- Login offline durci : `signIn()` ([[bug-powersync-role-utilisateur]] auth_provider) détecte les erreurs réseau (`AuthRetryableFetchException`/SocketException/ClientException…) → message français clair (« la session déjà ouverte reste active hors-ligne »). Le cold-start offline (`_init()` session persistée + profil local) marchait déjà — ne pas y toucher.
