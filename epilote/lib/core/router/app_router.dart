import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/routes.dart';
import '../../data/models/profile_model.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/super_admin/screens/super_dashboard_screen.dart';
import '../../features/super_admin/screens/school_groups_screen.dart';
import '../../features/super_admin/screens/administrators_screen.dart';
import '../../features/super_admin/screens/modules_screen.dart';
import '../../features/super_admin/screens/plans_screen.dart';
import '../../features/super_admin/screens/subscriptions_screen.dart';
import '../../features/super_admin/screens/audit_screen.dart';
import '../../features/communication/screens/announcements_screen.dart';
import '../../features/communication/screens/events_screen.dart';
import '../../features/super_admin/screens/invoices_screen.dart';
import '../../features/super_admin/screens/receipts_screen.dart';
import '../../features/super_admin/screens/payment_methods_screen.dart';
import '../../features/super_admin/screens/reports_screen.dart';
import '../../features/super_admin/screens/settings_screen.dart';
import '../../features/super_admin/screens/ai_screen.dart';
import '../../features/communication/screens/messages_screen.dart';
import '../../features/super_admin/screens/tickets_screen.dart';
import '../../features/super_admin/screens/national_map_screen.dart';
import '../../features/super_admin/screens/profile_screen.dart';
import '../../features/admin_groupe/screens/admin_dashboard_screen.dart';
import '../../features/admin_groupe/screens/admin_schools_screen.dart';
import '../../features/admin_groupe/screens/admin_users_screen.dart';
import '../../features/admin_groupe/screens/admin_access_screen.dart';
import '../../features/admin_groupe/screens/admin_reports_screen.dart';
import '../../features/admin_groupe/screens/admin_subscription_screen.dart';
import '../../features/admin_groupe/screens/admin_audit_screen.dart';
import '../../features/admin_groupe/screens/admin_settings_screen.dart';
import '../../features/admin_groupe/screens/admin_profile_screen.dart';
import '../../features/admin_groupe/screens/admin_module_screen.dart';
import '../../features/admin_groupe/screens/admin_modules_screen.dart';
import '../../features/students/screens/inscriptions_screen.dart';
import '../../features/students/screens/eleves_screen.dart';
import '../../features/user/screens/user_dashboard_screen.dart';
import '../../features/classes/screens/classes_screen.dart';
import '../../features/classes/screens/classe_detail_screen.dart';

// ─── Couleurs Design System ───────────────────────────────────────────────────
const _kNavy    = Color(0xFF1E3A5F);
const _kSurface = Color(0xFFF0F4F8);

/// Notifier qui écoute authNotifierProvider via Riverpod
/// et déclenche le refresh du router à chaque changement d'état auth.
class RouterNotifier extends ChangeNotifier {
  RouterNotifier(Ref ref) {
    ref.listen<AsyncValue<ProfileModel?>>(
      authNotifierProvider,
      (_, _) => notifyListeners(),
    );
  }
}

final _routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

