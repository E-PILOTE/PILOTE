import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../core/widgets/app_shell.dart';
import '../../super_admin/providers/invoices_provider.dart' show InvoiceDetail;
import '../../super_admin/providers/receipts_provider.dart' show ReceiptModel;
import '../../super_admin/services/financial_pdf_service.dart';
import '../providers/admin_subscription_provider.dart';
import 'admin_subscription_renew_dialog.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/utils/message_erreur.dart';

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
                  _CurrentPlanCard(sub: sub),
                  const SizedBox(height: 20),
                  const AdminSectionTitle('Consommation', icon: Icons.speed_rounded,
                      subtitle: 'Utilisation des quotas de votre plan'),
                  const SizedBox(height: 12),
                  _QuotaGrid(sub: sub),
                  const SizedBox(height: 16),
                  _QuotaChart(sub: sub),
                  const SizedBox(height: 24),
                  AdminSectionTitle('Changer de plan', icon: Icons.swap_horiz_rounded,
                      subtitle: 'Comparez les offres et envoyez une demande à la plateforme',
                      trailing: AdminBadge('${data.plans.length} offres', color: kNavy)),
                  const SizedBox(height: 12),
                  if (data.pendingRequest != null) ...[
                    _PendingRequestBanner(t: data.pendingRequest!),
                    const SizedBox(height: 12),
                  ],
                  _PlansGrid(
                    plans: data.plans,
                    currentPlanId: sub.planId,
                    locked: data.hasPendingRequest,
                  ),
                  if (data.plans.length > 1) ...[
                    const SizedBox(height: 24),
                    const AdminSectionTitle('Comparatif des offres', icon: Icons.table_chart_rounded,
                        subtitle: 'Limites et familles de modules par plan'),
                    const SizedBox(height: 12),
                    _ComparisonMatrix(data: data),
                  ],
                  if (data.tickets.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    AdminSectionTitle('Mes demandes', icon: Icons.history_rounded,
                        subtitle: 'Suivi de vos demandes de changement de plan',
                        trailing: AdminBadge(
                            '${data.tickets.length}', color: kNavy)),
                    const SizedBox(height: 12),
                    ...data.tickets.map((t) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _TicketRow(t: t),
                        )),
                  ],
                  const SizedBox(height: 24),
                  AdminSectionTitle('Facturation', icon: Icons.receipt_long_rounded,
                      subtitle: "Vos factures et reçus d'abonnement",
                      trailing: AdminBadge(
                          '${data.invoices.length} facture${data.invoices.length > 1 ? 's' : ''}',
                          color: kNavy)),
                  const SizedBox(height: 12),
                  _BillingSection(data: data),
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

// ─── Section facturation (factures + reçus, lecture seule) ─────────────────────
class _BillingSection extends StatelessWidget {
  const _BillingSection({required this.data});
  final AdminSubscriptionData data;

  @override
  Widget build(BuildContext context) {
    final invoices = data.invoices;
    if (invoices.isEmpty) {
      return AdminCard(
        child: Row(children: [
          Icon(Icons.receipt_long_rounded, color: kTextMuted, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Aucune facture émise pour le moment.',
                style: TextStyle(color: kTextMuted, fontSize: 13)),
          ),
        ]),
      );
    }
    return Column(children: [
      _BillingSummary(data: data),
      const SizedBox(height: 12),
      ...invoices.map((i) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _InvoiceRow(inv: i),
          )),
    ]);
  }
}

class _BillingSummary extends StatelessWidget {
  const _BillingSummary({required this.data});
  final AdminSubscriptionData data;

  @override
  Widget build(BuildContext context) {
    final reste = data.outstandingTotal;
    final items = [
      _MiniStat(label: 'Total facturé', value: data.billedTotal,
          color: kNavy, icon: Icons.summarize_rounded),
      _MiniStat(label: 'Encaissé', value: data.paidTotal,
          color: kGreen, icon: Icons.verified_rounded),
      _MiniStat(label: 'Reste à payer', value: reste,
          color: reste > 0 ? kRed : kTextMuted, icon: Icons.pending_actions_rounded),
    ];
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 640 ? 3 : 1;
      const gap = 12.0;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap, runSpacing: gap,
        children: items.map((i) => SizedBox(width: w, child: i)).toList(),
      );
    });
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, required this.color, required this.icon});
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 11.5, color: kTextMuted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(fmtXaf(value), maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
          ]),
        ),
      ]),
    );
  }
}

// ─── Ligne facture (export PDF facture + reçu) ─────────────────────────────────
class _InvoiceRow extends StatefulWidget {
  const _InvoiceRow({required this.inv});
  final InvoiceDetail inv;

