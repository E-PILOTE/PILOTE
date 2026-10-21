import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../core/widgets/app_shell.dart';
import '../../super_admin/providers/invoices_provider.dart' show InvoiceDetail;
import '../providers/admin_subscription_provider.dart';
import 'admin_subscription_billing.dart';
import 'admin_subscription_renew_dialog.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/utils/message_erreur.dart';

part 'abonnement/abo_comparatif.dart';
part 'abonnement/abo_demande.dart';
part 'abonnement/abo_formules.dart';
part 'abonnement/abo_mesures_manquantes.dart';
part 'abonnement/abo_plan_courant.dart';
part 'abonnement/abo_quotas.dart';

class AdminSubscriptionScreen extends ConsumerWidget {
  const AdminSubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppShell(
      title: 'Abonnement',
      child: ref.watch(adminSubscriptionProvider).when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const _SubscriptionSkeleton(),
        error: (e, _) => Center(child: Text(messageErreur(e), style: TextStyle(color: kTextMuted))),
        data: (d) => _Body(data: d),
      ),
    );
  }
}

// ─── Skeleton shimmer (état de chargement, cohérent avec les autres pages) ──────
class _SubscriptionSkeleton extends StatelessWidget {
  const _SubscriptionSkeleton();

  Widget _box(double w, double h, {double r = 12}) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(r),
        ),
      );

  Widget _grid({
    required double maxW,
    required int count,
    required int Function(double) cols,
    double tileH = 0,
    double? aspectRatio,
    double gap = 16,
  }) {
    final int n = cols(maxW);
    final double tileW = n == 1 ? maxW : (maxW - gap * (n - 1)) / n;
    final double h = aspectRatio != null ? tileW / aspectRatio : tileH;
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: List.generate(count, (_) => _box(tileW, h, r: 14)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final double w = constraints.maxWidth.isFinite
          ? constraints.maxWidth - 48
          : MediaQuery.of(ctx).size.width - 128;
      return Shimmer.fromColors(
        baseColor: const Color(0xFFE8ECF0),
        highlightColor: const Color(0xFFF5F7FA),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Carte plan courant
              _box(double.infinity, 150, r: 16),
              const SizedBox(height: 24),
              // Titre section Consommation
              _box(220, 18, r: 8),
              const SizedBox(height: 14),
              // Grille quotas — 4 colonnes large / 2 colonnes étroit
              _grid(
                maxW: w,
                count: 4,
                aspectRatio: 2.6,
                gap: 14,
                cols: (mw) => mw > 800 ? 4 : 2,
              ),
              const SizedBox(height: 28),
              // Titre section Changer de plan
              _box(240, 18, r: 8),
              const SizedBox(height: 14),
              // Grille plans (4 tuiles responsives)
              _grid(
                maxW: w,
                count: 4,
                tileH: 300,
                gap: 16,
                cols: (mw) => mw >= 1180 ? 4 : (mw >= 880 ? 3 : (mw >= 560 ? 2 : 1)),
              ),
              const SizedBox(height: 28),
              // Titre section Facturation
              _box(200, 18, r: 8),
              const SizedBox(height: 14),
              // Bloc facturation
              _box(double.infinity, 220, r: 16),
            ],
          ),
        ),
      );
    });
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.data});
  final AdminSubscriptionData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = data.subscription;
    // ⚠️ NE PAS FUSIONNER CES DEUX CAS. « Aucun abonnement » est un fait
    // vérifié ; l'échec de lecture est une absence de fait. Les confondre
    // annonçait à un client qui paie qu'il n'a pas de plan.
    if (sub == null && data.abonnementIllisible) {
      return const _AbonnementIllisible();
    }
    if (sub == null) {
      return const Center(
        child: AdminEmptyState(
          icon: Icons.credit_card_off_rounded,
          title: 'Aucun abonnement',
          message: "Ce groupe n'a pas encore de plan actif. Contactez l'administration de la plateforme.",
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => ref.refresh(adminSubscriptionProvider.future),
      child: LayoutBuilder(builder: (ctx, constraints) {
        final double w = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(ctx).size.width - 80;
        return SingleChildScrollView(
          child: SizedBox(
            width: w,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Avant la carte de plan : ce qui suit peut être incomplet,
                  // et on ne l'apprend pas après avoir lu les montants.
                  if (data.mesuresManquantes.isNotEmpty)
                    _MesuresManquantesAbonnement(data: data),
                  _CurrentPlanCard(
                    sub: sub,
                    enAttente: data.factureEnAttente,
                  ),
                  const SizedBox(height: 20),
                  const AdminSectionTitle('Consommation',
                      icon: Icons.speed_rounded,
                      subtitle: 'Utilisation des quotas de votre plan'),
                  const SizedBox(height: 12),
                  _QuotaGrid(sub: sub),
                  const SizedBox(height: 16),
                  _QuotaChart(sub: sub),
                  _MecaniqueAbonnement(data: data, sub: sub),
                  const SizedBox(height: 24),
                  AdminSectionTitle('Facturation',
                      icon: Icons.receipt_long_rounded,
                      subtitle: "Vos factures et reçus d'abonnement",
                      trailing: AdminBadge(
                          '${data.invoices.length} facture${data.invoices.length > 1 ? 's' : ''}',
                          color: kNavy)),
                  const SizedBox(height: 12),
                  BillingSection(data: data),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ─── Comparer les offres, en demander une autre, suivre ses demandes ─────────
