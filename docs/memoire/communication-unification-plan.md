---
name: communication-unification-plan
description: ✅ LIVRÉ 2026-06-12 — UN jeu de pages communication scope-aware (Messagerie WhatsApp + Annonces feed social avec onglet Agenda) partagé super_admin+admin_groupe+école ; likes/commentaires/médias inline
metadata: 
  node_type: memory
  type: project
  originSessionId: 9a353d1e-8580-4225-ac0f-9f5e98c64bd7
---

# État : ✅ LIVRÉ (2026-06-12) — analyze 0, build linux ✓, app lancée OK

Demande utilisateur : UN SEUL jeu de pages communication réutilisé partout (super_admin, admin_groupe, école), zéro doublon. WhatsApp messagerie / feed social annonces / calendrier événements.

## Décision Événements (validée par l'utilisateur : « je ne vois pas trop l'importance de la page evenements »)
**Page Événements autonome SUPPRIMÉE.** L'événementiel devient l'onglet **« Agenda »** du module **Annonces**. `StaffAnnouncementsScreen` est désormais un écran à 2 onglets : **Annonces** (feed) + **Agenda** (liste+calendrier). Raison : un calendrier natif direction existe déjà (config année scolaire) ; un événement = une publication datée → zéro page en doublon. Routes Événements (`adminEvenements`, `evenements`) repointées vers `StaffAnnouncementsScreen(initialTab: 1)`. Entrées sidebar « Événements » retirées ; libellé Annonces → « Annonces & Agenda » partout.

## Architecture livrée (NON négociable conservée : admin online / staff offline)
« Même page » = même WIDGET UI, source scope-aware dessous via `communicationContextProvider` (CommScope platform/group/school). PAS de fusion couche données.
- **Couche unifiée** = `Provider.autoDispose<AsyncValue<T>>` qui re-watch online OU offline selon scope (PAS `.stream` déprécié) :
  - `scopedMessagesProvider`, `scopedRecipientsProvider` (+ `sendMessageScoped`, `markMessageReadScoped/Unread`, `archiveMessageScoped`, `resolveScopedRecipient`)
  - `scopedAnnouncementsProvider` + `createAnnouncementScoped`/`updateAnnouncementScoped`/`setAnnouncementPinnedScoped`/`deleteAnnouncementScoped` + `announcementGroupsProvider`
  - `scopedEventsProvider` + `saveEventScoped`/`deleteEventScoped` + `eventGroupsProvider`
- **Formulaires scope-aware** (un seul dialogue chacun) : école→écriture locale `db.execute` (offline) ; admin_groupe→online sur SON groupe ; super_admin→online avec **sélecteur de groupe** (`_groupId`). `confirmDeleteAnnouncement(ref,…)` / `confirmDeleteEvent(ref,…)`.
- Écrans UNIQUES : `messagerie_staff.dart` (WhatsApp), `announcements_feed.dart` (tabs Annonces+Agenda hébergeant `EventsAgendaBody`), `events_feed.dart` (→ `EventsAgendaBody` public, plus de `StaffEventsScreen`).

## Routes (toutes câblées sur les écrans uniques)
`superMessagesInbox`/`adminMessagerie`/`messagerie` → `StaffMessagesScreen`. `superAnnonces`/`adminAnnonces`/`annonces` → `StaffAnnouncementsScreen`. `adminEvenements`/`evenements` → `StaffAnnouncementsScreen(initialTab:1)`. **`Routes.superEvenements` jamais créée — inutile désormais** (l'agenda est un onglet).

## Fichiers morts supprimés
messages_screen.dart + 6 parts ; announcements_screen.dart + 5 parts (kpis/filters/list/form/detail) ; events_screen.dart + event_form.dart + event_calendar.dart. (Restent les `*_feed*.dart` + `staff_event_calendar.dart`.)

## Social interactions (ajouté 2026-06-12, session suivante)
**Tables Supabase + PowerSync** : `announcement_reactions` (id, announcement_id, user_id, group_id, reaction, created_at) + `announcement_comments` (id, announcement_id, author_id, group_id, content, parent_id, created_at, updated_at). Ajoutées à `powersync_schema.dart` + `sync-rules.yaml` (bucket `by_group`). **Provider** : `announcement_interactions_provider.dart` — `annReactionsProvider(annId)` + `annCommentsProvider(annId)` (StreamProvider.autoDispose.family, scope-aware online/offline) ; `toggleReactionScoped`, `addCommentScoped`, `deleteCommentScoped`. **UI** : `StaffAnnCard` (ConsumerWidget) → pile d'emojis + compteurs + barre actions (👍 J'aime popup / 💬 Commenter) ; `announcement_comments_sheet.dart` (dialog 560×680 : fil threaded roots+réponses + saisie). **Média inline** : `FeedMediaGrid` + `_ImageGrid` dans `staff_feed_ui.dart` (1=full, 2=côte à côte, 3=big+2stacked, 4+=2×2+overlay). **Routes T16** : Agenda = onglet de StaffAnnouncementsScreen partout (super/admin/école) — zéro page Événements dupliquée.