  @override
  State<_InvoiceRow> createState() => _InvoiceRowState();
}

class _InvoiceRowState extends State<_InvoiceRow> {
  bool _busy = false;

  (Color, String, IconData) _statusMeta(String s) => switch (s) {
    'paid'      => (kGreen, 'Payée', Icons.check_circle_rounded),
    'pending'   => (kAccent, 'En attente', Icons.schedule_rounded),
    'overdue'   => (kRed, 'En retard', Icons.error_rounded),
    'cancelled' => (kTextMuted, 'Annulée', Icons.cancel_rounded),
    _           => (kTextMuted, s, Icons.circle),
  };

  String _d(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  ReceiptModel _toReceipt(InvoiceDetail i) => ReceiptModel(
        id: i.id,
        invoiceNumber: i.invoiceNumber,
        groupId: i.groupId,
        groupName: i.groupName,
        planName: i.planName ?? '—',
        amountXaf: i.amountXaf,
        periodStart: i.periodStart.toIso8601String(),
        periodEnd: i.periodEnd.toIso8601String(),
        paidAt: i.paidAt?.toIso8601String() ?? '',
        paymentMethod: i.paymentMethod ?? '',
        paymentReference: i.paymentReference ?? '',
        createdAt: i.createdAt.toIso8601String(),
      );

  Future<void> _run(Future<void> Function() task) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await task();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: kRed,
          content: Text('Génération PDF impossible : $e'),
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _pdfBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 15),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.inv;
    final (sc, sl, si) = _statusMeta(i.status);
    return AdminCard(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(builder: (context, c) {
        final narrow = c.maxWidth < 560;
        final info = Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: sc.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(si, color: sc, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(i.invoiceNumber, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kTextPrimary)),
                ),
                const SizedBox(width: 8),
                AdminBadge(sl, color: sc),
              ]),
              const SizedBox(height: 3),
              Text('${_d(i.periodStart)} → ${_d(i.periodEnd)}',
                  style: TextStyle(fontSize: 12, color: kTextMuted)),
            ]),
          ),
          const SizedBox(width: 12),
          Text(fmtXaf(i.amountXaf),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: sc)),
        ]);
        final actions = _busy
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: kNavy)),
              )
            : Row(mainAxisSize: MainAxisSize.min, children: [
                _pdfBtn('Facture', Icons.description_rounded, kNavy,
                    () => _run(() => InvoicePdfService.printInvoice(i))),
                if (i.isPaid) ...[
                  const SizedBox(width: 8),
                  _pdfBtn('Reçu', Icons.receipt_rounded, kGreen,
                      () => _run(() => ReceiptPdfService.printReceipt(_toReceipt(i)))),
                ],
              ]);
        if (narrow) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            info,
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerRight, child: actions),
          ]);
        }
        return Row(children: [
          Expanded(child: info),
          const SizedBox(width: 12),
          actions,
        ]);
      }),
    );
  }
}

// ─── Carte plan courant ───────────────────────────────────────────────────────
class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({required this.sub});
  final GroupSubscription sub;

  @override
  Widget build(BuildContext context) {
    final pColor = planColor(sub.planSlug);
    return AdminCard(
      accent: pColor,
      child: LayoutBuilder(builder: (context, c) {
        final narrow = c.maxWidth < 620;
        final left = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: pColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.workspace_premium_rounded, color: pColor, size: 24),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      Text('Plan ${sub.planName}',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kTextPrimary)),
                      const SizedBox(width: 10),
                      AdminBadge(statusLabel(sub.status), color: statusColor(sub.status),
                          icon: Icons.circle, ),
                    ]),
                    const SizedBox(height: 2),
                    Text(sub.priceXaf == 0
                            ? 'Gratuit'
                            : '${fmtXaf(sub.priceXaf)} / ${sub.periodSuffix}',
                        style: TextStyle(fontSize: 13, color: kTextMuted, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
            if (sub.description != null && sub.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(sub.description!, style: TextStyle(fontSize: 13, color: kTextMuted, height: 1.5)),
            ],
          ],
        );
        final right = Column(
          crossAxisAlignment: narrow ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            _PeriodLine(label: 'Début', date: sub.start),
            const SizedBox(height: 6),
            _PeriodLine(label: 'Échéance', date: sub.end),
            const SizedBox(height: 10),
            if (sub.expired)
              AdminBadge('Abonnement expiré', color: kRed, icon: Icons.error_rounded)
            else if (sub.expireSoon)
              AdminBadge('Expire dans ${sub.daysLeft} j', color: kAccent, icon: Icons.timelapse_rounded)
            else if (sub.daysLeft != null)
              AdminBadge('${sub.daysLeft} jours restants', color: kGreen, icon: Icons.check_circle_rounded),
            // Réabonnement en libre-service : visible dès que l'échéance
            // approche ou est dépassée. Génère une facture de renouvellement du
            // MÊME plan (cf. showRenewSubscriptionDialog / create_renewal_invoice).
            if (sub.expired || sub.expireSoon) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => showRenewSubscriptionDialog(context, sub),
                icon: const Icon(Icons.autorenew_rounded, size: 17),
                label: const Text('Renouveler mon abonnement'),
                style: FilledButton.styleFrom(
                  backgroundColor: sub.expired ? kRed : kNavy,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ],
        );
        if (narrow) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            left, const SizedBox(height: 16), Divider(color: kBorder), const SizedBox(height: 12), right,
          ]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: left), const SizedBox(width: 20), right,
        ]);
      }),
    );
  }
}

