---
name: annonces-feed-fixes
description: "Refonte feed Annonces (responsive, FAB, inline comments) + causes racines DB (realtime + FK profiles) des likes/commentaires cassés"
metadata: 
  node_type: memory
  type: project
  originSessionId: 1d4bb948-3b74-4035-ad23-3f3b70cbe1b4
---

Refonte page **Annonces & Agenda** (`features/communication`) le 2026-06-16, scope super_admin/admin_groupe (online).

**UI livré :**
- Rail droit « Vue d'ensemble » = tuiles KPI compactes (teinte 6%) au lieu de gros `AdminStatCard` empilés (corrige overflow 453px + « grosses parties bleues »). Voir `feed_right_rail.dart`.
- Barre recherche/tri 2 zones (search plafonnée 560 + Wrap de filtres) → jamais d'overflow.
- Fil publications : **1 colonne**, 2 colonnes uniquement si centre ≥ 1300px (27"+). `announcements_feed.dart`.
- FAB rouge « Publier » (radius 8 + halo pulsant) bas-droite ; le bouton « Nouvelle publication » du rail gauche a été retiré.
- Formulaire : option **« Toutes les écoles (tout le monde) »** = sentinelle `kAllGroupsSentinel` → fan-out 1 annonce par groupe ; **aperçu live** avant publication ; section pièces jointes multi-fichiers (rien ne publie tant qu'on n'appuie pas Publier).
- **Page détail = SUPPRIMÉE** (`StaffAnnDetailDialog` retiré) : tout est dans le fil, façon réseau social. Carte non cliquable globalement.
- **Commentaires INLINE** (`widgets/inline_comments.dart`) : s'ouvrent/étirent la carte dans la page, plus jamais de modal. `StaffAnnCard` est devenu `ConsumerStatefulWidget` (`_commentsOpen`).

**Causes racines DB (corrigées par migrations) — les « likes/commentaires/actions ne marchent pas » :**
1. `announcements`, `announcement_reactions`, `announcement_comments`, `saved_announcements` n'étaient **PAS dans `supabase_realtime`** → les `.stream()` / canaux realtime ne se rafraîchissaient jamais. Ajoutées à la publication (+ REPLICA IDENTITY FULL pour les 3 interactions). Voir [[realtime-publication-requirement]].
2. `announcement_comments.author_id` et `announcement_reactions.user_id` avaient une FK vers **`auth.users` et non `profiles`** → embed PostgREST `profiles!author_id` échouait (`PGRST200 Could not find a relationship`). Ajouté FK `..._author_profile_fkey` / `..._user_profile_fkey` vers `profiles(id)` (0 orphelin). C'est le **pattern du projet** : embarquer le profil via FK→profiles (cf. `announcements.created_by` qui marchait déjà).
3. **Le realtime Postgres Changes ne délivrait PAS** malgré la publication (messages OK mais pas ces tables) → les likes/commentaires s'inséraient en base mais l'UI ne se rafraîchissait jamais (« j'ai commenté, rien ne se passe »). **Fix fiable = invalider le provider après CHAQUE mutation** (ne pas dépendre du realtime) :
   - `announcementsProvider` après create/update/delete/pin (online).
   - `annReactionsProvider(annId)` + `annReactionPeopleProvider(annId)` dans `toggleReactionScoped` → likes instantanés (vérifié en direct : toggle ❤️/👍 met à jour le compteur immédiatement).
   - `annCommentsProvider(annId)` + `annFirstCommentProvider(annId)` dans `addCommentScoped` et via `_refresh()` dans `inline_comments.dart` (edit/delete).

**Autres ajustements 2026-06-16 (2e passe) :**
- Feed = **`ListView.builder` LAZY** en 1 colonne (cas courant) ; grille masonry eager seulement ≥1300px (rare). Helper `_annCard()` partagé.
- Commentaire : **Entrée = envoyer**, Maj+Entrée = nouvelle ligne (`Shortcuts`/`Actions` + `_SendIntent`, `SingleActivator(enter)`).

**3e passe 2026-06-16 (statuts + rail gauche) :**
- **Statuts (Stories) RETIRÉS de la page Annonces** (décision user : page institutionnelle = formelle/persistante, le statut éphémère 24h est un registre de Messagerie, pas d'Annonces). `StoriesStrip` + son import enlevés d'`announcements_feed.dart`. ⚠️ **Code/tables conservés** (réactivables) : `widgets/stories_strip.dart`, `screens/story_viewer.dart`, `widgets/story_composer.dart`, `providers/stories_provider.dart` + tables `stories`/`story_views` → désormais ORPHELINS (plus aucun import) mais valides. Si on veut les statuts un jour → les brancher dans la **Messagerie**.
- Rail gauche `feed_left_rail.dart` : `_IdentityCard` affiche enfin la **photo de profil** (`avatar_url` via `CachedNetworkImage`, fallback initiales) — avant : initiales seules alors que rail droit/composer la montraient (incohérence). Bouton mort « Nouvelle publication » de `_NavCard` (jamais affiché depuis le FAB, `onPublish` toujours null) **supprimé** + param `onPublish` retiré de `FeedLeftRail`/`_NavCard`. Reste du rail jugé complet (identité/nav compteurs live/communauté+présence). analyze 0 issue.

**4e passe 2026-06-16 (média carrousel + overflow rail + cartes hautes) — VÉRIFIÉ EN DIRECT (super_admin) :**
- **Médias = carrousel slide** (`feed_media.dart` réécrit → `FeedMediaCarousel`, remplace la mosaïque) : `PageView.builder` LAZY images+vidéos mélangées, **flèches ‹ › au survol** (MouseRegion+AnimatedOpacity), **compteur « i / N »** (top-right), **points indicateurs** animés (bas). 1 média → plein cadre sans chrome. Image tap → lightbox zoom/slide (sous-ensemble images) ; vidéo → `FeedVideoThumb`/`openVideo` confiné. **Hauteur média portée à 440px** (`_kMediaHeight`, façon réseau social sans plein écran TikTok ; avant 240 fixe). Images via `SignedNetworkImage` (buckets privés + cache offline). Testé live : compteur 1/4→2/4, flèches OK, image 2 chargée. ⚠️ vidéo non testée (pas de vidéo en données ; `video_player` indispo sur Linux dev → fallback externe, normal).
- **3e colonne OVERFLOW corrigé** (`feed_right_rail.dart`) : le rail était un `Column` + agenda `Expanded` → l'état vide de l'agenda débordait (« BOTTOM OVERFLOWED » constaté). Rail rendu **scrollable** (`ListView`) ; `_AgendaCard` n'utilise plus `Expanded`/ListView interne mais une `Column` (max 8 events). Plus aucun overflow (vérifié live, fenêtre 2560×1368).
- `_AuthorAvatar` (cartes, `announcements_feed_cards.dart`) affiche la **photo auteur** (`avatar_url` via `CachedNetworkImage`) — testé : avatar lion visible.
- Rail droit enrichi d'une carte **« Contributeurs actifs »** (top auteurs par nb de publications + part %, dérivée des annonces, 0 requête).
- ⚠️ **Piège GUI** : au lancement, le sidebar super_admin n'affichait PAS la section PLATEFORME (Messagerie/Annonces) → **code obsolète à l'exécution** ; un **hot restart** (DTD) recharge le code et la section apparaît. Toujours hot-restart après lancement avant de conclure à un bug d'UI. Login auto via **xclip + Ctrl+V** (le paste GTK marche, `xdotool type` non). super_admin → Annonces via PLATEFORME › Messagerie (chevron pour déplier) › Annonces & Agenda.

**5e passe 2026-06-16 (VIDÉO media_kit + visionneuse unifiée) — VALIDÉ EN DIRECT :**
- **`video_player` REMPLACÉ par `media_kit`** (libmpv). Cause vérifiée du « la vidéo ne marche pas » : le manifeste de `video_player` ne déclare QUE android/ios/macos/web → **aucun moteur Linux/Windows desktop** (et le code prétendait à tort supporter Windows). `media_kit` couvre **toutes** les plateformes Linux compris. Ajouté `media_kit`/`media_kit_video`/`media_kit_libs_video` ; `MediaKit.ensureInitialized()` dans `main.dart` ; `feed_video_player.dart` réécrit (`_VideoDialog` + `InlineVideoPlayer` via `Player`/`VideoController`/`Video`) ; `videoPlaybackSupported = true`. ⚠️ **Build Linux exige `libmpv-dev`** (pkg-config `mpv` ; installé 2.2.0) en plus de la lib runtime ; sinon CMake « PkgConfig::mpv not found ». `video_player`/`chewie` plus utilisés (laissés dans pubspec). **Testé live** : annonce publiée avec vidéo → lecture de la mire (play/pause, seek, 00:06/00:06, plein écran) **inline confinée** sur Linux. ⚠️ media_kit = **rebuild complet obligatoire** (natif), pas un hot restart.
- **Visionneuse plein écran UNIFIÉE** (`media_viewer.dart` → `openMediaViewer`, `_MediaViewer`) : carrousse **images ET vidéos** (avant `_Lightbox` = images seules). Swipe + flèches ‹ › + compteur « i/N » + points ; image = zoom `InteractiveViewer` ; page vidéo ACTIVE seulement = `InlineVideoPlayer` (1 lecteur à la fois). `openImageLightbox` délègue désormais à `openMediaViewer`. Le carrousel inline (`feed_media.dart`) ouvre cette visionneuse sur l'élément cliqué (tous éléments navigables). **Testé live** : post 4 images → 1/4 → 2/4 via flèche, points OK.
- Fix avertissement runtime cosmétique : `SwitchListTile` « Épingler » du compositeur enveloppé dans `Material(type: transparency)` (assertion « ListTile background… » éliminée). Pré-existant, sans rapport avec le média.
- **Outil test** : publier une vidéo via le compositeur = clic « Ajouter… » ouvre le **file chooser GTK natif** (≠ Flutter) où `xdotool` MARCHE : `Ctrl+L` + taper le chemin + Entrée. Vidéo test générée par `ffmpeg` (`testsrc`).

**6e passe 2026-06-16 (gestion publications + médias) :**
- **`is_archived`** ajouté à `announcements` (migration) → champ `AnnouncementDetail.isArchived`, `setAnnouncementArchivedScoped`, exclu du fil sauf vue « Mes publications » ; menu carte Archiver/Désarchiver + badge « archivé ».
- **« Mes publications »** (rail gauche, `FeedShortcut.mine`, `showMine=canManage`) + **contributeurs cliquables** (rail droit, clé=`createdBy`, `onSelectAuthor` → filtre fil + bannière `_AuthorFilterBanner` « Publications de X »).
- **Suppression par document** : `removeAttachmentScoped(ref, ann, att)` (réécrit la liste attachments) ; ✕ `AttachmentRemoveBadge` sur chaque média/PDF/doc des publications gérables (`FeedMediaGrid.manageable/onRemove`) + confirm `confirmRemoveAttachment`.
- **Feedback actions** : `runFeedAction(context, action, running, success)` (staff_feed_ui) = bandeau spinner → vert succès / **ROUGE avec message** ; câblé sur delete/archive/pin/retrait-doc. Révèle toute erreur (plus de silence).
- **Lien chat** : icône `chat_bubble` → `context.go('<messagerieRoute>?peer=<authorId>')` ; `StaffMessagesScreen(initialPeerId)` ouvre la conv EXISTANTE. ⚠️ NE PAS synthétiser un fil vide (`_ThreadView` lit `conv.first/last` → crash). ⚠️ Scope **plateforme** = messagerie cible des GROUPES (admins), pas des users → chat direct avec un auteur super_admin ne mappe pas (OK en scope école).
- **Régression PDF corrigée** : envelopper `PdfInlinePreview` dans un `Stack` au niveau Column lui faisait perdre la pleine largeur (stretch) → ✕ déplacé À L'INTÉRIEUR + `width: double.infinity`.
- ⚠️ Cause probable du « delete ne marche pas » signalé : **4 posts identiques** (fan-out « Toutes les écoles ») → supprimer 1 en laisse 3. DB/RLS (`announce_write` ALL + FK cascade + compte super_admin) autorisent bien la suppression ; `supabaseClientProvider`=client authentifié.

⚠️ **Test GUI Linux** : `xdotool type`/`key` n'atteint PAS les `TextField` Flutter-GTK (le champ se focus mais ne reçoit aucun texte — IM context). Impossible de tester la SAISIE au clavier via automation ; tester les clics/toggles oui (likes vérifiés). Voir [[gui-testing-linux]].

RLS `announce_write` = `is_super_admin() OR (group_id=auth_group_id() AND (is_admin_groupe() OR school_id=auth_school_id()))` → super_admin gère tout, OK.

Compression médias déjà robuste (`media_compression.dart`) : images ≤1600px JPEG q80, vidéos ~720p (mobile only), plafond 25 Mo après compression.
