import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../core/widgets/app_shell.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../providers/invoices_provider.dart';
import '../providers/school_groups_provider.dart';
import '../widgets/dunning_panel.dart';
import '../../communication/providers/notifications_provider.dart';
import '../services/financial_pdf_service.dart';

/// Message lisible d'une erreur base (garde-fou métier via .message).
String cleanInvoiceError(Object e) =>
    e is PostgrestException ? e.message : 'Erreur : $e';

// ─── Design tokens ────────────────────────────────────────────────────────────
const _kNavy    = Color(0xFF1E3A5F);
const _kGreen   = Color(0xFF009A44);
const _kGold    = Color(0xFFFBBC04);
const _kOrange  = Color(0xFFFF6B35);
const _kRed     = Color(0xFFEF4444);
const _kPurple  = Color(0xFF7C3AED);
const _kSurface = Color(0xFFF0F4F8);
const _kBg      = Color(0xFFFFFFFF);
const _kBorder  = Color(0xFFE2E8F0);
const _kText    = Color(0xFF0F172A);
const _kMuted   = Color(0xFF64748B);

// ─── Helpers statut ───────────────────────────────────────────────────────────
Color _statusColor(String s) => switch (s) {
  'paid'      => _kGreen,
  'pending'   => _kGold,
  'overdue'   => _kRed,
  'cancelled' => _kMuted,
  _           => _kMuted,
};

IconData _statusIcon(String s) => switch (s) {
  'paid'      => Icons.check_circle_rounded,
  'pending'   => Icons.hourglass_top_rounded,
  'overdue'   => Icons.warning_amber_rounded,
  'cancelled' => Icons.cancel_rounded,
  _           => Icons.help_rounded,
};

String _statusLabel(String s) => switch (s) {
  'paid'      => 'Payée',
  'pending'   => 'En attente',
  'overdue'   => 'En retard',
  'cancelled' => 'Annulée',
  _           => s,
};

String _methodLabel(String? m) => switch (m) {
  'mtn_money'   => 'MTN Money',
  'airtel_money' => 'Airtel Money',
  'visa'        => 'Visa/Carte',
  'especes'     => 'Espèces',
  _             => '—',
};

IconData _methodIcon(String? m) => switch (m) {
  'mtn_money'   => Icons.phone_android_rounded,
  'airtel_money' => Icons.phone_android_rounded,
  'visa'        => Icons.credit_card_rounded,
  'especes'     => Icons.payments_rounded,
  _             => Icons.payment_rounded,
};

// ─── Helpers formatage ────────────────────────────────────────────────────────
String _money(int v) {
  final s = v.abs().toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return '${v < 0 ? '-' : ''}$buf';
}

const _moisFr = [
  'jan.', 'fév.', 'mars', 'avr.', 'mai', 'juin',
  'juil.', 'août', 'sep.', 'oct.', 'nov.', 'déc.',
];

String _fmtDate(DateTime? d) {
  if (d == null) return '—';
  final l = d.toLocal();
  return '${l.day} ${_moisFr[l.month - 1]} ${l.year}';
}

String _fmtPeriod(DateTime start, DateTime end) =>
    '${_fmtDate(start)} → ${_fmtDate(end)}';

// ─── Écran principal ──────────────────────────────────────────────────────────

