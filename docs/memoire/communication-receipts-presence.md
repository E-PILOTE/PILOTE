---
name: communication-receipts-presence
description: "Accusés de lecture groupe + compteur non-lus groupe + présence en ligne (Messagerie), 2026-06-15"
metadata: 
  node_type: memory
  type: project
  originSessionId: 9a353d1e-8580-4225-ac0f-9f5e98c64bd7
---

✅ 2026-06-15 — Messagerie WhatsApp complétée : accusés de réception de groupe, compteur de non-lus de groupe, présence « en ligne ». Scope-aware (école PowerSync / admin online), 0 lint, build Linux ✓, hot reload sans erreur runtime.

**Source de vérité lecture groupe = `conversation_members.last_read_at`** (1 horodatage/membre ; RLS `conv_members_update` = `user_id = auth.uid()` → chacun met à jour SA ligne ; table dans `supabase_realtime` ✓ et dans `powersync_schema.dart` ✓). À l'ouverture d'un fil de groupe → `markConversationReadScoped` pousse mon `last_read_at = now()`.

Nouveaux fichiers :
- `providers/conversation_read_provider.dart` — `ConvReadState` (convId→userId→DateTime), `conversationReadProvider` (StreamProvider scope-aware : école=db.watch, admin=Supabase+realtime sur conversation_members), `markConversationReadScoped`. Méthodes : `unreadCount`, `readByCount`, `myLastRead`.
- `providers/presence_provider.dart` — `onlinePresenceProvider` (Set<String> des uid en ligne) via **Realtime Presence** (aucune table, aucune écriture), canal borné au groupe (`presence:grp:<groupId>`, sinon `presence:platform`). `channel.track({'user_id': myId})` après subscribe ; `presenceState()` agrégé sur sync/join/leave. Éphémère → rien à synchroniser offline ; marche dès qu'on est connecté.

UI :
- Non-lus groupe : `_Conversation.unread()` pour les groupes = messages des autres dont `created_at > myGroupLastRead` (badge vert sur la tuile + filtres Non lus/Groupes).
- Accusés groupe : `_MetaStamp` reçoit `groupReadBy`/`groupReadTotal` → ✓✓ bleu quand tous les autres ont lu, sinon ✓ gris + compteur « N/M ». Menu bulle « Infos de lecture » → feuille `_showReadInfo` (membres Lu / Non lu).
- Présence : `_PresenceAvatar` (pastille verte 0xFF00C853) sur tuiles 1-à-1 + avatar d'en-tête ; sous-titre « en ligne » (vert) dans le fil quand l'interlocuteur est connecté.

⚠️ Comparaison de dates : `messages.created_at` côté école est local-naïf (sans Z), `last_read_at` écrit en UTC+Z → `DateTime.parse` traite le naïf comme local puis `.toUtc()` donne le bon instant ; comparaisons cohérentes. NE PAS « corriger » en forçant un fuseau.

Vérifié en base live (groupe « Coordination pédagogique 3e ») : la requête `count(*) where sender<>moi and (last_read is null or created_at>last_read)` = exactement ce que calcule le provider (Ramsès 4, Léon 7, Aline 9). Badge non-lu vert visible à l'écran. Voir [[communication-media-compression]], [[realtime-publication-requirement]], [[communication-unification-plan]].
