import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../core/constants/licence_statut.dart';
import '../../../core/constants/routes.dart';
import '../../../core/widgets/app_shell.dart';
import '../providers/admin_dashboard_provider.dart';
import '../providers/referentiel_national_provider.dart';
import '../providers/admin_geo_provider.dart';
import '../../../core/widgets/admin_ui.dart';
import 'admin_exams_dashboard_section.dart';
import 'admin_regional_view.dart';

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

final _adminTabProv = StateProvider.autoDispose<int>((ref) => 0);

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const AppShell(title: 'Tableau de bord', child: _Body());
}

// ─── Corps : barre d'onglets + contenu paresseux ────────────────────────────
class _Body extends ConsumerWidget {
  const _Body();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_adminTabProv);

    // ⚠️ LA VUE RÉGIONALE EST UN OUTIL DE TUTELLE, PAS UN OUTIL DE CLIENT.
    //
    // Elle dessine les DOUZE DÉPARTEMENTS du Congo, les villes réelles (OSM)
    // et une analyse territoriale des distances : c'est la carte de couverture
    // d'un ministère qui supervise un parc national. Un groupe privé y voyait
    // le même pays, avec deux ou trois épingles dessus — un instrument de
    // supervision qui n'est pas le sien, et qui ne lui apprend rien.
    //
    // Le coût n'était pas nul non plus : les trois jeux GeoJSON nationaux se
    // pré-chargeaient à CHAQUE ouverture du tableau de bord, pour tout le
    // monde, sur des connexions congolaises. Ils ne se chargent plus que là où
    // ils servent — d'où le `if` autour des `ref.watch`, et non un simple
    // masquage de l'onglet.
    final estMinistere =
        ref.watch(groupeEstMinistereProvider).valueOrNull ?? false;

    if (estMinistere) {
      ref.watch(congoBoundaryProvider);
      ref.watch(congoDepartmentsProvider);
      ref.watch(congoPlacesProvider);
    }

    // Le drapeau arrive de façon asynchrone : un ministère commence donc à
    // FAUX pendant un instant. Sans ce repli, un onglet déjà sélectionné
    // renverrait sur une vue vide au rechargement.
    final surLaCarte = estMinistere && tab == 1;

    return Column(
      children: [
        if (estMinistere) _DashTabs(tab: tab),
        Expanded(
          child: surLaCarte ? const _RegionalTab() : const _OverviewTab(),
        ),
      ],
    );
  }
}
