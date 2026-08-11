import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../core/utils/jours_non_ouvres.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/pdf_preview_dialog.dart';
import '../providers/admin_academic_year_provider.dart';
import '../providers/admin_calendar_service.dart';
import '../providers/admin_year_analytics_provider.dart';
import '../providers/school_year_defaults.dart';
import '../services/admin_year_csv_service.dart';
import '../services/admin_year_pdf_service.dart';
import 'admin_year_calendar_dialog.dart';
import '../../../core/utils/message_erreur.dart';

part 'admin_year_adoption.dart';
part 'admin_year_analytics.dart';
part 'admin_year_management.dart';
part 'admin_year_dialogs.dart';
part 'admin_year_header.dart';
part 'admin_year_skeleton.dart';
part 'admin_year_timeline.dart';

final _fmt = DateFormat('d MMM yyyy', 'fr_FR');
final _fmtShort = DateFormat('dd/MM/yy', 'fr_FR');

// ─── Helpers de présentation partagés (toute la library) ───────────────────────
({String label, Color color, IconData icon}) _status(AdminYear y) {
  if (y.isLocked) {
    return (label: 'Archivée', color: kAccent, icon: Icons.archive_rounded);
  }
  if (y.isCurrent) {
    return (label: 'En cours', color: kGreen, icon: Icons.play_circle_rounded);
  }
  if (y.startDate.isAfter(DateTime.now())) {
    return (label: 'À venir', color: kNavy, icon: Icons.schedule_rounded);
  }
  return (label: 'Passée', color: kTextMuted, icon: Icons.history_rounded);
}

String _typeLabel(String t) => switch (t) {
      'public' => 'Public',
      'prive' => 'Privé',
      _ => t.isEmpty ? 'Autre' : '${t[0].toUpperCase()}${t.substring(1)}',
    };

Color _typeColor(String t) => switch (t) {
      'public' => kNavy,
      'prive' => kGreen,
      _ => kTextMuted,
    };

List<Color> get _palette => <Color>[
  kNavy,
  kGreen,
  const Color(0xFF0EA5E9),
  const Color(0xFF7C3AED),
  const Color(0xFFEF4444),
  const Color(0xFFF59E0B),
  const Color(0xFF0891B2),
  const Color(0xFFDB2777),
  const Color(0xFF65A30D),
  const Color(0xFF9333EA),
];
Color _palAt(int i) => _palette[i % _palette.length];

/// Variation en pourcentage entre deux valeurs (null si pas de base).
({String text, Color color, IconData icon})? _delta(num current, num? base) {
  if (base == null || base == 0) return null;
  final pct = (current - base) / base * 100;
  if (pct.abs() < 0.5) {
    return (text: 'stable', color: kTextMuted, icon: Icons.remove_rounded);
  }
  final up = pct > 0;
  return (
    text: '${up ? '+' : ''}${pct.toStringAsFixed(0)} % vs N-1',
    color: up ? kGreen : kRed,
    icon: up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
  );
}

// ════════════════════════════════════════════════════════════════════════════
//  ÉCRAN
// ════════════════════════════════════════════════════════════════════════════
class AdminAcademicYearsScreen extends ConsumerWidget {
  const AdminAcademicYearsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AppShell(title: 'Années scolaires', child: _Body());
  }
}

