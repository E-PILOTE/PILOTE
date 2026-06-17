import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../core/constants/routes.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/classes/providers/class_provider.dart';
import '../../../data/models/class_model.dart';
import '../../../features/communication/providers/announcements_provider.dart';
import '../../../features/structure/providers/academic_year_context.dart';
import '../../../features/structure/providers/academic_year_provider.dart';
import '../../../features/navigation/providers/module_navigation_provider.dart';
import '../../../features/navigation/providers/permissions_provider.dart';
import '../../../features/navigation/module_routes.dart';
import '../../../data/models/module_model.dart';
import '../../../services/powersync/powersync_service.dart';
import '../providers/dashboard_provider.dart';

part 'dashboard_year_parts.dart';
part 'dashboard_kpi_parts.dart';
part 'dashboard_chart_parts.dart';
part 'dashboard_block_parts.dart';
part 'dashboard_cards_parts.dart';
part 'dashboard_modules_parts.dart';

/// Palette cyclique pour les tuiles / graphes.
const _kPalette = [
  kNavy,
  kGreen,
  Color(0xFF0EA5E9),
  Color(0xFF7C3AED),
  Color(0xFFEF4444),
  Color(0xFFF59E0B),
  Color(0xFF0891B2),
  Color(0xFFDB2777),
];

