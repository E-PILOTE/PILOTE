import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../core/widgets/app_shell.dart';
import '../providers/admin_reports_provider.dart';
import '../services/reports_pdf_service.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/pdf_preview_dialog.dart';
import '../../../core/utils/message_erreur.dart';

part 'rapports/rapports_barre_controle.dart';
part 'rapports/rapports_effectifs.dart';
part 'rapports/rapports_etablissements.dart';
part 'rapports/rapports_finance.dart';
part 'rapports/rapports_graphiques.dart';
part 'rapports/rapports_kpis.dart';
part 'rapports/rapports_mesures_manquantes.dart';
part 'rapports/rapports_onglets.dart';
part 'rapports/rapports_rh.dart';
part 'rapports/rapports_squelette.dart';
part 'rapports/rapports_synthese.dart';

// ─── Accents locaux (complètent la palette admin_ui) ────────────────────────
const Color _kPurple = Color(0xFF7C3AED);
const Color _kBlue   = Color(0xFF0EA5E9);
const Color _kPink   = Color(0xFFEC4899);
const Color _kOrange = Color(0xFFF97316);
const Color _kTeal   = Color(0xFF14B8A6);

List<Color> get _kPalette => [
  kNavy, kGreen, _kPurple, _kOrange, _kBlue, _kTeal, _kPink, kAccent,
];

// ─── Section courante (état UI local) ───────────────────────────────────────
enum _Section { synthese, effectifs, finance, rh, etablissements }

final _sectionProvider =
    StateProvider.autoDispose<_Section>((_) => _Section.synthese);

const List<(_Section, String, IconData)> _kSections = [
  (_Section.synthese, 'Synthèse', Icons.dashboard_rounded),
  (_Section.effectifs, 'Effectifs', Icons.groups_rounded),
  (_Section.finance, 'Finance', Icons.payments_rounded),
  (_Section.rh, 'Personnel', Icons.badge_rounded),
  (_Section.etablissements, 'Établissements', Icons.account_balance_rounded),
];

// ════════════════════════════════════════════════════════════════════════════
//  SCREEN
// ════════════════════════════════════════════════════════════════════════════
class AdminReportsScreen extends ConsumerWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(reportFilterProvider);
    final async = ref.watch(reportDataProvider(filter));
    return AppShell(
      title: 'Rapports',
      child: RefreshIndicator(
        color: kNavy,
        onRefresh: () => ref.refresh(reportsSnapshotProvider.future),
        child: async.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => const _ShimmerSkeleton(),
          error: (e, _) => _ErrorView(
            error: e,
            onRetry: () => ref.invalidate(reportsSnapshotProvider),
          ),
          data: (d) => _Body(data: d),
        ),
      ),
    );
  }
}

// ─── Vue d'erreur (scrollable → pull-to-refresh actif) ───────────────────────
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 120, horizontal: 24),
        children: [
          Icon(Icons.cloud_off_rounded, size: 48, color: kTextMuted),
          const SizedBox(height: 12),
          Text('Impossible de charger les rapports.\n$error',
              textAlign: TextAlign.center,
              style: TextStyle(color: kTextMuted)),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ),
        ],
      );
}

// ════════════════════════════════════════════════════════════════════════════
//  BODY
// ════════════════════════════════════════════════════════════════════════════
class _Body extends ConsumerWidget {
  const _Body({required this.data});
  final ReportData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(_sectionProvider);

    return LayoutBuilder(builder: (ctx, constraints) {
      final double w = constraints.maxWidth.isFinite
          ? constraints.maxWidth
          : MediaQuery.of(ctx).size.width - 80;

      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          width: w,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ControlBar(data: data),
                const SizedBox(height: 16),
                // AVANT les chiffres : ce que la lecture n'a pas pu obtenir.
                // Un rapport de groupe part au ministère ; on ne laisse pas
                // découvrir après coup que les zéros venaient d'un échec.
                if (data.mesuresManquantes.isNotEmpty) ...[
                  _MesuresManquantesRapport(data: data),
                  const SizedBox(height: 16),
                ],
                _SectionTabs(
                  current: section,
                  onChanged: (s) =>
                      ref.read(_sectionProvider.notifier).state = s,
                ),
                const SizedBox(height: 20),
                switch (section) {
                  _Section.synthese => _SyntheseSection(data: data),
                  _Section.effectifs => _EffectifsSection(data: data),
                  _Section.finance => _FinanceSection(data: data),
                  _Section.rh => _RhSection(data: data),
                  _Section.etablissements => _EtablissementsSection(data: data),
                },
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      );
    });
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  BARRE DE CONTRÔLE : groupe · période · école · export
// ════════════════════════════════════════════════════════════════════════════