class _Body extends ConsumerWidget {
  const _Body();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminAcademicYearsProvider);
    return async.when(
      loading: () => const _YearsSkeleton(),
      error: (e, _) => Center(
        child: AdminEmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Impossible de charger les années',
          message: '$e',
        ),
      ),
      data: (years) {
        if (years.isEmpty) return const _EmptyState();

        // Année sélectionnée : choix utilisateur → courante → 1ʳᵉ.
        AdminYear? current;
        for (final y in years) {
          if (y.isCurrent) {
            current = y;
            break;
          }
        }
        final sel = ref.watch(selectedAdminYearIdProvider);
        var idx = 0;
        if (sel != null) {
          final i = years.indexWhere((y) => y.id == sel);
          if (i >= 0) idx = i;
        } else if (current != null) {
          idx = years.indexOf(current);
        }
        final selected = years[idx];
        // Les années sont triées DESC par date → l'année N-1 est juste après.
        final prev = idx + 1 < years.length ? years[idx + 1] : null;

        // Pleine largeur (pas de ConstrainedBox) → s'étend sur les 27 pouces.
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(adminAcademicYearsProvider);
            ref.invalidate(adminYearAnalyticsProvider(selected.id));
            ref.invalidate(adminYearCalendarProvider(selected.id));
            ref.invalidate(adminYearHolidaysProvider(selected.id));
            await ref.read(adminAcademicYearsProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 90),
            children: [
              _Header(years: years, selected: selected),
              const SizedBox(height: 18),
              _StatsSelectorBar(years: years, selectedId: selected.id),
              const SizedBox(height: 18),
              _KpiRow(selected: selected, prev: prev),
              const SizedBox(height: 22),
              _YearTimelineCard(year: selected),
              const SizedBox(height: 16),
              _EvolutionCard(years: years),
              const SizedBox(height: 16),
              _AnalyticsRow(year: selected),
              const SizedBox(height: 16),
              _SchoolAdoptionCard(year: selected),
              const SizedBox(height: 26),
              _ManagementSection(years: years),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(years: []),
                SizedBox(height: 18),
                AdminEmptyState(
                  icon: Icons.event_note_rounded,
                  title: 'Aucune année scolaire',
                  message: 'Créez la première année du groupe. Toutes les écoles '
                      "l'hériteront automatiquement à leur prochaine synchro.",
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Sélecteur d'année (pilote TOUTES les statistiques de la page) ─────────────
class _StatsSelectorBar extends ConsumerWidget {
  const _StatsSelectorBar({required this.years, required this.selectedId});
  final List<AdminYear> years;
  final String selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AdminCard(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, size: 18, color: kNavy),
              const SizedBox(width: 8),
              Text('Statistiques par année',
                  style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "— sélectionnez l'année à analyser ; KPI et graphiques "
                  'ci-dessous se mettent à jour.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: kTextMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _YearChips(years: years, selectedId: selectedId),
        ],
      ),
    );
  }
}

class _YearChips extends ConsumerWidget {
  const _YearChips({required this.years, required this.selectedId});
  final List<AdminYear> years;
  final String selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: years.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final y = years[i];
          final st = _status(y);
          final on = y.id == selectedId;
          return InkWell(
            onTap: () =>
                ref.read(selectedAdminYearIdProvider.notifier).state = y.id,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: on ? kNavy : kCardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: on ? kNavy : kBorder),
                boxShadow: on
                    ? [
                        BoxShadow(
                          color: kNavy.withValues(alpha: 0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: st.color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 7),
                      Text(y.label,
                          style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: on ? Colors.white : kTextPrimary)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text('${y.eleves} élèves · ${y.classes} classes',
                      style: TextStyle(
                          fontSize: 11,
                          color: on
                              ? Colors.white.withValues(alpha: 0.8)
                              : kTextMuted)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Ligne de KPI (année sélectionnée + variation N-1) ─────────────────────────
class _KpiRow extends ConsumerWidget {
  const _KpiRow({required this.selected, required this.prev});
  final AdminYear selected;
  final AdminYear? prev;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics =
        ref.watch(adminYearAnalyticsProvider(selected.id)).valueOrNull;
    final st = _status(selected);
    final dEleves = _delta(selected.eleves, prev?.eleves);
    final dClasses = _delta(selected.classes, prev?.classes);
    final adoptPct = selected.schoolsTotal == 0
        ? 0
        : (selected.schoolsAdopted / selected.schoolsTotal * 100).round();
    final moy = analytics?.moyenneElevesParClasse ?? 0;

    final cards = <Widget>[
      AdminStatCard(
        label: 'Élèves inscrits',
        value: '${selected.eleves}',
        icon: Icons.people_rounded,
        color: kGreen,
        subtitle: dEleves?.text ?? 'Année ${st.label.toLowerCase()}',
      ),
      AdminStatCard(
        label: 'Classes ouvertes',
        value: '${selected.classes}',
        icon: Icons.class_rounded,
        color: kNavy,
        subtitle: dClasses?.text ??
            (moy > 0 ? '${moy.toStringAsFixed(1)} élèves/classe' : '—'),
      ),
      AdminStatCard(
        label: 'Écoles préparées',
        value: '${selected.schoolsAdopted}/${selected.schoolsTotal}',
        icon: Icons.account_balance_rounded,
        color: kAccent,
        subtitle: "$adoptPct % d'adoption",
      ),
      AdminStatCard(
        label: 'Départements couverts',
        value: '${analytics?.departementsCouverts ?? 0}',
        icon: Icons.map_rounded,
        color: const Color(0xFF7C3AED),
        subtitle: analytics == null
            ? '…'
            : 'sur ${analytics.byDepartment.length} présents',
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 900 ? 4 : (c.maxWidth >= 560 ? 2 : 1);
        // Hauteur FIXE (mainAxisExtent) plutôt qu'un childAspectRatio : la carte
        // a un contenu de hauteur constante, l'aspectRatio débordait selon la
        // largeur (overflow 19px en 4 colonnes). 190px couvre un sous-titre/label
        // sur 2 lignes sans débordement.
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: 196,
          ),
          itemBuilder: (_, i) => cards[i],
        );
      },
    );
  }
}