class _PeriodLine extends StatelessWidget {
  const _PeriodLine({required this.label, required this.date});
  final String label;
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final txt = date == null
        ? '—'
        : '${date!.day.toString().padLeft(2, '0')}/${date!.month.toString().padLeft(2, '0')}/${date!.year}';
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text('$label : ', style: TextStyle(fontSize: 12, color: kTextMuted)),
      Text(txt, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary)),
    ]);
  }
}

// ─── Grille quotas ────────────────────────────────────────────────────────────
class _QuotaGrid extends StatelessWidget {
  const _QuotaGrid({required this.sub});
  final GroupSubscription sub;

  @override
  Widget build(BuildContext context) {
    double ratioOf(int used, int max) =>
        max <= 0 ? 0.0 : (used / max).clamp(0.0, 1.0);
    String subOf(int used, int max) => max <= 0 ? 'Illimité' : '$used / $max';
    String trendOf(int used, int max) =>
        max <= 0 ? 'Illimité' : '${(used * 100 / max).round()}% utilisé';
    bool nearOf(int used, int max) => max > 0 && (used / max) >= 0.9;

    final items = <_QKD>[
      _QKD(
        label: 'Écoles', value: '${sub.schoolsUsed}',
        sub: subOf(sub.schoolsUsed, sub.maxSchools),
        icon: Icons.school_rounded, color: kNavy,
        progressValue: ratioOf(sub.schoolsUsed, sub.maxSchools),
        trend: trendOf(sub.schoolsUsed, sub.maxSchools),
        near: nearOf(sub.schoolsUsed, sub.maxSchools),
      ),
      _QKD(
        label: 'Élèves', value: '${sub.studentsUsed}',
        sub: subOf(sub.studentsUsed, sub.maxStudents),
        icon: Icons.groups_rounded, color: kGreen,
        progressValue: ratioOf(sub.studentsUsed, sub.maxStudents),
        trend: trendOf(sub.studentsUsed, sub.maxStudents),
        near: nearOf(sub.studentsUsed, sub.maxStudents),
      ),
      _QKD(
        label: 'Personnel', value: '${sub.staffUsed}',
        sub: subOf(sub.staffUsed, sub.maxStaff),
        icon: Icons.badge_rounded, color: kAccent,
        progressValue: ratioOf(sub.staffUsed, sub.maxStaff),
        trend: trendOf(sub.staffUsed, sub.maxStaff),
        near: nearOf(sub.staffUsed, sub.maxStaff),
      ),
      _QKD(
        label: 'Modules', value: '${sub.moduleCount}',
        sub: 'Modules actifs',
        icon: Icons.extension_rounded, color: const Color(0xFF7C3AED),
        trend: 'Inclus au plan',
      ),
    ];

    return LayoutBuilder(builder: (_, c) {
      final cols = c.maxWidth > 800 ? 4 : 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols, crossAxisSpacing: 14,
          mainAxisSpacing: 14, mainAxisExtent: 110,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => _QuotaCard(d: items[i], idx: i),
      );
    });
  }
}

class _QKD {
  const _QKD({
    required this.label, required this.value, required this.icon, required this.color,
    this.sub, this.trend, this.progressValue, this.near = false,
  });
  final String label, value;
  final String? sub, trend;
  final bool near;
  final double? progressValue;
  final IconData icon;
  final Color color;
}

/// Carte KPI animée — design et dimensions identiques à la page Utilisateurs.
class _QuotaCard extends StatefulWidget {
  const _QuotaCard({required this.d, required this.idx});
  final _QKD d;
  final int idx;
  @override
  State<_QuotaCard> createState() => _QuotaCardState();
}