class InvoicesScreen extends ConsumerWidget {
  const InvoicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AppShell(
      title: 'Factures',
      child: _InvoicesBody(),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _InvoicesBody extends ConsumerStatefulWidget {
  const _InvoicesBody();
  @override
  ConsumerState<_InvoicesBody> createState() => _InvoicesBodyState();
}

class _InvoicesBodyState extends ConsumerState<_InvoicesBody> {
  final _searchCtrl = TextEditingController();
  String _filterStatus = 'tous';
  String _filterMethod = 'tous';
  String _sort         = 'recent';
  bool   _isTableView  = true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<InvoiceDetail> _applyFilters(List<InvoiceDetail> all) {
    final q = _searchCtrl.text.toLowerCase().trim();
    return all.where((inv) {
      if (q.isNotEmpty) {
        final match = inv.groupName.toLowerCase().contains(q)
            || inv.invoiceNumber.toLowerCase().contains(q)
            || (inv.planName?.toLowerCase().contains(q) ?? false);
        if (!match) return false;
      }
      if (_filterStatus != 'tous' && inv.status != _filterStatus) return false;
      if (_filterMethod != 'tous' && inv.paymentMethod != _filterMethod) return false;
      return true;
    }).toList()
      ..sort((a, b) => switch (_sort) {
        'az'      => a.groupName.compareTo(b.groupName),
        'za'      => b.groupName.compareTo(a.groupName),
        'montant' => b.amountXaf.compareTo(a.amountXaf),
        'echeance'=> a.periodEnd.compareTo(b.periodEnd),
        _         => b.createdAt.compareTo(a.createdAt),
      });
  }

  void _openDetail(InvoiceDetail inv) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.50),
      builder: (_) => _InvoiceDetailModal(
        invoice: inv,
        onMarkPaid: () => _markPaid(inv),
        onCancel:   () => _cancelInvoice(inv),
        onReopen:   () => _reopenInvoice(inv),
      ),
    );
  }

  Future<void> _markPaid(InvoiceDetail inv) async {
    Navigator.pop(context); // ferme modal détail

    // Afficher dialogue de confirmation paiement
    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => _PaymentConfirmDialog(invoice: inv),
    );
    if (result == null) return; // annulé

    try {
      final client = ref.read(supabaseClientProvider);
      // Appel RPC qui: marque payé + active le groupe + crée notification
      final res = await client.rpc('mark_invoice_paid', params: {
        'p_invoice_id':     inv.id,
        'p_payment_method': result['method'],
        'p_payment_ref':    result['ref']?.isNotEmpty == true ? result['ref'] : null,
        'p_notes':          result['notes']?.isNotEmpty == true ? result['notes'] : null,
      });

      // Invalider tous les providers impactés
      ref.invalidate(invoicesProvider);
      ref.invalidate(schoolGroupsProvider); // statut groupe mis à jour
      ref.invalidate(notificationsProvider); // nouvelle notification créée

      if (mounted) {
        final receiptNum = (res as Map?)?['receipt_number'] ?? '';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(
              'Paiement confirmé ! Reçu $receiptNum — Groupe activé',
              style: const TextStyle(fontWeight: FontWeight.w600),
            )),
          ]),
          backgroundColor: _kGreen,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(cleanInvoiceError(e)),
          backgroundColor: _kRed,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _cancelInvoice(InvoiceDetail inv) async {
    Navigator.pop(context);
    try {
      await ref.read(supabaseClientProvider)
          .from('group_invoices')
          .update({
            'status':    'cancelled',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', inv.id);
      ref.invalidate(invoicesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Facture annulée'),
          backgroundColor: _kOrange,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(cleanInvoiceError(e)),
          backgroundColor: _kRed,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _reopenInvoice(InvoiceDetail inv) async {
    Navigator.pop(context);
    try {
      await ref.read(supabaseClientProvider)
          .from('group_invoices')
          .update({
            'status':    'pending',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', inv.id);
      ref.invalidate(invoicesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Facture remise en attente'),
          backgroundColor: _kNavy,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(cleanInvoiceError(e)),
          backgroundColor: _kRed,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(invoicesProvider);

    return async.when(
      skipLoadingOnReload:  true,
      skipLoadingOnRefresh: true,
      loading: () => const _ShimmerSkeleton(),
      error: (e, _) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_rounded, size: 48, color: _kMuted),
          const SizedBox(height: 12),
          Text('Erreur : $e', style: const TextStyle(color: _kMuted)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => ref.invalidate(invoicesProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ]),
      ),
      data: (data) {
        final filtered = _applyFilters(data.invoices);
        return LayoutBuilder(builder: (context, constraints) {
          final w = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.of(context).size.width - 300;
          return SingleChildScrollView(
            child: SizedBox(
              width: w,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _KpiGrid(data: data),
                  const DunningPanel(),
                  const SizedBox(height: 20),
                  _FilterBar(
                    contentWidth:   w - 48,
                    searchCtrl:     _searchCtrl,
                    filterStatus:   _filterStatus,
                    filterMethod:   _filterMethod,
                    sort:           _sort,
                    isTableView:    _isTableView,
                    onSearchChange: (_) => setState(() {}),
                    onStatus:       (v) => setState(() => _filterStatus = v),
                    onMethod:       (v) => setState(() => _filterMethod = v),
                    onSort:         (v) => setState(() => _sort = v),
                    onToggleView:   () => setState(() => _isTableView = !_isTableView),
                    onReset: () => setState(() {
                      _searchCtrl.clear();
                      _filterStatus = _filterMethod = 'tous';
                      _sort = 'recent';
                    }),
                    onRefresh: () => ref.invalidate(invoicesProvider),
                  ),
                  const SizedBox(height: 16),
                  _ResultHeader(total: data.total, filtered: filtered.length),
                  const SizedBox(height: 12),
                  if (_isTableView)
                    _TableView(items: filtered, onView: _openDetail)
                  else
                    _CardGrid(items: filtered, onView: _openDetail),
                ]),
              ),
            ),
          );
        });
      },
    );
  }
}

// ─── KPI Grid ─────────────────────────────────────────────────────────────────

class _KD {
  const _KD({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.sub,
    this.progress,
  });
  final String  label, value;
  final String? sub;
  final double? progress;
  final IconData icon;
  final Color   color;
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.data});
  final InvoicesData data;

  @override
  Widget build(BuildContext context) {
    final n = data.total;
    final items = [
      _KD(
        label: 'Total factures', value: '$n',
        sub: '${data.totalPaid} payées · ${data.totalPending} en attente',
        icon: Icons.description_rounded, color: _kNavy,
        progress: n > 0 ? data.totalPaid / n : 0,
      ),
      _KD(
        label: 'Payées', value: '${data.totalPaid}',
        sub: n > 0 ? '${(data.totalPaid * 100 / n).round()}% du total' : '—',
        icon: Icons.check_circle_rounded, color: _kGreen,
        progress: n > 0 ? data.totalPaid / n : 0,
      ),
      _KD(
        label: 'En attente', value: '${data.totalPending}',
        sub: 'À encaisser',
        icon: Icons.hourglass_top_rounded, color: _kGold,
        progress: n > 0 ? data.totalPending / n : 0,
      ),
      _KD(
        label: 'En retard', value: '${data.totalOverdue}',
        sub: data.totalOverdue > 0 ? '⚠️ Action requise' : 'Aucun retard',
        icon: Icons.warning_amber_rounded, color: _kRed,
        progress: n > 0 ? data.totalOverdue / n : 0,
      ),
      _KD(
        label: 'Montant encaissé', value: '${_money(data.montantEncaisse)} F',
        sub: 'Total payé (XAF)',
        icon: Icons.account_balance_wallet_rounded, color: _kPurple,
        progress: data.montantEncaisse > 0 ? 1.0 : 0,
      ),
      _KD(
        label: 'Montant en attente', value: '${_money(data.montantPending)} F',
        sub: 'Pending + En retard',
        icon: Icons.pending_actions_rounded, color: _kOrange,
        progress: (data.montantEncaisse + data.montantPending) > 0
            ? data.montantPending / (data.montantEncaisse + data.montantPending)
            : 0,
      ),
    ];

    return LayoutBuilder(builder: (_, c) {
      final cols = c.maxWidth > 800 ? 3 : 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 2.6,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => _KpiCard(d: items[i], idx: i),
      );
    });
  }
}

