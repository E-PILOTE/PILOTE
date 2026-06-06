import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/routes.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/classes/providers/class_provider.dart';
import '../../../features/structure/providers/academic_year_provider.dart';
import '../../../services/powersync/powersync_service.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
const _kNavy   = Color(0xFF1E3A5F);
const _kGreen  = Color(0xFF009A44);
const _kGold   = Color(0xFFFBBC04);
const _kPurple = Color(0xFF7C3AED);
const _kText   = Color(0xFF0F172A);
const _kMuted  = Color(0xFF64748B);

class UserDashboardScreen extends ConsumerWidget {
  const UserDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AppShell(
      title: 'Tableau de bord',
      child: _DashboardBody(),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile        = ref.watch(authNotifierProvider).valueOrNull;
    final yearAsync      = ref.watch(currentAcademicYearProvider);
    final schoolAsync    = ref.watch(currentSchoolProvider);
    final classCountAsync= ref.watch(classCountProvider);
    final elevesAsync    = ref.watch(enrolledStudentCountProvider);
    final syncStatus     = ref.watch(syncStatusProvider);

    final isSyncing = syncStatus.valueOrNull?.connected ?? false;
    final yearLabel = yearAsync.valueOrNull?.label ?? '—';
    final schoolName= schoolAsync.valueOrNull?['name'] as String? ?? '—';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Bannière école ────────────────────────────────────────────
          _SchoolBanner(
            schoolName: schoolName,
            yearLabel:  yearLabel,
            isSyncing:  isSyncing,
            profile:    profile,
          ),
          const SizedBox(height: 20),

          // ── Contexte académique ───────────────────────────────────────
          yearAsync.whenOrNull(
            data: (year) => year != null
                ? _AcademicYearCard(year: year)
                : const SizedBox.shrink(),
          ) ?? const SizedBox.shrink(),

          const SizedBox(height: 20),

          // ── Titre stats ───────────────────────────────────────────────
          const Text(
            'Vue d\'ensemble',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _kText,
            ),
          ),
          const SizedBox(height: 12),

          // ── Grille stats ──────────────────────────────────────────────
          GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing:  12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              classCountAsync.when(
                loading: () => const _StatLoading(label: 'Classes'),
                error:   (_, e) => _StatCardItem(
                    label: 'Classes', value: '—',
                    icon: Icons.class_rounded, color: _kNavy,
                    onTap: () => context.push(Routes.classes)),
                data:    (n) => _StatCardItem(
                    label: 'Classes', value: '$n',
                    icon: Icons.class_rounded, color: _kNavy,
                    onTap: () => context.push(Routes.classes)),
              ),
              elevesAsync.when(
                loading: () => const _StatLoading(label: 'Élèves inscrits'),
                error:   (_, e) => const _StatCardItem(
                    label: 'Élèves inscrits', value: '—',
                    icon: Icons.people_rounded, color: _kGreen),
                data:    (n) => _StatCardItem(
                    label: 'Élèves inscrits', value: '$n',
                    icon: Icons.people_rounded, color: _kGreen,
                    onTap: () => context.push(Routes.eleves)),
              ),
              _StatCardItem(
                label: 'Présences',
                value: '—',
                icon: Icons.calendar_today_rounded,
                color: _kPurple,
                onTap: () => context.push(Routes.presences),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Accès rapide ──────────────────────────────────────────────
          const Text(
            'Accès rapide',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _kText,
            ),
          ),
          const SizedBox(height: 12),
          const _QuickAccessGrid(),
        ],
      ),
    );
  }
}

// ─── Bannière école ───────────────────────────────────────────────────────────

class _SchoolBanner extends StatelessWidget {
  const _SchoolBanner({
    required this.schoolName,
    required this.yearLabel,
    required this.isSyncing,
    required this.profile,
  });
  final String  schoolName;
  final String  yearLabel;
  final bool    isSyncing;
  final dynamic profile;

  @override
  Widget build(BuildContext context) {
    final greeting = _greeting();
    final firstName = profile?.firstName as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
          colors: [Color(0xFF1E3A5F), Color(0xFF0F2340)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting${firstName.isNotEmpty ? ", $firstName" : ""} !',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  schoolName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded,
                        size: 14, color: Colors.white54),
                    const SizedBox(width: 4),
                    Text(
                      'Année $yearLabel',
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  color: isSyncing
                      ? const Color(0xFF009A44)
                      : const Color(0xFFFBBC04),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isSyncing ? 'En ligne' : 'Hors ligne',
                style: const TextStyle(
                    color: Colors.white54, fontSize: 10),
              ),
            ],
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

// ─── Carte année académique ───────────────────────────────────────────────────

class _AcademicYearCard extends StatelessWidget {
  const _AcademicYearCard({required this.year});
  final dynamic year;

  @override
  Widget build(BuildContext context) {
    final startFmt = DateFormat('d MMM yyyy', 'fr_FR');
    final start = startFmt.format(year.startDate as DateTime);
    final end   = startFmt.format(year.endDate   as DateTime);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF009A44).withValues(alpha: 0.08),
        border: Border.all(
            color: const Color(0xFF009A44).withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.school_rounded,
              size: 20, color: Color(0xFF009A44)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Année scolaire active · ${year.label}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF059669),
                  ),
                ),
                Text(
                  '$start — $end',
                  style: const TextStyle(
                      fontSize: 12, color: _kMuted),
                ),
              ],
            ),
          ),
          if (year.isLocked as bool)
            const Tooltip(
              message: 'Année verrouillée',
              child: Icon(Icons.lock_rounded,
                  size: 16, color: _kMuted),
            ),
        ],
      ),
    );
  }
}

// ─── Widgets stats ────────────────────────────────────────────────────────────

class _StatCardItem extends StatelessWidget {
  const _StatCardItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });
  final String   label;
  final String   value;
  final IconData icon;
  final Color    color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return StatCard(
      label: label,
      value: value,
      icon:  icon,
      color: color,
      onTap: onTap,
    );
  }
}

class _StatLoading extends StatelessWidget {
  const _StatLoading({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 24, height: 24,
              child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(
                fontSize: 12, color: _kMuted)),
          ],
        ),
      ),
    );
  }
}

// ─── Accès rapide ─────────────────────────────────────────────────────────────

class _QuickAccessGrid extends StatelessWidget {
  const _QuickAccessGrid();

  final List<_QuickItem> _items = const [
    _QuickItem(icon: Icons.class_rounded,
        label: 'Classes',     route: Routes.classes,   color: _kNavy),
    _QuickItem(icon: Icons.people_rounded,
        label: 'Élèves',      route: Routes.eleves,    color: _kGreen),
    _QuickItem(icon: Icons.grade_rounded,
        label: 'Notes',       route: Routes.notes,     color: _kGold),
    _QuickItem(icon: Icons.calendar_today_rounded,
        label: 'Présences',   route: Routes.presences, color: _kPurple),
    _QuickItem(icon: Icons.attach_money_rounded,
        label: 'Paiements',   route: Routes.paiements, color: Color(0xFF0EA5E9)),
    _QuickItem(icon: Icons.campaign_rounded,
        label: 'Annonces',    route: Routes.annonces,  color: Color(0xFFEF4444)),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount:  3,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: _items.map((item) => _QuickCard(item: item)).toList(),
    );
  }
}

class _QuickItem {
  const _QuickItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.color,
  });
  final IconData icon;
  final String   label;
  final String   route;
  final Color    color;
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({required this.item});
  final _QuickItem item;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => context.push(item.route),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, color: item.color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                item.label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _kText,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
