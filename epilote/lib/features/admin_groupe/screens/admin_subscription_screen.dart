import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../core/widgets/app_shell.dart';
import '../../super_admin/providers/invoices_provider.dart' show InvoiceDetail;
import '../providers/admin_subscription_provider.dart';
import 'admin_licence_card.dart';
import 'admin_licence_couverture.dart';
import 'admin_subscription_billing.dart';
import 'admin_subscription_renew_dialog.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/utils/message_erreur.dart';

part 'abonnement/abo_comparatif.dart';
part 'abonnement/abo_demande.dart';
part 'abonnement/abo_formules.dart';
part 'abonnement/abo_plan_courant.dart';
part 'abonnement/abo_quotas.dart';

class AdminSubscriptionScreen extends ConsumerWidget {
  const AdminSubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ⚠️ Le titre suit la NATURE du groupe, pas la route. Un ministère de
    // tutelle n'a pas d'abonnement : il exécute un marché (0182/0183). Lire
    // « Abonnement » en tête de la page qui décrit sa licence nationale, c'est
    // déjà lui dire qu'on le range parmi les clients mensuels.
    final estMinistere = ref
            .watch(adminSubscriptionProvider)
            .valueOrNull
            ?.subscription
            ?.estMinistere ??
        false;
    return AppShell(
      title: estMinistere ? 'Licence de tutelle' : 'Abonnement',
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
                  if (sub.estMinistere)
                    LicenceDeTutelleSection(sub: sub)
                  else
                    _CurrentPlanCard(
                      sub: sub,
                      enAttente: data.factureEnAttente,
                    ),
                  const SizedBox(height: 20),
                  if (!sub.estMinistere)
                    const AdminSectionTitle('Consommation',
                        icon: Icons.speed_rounded,
                        subtitle: 'Utilisation des quotas de votre plan'),

                  // Ce que la licence ACHÈTE : le réseau couvert en KPI
                  // cliquables, deux graphes d'utilisation, les droits ouverts,
                  // et le montant DIVISÉ — seul chiffre qui se défend en
                  // réunion.
                  //
                  // ⚠️ PAS de `_QuotaGrid` ici, et c'est le correctif : ses
                  // trois jauges affichaient « Illimité » pour un ministère, et
                  // ses cartes (110 px) ne tombaient pas au même gabarit que
                  // le `KpiGrid` du reste de l'application (118 px). Deux
                  // gabarits sur une page se voient, même sans savoir pourquoi.
                  if (sub.estMinistere)
                    LicenceCouvertureSection(sub: sub)
                  else ...[
                    const SizedBox(height: 12),
                    _QuotaGrid(sub: sub),
                    const SizedBox(height: 16),
                    _QuotaChart(sub: sub),
                  ],
                  // ⚠️ Comparer des offres, en demander une autre, suivre
                  // ses demandes : la base refuse les trois à un ministère
                  // depuis 0182. Un écran qui les propose quand même envoie
                  // l'utilisateur se faire refuser.
                  if (!sub.estMinistere)
                    _MecaniqueAbonnement(data: data, sub: sub),
                  const SizedBox(height: 24),
                  AdminSectionTitle(
                      sub.estMinistere ? 'Historique de facturation' : 'Facturation',
                      icon: Icons.receipt_long_rounded,
                      subtitle: sub.estMinistere
                          ? 'Pièces émises avant le rattachement à la licence'
                          : "Vos factures et reçus d'abonnement",
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

// ─── Ce qui n'existe QUE pour un abonnement mensuel ───────────────────────────
//  Extrait du corps de page pour que la lecture de `_Body` montre d'un coup
//  d'œil ce qui sépare les deux natures de client : le ministère lit sa
//  licence et son réseau, le groupe privé lit tout ce bloc en plus.