class _KpiCard extends StatefulWidget {
  const _KpiCard({required this.d, required this.idx});
  final _KD d;
  final int idx;
  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard> with SingleTickerProviderStateMixin {
  bool _hov = false;
  late final AnimationController _entry;
  late final Animation<double>   _fade;
  late final Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fade  = CurvedAnimation(parent: _entry, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entry, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: 60 * widget.idx), () {
      if (mounted) _entry.forward();
    });
  }

  @override
  void dispose() { _entry.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hov = true),
          onExit:  (_) => setState(() => _hov = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kBorder),
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
                    colors: [d.color, d.color.withValues(alpha: _hov ? 0.9 : 0.4)],
                  )),
                ),
                Expanded(child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(d.value, style: TextStyle(
                          color: d.color, fontSize: 22,
                          fontWeight: FontWeight.w900, letterSpacing: -0.5,
                        ), overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(d.label, style: const TextStyle(
                          color: _kMuted, fontSize: 11.5, fontWeight: FontWeight.w600,
                        ), overflow: TextOverflow.ellipsis),
                        if (d.sub != null)
                          Text(d.sub!, style: TextStyle(
                            color: d.color.withValues(alpha: 0.70), fontSize: 10,
                          ), overflow: TextOverflow.ellipsis),
                      ])),
                      const SizedBox(width: 10),
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: _kSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _kBorder),
                        ),
                        child: Icon(d.icon, color: d.color, size: 18),
                      ),
                    ]),
                    const Spacer(),
                    if (d.progress != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: d.progress!.clamp(0.0, 1.0),
                          backgroundColor: d.color.withValues(alpha: 0.08),
                          valueColor: AlwaysStoppedAnimation(
                            d.color.withValues(alpha: _hov ? 1.0 : 0.75)),
                          minHeight: 4,
                        ),
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

// ─── Shimmer ──────────────────────────────────────────────────────────────────

class _ShimmerSkeleton extends StatelessWidget {
  const _ShimmerSkeleton();

