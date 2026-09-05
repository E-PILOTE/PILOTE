import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../core/constants/routes.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../services/powersync/powersync_service.dart';
import '../providers/super_dashboard_provider.dart';
import 'national_map_screen.dart';
import 'super_exams_section.dart';

part 'super_dash/sd_alertes.dart';
part 'super_dash/sd_bas_de_page.dart';
part 'super_dash/sd_departements.dart';
part 'super_dash/sd_entete.dart';
part 'super_dash/sd_etats.dart';
part 'super_dash/sd_etincelles.dart';
part 'super_dash/sd_graphiques.dart';
part 'super_dash/sd_insights.dart';
part 'super_dash/sd_kpis.dart';
part 'super_dash/sd_onglets.dart';
part 'super_dash/sd_revenus.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
Color get _kNavy => kNavy;
Color get _kGreen => kGreen;
Color get _kGold => kAccent;
Color get _kRed => kRed;
Color get _kCard => kCardBg;
Color get _kBg => kSurface;
Color get _kText => kTextPrimary;
Color get _kMuted => kTextMuted;
const _kBlue   = Color(0xFF3B82F6);
const _kTeal   = Color(0xFF14B8A6);
const _kPurple = Color(0xFF8B5CF6);
const _kOrange = Color(0xFFF97316);

// ─── Couleurs département & plan ─────────────────────────────────────────────
Map<String, Color> get _kDeptColors => {
  'Brazzaville': _kNavy,   'Pointe-Noire': _kBlue,
  'Dolisie':     _kTeal,   'Pool':         _kGreen,
  'Plateaux':    _kPurple, 'Kouilou':      const Color(0xFF0EA5E9),
  'Sangha':      _kOrange, 'Niari':        const Color(0xFFEC4899),
  'Bouenza':     const Color(0xFF84CC16), 'Autres': _kGold,
};
Color _deptColor(String d) => _kDeptColors[d] ?? _kMuted;

Map<String, Color> get _kPlanColors => {
  'Institutionnel': _kNavy, 'Premium': _kBlue,
  'Pro':            _kTeal, 'Gratuit': _kGold,
};
Color _planColor(String p) {
  for (final e in _kPlanColors.entries) {
    if (p.toLowerCase().contains(e.key.toLowerCase())) return e.value;
  }
  return _kMuted;
}

// ─── Écran principal ──────────────────────────────────────────────────────────
class SuperDashboardScreen extends ConsumerWidget {
  const SuperDashboardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      const AppShell(title: 'Tableau de bord', child: _DashboardBody());
}

// Onglet actif du tableau de bord : 0 = vue d'ensemble, 1 = vue nationale
final _dashTabProvider = StateProvider.autoDispose<int>((ref) => 0);

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_dashTabProvider);
    return Container(
      color: _kBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DashboardTabs(active: tab),
          Expanded(
            child: tab == 0 ? const _OverviewTab() : const NationalMapView(),
          ),
        ],
      ),
    );
  }
}

// ─── Sélecteur d'onglets (Vue d'ensemble / Vue Nationale) ────────────────────
