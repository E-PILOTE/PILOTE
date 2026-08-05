---
name: bug-powersync-role-utilisateur
description: "Bug bloquant — PowerSync ne se connecte jamais pour le personnel (test role 'utilisateur' inexistant)"
metadata: 
  node_type: memory
  type: project
  originSessionId: fbfd7c02-473f-415b-b6e1-a21454a8de92
---

✅ RÉSOLU le 2026-06-06. (Bug détecté le 2026-06-06.) `lib/services/powersync/powersync_service.dart` conditionnait `db.connect()` à `if (role == 'utilisateur')`. Or `'utilisateur'` N'EXISTE PAS dans l'enum `user_role` (cf. [[db-user-role-enum]]). → La synchro offline-first ne s'activait JAMAIS pour le personnel.

**Correctif appliqué :** ajout du helper `bool _isStaffRole(String? role) => role != null && role != 'super_admin' && role != 'admin_groupe';` et remplacement des 2 tests (init démarrage + onAuthStateChange signedIn) par `_isStaffRole(role)`. Commentaires header + isSyncingProvider corrigés. `flutter analyze` = 0 issue, `flutter build linux --debug` ✓, plateforme relancée ✓.

**Why (historique) :** tant que ce test était faux, aucun agent scolaire ne recevait ses données locales.

Lié : [[powersync-status]], [[modules-acces-hierarchie]]. Voir aussi placeholders espace personnel (`app_router.dart` ~251-276) et nav dynamique non branchée (`app_shell.dart` default).