  Widget _box(double w, double h, {double r = 10}) => Container(
    width: w, height: h,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(r),
    ),
  );

  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: const Color(0xFFE8ECF0),
    highlightColor: const Color(0xFFF5F7FA),
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, crossAxisSpacing: 14,
            mainAxisSpacing: 14, childAspectRatio: 2.6,
          ),
          itemCount: 6,
          itemBuilder: (_, _) => _box(double.infinity, double.infinity, r: 14),
        ),
        const SizedBox(height: 20),
        _box(double.infinity, 110, r: 12),
        const SizedBox(height: 16),
        _box(160, 18, r: 8),
        const SizedBox(height: 16),
        _box(double.infinity, 44, r: 6),
        const SizedBox(height: 1),
        ...List.generate(7, (_) => Column(children: [
          const SizedBox(height: 1),
          _box(double.infinity, 56, r: 0),
        ])),
      ]),
    ),
  );
}

// ─── Barre de filtres ─────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.contentWidth,
    required this.searchCtrl,
    required this.filterStatus,
    required this.filterMethod,
    required this.sort,
    required this.isTableView,
    required this.onSearchChange,
    required this.onStatus,
    required this.onMethod,
    required this.onSort,
    required this.onToggleView,
    required this.onReset,
    required this.onRefresh,
  });

  final double contentWidth;
  final TextEditingController searchCtrl;
  final String filterStatus, filterMethod, sort;
  final bool   isTableView;
  final ValueChanged<String> onSearchChange, onStatus, onMethod, onSort;
  final VoidCallback onToggleView, onReset, onRefresh;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: contentWidth,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: searchCtrl,
              onChanged: onSearchChange,
              decoration: InputDecoration(
                hintText: 'Rechercher par groupe, N° facture, plan…',
                hintStyle: const TextStyle(color: _kMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: _kMuted, size: 20),
                suffixIcon: searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: _kMuted),
                        onPressed: () { searchCtrl.clear(); onSearchChange(''); })
                    : null,
                filled: true,
                fillColor: _kSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _IconBtn(
            icon: isTableView ? Icons.grid_view_rounded : Icons.table_rows_rounded,
            tooltip: isTableView ? 'Vue cartes' : 'Vue tableau',
            onTap: onToggleView,
          ),
          const SizedBox(width: 8),
          _IconBtn(icon: Icons.refresh_rounded, tooltip: 'Actualiser', onTap: onRefresh),
          const SizedBox(width: 8),
          _IconBtn(icon: Icons.filter_alt_off_rounded, tooltip: 'Réinitialiser les filtres', onTap: onReset),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _FilterDropdown(
            icon: Icons.radio_button_checked_rounded,
            label: 'Statut',
            items: const {
              'tous':      'Tous les statuts',
              'pending':   'En attente',
              'paid':      'Payée',
              'overdue':   'En retard',
              'cancelled': 'Annulée',
            },
            value: filterStatus,
            onChanged: onStatus,
            active: filterStatus != 'tous',
          ),
          const SizedBox(width: 8),
          _FilterDropdown(
            icon: Icons.payment_rounded,
            label: 'Paiement',
            items: const {
              'tous':         'Tous les modes',
              'mtn_money':    'MTN Money',
              'airtel_money': 'Airtel Money',
              'visa':         'Visa/Carte',
              'especes':      'Espèces',
            },
            value: filterMethod,
            onChanged: onMethod,
            active: filterMethod != 'tous',
          ),
          const SizedBox(width: 8),
          _FilterDropdown(
            icon: Icons.sort_rounded,
            label: 'Trier',
            items: const {
              'recent':   'Plus récentes',
              'az':       'A → Z',
              'za':       'Z → A',
              'montant':  'Montant élevé',
              'echeance': 'Échéance proche',
            },
            value: sort,
            onChanged: onSort,
            active: sort != 'recent',
          ),
          const Spacer(),
          if (filterStatus != 'tous' || filterMethod != 'tous' || sort != 'recent')
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onReset,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: _kRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _kRed.withValues(alpha: 0.25)),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.filter_alt_off_rounded, size: 13, color: _kRed),
                    SizedBox(width: 4),
                    Text('Réinitialiser', style: TextStyle(
                        color: _kRed, fontSize: 11.5, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
        ]),
      ]),
    ),
  );
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String   tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBorder),
          ),
          child: Icon(icon, size: 18, color: _kNavy),
        ),
      ),
    ),
  );
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.icon,
    required this.label,
    required this.items,
    required this.value,
    required this.onChanged,
    required this.active,
  });
  final IconData              icon;
  final String                label;
  final Map<String, String>   items;
  final String                value;
  final ValueChanged<String>  onChanged;
  final bool                  active;

  @override
  Widget build(BuildContext context) => Container(
    height: 38,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: active ? _kNavy : _kSurface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: active ? _kNavy : _kBorder),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        dropdownColor: Colors.white,
        icon: Icon(Icons.arrow_drop_down, size: 18,
            color: active ? Colors.white : _kMuted),
        style: TextStyle(
          color: active ? Colors.white : _kMuted,
          fontSize: 12.5, fontWeight: FontWeight.w600,
        ),
        items: items.entries.map((e) => DropdownMenuItem(
          value: e.key,
          child: Text(e.value),
        )).toList(),
        onChanged: (v) { if (v != null) onChanged(v); },
      ),
    ),
  );
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({required this.total, required this.filtered});
  final int total, filtered;

  @override
  Widget build(BuildContext context) => Row(children: [
    Text('$filtered résultat${filtered > 1 ? "s" : ""}',
        style: const TextStyle(color: _kText, fontSize: 14, fontWeight: FontWeight.w700)),
    if (filtered < total) ...[
      const SizedBox(width: 8),
      Text('sur $total', style: const TextStyle(color: _kMuted, fontSize: 13)),
    ],
  ]);
}

