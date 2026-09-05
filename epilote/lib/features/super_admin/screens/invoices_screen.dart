import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
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
import '../../../core/utils/message_erreur.dart';

part 'factures/facture_detail.dart';
part 'factures/facture_paiement.dart';
part 'factures/factures_cartes.dart';
part 'factures/factures_filtres.dart';
part 'factures/factures_kpis.dart';
part 'factures/factures_table.dart';

/// Message lisible d'une erreur base (garde-fou métier via .message).
String cleanInvoiceError(Object e) =>
    e is PostgrestException ? e.message : messageErreur(e);

// ─── Design tokens ────────────────────────────────────────────────────────────
Color get _kNavy => kNavy;
Color get _kGreen => kGreen;
Color get _kGold => kAccent;
const _kOrange  = Color(0xFFFF6B35);
const _kRed     = Color(0xFFEF4444);
const _kPurple  = Color(0xFF7C3AED);
Color get _kSurface => kSurface;
Color get _kBg => kCardBg;
Color get _kBorder => kBorder;
Color get _kText => kTextPrimary;
Color get _kMuted => kTextMuted;

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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Facture remise en attente'),
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
          Icon(Icons.cloud_off_rounded, size: 48, color: _kMuted),
          const SizedBox(height: 12),
          Text(messageErreur(e), style: TextStyle(color: _kMuted)),
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
