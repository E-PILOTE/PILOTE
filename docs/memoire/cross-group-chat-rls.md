---
name: cross-group-chat-rls
description: Chats cross-groupe (coordination nationale) — fix RLS msg_insert + filtre client messagesProvider
metadata: 
  node_type: memory
  type: project
  originSessionId: 1d4bb948-3b74-4035-ad23-3f3b70cbe1b4
---

Les **conversations de groupe peuvent être cross-groupe** : le super_admin crée des chats de « coordination nationale » (`conversations.group_id` = un groupe donné) incluant des `admin_groupe` d'AUTRES groupes comme membres (ex. vianney MELACK, groupe `da3954ca`, membre d'un chat `group_id=a2000000`).

**Bug résolu 2026-06-20** : impossible d'envoyer dans ces chats (PostgrestException 42501).
Cause = double trou (pas une session expirée) :
1. **RLS `msg_insert`** exigeait `group_id = auth_group_id()` → rejet car le `group_id` de la conversation ≠ groupe de l'expéditeur. `msg_select`/`msg_update` autorisaient déjà les membres via `is_conversation_member()`, mais PAS l'insert. **Fix appliqué en prod** (`ALTER POLICY`, voir aussi `database/schema.sql`) :
   `is_super_admin() OR (group_id=auth_group_id() AND sender_id=auth.uid()) OR (conversation_id IS NOT NULL AND sender_id=auth.uid() AND is_conversation_member(conversation_id))`.
2. **Filtre client** `messagesProvider` (messages_provider.dart) faisait `.eq('group_id', ctx.groupId)` pour admin_groupe → cachait les messages cross-groupe. Remplacé par `.or('group_id.eq.<grp>,conversation_id.not.is.null')` (la RLS `msg_select` borne déjà la visibilité aux convs dont on est membre).

Vérification possible sans écrire en prod : transaction `BEGIN READ ONLY` + `SET LOCAL role authenticated` + `SET LOCAL request.jwt.claims='{"sub":"<uid>","role":"authenticated"}'` puis SELECT du prédicat de policy (donne `auth.uid()`/`auth_group_id()` réels). Le classifier auto-mode bloque tout INSERT (même ROLLBACK) → rester en read-only.

Voir aussi [[realtime-publication-requirement]], [[communication-unification-plan]]. Bug d'affichage corrigé en même temps : `_Conversation.last`/`.first` sur un **groupe vide** → `Bad state: No element` (StateError) ; ajout de `lastOrNull`/`firstOrNull` + garde dans `messagerie_staff_thread.dart didUpdateWidget`. Envoi en échec affiche désormais « Session expirée — reconnectez-vous » (compose + thread) au lieu de planter.