## Passe « vrai réseau social temps réel » (2026-06-13)
**Annonces** : auteur réel (avatar initiales coloré par rôle + badge rôle, JOIN profiles offline SQLite & online `author:profiles!created_by`) ; compteurs par réaction (👍 5 ❤️ 3 👏 2) cliquables → dialog « Qui a réagi » (`annReactionPeopleProvider`) ; preview 1er commentaire dans la card (`annFirstCommentProvider`) ; #hashtags surlignés/cliquables (`HashtagText` → filtre le fil) ; bouton Partager (copie) ; bouton Réagir tap=like, long-press=bottom-sheet picker ; édition de commentaire (`updateCommentScoped`, RLS ann_comment_update existait).
**Messagerie** : séparateurs de jour (Aujourd'hui/Hier/date), coches ✓/✓✓ vertes DANS la bulle (heure intégrée, tooltip « Lu le… »), avatars colorés par rôle + badge rôle dans l'en-tête de fil ; rôles ajoutés au modèle (s_role/r_role offline, profiles(role) online).
**Tickets = CONVERSATION temps réel** : nouvelle table `support_ticket_messages` (ticket_id, group_id, **ticket_owner_id dénormalisé** pour sync-rules sans JOIN, author_id, body, is_from_support) + RLS (super/owner/admin_groupe) + realtime publication + migration appliquée. Provider scope-aware `ticket_thread_provider.dart` (école db.watch / admin stream) + widget partagé `ticket_thread_view.dart` (TicketThreadView inline super_admin + TicketThreadDialog admin_groupe & staff). super_admin : détail = chat + chips statut direct, realtime liste ajouté, sélection par ID (plus de modèle périmé) ; réponse support met aussi à jour `response` legacy (fallback offline tant que sync-rules pas déployées). admin_groupe : relance rouvre le ticket (`sendRequesterFollowUp`). Staff : fil offline local.
**Découpages 500 lignes** : `announcements_feed_social.dart` (réactions/preview/barre actions, 443L) extrait de cards (904→481) ; `comm_text.dart` (dates FR+rôles+HashtagText) + `feed_media.dart` (FeedMediaGrid) extraits de staff_feed_ui (773→~500, ré-exportés — imports inchangés). Helpers partagés `roleColor`/`roleLabelFr`/`initialsOf`.

## Passe « réseau social premium » (2026-06-13, soir) — Stories + Vidéo
**Décisions libs (validées)** : `video_player`+`chewie` (lecture vidéo, 751k installs) ; `story_view` 0.16.6 (viewer Stories, l'original blackmann). **PAS de Mux** (CDN payant inadapté offline-first Congo) → vidéos dans Supabase Storage. **Chat libs pub.dev rejetées** (toutes faibles + backend Firebase imposé, incompatible PowerSync) → chat custom conservé.
**Commentaires (fix)** : online utilisait `.stream()` (pas de JOIN) → avatar « ? » / nom manquant. Remplacé par `_watchCommentsOnline` = fetch `.select(*, profiles!author_id(...))` + réabonnement realtime (helper partagé annCommentsProvider + annFirstCommentProvider). `resolveAuthorName` (code mort) supprimé.
**Vidéo** : `feed_video_player.dart` — `FeedVideoThumb` (vignette play inline) + `openVideo` (dialog Chewie plein écran). `videoPlaybackSupported` = Android/iOS/macOS/Windows/Web ; **Linux desktop (dev) NON supporté** → fallback `url_launcher` externe. Intégré dans `feed_media.dart` (FeedMediaGrid : vidéos inline) + `comm_attachments.dart` (chat : vignette vidéo au lieu de chip).
**Stories** : tables `stories` (24h, image/video/text, scope-aware) + `story_views` (« vu par ») + RLS + realtime + **FK author_id→profiles OBLIGATOIRE** (sinon embed PostgREST `profiles!author_id` échoue → strip vide ; piège vérifié). `stories_provider.dart` scope-aware (école db.watch / admin online+realtime), `groupStories()` regroupe par auteur. UI : `stories_strip.dart` (bandeau « Votre story » + anneaux dégradé=non vu/gris=vu), `story_composer.dart` (mode Photo/Vidéo upload OU Texte fond coloré 8 teintes — ⚠️ TextField texte-mode DOIT avoir `filled:false` sinon le thème global force un fond blanc), `story_viewer.dart` (plein écran, `story_view` préfixé `sv` car conflit `StoryItem`, PageView par auteur, marque vues). Bandeau ajouté en tête de `announcements_feed.dart`. Sync-rules `by_group` : stories+story_views (À DÉPLOYER, PAT).
**Vérifié visuellement (super_admin Linux)** : strip rings ✓, composer texte/couleurs ✓, viewer plein écran texte violet + rôle ✓, 0 runtime error. Sidebar super_admin PLATEFORME = juste scrollée (pas un bug).
**Fix overflow** : `invoices_screen.dart` badge statut (SizedBox 80→96 + Flexible/ellipsis) — RenderFlex 7.6px réglé.
**Découpage 500** : `feed_video_player.dart`, `stories_provider.dart`, `stories_strip.dart`, `story_composer.dart`, `story_viewer.dart` tous neufs <360L.

## Chat de groupe ✅ LIVRÉ + VÉRIFItÉ (2026-06-13)
**`stream_feeds` REFUSÉ** (SaaS GetStream cloud US, online-only) → viole offline-first + souveraineté données plateforme gouvernementale. Chat custom conservé.
**DB** : `conversations` (group_id, school_id, title, is_group, avatar_url, created_by) + `conversation_members` (conversation_id, user_id, group_id, role member/admin, last_read_at) + `messages.conversation_id` (nullable=1-1 legacy) ; `recipient_id` rendu NULLABLE + CHECK (recipient_id OR conversation_id). RLS via **`is_conversation_member(uuid)` SECURITY DEFINER** (évite récursion). `msg_select` étendu aux membres. Realtime activé. **⚠️ 2 FK OBLIGATOIRES** (même piège stories) : `conversation_members.user_id→profiles` ET `stories.author_id→profiles` — sinon embed PostgREST `profiles!user_id` échoue → liste vide (vérifié : c'était la cause du groupe invisible).
**PowerSync** : tables conversations + conversation_members + colonne messages.conversation_id ajoutées au schéma ; bucket sync-rules `by_conversation` (paramétré par appartenance, sans JOIN) — **À DÉPLOYER (PAT)**.
**Providers** : `group_chat_provider.dart` (scope-aware : école db.watch / admin online+realtime) — `groupConversationsProvider`, `createGroupConversationScoped`, `sendGroupMessageScoped`. `MessageModel.conversationId`+`isGroupMessage` ajoutés ; requêtes messages (online+offline) captent les messages de groupe (membre).
**UI** : `_Conversation` devenu thread unifié (1-1 OU groupe) ; `_group()` (1-1 sans conversation_id) + `_groupThreads()` + `_mergeThreads()` triés par activité. Bouton « Nouveau groupe » → `group_create_dialog.dart` (nom + multi-sélection annuaire). Inbox : `_GroupAvatar` (dégradé navy→accent + icône groups), préfixe expéditeur dans l'aperçu, fil vide=« Nouveau groupe » italique. Thread : header avatar groupe + « N membres », bulles avec **nom expéditeur coloré par rôle** (showSender), actions archive/non-lu masquées. Group unread = 0 pour l'instant (last_read_at = enrichissement futur, évite badge collé).
**Vérifié (super_admin Linux)** : dialogue création ✓, groupe apparaît en tête inbox (avatar + « Léon : Parfait, merci Aline 👍 ») ✓, thread = séparateur jour + noms colorés Léon(navy)/Aline(bleu) + input ✓, 0 runtime error. analyze 0 / build linux ✓.

## ✅ SYNC-RULES DÉPLOYÉES (2026-06-13) — débloqué
Déploiement Cloud réussi via CLI 0.9.0 + PAT fourni par l'utilisateur. Instance connected, initial replication done, lag 0. Les 5 nouvelles tables répliquent : `stories`, `story_views`, `conversations`, `conversation_members`, `support_ticket_messages`. → staff offline reçoit désormais stories + chat de groupe + fils tickets.
**Procédure de déploiement (À RÉUTILISER)** :
- ⚠️ Le CLI déploie `powersync/sync-config.yaml` PAR DÉFAUT, mais ce fichier est PÉRIMÉ (format streams edition 3, abandonné). La VRAIE source = `powersync/config/sync-rules.yaml` (format `bucket_definitions`). TOUJOURS déployer avec `--sync-config-file-path powersync/config/sync-rules.yaml`.
- Depuis la RACINE du dépôt (le CLI cherche `powersync/` en sous-dossier du cwd) : `PS_ADMIN_TOKEN=<pat> npx powersync@latest deploy sync-config --sync-config-file-path powersync/config/sync-rules.yaml`. `cli.yaml` fournit instance/project/org.
- PAT à générer sur https://dashboard.powersync.com/account/access-tokens (NE PAS stocker en mémoire). Skills installées : `.agents/skills/powersync/`.
- ⚠️ **`now()` INTERDIT dans les sync-rules** (PowerSync ne réévalue pas dans le temps ; seuls `unixepoch()`/`datetime()` existent). La règle stories filtrait `expires_at > now()` → retiré (le client filtre l'expiration). Vérifier aussi : pas de JOIN/COALESCE/ORDER BY/LIMIT/GROUP BY dans les data queries.

## Passe « WhatsApp exact » messagerie (2026-06-13, nuit) ✅ VÉRIFIÉ
- **Look WhatsApp** (messagerie_staff_thread.dart) : fond beige `#ECE5DD` à motif points (`_ChatWallpaper`+`_DoodlePainter`), bulles **vert `#D9FDD3` sortantes / blanches entrantes** texte sombre `#111B21` avec pointe (coin sup. externe carré) + ombre, heure+coches via `_MetaStamp` (coche bleue `#53BDEB` = lu), séparateur jour pilule bleutée, barre saisie grise champ blanc arrondi + bouton envoi vert `#00A884`, panneau vide « Votre messagerie » style WhatsApp Web. Noms expéditeurs colorés par rôle (groupes).
- **FAB menu montant** (remplace la barre d'outils dupliquée « Messagerie (6 non lus) » + boutons → supprime aussi l'overflow) : `_ComposeFab`/`_MiniAction` dans messagerie_staff_inbox.dart — FAB vert `#00A884` (icône chat↔X rotation 45°=+), 2 actions montantes (Nouveau groupe vert / Nouveau message navy) + scrim de fermeture. Posé en `Positioned.fill` dans le Stack du volet liste. Le titre n'est plus que dans l'en-tête AppShell.
- **Média in-app SANS quitter la page** (`media_viewer.dart`) : `openImageLightbox` = galerie plein écran InteractiveViewer (zoom/pan) + swipe multi-images + download ; `openPdf` = `SfPdfViewer.network` plein écran (dep `syncfusion_flutter_pdfviewer ^33.2.8`, **Linux non supporté → fallback url_launcher** comme la vidéo). `openAttachment` route image→lightbox, vidéo→Chewie, pdf→viewer, autres→externe. Câblé dans `comm_attachments.dart` (chat, passe la galerie) ET `feed_media.dart` (`_Img` cliquable gallery+index). Vérifié : clic image feed → lightbox plein écran ✓.
- **Responsive** : split ≥900px (liste 340 + thread), panneau unique <900 avec flèche retour. Vérifié étroit ✓.
- analyze 0 / build linux ✓ / 0 runtime error.

## Feed Annonces « social premium 3 colonnes » (2026-06-13) ✅ VÉRIFIÉ
Réf Behance social desktop. Layout ≥1180px : feed central colonne unique (cards larges, `maxWidth 680` centré, `columns=1`) + **rail droit 332px** (`feed_right_rail.dart` `FeedRightRail`) = carte « Activité de la communauté » (Publications/Épinglées/À venir) + « Événements à venir » (scopedEventsProvider, prochains 4, pastille date) + « Tendances » (#hashtags comptés sur le contenu, top 6, cliquables→filtre). <1180px : retombe sur grille 2-col (≥980) ou 1-col. Câblé dans `announcements_feed.dart _buildBody` (centerList extrait, Row[Expanded(center) + rail]). analyze 0 / 0 runtime error.

## ⚠️ RESTE EN SUSPENS
- Purge serveur des stories expirées (cron Supabase `DELETE FROM stories WHERE expires_at < now()`) pour les retirer des appareils — la sync-rule ne filtre plus par temps.
- Enrichissement chat groupe : `last_read_at` (unread groupe = 0 actuellement).
- Doublons mineurs restants (date formatters x3, filtrage audience x2, `unified_calendar.dart` non factorisé) — dette cosmétique, non bloquante.
- Test visuel multi-rôles (proviseur/admin_groupe/super_admin) à faire connecté ; lancement + login screen OK.

Voir [[staff-support-offline]], [[modules-natifs-communication]], [[regle-taille-fichier-500]].