class _QuotaCardState extends State<_QuotaCard> with SingleTickerProviderStateMixin {
  bool _hov = false;
  late final AnimationController _entry;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _fade = CurvedAnimation(parent: _entry, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entry, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: 60 * widget.idx), () {
      if (mounted) _entry.forward();
    });
  }

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    final color = d.near ? kRed : d.color;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hov = true),
          onExit: (_) => setState(() => _hov = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kBorder),
              boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: _hov ? 0.08 : 0.04),
                blurRadius: _hov ? 12 : 4,
                offset: Offset(0, _hov ? 4 : 2),
              )],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 3,
                  decoration: BoxDecoration(gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: _hov ? 0.9 : 0.4)],
                  )),
                ),
                Expanded(child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(d.value, style: TextStyle(
                          color: color, fontSize: 22,
                          fontWeight: FontWeight.w900, letterSpacing: -0.5,
                        )),
                        const SizedBox(height: 2),
                        Text(d.label, style: TextStyle(
                          color: kTextMuted, fontSize: 11.5, fontWeight: FontWeight.w600,
                        ), overflow: TextOverflow.ellipsis),
                        if (d.sub != null)
                          Text(d.sub!, style: TextStyle(
                            color: color.withValues(alpha: 0.70), fontSize: 10,
                          ), overflow: TextOverflow.ellipsis),
                      ])),
                      const SizedBox(width: 10),
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: kSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: kBorder),
                        ),
                        child: Icon(d.near ? Icons.warning_amber_rounded : d.icon,
                            color: color, size: 18),
                      ),
                    ]),
                    const Spacer(),
                    if (d.progressValue != null)
                      Row(children: [
                        Expanded(child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: d.progressValue!.clamp(0.0, 1.0),
                            backgroundColor: color.withValues(alpha: 0.08),
                            valueColor: AlwaysStoppedAnimation(
                                color.withValues(alpha: _hov ? 1.0 : 0.75)),
                            minHeight: 4,
                          ),
                        )),
                        if (d.trend != null) ...[
                          const SizedBox(width: 8),
                          Text(d.trend!, style: TextStyle(
                            color: color, fontSize: 10, fontWeight: FontWeight.w600,
                          )),
                        ],
                      ])
                    else if (d.trend != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(d.trend!, style: TextStyle(
                          color: color, fontSize: 10, fontWeight: FontWeight.w600,
                        )),
                      ),
                  ]),
                )),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Graphe de consommation des quotas ────────────────────────────────────────
class _QChartData {
  const _QChartData(this.label, this.used, this.maxVal, this.color);
  final String label;
  final int used;
  final int maxVal; // 0 = illimité
  final Color color;

  double get pct => maxVal > 0 ? (used / maxVal * 100).clamp(0.0, 100.0) : 0.0;
  bool get unlimited => maxVal <= 0;
  String get displayMax => maxVal <= 0 ? '∞' : fmtInt(maxVal);
}

class _QuotaChart extends StatelessWidget {
  const _QuotaChart({required this.sub});
  final GroupSubscription sub;

