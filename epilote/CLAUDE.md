# CLAUDE.md — E-PILOTE CONGO v3.0

## Projet
Application Flutter de gestion scolaire multi-tenant pour la République du Congo.

## Commandes essentielles

```bash
# Dépendances
flutter pub get

# Analyser le code
flutter analyze

# Tests
flutter test

# Lancer sur Linux desktop (dev rapide)
flutter run -d linux

# Build Android
flutter build apk --release

# Générer les fichiers Riverpod
dart run build_runner build --delete-conflicting-outputs
```

## Architecture & conventions

### Packages clés
- **supabase_flutter** : Auth + BDD + Storage
- **flutter_riverpod** : State management (StateNotifier + FutureProvider)
- **go_router** : Navigation déclarative avec redirections par rôle
- **powersync** : Sync offline SQLite ↔ Supabase

### Rôles utilisateur
| Rôle | Accès | Dashboard |
|------|-------|-----------|
| `super_admin` | Global (toutes les tables) | `/super/dashboard` |
| `admin_groupe` | Son groupe (group_id) | `/admin/dashboard` |
| `utilisateur` | Son école (school_id) | `/user/dashboard` |

### Ajout d'un nouveau module
1. Créer `lib/features/<module>/screens/<module>_screen.dart`
2. Créer `lib/features/<module>/providers/<module>_provider.dart`
3. Créer `lib/data/repositories/<module>_repository.dart`
4. Ajouter la route dans `lib/core/router/app_router.dart`
5. Ajouter la constante dans `lib/core/constants/routes.dart`

### Supabase
- **Project ID** : `wqpdamlnrwgozfvzjjpo`
- **Region** : eu-central-2
- **RLS** : activée sur 28 tables (group_id + school_id)
- Fonctions utiles : `is_super_admin()`, `auth_group_id()`, `auth_school_id()`, `check_quota()`

### Conventions de code
- Tous les fichiers Dart : snake_case
- Toutes les classes : PascalCase  
- Imports : packages d'abord, puis fichiers locaux (séparés par une ligne vide)
- Éviter `print()` → utiliser le package `logger`
- Pas de `setState` sauf dans les `StatefulWidget` simples — préférer Riverpod

## Clé Supabase
⚠️ Mettre la clé anon dans `lib/core/constants/supabase_constants.dart` avant de lancer.
Récupérer depuis : Supabase Dashboard → Project Settings → API → anon / public
