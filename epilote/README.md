# E-PILOTE CONGO v3.0

> Plateforme de gestion scolaire multi-tenant pour la République du Congo

## Stack technique

| Couche | Technologie |
|--------|------------|
| Mobile/Desktop | Flutter 3.44 (Android, iOS, Linux, Windows) |
| Backend | Supabase (PostgreSQL 17 + Auth + RLS + Storage + Edge Functions) |
| Offline-first | PowerSync (SQLite ↔ PostgreSQL sync) |
| State management | Riverpod 2 |
| Navigation | go_router 14 |

## Architecture

```
SUPER_ADMIN (global)
  └── ADMIN_GROUPE (tenant = réseau d'écoles)
        └── UTILISATEURS (personnel d'école, par profil d'accès)
```

## Structure du projet

```
lib/
├── core/
│   ├── constants/      ← Routes, Supabase credentials, AppConstants
│   ├── extensions/     ← String, DateTime helpers
│   ├── router/         ← GoRouter + guards d'auth par rôle
│   ├── theme/          ← Thème Material 3 (Vert Congo + Or)
│   ├── utils/          ← CurrencyFormatter
│   └── widgets/        ← LoadingWidget, ErrorWidget, EmptyWidget
├── data/
│   ├── models/         ← ProfileModel, StudentModel, SchoolModel…
│   └── repositories/   ← Accès Supabase par entité
├── features/
│   ├── auth/           ← Login, Splash, ForgotPassword, ProfilePending
│   ├── super_admin/    ← Dashboard global
│   ├── admin_groupe/   ← Gestion écoles/utilisateurs
│   ├── dashboard/      ← Dashboard utilisateur école
│   ├── scolarisation/  ← Élèves, classes, inscriptions
│   ├── pedagogie/      ← Notes, bulletins, emploi du temps
│   ├── finance/        ← Paiements, frais scolarité
│   └── communication/  ← Annonces, notifications
└── services/
    └── supabase_service.dart
```

## Configuration

1. Copier `.env.example` → `.env`
2. Remplir `SUPABASE_ANON_KEY` depuis le [Dashboard Supabase](https://supabase.com/dashboard/project/wqpdamlnrwgozfvzjjpo/settings/api)
3. Mettre la valeur dans `lib/core/constants/supabase_constants.dart`

```bash
flutter pub get
flutter run
```

## Compte de test

| Rôle | Email | Mot de passe |
|------|-------|-------------|
| Super Admin | `super@admin.cg` | `Admin@2024!` |

---
*E-PILOTE CONGO v3.0 — © 2026*