// ─── Vue Tableau ──────────────────────────────────────────────────────────────

class _TableView extends StatelessWidget {
  const _TableView({required this.items, required this.onView});
  final List<InvoiceDetail> items;
  final ValueChanged<InvoiceDetail> onView;

  static Widget _hdr(String label, int flex) => Expanded(
    flex: flex,
    child: Text(label, style: const TextStyle(
        color: _kMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.4),
        overflow: TextOverflow.ellipsis),
  );

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _EmptyState();

    return Container(
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 8, offset: const Offset(0, 2),
        )],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(children: [
          Container(
            height: 38, color: _kSurface,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _hdr('N° Facture',   2),
              _hdr('Groupe',       3),
              _hdr('Plan',         2),
              _hdr('Montant XAF',  2),
              _hdr('Période',      3),
              _hdr('Mode',         2),
              _hdr('Payée le',     2),
              const SizedBox(width: 80, child: Center(
                child: Text('Statut', style: TextStyle(
                    color: _kMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
              )),
              const SizedBox(width: 36),
            ]),
          ),
          const Divider(height: 1, color: _kBorder),
          ...items.asMap().entries.map((e) => _TableRow(
            inv:   e.value,
            isOdd: e.key.isOdd,
            onTap: () => onView(e.value),
          )),
        ]),
      ),
    );
  }
}

class _TableRow extends StatefulWidget {
  const _TableRow({required this.inv, required this.isOdd, required this.onTap});
  final InvoiceDetail inv;
  final bool         isOdd;
  final VoidCallback onTap;
  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    final inv   = widget.inv;
    final color = _statusColor(inv.status);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hov = true),
      onExit:  (_) => setState(() => _hov = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _hov
                ? _kNavy.withValues(alpha: 0.04)
                : widget.isOdd ? _kSurface.withValues(alpha: 0.5) : _kBg,
            border: Border(bottom: BorderSide(color: _kBorder.withValues(alpha: 0.6))),
          ),
          child: Row(children: [
            // N° Facture
            Expanded(flex: 2, child: Text(
              inv.invoiceNumber,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kNavy),
              overflow: TextOverflow.ellipsis,
            )),
            // Groupe
            Expanded(flex: 3, child: Text(
              inv.groupName,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _kText),
              overflow: TextOverflow.ellipsis,
            )),
            // Plan
            Expanded(flex: 2, child: Text(
              inv.planName ?? '—',
              style: TextStyle(fontSize: 12, color: inv.planName != null ? _kText : _kMuted),
              overflow: TextOverflow.ellipsis,
            )),
            // Montant
            Expanded(flex: 2, child: Text(
              '${_money(inv.amountXaf)} F',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _kText),
              overflow: TextOverflow.ellipsis,
            )),
            // Période
            Expanded(flex: 3, child: Text(
              _fmtPeriod(inv.periodStart, inv.periodEnd),
              style: const TextStyle(fontSize: 11, color: _kMuted),
              overflow: TextOverflow.ellipsis,
            )),
            // Mode paiement
            Expanded(flex: 2, child: Row(children: [
              Icon(_methodIcon(inv.paymentMethod), size: 13, color: _kMuted),
              const SizedBox(width: 4),
              Flexible(child: Text(
                _methodLabel(inv.paymentMethod),
                style: const TextStyle(fontSize: 11, color: _kMuted),
                overflow: TextOverflow.ellipsis,
              )),
            ])),
            // Payée le
            Expanded(flex: 2, child: Text(
              _fmtDate(inv.paidAt),
              style: const TextStyle(fontSize: 11, color: _kMuted),
              overflow: TextOverflow.ellipsis,
            )),
            // Statut
            SizedBox(width: 96, child: _StatusBadge(status: inv.status)),
            // Action
            SizedBox(width: 36, child: Tooltip(
              message: 'Voir la facture',
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withValues(alpha: 0.20)),
                ),
                child: Icon(Icons.open_in_new_rounded, size: 13, color: color),
              ),
            )),
          ]),
        ),
      ),
    );
  }
}