class UserDashboardScreen extends ConsumerWidget {
  const UserDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AppShell(title: 'Tableau de bord', child: _DashboardBody());
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authNotifierProvider).valueOrNull;
    final activeYear = ref.watch(activeYearProvider);
    final schoolAsync = ref.watch(currentSchoolProvider);
    final syncState = ref.watch(syncIndicatorProvider);
    final permsAsync = ref.watch(myPermissionsProvider);
    final perms = permsAsync.valueOrNull ?? const {};

    final schoolName = schoolAsync.valueOrNull?['name'] as String? ?? '—';

    // Présence de modules accordés (plan ∩ can_read). On NE rend PAS de grille
    // « Accès rapide » : ce serait un doublon de la sidebar. On s'en sert
    // uniquement pour décider d'afficher un message si le membre n'a AUCUN module.
    final groupedAsync = ref.watch(modulesGroupedByCategoryProvider);
    final grouped = groupedAsync.valueOrNull ?? const {};
    final modulesSyncing =
        (groupedAsync.isLoading && !groupedAsync.hasValue) ||
        (permsAsync.isLoading && !permsAsync.hasValue);
    final modulesError = groupedAsync.hasError || permsAsync.hasError;
    var hasModules = false;
    for (final entry in grouped.entries) {
      if (entry.value.any((m) => perms[m.slug]?.canRead ?? false)) {
        hasModules = true;
        break;
      }
    }

    // Permissions d'affichage des blocs métier.
    final showClasses = perms['classes']?.canRead ?? false;
    final showEleves = (perms['eleves']?.canRead ?? false) ||
        (perms['inscriptions']?.canRead ?? false);
    final showInscriptions = perms['inscriptions']?.canRead ?? false;
    final canValidate = perms['inscriptions']?.canValidate ?? false;

    // Blocs métier composés selon les PERMISSIONS (→ adaptatif au rôle).
    final showScolarite = showClasses || showEleves;
    final showFinance = (perms['paiements-eleves']?.canRead ?? false) ||
        (perms['frais-scolarite']?.canRead ?? false) ||
        (perms['depenses']?.canRead ?? false) ||
        (perms['budget']?.canRead ?? false);
    final showMedical = perms['infirmerie']?.canRead ?? false;
    final showDiscipline = perms['discipline']?.canRead ?? false;
    final anyBlock =
        showScolarite || showFinance || showMedical || showDiscipline;

    final role = profile?.role ?? '';
    final isParent = role == 'parent';
    final isEleve = role == 'eleve';

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 80),
      children: [
        _SchoolBanner(
          schoolName: schoolName,
          yearLabel: activeYear?.label ?? '—',
          syncState: syncState,
          firstName: profile?.firstName ?? '',
        ),
        const SizedBox(height: 18),

        if (activeYear != null) ...[
          _AcademicYearCard(year: activeYear),
          const SizedBox(height: 12),
          _CalendarStrip(yearId: activeYear.id),
          const SizedBox(height: 22),
        ],

        // ── Bloc SCOLARITÉ (classes / élèves / inscriptions) ────────────────
        if (showScolarite) ...[
          const AdminSectionTitle("Vue d'ensemble", icon: Icons.insights_rounded),
          const SizedBox(height: 14),
          _KpiGrid(
            showClasses: showClasses,
            showEleves: showEleves,
            showInscriptions: showInscriptions,
          ),
          const SizedBox(height: 24),
          const AdminSectionTitle('Statistiques', icon: Icons.bar_chart_rounded),
          const SizedBox(height: 14),
          const _ChartsRow(),
          const SizedBox(height: 24),
        ],

        // ── Bloc FINANCE (comptable / direction) ────────────────────────────
        if (showFinance) const _FinanceBlock(),

        // ── Bloc MÉDICAL (infirmier / direction) ────────────────────────────
        if (showMedical) const _MedicalBlock(),

        // ── Bloc DISCIPLINE (cpe / surveillant / direction) ─────────────────
        if (showDiscipline) const _DisciplineBlock(),

        // ── À traiter : inscriptions en attente ─────────────────────────────
        if (showInscriptions) _PendingInscriptionsCard(canValidate: canValidate),

        // ── Accueil parent / élève (pas de modules de gestion) ──────────────
        if ((isParent || isEleve) && !anyBlock)
          _ParentWelcomeCard(isParent: isParent),

        // ── Accès rapide aux modules (lanceur compact, après les insights) ──
        // Complément de la sidebar, pas un doublon de KPI. Groupé par catégorie,
        // filtré `can_read` (verrou 3). Placé sous les indicateurs pour que
        // l'accueil mène par l'information, pas par un mur de boutons.
        if (hasModules) ...[
          const AdminSectionTitle('Accès rapide', icon: Icons.apps_rounded),
          const SizedBox(height: 14),
          const _QuickModulesGrid(),
          const SizedBox(height: 24),
        ],

        // ── Annonces récentes ───────────────────────────────────────────────
        const _RecentAnnouncementsCard(),

        // ── État modules (informatif uniquement, pas de doublon sidebar) ────
        if (!hasModules && !anyBlock) ...[
          if (modulesSyncing)
            const _SyncingModulesCard()
          else if (modulesError)
            const _ModulesErrorCard()
          else
            const _NoModulesCard(),
        ],
      ],
    );
  }
}

// ─── Bannière école (avec état de synchro offline-first) ───────────────────────
class _SchoolBanner extends StatelessWidget {
  const _SchoolBanner({
    required this.schoolName,
    required this.yearLabel,
    required this.syncState,
    required this.firstName,
  });
  final String schoolName;
  final String yearLabel;
  final SyncUiState syncState;
  final String firstName;

  @override
  Widget build(BuildContext context) {
    final (dotColor, label) = switch (syncState) {
      SyncUiState.synced => (kGreen, 'À jour'),
      SyncUiState.syncing => (const Color(0xFF0EA5E9), 'Synchronisation…'),
      SyncUiState.offline => (kAccent, 'Hors ligne'),
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kNavyDark, kNavy],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: kNavy.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_greeting()}${firstName.isNotEmpty ? ", $firstName" : ""} !',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 4),
                Text(schoolName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.calendar_month_rounded,
                      size: 14, color: Colors.white54),
                  const SizedBox(width: 4),
                  Text('Année $yearLabel',
                      style: const TextStyle(color: Colors.white60, fontSize: 12)),
                ]),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
              Text(label,
                  style: const TextStyle(color: Colors.white, fontSize: 11.5)),
            ]),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bonjour';
    if (h < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }
}