  @override
  Widget build(BuildContext context) {
    // Données : quotas avec une limite définie EN PREMIER (pour les barres),
    // quotas illimités affichés en chip séparé.
    final limited = <_QChartData>[
      if (sub.maxStudents > 0)
        _QChartData('Élèves', sub.studentsUsed, sub.maxStudents, kGreen),
      if (sub.maxStaff > 0)
        _QChartData('Personnel', sub.staffUsed, sub.maxStaff, kAccent),
      if (sub.maxSchools > 0)
        _QChartData('Écoles', sub.schoolsUsed, sub.maxSchools, kNavy),
    ];
    final unlimited = <_QChartData>[
      if (sub.maxStudents <= 0)
        _QChartData('Élèves', sub.studentsUsed, 0, kGreen),
      if (sub.maxStaff <= 0)
        _QChartData('Personnel', sub.staffUsed, 0, kAccent),
      if (sub.maxSchools <= 0)
        _QChartData('Écoles', sub.schoolsUsed, 0, kNavy),
    ];

    // Axe X : plage intelligente — zoom sur les valeurs réelles (min 5%)
    final maxPct = limited.fold<double>(0, (m, d) => max(m, d.pct));
    final xMax = max(5.0, maxPct * 1.5).ceilToDouble();

    return AdminCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── En-tête ──
        Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: kNavy.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(Icons.bar_chart_rounded, color: kNavy, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Analyse de consommation',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kTextPrimary)),
              Text('Utilisation de vos ressources par rapport aux limites du plan',
                  style: TextStyle(fontSize: 11.5, color: kTextMuted)),
            ]),
          ),
        ]),

        // ── Chips quotas illimités ──
        if (unlimited.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (final d in unlimited)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: d.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: d.color.withValues(alpha: 0.25)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.all_inclusive_rounded, size: 13, color: d.color),
                  const SizedBox(width: 5),
                  Text('${d.label} : ${fmtInt(d.used)} (Illimité)',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: d.color)),
                ]),
              ),
          ]),
        ],

        if (limited.isEmpty) ...[
          const SizedBox(height: 16),
          Center(child: Text('Tous les quotas de ce plan sont illimités.',
              style: TextStyle(fontSize: 13, color: kTextMuted))),
          const SizedBox(height: 8),
        ] else ...[
          // ── Légende ──
          const SizedBox(height: 14),
          Wrap(spacing: 14, runSpacing: 6, children: [
            for (final d in limited) ...[
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(
                    color: d.color, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 5),
                Text('${d.label} : ${fmtInt(d.used)} / ${d.displayMax}  (${d.pct.toStringAsFixed(1)}%)',
                    style: TextStyle(fontSize: 11.5, color: kTextMuted, fontWeight: FontWeight.w600)),
              ]),
            ],
          ]),
          // ── Graphe Syncfusion ──
          const SizedBox(height: 8),
          SizedBox(
            height: max(120.0, limited.length * 58.0 + 40),
            child: SfCartesianChart(
              plotAreaBackgroundColor: Colors.transparent,
              borderWidth: 0,
              margin: const EdgeInsets.only(bottom: 0),
              // BarSeries transpose le rendu : primaryXAxis = catégories (labels String),
              // primaryYAxis = valeurs numériques. Ne pas inverser — erreur type cast.
              primaryXAxis: CategoryAxis(
                majorGridLines: const MajorGridLines(width: 0),
                axisLine: const AxisLine(width: 0),
                labelStyle: TextStyle(fontSize: 12, color: kTextMuted, fontWeight: FontWeight.w700),
              ),
              primaryYAxis: NumericAxis(
                minimum: 0,
                maximum: xMax,
                labelFormat: '{value}%',
                majorGridLines: MajorGridLines(color: kBorder, width: 0.6),
                axisLine: const AxisLine(width: 0),
                labelStyle: TextStyle(fontSize: 10.5, color: kTextMuted),
              ),
              tooltipBehavior: TooltipBehavior(
                enable: true,
                format: 'point.x : point.y%',
                color: kNavy,
                textStyle: const TextStyle(color: Colors.white, fontSize: 11),
              ),
              series: <CartesianSeries>[
                // Barre "utilisé"
                BarSeries<_QChartData, String>(
                  dataSource: limited,
                  xValueMapper: (d, _) => d.label,
                  yValueMapper: (d, _) => d.pct,
                  pointColorMapper: (d, _) => d.color,
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                  width: 0.45,
                  animationDuration: 700,
                  dataLabelSettings: DataLabelSettings(
                    isVisible: true,
                    labelAlignment: ChartDataLabelAlignment.outer,
                    textStyle: TextStyle(fontSize: 11, color: kTextPrimary, fontWeight: FontWeight.w800),
                  ),
                  dataLabelMapper: (d, _) => '${d.pct.toStringAsFixed(1)}%',
                ),
                // Barre "disponible" (fond clair)
                BarSeries<_QChartData, String>(
                  dataSource: limited,
                  xValueMapper: (d, _) => d.label,
                  yValueMapper: (d, _) => xMax - d.pct,
                  pointColorMapper: (d, _) => d.color.withValues(alpha: 0.07),
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                  width: 0.45,
                  animationDuration: 700,
                  isVisibleInLegend: false,
                  enableTooltip: false,
                ),
              ],
            ),
          ),
        ],
      ]),
    );
  }
}

// ─── Grille des plans ─────────────────────────────────────────────────────────
class _PlansGrid extends StatelessWidget {
  const _PlansGrid({
    required this.plans,
    required this.currentPlanId,
    required this.locked,
  });
  final List<PlanOption> plans;
  final String? currentPlanId;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    if (plans.isEmpty) {
      return AdminCard(child: Text('Aucune offre disponible pour le moment.',
          style: TextStyle(color: kTextMuted)));
    }
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 1180 ? 4 : c.maxWidth >= 880 ? 3 : c.maxWidth >= 560 ? 2 : 1;
      const gap = 16.0;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap, runSpacing: gap,
        children: plans
            .map((p) => SizedBox(
                  width: w,
                  child: _PlanCard(
                    plan: p,
                    current: p.id == currentPlanId,
                    locked: locked,
                  ),
                ))
            .toList(),
      );
    });
  }
}

