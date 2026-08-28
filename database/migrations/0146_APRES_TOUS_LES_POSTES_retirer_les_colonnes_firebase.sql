-- ════════════════════════════════════════════════════════════════════════════
--  0146 — RETIRER LES DEUX COLONNES FIREBASE
--
--  ⚠️⚠️ NE PAS APPLIQUER AUJOURD'HUI. Lire « QUAND » plus bas.
--
--  ── LA DÉCISION (2026-08-29) ──────────────────────────────────────────────
--  La plateforme n'a qu'un fournisseur : Supabase. Firebase n'entre pas.
--  Le cahier des charges, règle n°3, promettait « notification push FCM » ;
--  cette promesse est REMPLACÉE, pas ajournée — et par mieux, sur ce terrain :
--
--    • `firebase_messaging` ne couvre qu'Android et iOS. Les écoles travaillent
--      sur des postes Windows partagés : FCM n'aurait jamais sonné là où le
--      travail se fait ;
--    • la table `notifications` + PowerSync + la cloche de l'en-tête couvre les
--      quatre cibles, et arrive AUSSI quand le poste était éteint au moment de
--      l'événement, parce qu'elle est stockée et non diffusée.
--
--  ── CE QUE CETTE MIGRATION RETIRE ─────────────────────────────────────────
--    profiles.fcm_token          jeton d'appareil   — 0 valeur sur 344 profils
--    notifications.fcm_message_id  accusé d'envoi   — 0 valeur sur 121 lignes
--
--  Aucune donnée n'est perdue : les deux colonnes n'ont JAMAIS été écrites.
--  Elles ne sont pas neutres pour autant. `fcm_token` est une CLÉ D'APPAREIL —
--  qui la détient peut faire sonner le téléphone d'un collègue — et tant
--  qu'elle existe, elle attend qu'un `SELECT *` la distribue à toute l'école.
--  Une colonne morte au nom d'un fournisseur écarté est exactement le piège
--  dormant que ce dépôt connaît déjà (cf. `AppConstants.roleUtilisateur`).
--
--  ── QUAND L'APPLIQUER, ET POURQUOI PAS AVANT ──────────────────────────────
--  ⚠️ Le danger n'est pas la perte de données, c'est le BLOCAGE DE SYNCHRO.
--
--  Un poste qui tourne encore sur un build antérieur déclare `fcm_token` dans
--  son schéma PowerSync local ; son upsert de `profiles` envoie donc la colonne.
--  Contre une colonne disparue, PostgREST répond 42703 — et `_fatalResponseCodes`
--  (`^22`, `^23`, `^42501`) ne le reconnaît PAS. Le connecteur ne complète donc
--  pas la transaction : il REJOUE le lot, indéfiniment. Ce poste n'envoie plus
--  rien, jamais, sans le moindre message à l'écran.
--
--  Le build qui porte cette décision retire les deux colonnes du schéma local.
--  À partir de lui, aucun poste ne les envoie plus. La condition est donc :
--
--    1. publier le build ≥ 3.3.1 ;
--    2. attendre que TOUS les postes l'aient reçu — pas seulement la majorité :
--       un seul poste resté en arrière est un poste dont la synchro se bloque ;
--    3. vérifier avant d'exécuter :
--         SELECT count(*) FROM profiles WHERE fcm_token IS NOT NULL;   -- 0
--       puis appliquer.
--
--  Tant que le doute existe sur le parc, NE PAS APPLIQUER : deux colonnes
--  nulles ne coûtent rien, une école dont les inscriptions ne remontent plus
--  coûte tout.
--
--  ── LES SYNC-RULES ────────────────────────────────────────────────────────
--  `profiles` est projeté par une liste EXPLICITE qui ne contient pas
--  `fcm_token` : rien à modifier, et le commentaire qui explique l'exclusion
--  devient caduc le jour où ceci est appliqué — le retirer alors.
--  `notifications` est projeté par `SELECT *` : il s'adapte tout seul.
--  Garde applicatif : `epilote/test/notification_sans_firebase_test.dart`.
-- ════════════════════════════════════════════════════════════════════════════

ALTER TABLE public.profiles      DROP COLUMN IF EXISTS fcm_token;
ALTER TABLE public.notifications DROP COLUMN IF EXISTS fcm_message_id;

COMMENT ON TABLE public.notifications IS
  'Canal de notification de la plateforme. Alimentée par les déclencheurs '
  'notify_on_announcement / notify_on_message, synchronisée par PowerSync, lue '
  'par la cloche de l''en-tête. Aucun fournisseur de push n''intervient : '
  'décision du 2026-08-29, la plateforme n''a que Supabase.';
