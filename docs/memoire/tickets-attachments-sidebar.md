---
name: tickets-attachments-sidebar
description: Pièces jointes (images/docs de plainte) sur les tickets support + sidebar super_admin aplatie
metadata: 
  node_type: memory
  type: project
  originSessionId: 1d4bb948-3b74-4035-ad23-3f3b70cbe1b4
---

✅ 2026-06-17.

**Pièces jointes tickets** (images + documents de plainte, partout : création + fil, des deux côtés) :
- Migration : `support_tickets.attachments` + `support_ticket_messages.attachments` = `jsonb '[]'` (même format que messages/annonces : `[{name,url,mime,size,kind}]`).
- Réutilise l'infra existante : `pickAndUploadAttachments` (bucket `communication-attachments`), `MessageAttachment.toJson`/`parseAttachments`, `CommAttachmentEditList` (param `items:` + `onRemove(int index)`), `CommAttachmentView`.
- PowerSync : `Column.text('attachments')` ajouté aux 2 tables dans `powersync_schema.dart` ; décodage TEXT→jsonb dans `_jsonbColumns` du connecteur. Sync-rules = `SELECT *` → **aucun redéploiement** nécessaire (la colonne descend automatiquement).
- `TicketThreadView.onSend` change de signature → `(String body, List<MessageAttachment> attachments)`. Nouveau param `originalAttachments` (pièces jointes de la plainte initiale, rendues dans la 1re bulle). Composer = 2 boutons joindre (image/doc) + liste en attente. Modèles enrichis : `TicketMessage`, super `TicketModel`, `AdminTicket`, `StaffTicket`.
- Côté staff = offline (`createStaffTicketLocal` jsonEncode) ; l'upload des fichiers nécessite internet (le texte part hors-ligne).

**Sidebar super_admin aplatie** (`app_shell.dart`) : supprimé le déroulant « Messagerie » (route `superMessages` = `/super/messagerie`, inutilisée) → nouvelle section `COMMUNICATION` avec items directs Annonces & Agenda / Messages / Tickets support (cohérent avec admin_groupe). Code mort d'expansion retiré (`children` de `_NavItem`, `_expandedMenus`, params `trailing`/`isChild` de `_NavTile`).