class _PlanCard extends ConsumerWidget {
  const _PlanCard({required this.plan, required this.current, required this.locked});
  final PlanOption plan;
  final bool current;
  final bool locked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pColor = planColor(plan.slug);
    return AdminCard(
      accent: current ? kGreen : pColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(plan.name, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kTextPrimary)),
            ),
            const SizedBox(width: 8),
            if (current) AdminBadge('Plan actuel', color: kGreen, icon: Icons.check_rounded),
          ]),
          const SizedBox(height: 4),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(plan.priceXaf == 0 ? 'Gratuit' : fmtXaf(plan.priceXaf),
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: pColor)),
            if (plan.priceXaf != 0)
              // La période vient du plan : « / an » en dur contredisait
              // l'espace plateforme, qui affichait « / mois » pour le MÊME
              // tarif. C'est cette divergence qu'on supprime.
              Text(' / ${plan.periodSuffix}', style: TextStyle(fontSize: 12.5, color: kTextMuted, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 12),
          _PlanFeature(icon: Icons.school_rounded, text: plan.unlimitedSchools ? 'Écoles illimitées' : '${plan.maxSchools} école${plan.maxSchools > 1 ? 's' : ''}'),
          _PlanFeature(icon: Icons.groups_rounded, text: plan.unlimitedStudents ? 'Élèves illimités' : '${fmtInt(plan.maxStudents)} élèves'),
          _PlanFeature(icon: Icons.badge_rounded, text: plan.unlimitedStaff ? 'Personnel illimité' : '${fmtInt(plan.maxStaff)} personnels'),
          _PlanFeature(icon: Icons.extension_rounded, text: '${plan.moduleCount} modules'),
          const SizedBox(height: 8),
          Text(plan.effectiveDescription, style: TextStyle(fontSize: 12, color: kTextMuted, height: 1.4)),
          if (plan.categories.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(color: kBorder, height: 1),
            const SizedBox(height: 10),
            Text('Familles de modules', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: kTextMuted, letterSpacing: 0.4)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: plan.categories
                  .map((c) => _CategoryChip(label: c.name, count: c.moduleCount, color: pColor))
                  .toList(),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: _planButton(context),
          ),
        ],
      ),
    );
  }

  Widget _planButton(BuildContext context) {
    if (current) {
      return OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.verified_rounded, size: 16),
        label: const Text('Plan en cours'),
        style: OutlinedButton.styleFrom(
          foregroundColor: kGreen,
          side: BorderSide(color: kBorder),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
    if (locked) {
      return OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.hourglass_top_rounded, size: 16),
        label: const Text('Demande en cours'),
        style: OutlinedButton.styleFrom(
          foregroundColor: kTextMuted,
          side: BorderSide(color: kBorder),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
    return FilledButton.icon(
      onPressed: () => showDialog(
        context: context,
        builder: (_) => RequestPlanChangeDialog(plan: plan),
      ),
      icon: const Icon(Icons.send_rounded, size: 16),
      label: const Text('Demander ce plan'),
      style: FilledButton.styleFrom(
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.count, required this.color});
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text('$label · $count',
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _PlanFeature extends StatelessWidget {
  const _PlanFeature({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Icon(icon, size: 15, color: kTextMuted),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: kTextPrimary))),
      ]),
    );
  }
}

// ─── Bannière « demande en cours » ─────────────────────────────────────────────
class _PendingRequestBanner extends StatelessWidget {
  const _PendingRequestBanner({required this.t});
  final SubscriptionTicket t;

  @override
  Widget build(BuildContext context) {
    final inProgress = t.status == 'in_progress';
    final color = inProgress ? kNavy : kAccent;
    final label = inProgress ? 'en cours de traitement' : 'en attente de validation';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(inProgress ? Icons.autorenew_rounded : Icons.hourglass_top_rounded, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Une demande de changement de plan est $label.',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 2),
            Text('Vous pourrez en soumettre une nouvelle une fois celle-ci traitée.',
                style: TextStyle(fontSize: 12, color: kTextMuted)),
          ]),
        ),
      ]),
    );
  }
}

// ─── Matrice comparative des plans ──────────────────────────────────────────────
class _ComparisonMatrix extends StatelessWidget {
  const _ComparisonMatrix({required this.data});
  final AdminSubscriptionData data;

