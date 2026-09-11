-- ════════════════════════════════════════════════════════════════════════════
--  0189 — TROIS FONCTIONS QUI ÉCRIVENT ÉTAIENT OUVERTES À `anon`
--
--  ── CE QUE `anon` VEUT DIRE ICI ───────────────────────────────────────────
--  `anon` est le rôle de la CLÉ PUBLIQUE de l'application — celle qui est
--  écrite en clair dans `lib/core/constants/supabase_constants.dart` et donc
--  présente dans chaque installateur distribué. Une fonction exécutable par
--  `anon` est exécutable par quiconque a ouvert le binaire, SANS COMPTE et
--  sans mot de passe.
--
--  Ce n'est pas grave en soi : la quasi-totalité des fonctions `SECURITY
--  DEFINER` de cette base vérifient elles-mêmes l'appelant
--  (`is_super_admin()`, `auth_group_id()`, `_agent_mouvement_autorise()`…) et
--  répondent « accès refusé » à `anon`. L'inventaire du 2026-09-04 en a trouvé
--  TROIS qui écrivent sans rien vérifier :
--
--   1. `liberer_charge_agent(profil, ecole)` — la plus grave. Elle SUPPRIME
--      les affectations de cours (`teacher_subjects`) et retire le professeur
--      principal des classes (`classes.main_teacher_id`). Sans compte, sur
--      n'importe quel enseignant de n'importe quelle école. Elle est légitime
--      là où elle sert : `muter_agent`, `radier_agent` et
--      `annuler_enregistrement_agent` l'appellent APRÈS avoir vérifié
--      l'appelant. Elle n'a simplement jamais eu à être appelable de
--      l'extérieur.
--
--   2. `emit_subscription_reminders()` — la tâche qui émet les rappels
--      d'échéance. Appelée en boucle par un tiers, elle fabrique des
--      notifications à tout le parc.
--
--   3. `next_license_version(groupe)` — incrémente le compteur de version de
--      licence d'un groupe. C'est l'Edge Function `license-issuer` qui doit
--      l'appeler, et elle le fait en `service_role`.
--
--  ── CE QUE FAIT CETTE MIGRATION ───────────────────────────────────────────
--  Elle retire le droit d'exécution à `anon` ET à `authenticated`. Aucune des
--  trois n'est appelée par l'application Flutter (vérifié : aucune occurrence
--  dans `epilote/lib/`), et les appels internes continuent de fonctionner —
--  dans une fonction `SECURITY DEFINER`, c'est le propriétaire qui exécute,
--  et il garde son droit.
--
--  ⚠️ CE QUE CETTE MIGRATION NE FAIT PAS. Elle ne retire rien aux ~70 autres
--  fonctions exposées à `anon` : elles portent leur propre garde, et les
--  révoquer en masse casserait l'écran de connexion (versions du parc,
--  contexte de création d'un agent…). Le principe reste à tenir fonction par
--  fonction : une fonction qui ÉCRIT doit vérifier son appelant, ou n'être pas
--  exposée.
-- ════════════════════════════════════════════════════════════════════════════

REVOKE EXECUTE ON FUNCTION public.liberer_charge_agent(uuid, uuid)
  FROM PUBLIC, anon, authenticated;

REVOKE EXECUTE ON FUNCTION public.emit_subscription_reminders()
  FROM PUBLIC, anon, authenticated;

REVOKE EXECUTE ON FUNCTION public.next_license_version(uuid)
  FROM PUBLIC, anon, authenticated;

COMMENT ON FUNCTION public.liberer_charge_agent(uuid, uuid) IS
  '0189 — usage INTERNE (muter/radier/annuler). Écrit sans vérifier '
  'l''appelant : ne jamais la ré-exposer à anon ou authenticated.';

COMMENT ON FUNCTION public.emit_subscription_reminders() IS
  '0189 — tâche serveur (service_role). Ne pas exposer à anon/authenticated.';

COMMENT ON FUNCTION public.next_license_version(uuid) IS
  '0189 — appelée par l''Edge Function license-issuer en service_role. Ne pas '
  'exposer à anon/authenticated.';