/// Écran placeholder générique pour les routes non encore implémentées
class _PlaceholderScreen extends ConsumerWidget {
  const _PlaceholderScreen({required this.title});
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: _kSurface,
      appBar: AppBar(
        backgroundColor: _kNavy,
        foregroundColor: Colors.white,
        title: Text(title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        actions: [
          // Bouton déconnexion toujours visible sur les placeholders
          TextButton.icon(
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).signOut();
            },
            icon: const Icon(Icons.logout_rounded,
                size: 16, color: Colors.white70),
            label: const Text('Déconnexion',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.construction_rounded,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A))),
            const SizedBox(height: 8),
            Text('Écran en cours de développement',
                style: TextStyle(color: Colors.grey.shade500)),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () async {
                await ref.read(authNotifierProvider.notifier).signOut();
              },
              icon: const Icon(Icons.logout_rounded, size: 16),
              label: const Text('Se déconnecter → page Login'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kNavy,
                side: const BorderSide(color: _kNavy),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

GoRoute _placeholder(String path, String title) => GoRoute(
      path: path,
      builder: (_, _) => _PlaceholderScreen(title: title),
    );

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(_routerNotifierProvider);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final isLoading = authState.isLoading;
      final profile   = authState.valueOrNull;
      final isLoggedIn = profile != null;

      final loc = state.matchedLocation;
      final isOnAuth = loc == Routes.login ||
          loc == Routes.splash ||
          loc == Routes.forgotPassword;

      if (isLoading) {
        return loc == Routes.splash ? null : Routes.splash;
      }
      if (!isLoggedIn && !isOnAuth) return Routes.login;
      if (!isLoggedIn && loc == Routes.splash) return Routes.login;
      if (isLoggedIn && isOnAuth) return _dashboardForRole(profile);
      if (isLoggedIn && profile.hasPendingProfile) {
        if (loc != Routes.profilePending) return Routes.profilePending;
      }

      // ── Garde de rôle ─────────────────────────────────────────────────
      // super_admin et admin_groupe ne peuvent pas accéder aux routes /user/*
      // (module offline-first, PowerSync non connecté pour eux → données vides)
      if (isLoggedIn && !profile.hasPendingProfile) {
        final role = profile.role;
        final isAdminSpace = loc.startsWith('/super') || loc.startsWith('/admin');
        final isUserSpace  = loc.startsWith('/user');

        if (isUserSpace &&
            (role == AppConstants.roleSuperAdmin ||
             role == AppConstants.roleAdminGroupe)) {
          return _dashboardForRole(profile);
        }
        if (isAdminSpace &&
            role != AppConstants.roleSuperAdmin &&
            role != AppConstants.roleAdminGroupe) {
          return _dashboardForRole(profile);
        }
      }

      return null;
    },
    routes: [
      // ── Auth ──────────────────────────────────────────────────────────
      GoRoute(
        path: Routes.splash,
        builder: (_, _) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (_, _) => const LoginScreen(),
      ),
      _placeholder(Routes.forgotPassword, 'Mot de passe oublié'),
      _placeholder(Routes.profilePending, 'Compte en attente'),

      // ── Super Admin ───────────────────────────────────────────────────
      GoRoute(
        path: Routes.superDashboard,
        builder: (_, _) => const SuperDashboardScreen(),
      ),
      GoRoute(
        path: Routes.superGroupes,
        builder: (_, _) => const SchoolGroupsScreen(),
      ),
      GoRoute(
        path: Routes.superAdministrateurs,
        builder: (_, _) => const AdministratorsScreen(),
      ),
      GoRoute(
        path: Routes.superModules,
        builder: (_, _) => const ModulesScreen(),
      ),
      GoRoute(
        path: Routes.superPlans,
        builder: (_, _) => const PlansScreen(),
      ),
      GoRoute(
        path: Routes.superAbonnements,
        builder: (_, _) => const SubscriptionsScreen(),
      ),
      GoRoute(path: Routes.superFactures, builder: (_, _) => const InvoicesScreen()),
      GoRoute(path: Routes.superRecus,     builder: (_, _) => const ReceiptsScreen()),
      GoRoute(path: Routes.superPaiements, builder: (_, _) => const PaymentMethodsScreen()),
      _placeholder(Routes.superMessages,     'Messagerie'),
      GoRoute(path: Routes.superMessagesInbox, builder: (_, _) => const MessagesScreen()),
      GoRoute(path: Routes.superTickets,       builder: (_, _) => const TicketsScreen()),
      GoRoute(path: Routes.superAnnonces, builder: (_, _) => const AnnouncementsScreen()),
      GoRoute(path: Routes.superIa, builder: (_, _) => const AiScreen()),
      GoRoute(path: Routes.superAudit, builder: (_, _) => const AuditScreen()),
      GoRoute(path: Routes.superRapports,   builder: (_, _) => const ReportsScreen()),
      GoRoute(path: Routes.superParametres, builder: (_, _) => const SettingsScreen()),
      GoRoute(path: Routes.superCarte,      builder: (_, _) => const NationalMapScreen()),
      GoRoute(path: Routes.superProfil,     builder: (_, _) => const ProfileScreen()),

      // ── Admin Groupe ──────────────────────────────────────────────────
      GoRoute(path: Routes.adminDashboard,    builder: (_, _) => const AdminDashboardScreen()),
      GoRoute(path: Routes.adminEcoles,       builder: (_, _) => const AdminSchoolsScreen()),
      GoRoute(path: Routes.adminUtilisateurs, builder: (_, _) => const AdminUsersScreen()),
      GoRoute(path: Routes.adminProfils,      builder: (_, _) => const AdminAccessScreen()),
      GoRoute(path: Routes.adminRapports,     builder: (_, _) => const AdminReportsScreen()),
      GoRoute(path: Routes.adminAbonnement,   builder: (_, _) => const AdminSubscriptionScreen()),
      GoRoute(path: Routes.adminAudit,        builder: (_, _) => const AdminAuditScreen()),
      GoRoute(path: Routes.adminParametres,   builder: (_, _) => const AdminSettingsScreen()),
      GoRoute(path: Routes.adminProfil,       builder: (_, _) => const AdminProfileScreen()),
      GoRoute(path: Routes.adminModules,      builder: (_, _) => const AdminModulesScreen()),
      GoRoute(
        path: Routes.adminModuleDetail,
        builder: (_, state) => AdminModuleScreen(slug: state.pathParameters['slug']!),
      ),
      // Communication native (admin groupe) — module partagé scope-aware
      GoRoute(path: Routes.adminAnnonces,      builder: (_, _) => const AnnouncementsScreen()),
      GoRoute(path: Routes.adminMessagerie,    builder: (_, _) => const MessagesScreen()),
      GoRoute(path: Routes.adminEvenements,    builder: (_, _) => const EventsScreen()),

      // ── Utilisateur École ─────────────────────────────────────────────
      GoRoute(
        path: Routes.userDashboard,
        builder: (_, _) => const UserDashboardScreen(),
      ),
      GoRoute(
        path: Routes.eleves,
        builder: (_, _) => const ElevesScreen(),
      ),
      GoRoute(
        path: Routes.eleveDetail,
        builder: (_, state) =>
            _PlaceholderScreen(title: 'Élève · ${state.pathParameters['id']}'),
      ),
      GoRoute(
        path: Routes.inscriptions,
        builder: (_, _) => const InscriptionsScreen(),
      ),
      GoRoute(
        path: Routes.classes,
        builder: (_, _) => const ClassesScreen(),
      ),
      GoRoute(
        path: Routes.classeDetail,
        builder: (_, state) =>
            ClasseDetailScreen(classId: state.pathParameters['id']!),
      ),
      _placeholder(Routes.notes,             'Notes & Bulletins'),
      _placeholder(Routes.bulletins,         'Bulletins'),
      _placeholder(Routes.presences,         'Présences'),
      _placeholder(Routes.emploiDuTemps,     'Emploi du Temps'),
      _placeholder(Routes.discipline,        'Discipline'),
      _placeholder(Routes.paiements,         'Paiements Scolarité'),
      _placeholder(Routes.personnel,         'Personnel'),
      // Communication native (personnel école / parent) — écrans à construire
      _placeholder(Routes.annonces,          'Annonces'),
      _placeholder(Routes.notifications,     'Notifications'),
      _placeholder(Routes.messagerie,        'Messagerie'),
      _placeholder(Routes.evenements,        'Événements'),
      _placeholder(Routes.espaceParent,      'Espace Parent'),
      _placeholder(Routes.userRapports,      'Rapports'),
      _placeholder(Routes.userParametres,    'Paramètres'),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Page introuvable : ${state.error}')),
    ),
  );
});

String _dashboardForRole(ProfileModel profile) {
  switch (profile.role) {
    case AppConstants.roleSuperAdmin:  return Routes.superDashboard;
    case AppConstants.roleAdminGroupe: return Routes.adminDashboard;
    default:
      if (profile.hasPendingProfile) return Routes.profilePending;
      return Routes.userDashboard;
  }
}