  @override
  Widget build(BuildContext context) {
    final plans = data.plans;
    final cats = data.allCategories;
    final currentId = data.subscription?.planId;

    String limit(int v, {bool money = false}) {
      if (v <= 0 && !money) return 'Illimité';
      if (money) return v == 0 ? 'Gratuit' : fmtXaf(v);
      return fmtInt(v);
    }

    final rows = <_MatrixRow>[
      _MatrixRow('Tarif', Icons.payments_rounded,
          plans.map((p) => p.priceXaf == 0
              ? 'Gratuit'
              : '${limit(p.priceXaf, money: true)} / ${p.periodSuffix}').toList(),
          highlight: true),
      _MatrixRow('Périodicité', Icons.event_repeat_rounded,
          plans.map((p) => p.periodLabel).toList()),
      _MatrixRow('Écoles', Icons.school_rounded, plans.map((p) => limit(p.maxSchools)).toList()),
      _MatrixRow('Élèves', Icons.groups_rounded, plans.map((p) => limit(p.maxStudents)).toList()),
      _MatrixRow('Personnel', Icons.badge_rounded, plans.map((p) => limit(p.maxStaff)).toList()),
      _MatrixRow('Modules', Icons.extension_rounded, plans.map((p) => '${p.moduleCount}').toList()),
      for (final c in cats)
        _MatrixRow(c.name, Icons.category_rounded,
            plans.map((p) {
              final n = p.modulesInCategory(c.slug);
              return n == 0 ? '—' : '$n';
            }).toList(),
            isCategory: true),
    ];

    const labelColW = 180.0;
    const minPlanColW = 120.0;
    final minTableW = labelColW + plans.length * minPlanColW;

    Widget buildTable(double planColW) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _MatrixHeaderRow(plans: plans, currentId: currentId,
                labelColW: labelColW, planColW: planColW),
            ...rows.asMap().entries.map((e) => _MatrixDataRow(
                  row: e.value, plans: plans, currentId: currentId,
                  zebra: e.key.isOdd, labelColW: labelColW, planColW: planColW,
                )),
          ],
        );

    return AdminCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(builder: (_, c) {
          // Sur grand écran : colonnes plans s'élargissent pour remplir la largeur.
          if (c.maxWidth > minTableW) {
            final planColW = (c.maxWidth - labelColW) / plans.length;
            return buildTable(planColW);
          }
          // Sur petit écran : scroll horizontal avec largeur min.
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: minTableW, child: buildTable(minPlanColW)),
          );
        }),
      ),
    );
  }
}

class _MatrixRow {
  _MatrixRow(this.label, this.icon, this.values,
      {this.highlight = false, this.isCategory = false});
  final String label;
  final IconData icon;
  final List<String> values;
  final bool highlight;
  final bool isCategory;
}

class _MatrixHeaderRow extends StatelessWidget {
  const _MatrixHeaderRow({
    required this.plans, required this.currentId,
    this.labelColW = 180, this.planColW = 120,
  });
  final List<PlanOption> plans;
  final String? currentId;
  final double labelColW;
  final double planColW;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [kNavyDark, kNavy]),
      ),
      child: Row(children: [
        SizedBox(
          width: labelColW,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Text('Caractéristiques',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ),
        ...plans.map((p) {
          final isCurrent = p.id == currentId;
          return SizedBox(
            width: planColW,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(p.name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white)),
                if (isCurrent) ...[
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: kGreen,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Actuel',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ],
              ]),
            ),
          );
        }),
      ]),
    );
  }
}

class _MatrixDataRow extends StatelessWidget {
  const _MatrixDataRow({
    required this.row,
    required this.plans,
    required this.currentId,
    required this.zebra,
    this.labelColW = 180,
    this.planColW = 120,
  });
  final _MatrixRow row;
  final List<PlanOption> plans;
  final String? currentId;
  final bool zebra;
  final double labelColW;
  final double planColW;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: zebra ? kSurface.withValues(alpha: 0.5) : kCardBg,
        border: Border(bottom: BorderSide(color: kBorder)),
      ),
      // IntrinsicHeight : indispensable car la matrice est rendue dans un
      // SingleChildScrollView vertical (hauteur non bornée). Sans cela,
      // `CrossAxisAlignment.stretch` reçoit une hauteur infinie → crash layout.
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            width: labelColW,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Icon(row.icon, size: 15, color: row.isCategory ? kTextMuted : kNavy),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(row.label,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: row.highlight ? FontWeight.w800 : FontWeight.w600,
                          color: kTextPrimary)),
                ),
              ]),
            ),
          ),
          ...List.generate(plans.length, (i) {
            final isCurrent = plans[i].id == currentId;
            final val = i < row.values.length ? row.values[i] : '—';
            final muted = val == '—';
            return Container(
              width: planColW,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
              decoration: BoxDecoration(
                color: isCurrent ? kGreen.withValues(alpha: 0.06) : null,
                border: Border(left: BorderSide(color: kBorder)),
              ),
              child: Text(val,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: row.highlight ? FontWeight.w800 : FontWeight.w600,
                    color: muted ? Colors.grey.shade400 : (row.highlight ? planColor(plans[i].slug) : kTextPrimary),
                  )),
            );
          }),
        ]),
      ),
    );
  }
}

