import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/routes.dart';
import '../../../core/constants/caractere_groupe.dart';
import '../../../core/constants/tutelle.dart';
import '../../../core/widgets/badge_ministere.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../features/user/widgets/user_settings_cards.dart' show ThemePicker;
import '../providers/admin_settings_provider.dart';
import '../widgets/bareme_passage_card.dart';
import '../widgets/partner_opt_in_tile.dart';
import '../../../core/utils/message_erreur.dart';
import '../../../core/providers/identite_etablissement.dart';

part 'reglages/reglages_connexions.dart';
part 'reglages/reglages_conservation.dart';
part 'reglages/reglages_facturation.dart';
part 'reglages/reglages_general.dart';
part 'reglages/reglages_notifications.dart';
part 'reglages/reglages_paiement_editeur.dart';
part 'reglages/reglages_pedagogie.dart';
part 'reglages/reglages_securite.dart';
part 'reglages/reglages_support.dart';
part 'reglages/reglages_widgets.dart';

// ═════════════════════════════════════════════════════════════════════════════
// PARAMÈTRES — espace admin_groupe (online, scope group_id)
// 4 onglets persistés : Général · Facturation · Notifications · Sécurité
// ═════════════════════════════════════════════════════════════════════════════
class AdminSettingsScreen extends ConsumerStatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  ConsumerState<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends ConsumerState<AdminSettingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Paramètres',
      child: Column(
        children: [
          _SettingsTabBar(controller: _tabs),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: const [
                _GeneralTab(),
                _BillingTab(),
                _NotificationsTab(),
                _SecurityTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Barre d'onglets (style navy) ────────────────────────────────────────────
class _SettingsTabBar extends StatelessWidget {
  const _SettingsTabBar({required this.controller});
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        border: Border(bottom: BorderSide(color: kBorder)),
      ),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: kNavy,
        unselectedLabelColor: kTextMuted,
        indicatorColor: kNavy,
        indicatorWeight: 2.5,
        labelStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(icon: Icon(Icons.tune_rounded, size: 18), text: 'Général'),
          Tab(icon: Icon(Icons.payments_outlined, size: 18), text: 'Facturation'),
          Tab(icon: Icon(Icons.notifications_outlined, size: 18), text: 'Notifications'),
          Tab(icon: Icon(Icons.shield_outlined, size: 18), text: 'Sécurité'),
        ],
      ),
    );
  }
}

// ─── Conteneur scrollable pleine-largeur commun aux onglets ──────────────────
class _TabScaffold extends StatelessWidget {
  const _TabScaffold({required this.children, this.onRefresh});
  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, c) {
      final w = c.maxWidth.isFinite ? c.maxWidth : MediaQuery.of(ctx).size.width - 80;
      final scrollView = SingleChildScrollView(
        child: SizedBox(
          width: w,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      );
      if (onRefresh == null) return scrollView;
      return RefreshIndicator(onRefresh: onRefresh!, child: scrollView);
    });
  }
}

// ─── Bandeau « bouton Enregistrer » réutilisable ─────────────────────────────
