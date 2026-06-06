# 🧠 CONTEXTE DE SESSION — E-PILOTE CONGO v3.0
> **À lire en début de nouvelle session** : "Lis /home/melack/E-PILOTE/docs/CONTEXTE.md et reprends le travail sur E-PILOTE CONGO v3.0"

---

## 📍 ÉTAT ACTUEL DU PROJET (26 Mai 2026)

### Phases accomplies
- ✅ **Analyse complète** (`/home/melack/E-PILOTE/docs/ANALYSE.md`)
- ✅ **Maquettes UI** (`/home/melack/E-PILOTE/mockups/maquette.md`)
- ✅ **Schéma SQL complet** (`/home/melack/E-PILOTE/database/schema.sql`)
- ✅ **19 migrations appliquées** sur Supabase (projet PILOTE)
- ✅ **Compte SUPER_ADMIN créé** et testé
- ✅ **Projet Flutter lancé et fonctionnel** (`/home/melack/E-PILOTE/epilote/`)
- ✅ **0 erreur de compilation** (`flutter analyze` propre — 97 infos de style uniquement)
- ✅ **App Linux desktop tourne** (`flutter run -d linux` → build OK)
- ✅ **Splash → Login** : navigation fonctionnelle (bug RouterNotifier corrigé)
- ✅ **Module Élèves** : liste + recherche + détail fiche
- ✅ **Module Classes** : liste avec taux de remplissage + détail avec liste élèves
- ✅ **Module Notes** : saisie en masse (classe / matière / séquence)
- ✅ **Module Paiements** : liste + total mensuel
- ✅ **Super Admin Dashboard** : stats réelles Supabase (groupes, écoles, élèves, users, abonnements)

---

## 🔌 SUPABASE — CONNEXION & CREDENTIALS

| Paramètre | Valeur |
|---|---|
| **Project ID** | `wqpdamlnrwgozfvzjjpo` |
| **Project Name** | PILOTE |
| **Region** | eu-central-2 |
| **PostgreSQL** | 17.6.1 |
| **MCP Tool prefix** | `mcp__f7a8601c-f9c6-48d4-91c5-f9b2e9d95d06__` |

### Clés API (⚠️ ne pas committer)
| Clé | Fichier | Usage |
|---|---|---|
| **anon** | `lib/core/constants/supabase_constants.dart` | Flutter app |
| **service_role** | Mémoire projet uniquement | Edge Functions (Phase 2) |

### Compte SUPER_ADMIN
| Champ | Valeur |
|---|---|
| Email | `super@admin.cg` |
| Mot de passe | `Admin@2024!` |
| UUID | `9cfd4d67-d181-45f3-9b21-f4acae7bdc60` |
| Rôle (profiles) | `super_admin` |

---

## 📱 PROJET FLUTTER — `/home/melack/E-PILOTE/epilote/`

### Stack
```
Flutter 3.44 + Dart 3.12
supabase_flutter: ^2.8.4
postgrest: ^2.7.0        ← dépendance directe (CountOption)
flutter_riverpod: ^2.6.1
go_router: ^14.8.1
```

### Structure lib/ (état actuel)
```
lib/
├── main.dart
├── core/
│   ├── constants/
│   │   ├── supabase_constants.dart    ← URL + anonKey + noms tables
│   │   ├── app_constants.dart         ← Rôles, mentions, devise XAF
│   │   └── routes.dart                ← Toutes les routes GoRouter
│   ├── extensions/
│   │   ├── string_extensions.dart
│   │   └── datetime_extensions.dart
│   ├── router/app_router.dart         ← GoRouter + RouterNotifier (Riverpod)
│   ├── theme/app_theme.dart           ← Material 3, Vert Congo + Or
│   ├── utils/currency_formatter.dart
│   └── widgets/
│       ├── loading_widget.dart        ← LoadingWidget / ErrorWidget / EmptyWidget
│       ├── app_button.dart
│       └── stat_card.dart
├── data/
│   ├── models/
│   │   ├── profile_model.dart         ← isSuperAdmin, hasPendingProfile, etc.
│   │   ├── school_model.dart
│   │   ├── school_group_model.dart
│   │   ├── student_model.dart         ← fullName, age, genderLabel, etc.
│   │   ├── class_model.dart           ← fillRate, fillRateLabel
│   │   ├── academic_year_model.dart
│   │   ├── grade_model.dart           ← mention (Excellent→Insuffisant)
│   │   └── subscription_model.dart
│   └── repositories/
│       ├── profile_repository.dart
│       ├── student_repository.dart
│       └── class_repository.dart      ← getBySchool + getById + jointures
├── features/
│   ├── auth/
│   │   ├── providers/auth_provider.dart   ← AuthNotifier, supabaseClientProvider
│   │   └── screens/
│   │       ├── splash_screen.dart
│   │       ├── login_screen.dart
│   │       ├── forgot_password_screen.dart
│   │       └── profile_pending_screen.dart
│   ├── super_admin/
│   │   ├── providers/super_admin_provider.dart  ← superAdminStatsProvider
│   │   └── screens/super_dashboard_screen.dart
│   ├── admin_groupe/
│   │   └── screens/admin_dashboard_screen.dart
│   ├── dashboard/
│   │   └── screens/user_dashboard_screen.dart   ← boutons Élèves/Classes/Notes/Paiements liés
│   ├── scolarisation/
│   │   ├── providers/
│   │   │   ├── students_provider.dart    ← studentsListProvider, studentByIdProvider, studentsByClassProvider
│   │   │   └── classes_provider.dart     ← classesListProvider, classByIdProvider
│   │   └── screens/
│   │       ├── students_list_screen.dart
│   │       ├── student_detail_screen.dart
│   │       ├── classes_list_screen.dart
│   │       └── class_detail_screen.dart
│   ├── pedagogie/
│   │   ├── providers/grades_provider.dart    ← gradesListProvider, studentAverageProvider
│   │   └── screens/grades_entry_screen.dart  ← sélecteurs + saisie masse + _SummaryBar
│   └── finance/
│       ├── providers/payments_provider.dart
│       └── screens/payments_list_screen.dart
└── services/supabase_service.dart
```