// ─── Vue Cartes ───────────────────────────────────────────────────────────────

class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.items, required this.onView});
  final List<InvoiceDetail> items;
  final ValueChanged<InvoiceDetail> onView;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _EmptyState();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 14, crossAxisSpacing: 14,
        childAspectRatio: 1.6,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _InvoiceCard(inv: items[i], onTap: () => onView(items[i])),
    );
  }
}

class _InvoiceCard extends StatefulWidget {
  const _InvoiceCard({required this.inv, required this.onTap});
  final InvoiceDetail inv;
  final VoidCallback  onTap;
  @override
  State<_InvoiceCard> createState() => _InvoiceCardState();
}

class _InvoiceCardState extends State<_InvoiceCard> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    final inv   = widget.inv;
    final color = _statusColor(inv.status);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hov = true),
      onExit:  (_) => setState(() => _hov = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _kBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hov ? color.withValues(alpha: 0.4) : _kBorder,
            ),
            boxShadow: _hov
                ? [BoxShadow(color: color.withValues(alpha: 0.08),
                    blurRadius: 16, offset: const Offset(0, 4))]
                : [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                ),
                child: Icon(_statusIcon(inv.status), color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(inv.invoiceNumber, style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w800, color: _kNavy),
                    overflow: TextOverflow.ellipsis),
                Text(inv.groupName, style: const TextStyle(
                    fontSize: 11.5, color: _kMuted),
                    overflow: TextOverflow.ellipsis),
              ])),
              _StatusBadge(status: inv.status),
            ]),
            const SizedBox(height: 10),
            Text('${_money(inv.amountXaf)} XAF', style: TextStyle(
              color: color, fontSize: 18, fontWeight: FontWeight.w900,
            )),
            const SizedBox(height: 4),
            Text(inv.planName ?? 'Sans plan', style: const TextStyle(
                color: _kMuted, fontSize: 11.5)),
            const Spacer(),
            Row(children: [
              const Icon(Icons.calendar_today_rounded, size: 11, color: _kMuted),
              const SizedBox(width: 4),
              Expanded(child: Text(
                _fmtPeriod(inv.periodStart, inv.periodEnd),
                style: const TextStyle(fontSize: 10.5, color: _kMuted),
                overflow: TextOverflow.ellipsis,
              )),
            ]),
            if (inv.paidAt != null) ...[
              const SizedBox(height: 2),
              Row(children: [
                const Icon(Icons.check_circle_outline_rounded, size: 11, color: _kGreen),
                const SizedBox(width: 4),
                Text('Payée le ${_fmtDate(inv.paidAt)}',
                    style: const TextStyle(fontSize: 10.5, color: _kGreen)),
              ]),
            ],
          ]),
        ),
      ),
    );
  }
}

// ─── Badges ───────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(_statusIcon(status), size: 11, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(_statusLabel(status),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
        ),
      ]),
    );
  }
}

// ─── État vide ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 64),
    alignment: Alignment.center,
    child: const Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.description_rounded, size: 56, color: _kBorder),
      SizedBox(height: 16),
      Text('Aucune facture trouvée', style: TextStyle(
          color: _kText, fontSize: 16, fontWeight: FontWeight.w700)),
      SizedBox(height: 6),
      Text('Modifiez vos filtres pour voir plus de résultats.',
          style: TextStyle(color: _kMuted, fontSize: 13)),
    ]),
  );
}

// ─── Modal Détail Facture ─────────────────────────────────────────────────────

class _InvoiceDetailModal extends StatelessWidget {
  const _InvoiceDetailModal({
    required this.invoice,
    required this.onMarkPaid,
    required this.onCancel,
    required this.onReopen,
  });

  final InvoiceDetail invoice;
  final VoidCallback  onMarkPaid;
  final VoidCallback  onCancel;
  final VoidCallback  onReopen;

