---
name: realtime-publication-requirement
description: Supabase Realtime exige que chaque table écoutée soit dans la publication supabase_realtime — piège récurrent communication
metadata: 
  node_type: memory
  type: project
  originSessionId: 9a353d1e-8580-4225-ac0f-9f5e98c64bd7
---

⚠️ **Piège récurrent** : `onPostgresChanges(...)` et `.stream(primaryKey:)` côté Flutter ne reçoivent RIEN si la table n'est pas dans la publication Postgres `supabase_realtime`. Le code peut être parfait — sans la publication, zéro événement.

**Bug résolu 2026-06-14** : la messagerie n'affichait pas les messages en temps réel (super_admin/admin_groupe). Cause = `messages`, `announcements`, `announcement_comments`, `announcement_reactions`, `events`, `notifications`, `support_tickets` **absentes** de la publication. Migration `realtime_publish_communication_tables` : `ALTER PUBLICATION supabase_realtime ADD TABLE ...` + `REPLICA IDENTITY FULL` (pour que UPDATE/DELETE portent l'ancienne ligne et respectent les filtres `.eq()` comme reactions par announcement_id).

**Vérifier** : `SELECT tablename FROM pg_publication_tables WHERE pubname='supabase_realtime';`
État OK = 13 tables publiées (les 7 ci-dessus + conversations, conversation_members, saved_announcements, stories, story_views, support_ticket_messages).

**Règle** : toute nouvelle table écoutée en Realtime → l'ajouter à la publication, sinon le live ne marche pas. Côté offline (PowerSync `db.watch()`), ça ne concerne pas — c'est uniquement le chemin online Supabase.

Voir [[communication-unification-plan]], [[staff-support-offline]].