### Routes actives (app_router.dart)
```
/                          → SplashScreen
/login                     → LoginScreen
/forgot-password           → ForgotPasswordScreen
/profile-pending           → ProfilePendingScreen
/super/dashboard           → SuperDashboardScreen
/admin/dashboard           → AdminDashboardScreen
/user/dashboard            → UserDashboardScreen
/user/eleves               → StudentsListScreen
/user/eleves/:id           → StudentDetailScreen
/user/classes              → ClassesListScreen
/user/classes/:id          → ClassDetailScreen
/user/notes                → GradesEntryScreen
/user/paiements            → PaymentsListScreen
```

### Flux d'authentification (CORRIGÉ)
```
App start → SplashScreen (loading)
AuthNotifier._init() → AsyncValue.data(null)
RouterNotifier (ref.listen) → notifyListeners()
GoRouter redirect réévalue → /login
Login → Supabase Auth → _loadProfile() → redirect par rôle :
  super_admin   → /super/dashboard
  admin_groupe  → /admin/dashboard
  utilisateur   → /user/dashboard (ou /profile-pending)
```

---

## 🐛 BUG CRITIQUE CORRIGÉ — Router bloqué sur splash

**Cause** : `GoRouterRefreshStream` n'écoutait que `onAuthStateChange` (stream Supabase). Quand `_init()` terminait sans session, seul le provider Riverpod changeait → router jamais notifié.

**Fix** : `RouterNotifier extends ChangeNotifier` avec `ref.listen(authNotifierProvider, ...)` dans `app_router.dart`. Remplace entièrement `GoRouterRefreshStream`.

---

## 🗄️ BASE DE DONNÉES — ÉTAT FINAL

### 55 tables | 41 modules | 4 plans d'abonnement

### Fonctions RLS actives
```sql
is_super_admin()            → BOOLEAN
auth_group_id()             → UUID
auth_school_id()            → UUID
check_quota(group_id, type) → BOOLEAN
get_mention(avg)            → TEXT
generate_receipt_number()   → TEXT  (RECU-2026-XXXXX)
generate_invoice_number()   → TEXT  (FACT-2026-XXXXX)
```

---

## ⚠️ POINTS TECHNIQUES CRITIQUES

1. **API count Supabase v2** : `.count(CountOption.exact)` chaîné + `import 'package:postgrest/postgrest.dart'`
2. **`inFilter()`** au lieu de `in_()` dans postgrest 2.7.0
3. **CardTheme** → `CardThemeData` dans Flutter 3.44
4. **`withOpacity`** deprecated → utiliser `.withValues(alpha: x)`
5. **RouterNotifier** → écouter `authNotifierProvider` via `ref.listen`, PAS `GoRouterRefreshStream`
6. **service_role** → JAMAIS dans le code Flutter, réservé aux Edge Functions

---

## 🚀 PROCHAINES ÉTAPES (ordre de priorité)

### Immédiat — Tester le login
```bash
cd /home/melack/E-PILOTE/epilote
flutter run -d linux
# Identifiants : super@admin.cg / Admin@2024!
```

### Phase 1 — Modules restants à développer

#### Priorité haute
1. **Bulletins** — calcul moyenne pondérée par trimestre + affichage formaté
2. **Formulaire inscription élève** — nouveau + édition (StudentFormScreen)
3. **Module Super Admin** — gestion groupes (`/super/groupes`) + plans + facturation

#### Priorité moyenne
4. **Présences** — grille par jour/élève, calcul taux
5. **Emploi du temps** — grille hebdomadaire par classe
6. **Personnel** — liste enseignants + fiches

#### Dashboard Utilisateur
- Boutons restants à connecter : Bulletins, Présences, Emploi du temps, Personnel, Annonces

### Phase 2 (après Phase 1 complète)
- PowerSync (offline SQLite ↔ Supabase)
- Notifications push (Firebase)
- Bulletins PDF (impression)
- Mobile Money (MTN + Airtel Congo)
- Intégration IA (suggestions, prédictions)

---

## 📊 AVANCEMENT MODULES

| Module | Écran liste | Écran détail | Formulaire | Connecté Dashboard |
|--------|------------|--------------|------------|-------------------|
| Élèves | ✅ | ✅ | ❌ TODO | ✅ |
| Classes | ✅ | ✅ | ❌ TODO | ✅ |
| Notes | ✅ (saisie masse) | — | — | ✅ |
| Paiements | ✅ | ❌ TODO | ❌ TODO | ✅ |
| Bulletins | ❌ TODO | ❌ TODO | — | ❌ |
| Présences | ❌ TODO | ❌ TODO | — | ❌ |
| Super Admin Groupes | ❌ TODO | ❌ TODO | ❌ TODO | — |
| Admin Écoles | ❌ TODO | ❌ TODO | ❌ TODO | — |

---

*Contexte mis à jour le 26 Mai 2026 — Session 3 (modules Classes + Notes + fix Router)*