  @override
  Widget build(BuildContext context) {
    final inv   = invoice;
    final color = _statusColor(inv.status);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 620),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 32, offset: const Offset(0, 8),
          )],
        ),
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: _kBorder)),
            ),
            child: Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.30)),
                ),
                child: Icon(_statusIcon(inv.status), color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(inv.invoiceNumber, style: const TextStyle(
                    color: _kText, fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(inv.groupName, style: const TextStyle(
                    color: _kMuted, fontSize: 13)),
              ])),
              _StatusBadge(status: inv.status),
              const SizedBox(width: 10),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: _kSurface, borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _kBorder),
                    ),
                    child: const Icon(Icons.close_rounded, size: 15, color: _kMuted),
                  ),
                ),
              ),
            ]),
          ),

          // Contenu
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // Montant
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withValues(alpha: 0.08), color.withValues(alpha: 0.03)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withValues(alpha: 0.20)),
                  ),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${_money(inv.amountXaf)} XAF', style: TextStyle(
                          color: color, fontSize: 28,
                          fontWeight: FontWeight.w900, letterSpacing: -1)),
                      const SizedBox(height: 4),
                      Text(inv.planName ?? 'Sans plan',
                          style: const TextStyle(color: _kMuted, fontSize: 13)),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      const Text('Émise le', style: TextStyle(color: _kMuted, fontSize: 11)),
                      Text(_fmtDate(inv.createdAt), style: const TextStyle(
                          color: _kText, fontSize: 13, fontWeight: FontWeight.w700)),
                    ]),
                  ]),
                ),
                const SizedBox(height: 20),
                // Détails
                _DetailSection('Période de facturation', [
                  _DetailRow(Icons.calendar_today_rounded, 'Début de période', _fmtDate(inv.periodStart)),
                  _DetailRow(Icons.event_rounded, 'Fin de période', _fmtDate(inv.periodEnd)),
                ]),
                const SizedBox(height: 16),
                _DetailSection('Paiement', [
                  _DetailRow(Icons.payment_rounded, 'Mode de paiement', _methodLabel(inv.paymentMethod)),
                  _DetailRow(Icons.receipt_rounded, 'Référence', inv.paymentReference ?? '—'),
                  _DetailRow(Icons.check_circle_rounded, 'Payée le', _fmtDate(inv.paidAt)),
                ]),
                if (inv.notes != null) ...[
                  const SizedBox(height: 16),
                  _DetailSection('Notes', [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 4, 0, 0),
                      child: Text(inv.notes!, style: const TextStyle(
                          color: _kMuted, fontSize: 13)),
                    ),
                  ]),
                ],
              ]),
            ),
          ),

          // Actions footer
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _kBorder)),
            ),
            child: Row(children: [
              // Actions document officiel
              _IconBtn(
                icon: Icons.copy_rounded,
                tooltip: 'Copier le N°',
                onTap: () {
                  Clipboard.setData(ClipboardData(text: inv.invoiceNumber));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Numéro copié'),
                        behavior: SnackBarBehavior.floating));
                },
              ),
              const SizedBox(width: 8),
              _IconBtn(
                icon: Icons.print_rounded,
                tooltip: 'Imprimer',
                onTap: () => InvoicePdfService.printInvoice(inv),
              ),
              const SizedBox(width: 8),
              _IconBtn(
                icon: Icons.share_rounded,
                tooltip: 'Partager',
                onTap: () => InvoicePdfService.shareInvoice(inv),
              ),
              const SizedBox(width: 8),
              _IconBtn(
                icon: Icons.picture_as_pdf_rounded,
                tooltip: 'Télécharger PDF',
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final path = await InvoicePdfService.downloadInvoice(inv);
                  messenger.showSnackBar(SnackBar(
                    content: Text(path != null
                        ? 'Facture enregistrée : $path'
                        : 'Échec de l\'enregistrement du PDF'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: path != null ? _kGreen : _kRed,
                  ));
                },
              ),
              const Spacer(),
              if (inv.isPending || inv.isOverdue) ...[
                // Annuler
                _FooterBtn(
                  icon: Icons.cancel_rounded,
                  label: 'Annuler',
                  color: _kRed,
                  onTap: onCancel,
                ),
                const SizedBox(width: 10),
                // Marquer payée
                _FooterBtn(
                  icon: Icons.check_circle_rounded,
                  label: 'Marquer payée',
                  color: _kGreen,
                  filled: true,
                  onTap: onMarkPaid,
                ),
              ] else if (inv.isCancelled)
                _FooterBtn(
                  icon: Icons.restore_rounded,
                  label: 'Remettre en attente',
                  color: _kNavy,
                  onTap: onReopen,
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection(this.title, this.children);
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title.toUpperCase(), style: const TextStyle(
        color: _kMuted, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
    const SizedBox(height: 10),
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Column(children: children),
    ),
  ]);
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.icon, this.label, this.value);
  final IconData icon;
  final String   label, value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Icon(icon, size: 14, color: _kMuted),
      const SizedBox(width: 10),
      Expanded(child: Text(label, style: const TextStyle(color: _kMuted, fontSize: 12.5))),
      Text(value, style: const TextStyle(
          color: _kText, fontSize: 12.5, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _FooterBtn extends StatelessWidget {
  const _FooterBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.filled = false,
  });
  final IconData     icon;
  final String       label;
  final Color        color;
  final bool         filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color:  filled ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: filled ? color : color.withValues(alpha: 0.25)),
          boxShadow: filled ? [BoxShadow(
            color: color.withValues(alpha: 0.25),
            blurRadius: 8, offset: const Offset(0, 3),
          )] : [],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: filled ? Colors.white : color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
              color: filled ? Colors.white : color,
              fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
      ),
    ),
  );
}