// ─── Ligne ticket (demande) ───────────────────────────────────────────────────
class _TicketRow extends StatelessWidget {
  const _TicketRow({required this.t});
  final SubscriptionTicket t;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (t.status) {
      'open'        => (kAccent, 'En attente'),
      'in_progress' => (kNavy, 'En traitement'),
      'resolved'    => (kGreen, 'Résolu'),
      'closed'      => (kTextMuted, 'Clôturé'),
      _             => (kTextMuted, t.status),
    };
    return AdminCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(t.subject,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextPrimary)),
            ),
            const SizedBox(width: 8),
            AdminBadge(label, color: color),
          ]),
          if (t.body != null && t.body!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(t.body!, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: kTextMuted, height: 1.4)),
          ],
          if (t.response != null && t.response!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kGreen.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kGreen.withValues(alpha: 0.2)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.support_agent_rounded, size: 16, color: kGreen),
                const SizedBox(width: 8),
                Expanded(child: Text(t.response!, style: TextStyle(fontSize: 12.5, color: kTextPrimary, height: 1.4))),
              ]),
            ),
          ],
          const SizedBox(height: 8),
          Text(_dateLabel(t.createdAt), style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  String _dateLabel(DateTime? d) {
    if (d == null) return '—';
    return 'Envoyée le ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}

class _DialogChip extends StatelessWidget {
  const _DialogChip(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: kBorder),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: kTextMuted),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kTextPrimary)),
      ]),
    );
  }
}

// ─── Modal demande de changement ──────────────────────────────────────────────
class RequestPlanChangeDialog extends ConsumerStatefulWidget {
  const RequestPlanChangeDialog({super.key, required this.plan});
  final PlanOption plan;

  @override
  ConsumerState<RequestPlanChangeDialog> createState() => _RequestPlanChangeDialogState();
}

class _RequestPlanChangeDialogState extends ConsumerState<RequestPlanChangeDialog> {
  late final TextEditingController _msg;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Plan visé pré-rempli : un motif d'ouverture éditable par l'utilisateur.
    _msg = TextEditingController(
      text: 'Nous souhaitons faire évoluer notre abonnement vers le plan '
          '${widget.plan.name}.',
    );
  }

  @override
  void dispose() {
    _msg.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() { _saving = true; _error = null; });
    try {
      await ref.read(adminSubscriptionServiceProvider).requestPlanChange(
            targetPlanName: widget.plan.name,
            message: _msg.text.trim().isEmpty
                ? 'Demande de passage au plan ${widget.plan.name}.'
                : _msg.text.trim(),
          );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: kGreen,
          content: Text('Demande envoyée pour le plan ${widget.plan.name}.'),
        ));
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminDialogHeader(
              title: 'Demander le plan ${widget.plan.name}',
              icon: Icons.swap_horiz_rounded,
              subtitle: 'Votre demande sera transmise à la plateforme',
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: planColor(widget.plan.slug).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: planColor(widget.plan.slug).withValues(alpha: 0.25)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(Icons.workspace_premium_rounded, color: planColor(widget.plan.slug), size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Plan ${widget.plan.name}', style: TextStyle(fontWeight: FontWeight.w800, color: kTextPrimary)),
                            Text(widget.plan.priceXaf == 0
                                ? 'Gratuit'
                                : '${fmtXaf(widget.plan.priceXaf)} / ${widget.plan.periodSuffix}',
                                style: TextStyle(fontSize: 12, color: kTextMuted)),
                          ]),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        _DialogChip(Icons.school_rounded, widget.plan.unlimitedSchools ? 'Écoles illimitées' : '${widget.plan.maxSchools} écoles'),
                        _DialogChip(Icons.groups_rounded, widget.plan.unlimitedStudents ? 'Élèves illimités' : '${fmtInt(widget.plan.maxStudents)} élèves'),
                        _DialogChip(Icons.badge_rounded, widget.plan.unlimitedStaff ? 'Personnel illimité' : '${fmtInt(widget.plan.maxStaff)} personnels'),
                        _DialogChip(Icons.extension_rounded, '${widget.plan.moduleCount} modules'),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _msg,
                    maxLines: 4,
                    decoration: adminInputDecoration('Motif de la demande',
                        hint: 'Précisez le motif de votre demande…'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    AdminErrorBanner(message: _error!),
                  ],
                ],
              ),
            ),
            AdminDialogFooter(
              saving: _saving,
              submitLabel: 'Envoyer la demande',
              submitIcon: Icons.send_rounded,
              onCancel: () => Navigator.of(context).pop(),
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
