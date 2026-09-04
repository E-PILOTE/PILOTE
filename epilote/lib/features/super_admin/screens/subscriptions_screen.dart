import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/routes.dart';
import '../../../core/utils/message_erreur.dart';
import '../../../core/widgets/app_shell.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/subscriptions_provider.dart';
import 'economie/licence_form_dialog.dart';
import 'subscriptions/subs_card_grid.dart';
import 'subscriptions/subs_filter_bar.dart';
import 'subscriptions/subs_kpis.dart';
import 'subscriptions/subs_style.dart';
import 'subscriptions/subs_table_view.dart';
import 'subscriptions/subscription_detail_modal.dart';
import 'subscriptions/subscription_form_modal.dart';
import 'subscriptions/subscription_print_preview.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  ABONNEMENTS — la coquille
//
//  Ce fichier faisait 2 652 lignes. Il porte maintenant CE dont l'écran a
//  besoin pour exister : l'état (recherche, filtres, tri, vue), ce qui se
//  passe quand on clique, et l'assemblage. Le reste vit dans `subscriptions/`,
//  un fichier par responsabilité.
//
//  Règle du projet : ≤ 500 lignes par fichier Dart, coupé le long des coutures
//  de cohésion — jamais au milieu d'un widget.
// ═════════════════════════════════════════════════════════════════════════════

class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AppShell(
      title: 'Abonnements',
      child: _SubsBody(),
    );
  }
}

class _SubsBody extends ConsumerStatefulWidget {
  const _SubsBody();
  @override
  ConsumerState<_SubsBody> createState() => _SubsBodyState();
}

class _SubsBodyState extends ConsumerState<_SubsBody> {
  final _searchCtrl   = TextEditingController();
  String _filterStatus = 'tous';
  String _filterType   = 'tous';
  String _sort         = 'recent';
  bool   _isTableView  = true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<SubscriptionDetail> _applyFilters(List<SubscriptionDetail> all) {
    final q = _searchCtrl.text.toLowerCase().trim();
    return all.where((s) {
      if (q.isNotEmpty) {
        final match = s.groupName.toLowerCase().contains(q)
            || s.adminEmail.toLowerCase().contains(q)
            || (s.planName?.toLowerCase().contains(q) ?? false)
            || (s.department?.toLowerCase().contains(q) ?? false);
        if (!match) return false;
      }
      if (_filterStatus != 'tous' && s.status != _filterStatus) return false;
      if (_filterType   != 'tous' && s.groupType != _filterType) return false;
      return true;
    }).toList()..sort((a, b) => switch (_sort) {
      'az'       => a.groupName.compareTo(b.groupName),
      'za'       => b.groupName.compareTo(a.groupName),
      'echeance' => (a.end ?? DateTime(2999)).compareTo(b.end ?? DateTime(2999)),
      'revenu'   => b.priceXaf.compareTo(a.priceXaf),
      _          => b.createdAt.compareTo(a.createdAt),
    });
  }

