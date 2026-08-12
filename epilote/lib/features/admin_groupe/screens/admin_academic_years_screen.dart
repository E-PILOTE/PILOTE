import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../services/admin_year_department_pdf_service.dart';
import '../services/admin_year_pdf_service.dart';
import 'admin_year_calendar_dialog.dart';
import '../../../core/utils/message_erreur.dart';

part 'admin_year_adoption.dart';
part 'admin_year_analytics.dart';
part 'admin_year_department_sheet.dart';
part 'admin_year_management.dart';
part 'admin_year_dialogs.dart';
part 'admin_year_evolution.dart';
part 'admin_year_header.dart';
part 'admin_year_kpi.dart';
part 'admin_year_rail.dart';
part 'admin_year_rail_pieces.dart';
part 'admin_year_skeleton.dart';
part 'admin_year_timeline.dart';

final _fmt = DateFormat('d MMM yyyy', 'fr_FR');
final _fmtShort = DateFormat('dd/MM/yy', 'fr_FR');

// ─── Rythme vertical de la page (cf. `_Body`) ────────────────────────────────
const double _kGapCarte = 16;
const double _kGapTitre = 14;
const double _kGapChapitre = 30;

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
        //
        // ⚠️ RYTHME VERTICAL — trois valeurs, et trois seulement.
        //  `_kGapCarte` entre deux cartes d'un même chapitre, `_kGapChapitre`
        //  entre deux chapitres, `_kGapTitre` entre un titre et son contenu.
        //  La page mélangeait auparavant 18, 22, 16 et 26 px sans règle : rien
        //  n'indiquait à l'œil où un sujet s'arrêtait et où le suivant
        //  commençait, et douze cartes identiques se lisaient comme une seule
        //  liste indifférenciée.
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
              _YearLens(years: years, selected: selected),
              const SizedBox(height: _kGapChapitre),
              const _ChapterTitle("Vue d'ensemble", icon: Icons.speed_rounded),
              const SizedBox(height: _kGapTitre),
              _KpiRow(selected: selected, prev: prev),
              const SizedBox(height: _kGapCarte),
              _YearTimelineCard(year: selected),
              const SizedBox(height: _kGapChapitre),
              const _ChapterTitle('Analyses', icon: Icons.insights_rounded),
              const SizedBox(height: _kGapTitre),
              _EvolutionCard(years: years),
              const SizedBox(height: _kGapCarte),
              _AnalyticsRow(year: selected),
              const SizedBox(height: _kGapCarte),
              _SchoolAdoptionCard(year: selected),
              const SizedBox(height: _kGapChapitre),
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