// ─── Dialogue confirmation paiement ──────────────────────────────────────────

class _PaymentConfirmDialog extends StatefulWidget {
  const _PaymentConfirmDialog({required this.invoice});
  final InvoiceDetail invoice;

  @override
  State<_PaymentConfirmDialog> createState() => _PaymentConfirmDialogState();
}

class _PaymentConfirmDialogState extends State<_PaymentConfirmDialog> {
  String _method = 'especes';
  final _refCtrl   = TextEditingController();
  final _notesCtrl = TextEditingController();

  static const _methods = {
    'especes':     ('Espèces',      Icons.payments_rounded),
    'mtn_money':   ('MTN Money',    Icons.phone_android_rounded),
    'airtel_money':('Airtel Money', Icons.phone_android_rounded),
    'visa':        ('Visa / Carte', Icons.credit_card_rounded),
  };

  @override
  void dispose() {
    _refCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inv = widget.invoice;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_kNavy, Color(0xFF2A4F7A)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(children: [
                const Icon(Icons.payment_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Confirmer le paiement',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                    Text('${inv.groupName} — ${inv.invoiceNumber}',
                        style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  ]),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Montant
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _kGreen.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _kGreen.withValues(alpha: 0.2)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.monetization_on_rounded, color: _kGreen, size: 20),
                      const SizedBox(width: 10),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Montant à encaisser',
                            style: TextStyle(fontSize: 11, color: _kMuted)),
                        Text('${_money(inv.amountXaf)} XAF',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _kGreen)),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 16),

                  // Méthode de paiement
                  const Text('Mode de paiement',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kText)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _methods.entries.map((e) {
                      final sel = _method == e.key;
                      return GestureDetector(
                        onTap: () => setState(() => _method = e.key),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel ? _kNavy : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: sel ? _kNavy : _kBorder,
                              width: sel ? 2 : 1,
                            ),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(e.value.$2, size: 14,
                                color: sel ? Colors.white : _kMuted),
                            const SizedBox(width: 6),
                            Text(e.value.$1,
                                style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600,
                                  color: sel ? Colors.white : _kText,
                                )),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Référence
                  const Text('Référence de paiement (optionnel)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kText)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _refCtrl,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Ex: TXN-0045678, reçu papier n°…',
                      hintStyle: const TextStyle(fontSize: 12, color: _kMuted),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border:        OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kNavy)),
                      filled: true, fillColor: const Color(0xFFF8FAFC),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Notes
                  const Text('Notes internes (optionnel)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kText)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _notesCtrl,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Observations…',
                      hintStyle: const TextStyle(fontSize: 12, color: _kMuted),
                      isDense: true,
                      contentPadding: const EdgeInsets.all(12),
                      border:        OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kNavy)),
                      filled: true, fillColor: const Color(0xFFF8FAFC),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Avertissement
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _kGold.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _kGold.withValues(alpha: 0.3)),
                    ),
                    child: const Row(children: [
                      Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFB45309)),
                      SizedBox(width: 8),
                      Expanded(child: Text(
                        'Cette action activera le groupe scolaire et rendra ses modules accessibles.',
                        style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                      )),
                    ]),
                  ),
                  const SizedBox(height: 16),

                  // Boutons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kMuted,
                          side: const BorderSide(color: _kBorder),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        child: const Text('Annuler'),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: () => Navigator.pop(context, {
                          'method': _method,
                          'ref':    _refCtrl.text,
                          'notes':  _notesCtrl.text,
                        }),
                        icon: const Icon(Icons.check_circle_rounded, size: 16),
                        label: const Text('Confirmer le paiement',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        style: FilledButton.styleFrom(
                          backgroundColor: _kGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
