import 'package:flutter/material.dart';

import '../../core/widgets/admin_ui.dart';
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
import '../../features/super_admin/screens/invoices_screen.dart';
import '../../features/super_admin/screens/receipts_screen.dart';
import '../../features/super_admin/screens/payment_methods_screen.dart';
import '../../features/super_admin/screens/reports_screen.dart';
import '../../features/super_admin/screens/settings_screen.dart';
import '../../features/super_admin/screens/ai_screen.dart';
import '../../features/communication/screens/announcements_feed.dart';
import '../../features/communication/screens/messagerie_staff.dart';
import '../../features/super_admin/screens/tickets_screen.dart';
import '../../features/super_admin/screens/platform_service_messages_screen.dart';
import '../../features/super_admin/screens/platform_partners_screen.dart';
import '../../features/super_admin/screens/national_map_screen.dart';
import '../../features/super_admin/screens/profile_screen.dart';
import '../../features/admin_groupe/screens/admin_academic_years_screen.dart';
import '../../features/admin_groupe/screens/admin_dashboard_screen.dart';
import '../../features/admin_groupe/screens/admin_schools_screen.dart';
import '../../features/admin_groupe/screens/admin_users_screen.dart';
import '../../features/admin_groupe/screens/admin_access_screen.dart';
import '../../features/admin_groupe/screens/admin_reports_screen.dart';
import '../../features/admin_groupe/screens/admin_subscription_screen.dart';
import '../../features/admin_groupe/screens/admin_audit_screen.dart';
import '../../features/admin_groupe/screens/admin_settings_screen.dart';
import '../../features/communication/screens/support_requester_screen.dart';
import '../../features/admin_groupe/screens/admin_profile_screen.dart';
import '../../features/admin_groupe/screens/admin_module_screen.dart';
import '../../features/admin_groupe/screens/admin_modules_screen.dart';
import '../../features/students/screens/inscriptions_screen.dart';
import '../../features/students/screens/eleves_screen.dart';
import '../../features/students/screens/annuaire_screen.dart';
import '../../features/students/screens/documents_screen.dart';
import '../../features/students/screens/transferts_screen.dart';
import '../../features/structure/screens/subjects_screen.dart';
import '../../features/structure/screens/cahier_textes_screen.dart';
import '../../features/structure/screens/emploi_du_temps_screen.dart';
import '../../features/evaluation/screens/notes_screen.dart';
import '../../features/evaluation/screens/bulletins_screen.dart';
import '../../features/evaluation/screens/conseils_screen.dart';
import '../../features/vie_scolaire/screens/presences_screen.dart';
import '../../features/vie_scolaire/screens/discipline_screen.dart';
import '../../features/vie_scolaire/screens/orientation_screen.dart';
import '../../features/vie_scolaire/screens/infirmerie_screen.dart';
import '../../features/vie_scolaire/screens/cantine_screen.dart';
import '../../features/vie_scolaire/screens/bibliotheque_screen.dart';
import '../../features/finance/screens/frais_screen.dart';
import '../../features/finance/screens/paiements_screen.dart';
import '../../features/finance/screens/depenses_screen.dart';
import '../../features/finance/screens/budget_screen.dart';
import '../../features/structure/screens/programmes_screen.dart';
import '../../features/structure/screens/school_calendar_screen.dart';
import '../../features/structure/screens/academic_structure_screen.dart';
import '../../features/staff/screens/personnel_screen.dart';
import '../../features/staff/screens/presences_personnel_screen.dart';
import '../../features/staff/screens/conges_screen.dart';
import '../../features/staff/screens/paie_screen.dart';
import '../../features/navigation/module_routes.dart';
import '../../features/navigation/providers/permissions_provider.dart';
import '../../licensing/presentation/license_providers.dart';
import '../../features/navigation/widgets/module_coming_soon.dart';
import '../../features/user/screens/staff_audit_screen.dart';
import '../../features/user/screens/renewal_wall_screen.dart';
import '../../features/user/screens/user_dashboard_screen.dart';
import '../../features/user/screens/user_profile_screen.dart';
import '../../features/user/screens/user_settings_screen.dart';
import '../../features/classes/screens/classes_screen.dart';
import '../../features/classes/screens/classe_detail_screen.dart';
import '../../features/examens/screens/examens_screen.dart';
import '../../features/examens/screens/exam_session_screen.dart';
import '../../features/stages/screens/stages_screen.dart';