  void _openForm({SubscriptionDetail? editing}) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      barrierDismissible: false,
      builder: (_) => SubFormModal(editing: editing),
    ).then((_) => ref.invalidate(subscriptionsProvider));
  }

  /// La licence, créée ou gérée SANS quitter la page des abonnements.
  ///
  /// ⚠️ C'est le correctif de fond. Le fondateur gère les abonnements ici ; les
  /// licences vivaient dans « Économie », un écran qu'il faut savoir chercher.
  /// Il a activé une licence, puis est venu la voir ici — et n'a rien vu.
  /// « La création et l'affectation de la licence devrait être simple comme
  /// pour les mensuelles. » C'est le MÊME formulaire qu'en Économie, ouvert
  /// depuis la ligne du ministère, avec le groupe déjà choisi.
  ///
  /// ⚠️ Et le bouton OUVRE le marché existant. Il rouvrait un formulaire de
  /// création sur un ministère qui avait déjà sa licence — l'infobulle disait
  /// « Gérer la licence », l'écran proposait d'en créer une seconde, et la
  /// garde anti-chevauchement (0186) l'aurait refusée après la saisie. Vu à
  /// l'écran le 2026-09-04.
  void _openLicence(SubscriptionDetail s) {
    final l = s.licence;
    ouvrirFormulaireLicence(
      context,
      edition: l,
      groupeImpose: l == null ? s.id : null,
    ).then((_) => ref.invalidate(subscriptionsProvider));
  }

  void _openDetail(SubscriptionDetail s) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => SubDetailModal(
        sub: s,
        onEdit:   () { Navigator.pop(context); _openForm(editing: s); },
        onStatus: (st) { Navigator.pop(context); _setStatus(s, st); },
        onPrint:  () => _printSub(s),
      ),
    );
  }

  void _printSub(SubscriptionDetail s) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => SubPrintPreviewModal(sub: s),
    );
  }

  Future<void> _setStatus(SubscriptionDetail s, String status) async {
    try {
      final client = ref.read(supabaseClientProvider);
      await client.from('school_groups').update({
        'subscription_status': status,
        'is_active': status == 'active' || status == 'trial',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', s.id);
      ref.invalidate(subscriptionsProvider);
      if (mounted) _showSuccess('Statut mis à jour : ${subStatusLabel(status)}');
    } catch (e) {
      if (mounted) _showError(cleanDbError(e));
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: kSubRed,
        behavior: SnackBarBehavior.floating));

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: kSubGreen,
        behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(subscriptionsProvider);

    return async.when(
      skipLoadingOnReload:  true,
      skipLoadingOnRefresh: true,
      loading: () => const SubShimmerSkeleton(),
      error: (e, _) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cloud_off_rounded, size: 48, color: kSubMuted),
          const SizedBox(height: 12),
          Text(messageErreur(e), style: TextStyle(color: kSubMuted)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => ref.invalidate(subscriptionsProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ]),
      ),
      data: (data) => _buildContent(data),
    );
  }

  Widget _buildContent(SubscriptionsData data) {
    final filtered = _applyFilters(data.subscriptions);

    return LayoutBuilder(builder: (context, constraints) {
      final double w = constraints.maxWidth.isFinite
          ? constraints.maxWidth
          : MediaQuery.of(context).size.width - 300;

      return SingleChildScrollView(
        child: SizedBox(
          width: w,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SubKpiGrid(data: data),
              const SizedBox(height: 20),
              SubFilterBar(
                contentWidth:   w - 48,
                searchCtrl:     _searchCtrl,
                filterStatus:   _filterStatus,
                filterType:     _filterType,
                sort:           _sort,
                isTableView:    _isTableView,
                onSearchChange: (_) => setState(() {}),
                onStatus:       (v) => setState(() => _filterStatus = v),
                onType:         (v) => setState(() => _filterType   = v),
                onSort:         (v) => setState(() => _sort         = v),
                onToggleView:   ()  => setState(() => _isTableView  = !_isTableView),
                onReset: () => setState(() {
                  _searchCtrl.clear();
                  _filterStatus = _filterType = 'tous';
                  _sort = 'recent';
                }),
                // ⚠️ NE CRÉE PLUS DE GROUPE ICI. Ce dialogue en créait un sans
                // `tutelle` — donc invisible de son ministère, et ses écoles
                // en héritaient une tutelle nulle : exactement la brèche que
                // les migrations 0155 et 0158 ont fermée. Deux formulaires de
                // création avec des champs différents, c'est la garantie qu'un
                // groupe naît un jour à moitié configuré.
                // Un seul endroit crée un groupe : l'écran des groupes.
                onAdd: () => context.go(Routes.superGroupes),
              ),
              const SizedBox(height: 16),
              SubResultHeader(total: data.total, filtered: filtered.length),
              const SizedBox(height: 12),
              if (_isTableView)
                SubTableView(
                  subs:      filtered,
                  onView:    _openDetail,
                  onEdit:    (s) => _openForm(editing: s),
                  onLicence: _openLicence,
                )
              else
                SubCardGrid(
                  subs:      filtered,
                  onView:    _openDetail,
                  onEdit:    (s) => _openForm(editing: s),
                  onLicence: _openLicence,
                ),
            ]),
          ),
        ),
      );
    });
  }
}
