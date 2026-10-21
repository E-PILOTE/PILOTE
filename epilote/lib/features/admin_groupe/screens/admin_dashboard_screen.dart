import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../core/constants/routes.dart';
import '../../../core/widgets/app_shell.dart';
import '../providers/admin_dashboard_provider.dart';
import '../../../core/widgets/admin_ui.dart';
import 'admin_exams_dashboard_section.dart';

part 'tableau_de_bord/dash_apercu.dart';
part 'tableau_de_bord/dash_bandeau.dart';
part 'tableau_de_bord/dash_bas_de_page.dart';
part 'tableau_de_bord/dash_departements.dart';
part 'tableau_de_bord/dash_etats.dart';
part 'tableau_de_bord/dash_etincelles.dart';
part 'tableau_de_bord/dash_gouvernance.dart';
part 'tableau_de_bord/dash_graphiques.dart';
part 'tableau_de_bord/dash_kpis.dart';
part 'tableau_de_bord/dash_onglets.dart';
part 'tableau_de_bord/dash_rh.dart';
part 'tableau_de_bord/dash_risques.dart';

// ─── Accents locaux (complètent la palette admin_ui) ────────────────────────
const Color _kPurple = Color(0xFF7C3AED);
const Color _kBlue   = Color(0xFF0EA5E9);
const Color _kTeal   = Color(0xFF14B8A6);
const Color _kOrange = Color(0xFFF97316);
const Color _kPink   = Color(0xFFEC4899);

// ⚠️ Plus d'onglet « Vue régionale » (2026-10-21). C'était la carte de
// couverture d'un MINISTÈRE — les douze départements, les villes, l'analyse
// territoriale —, et la plateforme ne sert plus que des groupes privés.
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const AppShell(title: 'Tableau de bord', child: _OverviewTab());
}