// ─── Couleurs Design System ───────────────────────────────────────────────────
Color get _kNavy => kNavy;
Color get _kSurface => kSurface;

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
        foregroundColor: kCardBg,
        title: Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        actions: [
          // Bouton déconnexion toujours visible sur les placeholders
          TextButton.icon(
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).signOut();
            },
            icon: const Icon(
              Icons.logout_rounded,
              size: 16,
              color: Colors.white70,
            ),
            label: const Text(
              'Déconnexion',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.construction_rounded,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: kTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Écran en cours de développement',
              style: TextStyle(color: Colors.grey.shade500),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () async {
                await ref.read(authNotifierProvider.notifier).signOut();
              },
              icon: const Icon(Icons.logout_rounded, size: 16),
              label: const Text('Se déconnecter → page Login'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kNavy,
                side: BorderSide(color: _kNavy),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
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

/// Titre lisible à partir d'un slug (`paiements-eleves` → `Paiements eleves`).
String _prettifySlug(String slug) {
  if (slug.isEmpty) return 'Module';
  final words = slug.split('-');
  return words
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(_routerNotifierProvider);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final isLoading = authState.isLoading;
      final profile = authState.valueOrNull;
      final isLoggedIn = profile != null;

      final loc = state.matchedLocation;
      final isOnAuth =
          loc == Routes.login ||
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
        final isAdminSpace =
            loc.startsWith('/super') || loc.startsWith('/admin');
        final isUserSpace = loc.startsWith('/user');

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

        // ── Calendrier scolaire : config NATIVE réservée à la direction ────
        // (hors catalogue → pas géré par le verrou 3 modules). On garde la
        // route au même titre que la sidebar la masque pour les autres rôles.
        if (loc == Routes.calendrier) {
          if (!AppConstants.directionRoles.contains(role)) {
            return Routes.userDashboard;
          }
        }

        // ── Verrou 3 au routage : accès module-par-module ──────────────────
        // Si la route /user/* correspond à un module et que le membre n'a pas
        // `can_read` dessus → retour au dashboard. (Routes natives Communication
        // + dashboard/rapports/paramètres ne sont pas des modules → non gardées.)
        if (isUserSpace) {
          final slug = moduleSlugForLocation(loc);
          if (slug != null) {
            final ent = ref.read(entitlementProvider).valueOrNull;
            // ── Verrou HARD-LOCK (impayé PRIVÉ confirmé au-delà de la grâce) ──
            // Les modules deviennent inaccessibles → mur de renouvellement.
            // Seuls Dashboard/Profil/Paramètres + routes natives (slug == null)
            // restent. Fail-soft : non-enforcé, plan public, ou encore en
            // grâce/lecture seule → isHardLockedAt == false → aucun effet.
            // Ne gate JAMAIS la synchro PowerSync (C4/ADR-0006).
            if (ent != null && ent.isHardLockedAt(DateTime.now().toUtc())) {
              return Routes.userRenew;
            }
            // ── Verrou PLAN (licence) : le module est-il dans l'entitlement ? ─
            // Fail-soft : entitlement absent ou non-enforcé (aucune licence) →
            // grantsModule == true → laisse passer (comportement actuel préservé
            // tant que les clés ne sont pas provisionnées).
            if (ent != null && !ent.grantsModule(slug)) {
              return Routes.userDashboard;
            }
            final perms = ref.read(myPermissionsProvider).valueOrNull;
            // perms == null → encore en chargement : on laisse passer.
            if (perms != null && (perms[slug]?.canRead != true)) {
              return Routes.userDashboard;
            }
          }
        }
      }

      return null;
    },
    routes: [
      // ── Auth ──────────────────────────────────────────────────────────
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
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
      GoRoute(path: Routes.superPlans, builder: (_, _) => const PlansScreen()),
      GoRoute(
        path: Routes.superAbonnements,
        builder: (_, _) => const SubscriptionsScreen(),
      ),
      GoRoute(
        path: Routes.superFactures,
        builder: (_, _) => const InvoicesScreen(),
      ),
      GoRoute(
        path: Routes.superRecus,
        builder: (_, _) => const ReceiptsScreen(),
      ),
      GoRoute(
        path: Routes.superPaiements,
        builder: (_, _) => const PaymentMethodsScreen(),
      ),
      _placeholder(Routes.superMessages, 'Messagerie'),
      GoRoute(
        path: Routes.superMessagesInbox,
        builder: (_, state) => StaffMessagesScreen(
            initialPeerId: state.uri.queryParameters['peer']),
      ),
      GoRoute(
        path: Routes.superTickets,
        builder: (_, _) => const TicketsScreen(),
      ),
      GoRoute(
        path: Routes.superAnnonces,
        builder: (_, _) => const StaffAnnouncementsScreen(),
      ),
      GoRoute(
        path: Routes.superMessagesAccueil,
        builder: (_, _) => const PlatformServiceMessagesScreen(),
      ),
      GoRoute(
        path: Routes.superPartenaires,
        builder: (_, _) => const PlatformPartnersScreen(),
      ),
      GoRoute(path: Routes.superIa, builder: (_, _) => const AiScreen()),
      GoRoute(path: Routes.superAudit, builder: (_, _) => const AuditScreen()),
      GoRoute(
        path: Routes.superRapports,
        builder: (_, _) => const ReportsScreen(),
      ),
      GoRoute(
        path: Routes.superParametres,
        builder: (_, _) => const SettingsScreen(),
      ),
      GoRoute(
        path: Routes.superCarte,
        builder: (_, _) => const NationalMapScreen(),
      ),
      GoRoute(
        path: Routes.superProfil,
        builder: (_, _) => const ProfileScreen(),
      ),

      // ── Admin Groupe ──────────────────────────────────────────────────
      GoRoute(
        path: Routes.adminDashboard,
        builder: (_, _) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: Routes.adminEcoles,
        builder: (_, _) => const AdminSchoolsScreen(),
      ),
      GoRoute(
        path: Routes.adminAnnees,
        builder: (_, _) => const AdminAcademicYearsScreen(),
      ),
      GoRoute(
        path: Routes.adminUtilisateurs,
        builder: (_, _) => const AdminUsersScreen(),
      ),
      GoRoute(
        path: Routes.adminProfils,
        builder: (_, _) => const AdminAccessScreen(),
      ),
      GoRoute(
        path: Routes.adminRapports,
        builder: (_, _) => const AdminReportsScreen(),
      ),
      GoRoute(
        path: Routes.adminAbonnement,
        builder: (_, _) => const AdminSubscriptionScreen(),
      ),
      GoRoute(
        path: Routes.adminAudit,
        builder: (_, _) => const AdminAuditScreen(),
      ),
      GoRoute(
        path: Routes.adminSupport,
        builder: (_, _) => const SupportRequesterScreen(),
      ),
      GoRoute(
        path: Routes.adminParametres,
        builder: (_, _) => const AdminSettingsScreen(),
      ),
      GoRoute(
        path: Routes.adminProfil,
        builder: (_, _) => const AdminProfileScreen(),
      ),
      GoRoute(
        path: Routes.adminModules,
        builder: (_, _) => const AdminModulesScreen(),
      ),
      GoRoute(
        path: Routes.adminModuleDetail,
        builder: (_, state) =>
            AdminModuleScreen(slug: state.pathParameters['slug']!),
      ),
      // Communication native (admin groupe) — module partagé scope-aware
      GoRoute(
        path: Routes.adminAnnonces,
        builder: (_, _) => const StaffAnnouncementsScreen(),
      ),
      GoRoute(
        path: Routes.adminMessagerie,
        builder: (_, state) => StaffMessagesScreen(
            initialPeerId: state.uri.queryParameters['peer']),
      ),
      GoRoute(
        path: Routes.adminEvenements,
        builder: (_, _) =>
            const StaffAnnouncementsScreen(initialTab: 1),
      ),

      // ── Utilisateur École ─────────────────────────────────────────────
      GoRoute(
        path: Routes.userDashboard,
        builder: (_, _) => const UserDashboardScreen(),
      ),
      GoRoute(path: Routes.eleves, builder: (_, _) => const ElevesScreen()),
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
        path: Routes.structure,
        builder: (_, _) => const AcademicStructureScreen(),
      ),
      GoRoute(path: Routes.classes, builder: (_, _) => const ClassesScreen()),
      GoRoute(
        path: Routes.classeDetail,
        builder: (_, state) =>
            ClasseDetailScreen(classId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.calendrier,
        builder: (_, _) => const SchoolCalendarScreen(),
      ),
      GoRoute(path: Routes.matieres, builder: (_, _) => const SubjectsScreen()),
      GoRoute(
        path: Routes.programmes,
        builder: (_, _) => const ProgrammesScreen(),
      ),
      // Hôte générique : modules accordés mais pas encore dotés d'un écran.
      GoRoute(
        path: Routes.moduleHost,
        builder: (_, state) {
          final slug = state.pathParameters['slug'] ?? '';
          return ModuleComingSoonScreen(slug: slug, title: _prettifySlug(slug));
        },
      ),
      GoRoute(
        path: Routes.transferts,
        builder: (_, _) => const TransfertsScreen(),
      ),
      GoRoute(
        path: Routes.documents,
        builder: (_, _) => const DocumentsScreen(),
      ),
      GoRoute(
        path: Routes.annuaire,
        builder: (_, _) => const AnnuaireScreen(),
      ),
      GoRoute(
        path: Routes.notes,
        builder: (_, _) => const NotesScreen(),
      ),
      GoRoute(
        path: Routes.bulletins,
        builder: (_, _) => const BulletinsScreen(),
      ),
      GoRoute(
        path: Routes.conseils,
        builder: (_, _) => const ConseilsScreen(),
      ),
      GoRoute(
        path: Routes.examens,
        builder: (_, _) => const ExamensScreen(),
      ),
      GoRoute(
        path: Routes.stages,
        builder: (_, _) => const StagesScreen(),
      ),
      GoRoute(
        path: Routes.examenSession,
        builder: (_, st) =>
            ExamSessionScreen(sessionId: st.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.presences,
        builder: (_, _) => const PresencesScreen(),
      ),
      GoRoute(
        path: Routes.emploiDuTemps,
        builder: (_, _) => const EmploiDuTempsScreen(),
      ),
      GoRoute(
        path: Routes.cahierTextes,
        builder: (_, _) => const CahierTextesScreen(),
      ),
      GoRoute(
        path: Routes.discipline,
        builder: (_, _) => const DisciplineScreen(),
      ),
      GoRoute(
        path: Routes.orientation,
        builder: (_, _) => const OrientationScreen(),
      ),
      GoRoute(
        path: Routes.infirmerie,
        builder: (_, _) => const InfirmerieScreen(),
      ),
      GoRoute(
        path: Routes.cantine,
        builder: (_, _) => const CantineScreen(),
      ),
      GoRoute(
        path: Routes.bibliotheque,
        builder: (_, _) => const BibliothequeScreen(),
      ),
      GoRoute(
        path: Routes.fraisScolarite,
        builder: (_, _) => const FraisScreen(),
      ),
      GoRoute(
        path: Routes.paiements,
        builder: (_, _) => const PaiementsScreen(),
      ),
      GoRoute(
        path: Routes.depenses,
        builder: (_, _) => const DepensesScreen(),
      ),
      GoRoute(
        path: Routes.budget,
        builder: (_, _) => const BudgetScreen(),
      ),
      GoRoute(
        path: Routes.personnel,
        builder: (_, _) => const PersonnelScreen(),
      ),
      GoRoute(
        path: Routes.presencesPersonnel,
        builder: (_, _) => const PresencesPersonnelScreen(),
      ),
      GoRoute(
        path: Routes.conges,
        builder: (_, _) => const CongesScreen(),
      ),
      GoRoute(
        path: Routes.paie,
        builder: (_, _) => const PaieScreen(),
      ),
      // Communication native (personnel école / parent) — écrans à construire
      GoRoute(
        path: Routes.annonces,
        builder: (_, _) => const StaffAnnouncementsScreen(),
      ),
      // Notifications = cloche + drawer dans le header (pas une page de route).
      GoRoute(
        path: Routes.messagerie,
        builder: (_, state) => StaffMessagesScreen(
            initialPeerId: state.uri.queryParameters['peer']),
      ),
      GoRoute(
        path: Routes.evenements,
        builder: (_, _) =>
            const StaffAnnouncementsScreen(initialTab: 1),
      ),
      GoRoute(
        path: Routes.espaceParent,
        builder: (_, _) => const StaffComingSoonScreen(
          title: 'Espace Parent',
          icon: Icons.family_restroom_rounded,
          message:
              'Le suivi de votre enfant (notes, présences, paiements) '
              'sera bientôt accessible ici.',
        ),
      ),
      GoRoute(
        path: Routes.userRapports,
        builder: (_, _) => const StaffComingSoonScreen(
          title: 'Rapports',
          icon: Icons.bar_chart_rounded,
          message:
              'Vos rapports et statistiques seront bientôt disponibles ici.',
        ),
      ),
      GoRoute(
        path: Routes.userAudit,
        builder: (_, _) => const StaffAuditScreen(),
      ),
      GoRoute(
        path: Routes.userSupport,
        builder: (_, _) => const SupportRequesterScreen(),
      ),
      GoRoute(
        path: Routes.userParametres,
        builder: (_, _) => const UserSettingsScreen(),
      ),
      GoRoute(
        path: Routes.userProfil,
        builder: (_, _) => const UserProfileScreen(),
      ),
      GoRoute(
        path: Routes.userRenew,
        builder: (_, _) => const RenewalWallScreen(),
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Page introuvable : ${state.error}')),
    ),
  );
});

String _dashboardForRole(ProfileModel profile) {
  switch (profile.role) {
    case AppConstants.roleSuperAdmin:
      return Routes.superDashboard;
    case AppConstants.roleAdminGroupe:
      return Routes.adminDashboard;
    default:
      if (profile.hasPendingProfile) return Routes.profilePending;
      return Routes.userDashboard;
  }
}
