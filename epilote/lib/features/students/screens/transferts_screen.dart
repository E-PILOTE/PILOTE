import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/pdf_preview_dialog.dart';
import '../../auth/providers/auth_provider.dart';
import '../../navigation/providers/permissions_provider.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../structure/providers/academic_year_context.dart';
import '../providers/transfers_provider.dart';
import '../services/transfers_pdf_service.dart';
import '../widgets/transfer_destination_picker.dart';
import '../../../core/utils/message_erreur.dart';
import '../../../core/utils/date_scolaire.dart';

part 'transferts_parts.dart';
part 'transferts_form.dart';

const _kSlug = 'transferts';

// Couleur par statut (cohérente avec l'export PDF).
Color _statusColor(String s) => switch (s) {
      'pending' => kAccent,
      'approved' => const Color(0xFF0EA5E9),
      'completed' => kGreen,
      'rejected' => kRed,
      _ => kNavy,
    };

String _pl(int n, String s, String p) => '$n ${n <= 1 ? s : p}';

// ════════════════════════════════════════════════════════════════════════════
//  PAGE TRANSFERTS — registre formel des départs d'élèves vers un autre
//  établissement (cycle de vie pending → approved/rejected → completed). Design
//  plateforme (KPI → filtres → table / cartes). Offline-first. À l'approbation,
//  l'inscription bascule en `transferred` (réconciliation fiche élève).
// ════════════════════════════════════════════════════════════════════════════
class TransfertsScreen extends ConsumerWidget {
  const TransfertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => const ModuleScaffold(
        slug: _kSlug,
        title: 'Transferts',
        child: _Body(),
      );
}

class _Body extends ConsumerStatefulWidget {
  const _Body();
  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  final _search = TextEditingController();
  String _status = 'all'; // all | pending | approved | rejected | completed
  bool _isTable = true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _snack(String m, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(m), backgroundColor: c));
  }

  void _resetFilters() => setState(() {
        _search.clear();
        _status = 'all';
      });

  List<TransferRow> _apply(List<TransferRow> all) {
    final q = _search.text.trim().toLowerCase();
    return all.where((t) {
      if (_status != 'all' && t.status != _status) return false;
      if (q.isEmpty) return true;
      return t.fullName.toLowerCase().contains(q) ||
          t.matricule.toLowerCase().contains(q) ||
          (t.toSchoolName ?? '').toLowerCase().contains(q) ||
          (t.className ?? '').toLowerCase().contains(q);
    }).toList();
  }

  void _openForm() => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _NewTransferDialog(),
      );

  void _openDetail(TransferRow t) => showDialog(
        context: context,
        builder: (_) => _TransferDetail(
          row: t,
          onApprove: () => _approve(t),
          onReject: () => _reject(t),
          onComplete: () => _complete(t),
          onDelete: () => _delete(t),
        ),
      );

  Future<void> _approve(TransferRow t) async {
    final me = ref.read(authNotifierProvider).valueOrNull?.id;
    await runModuleWrite(
      context,
      () => approveTransfer(
          transferId: t.id,
          enrollmentId: t.enrollmentId,
          approvedBy: me,
          reason: t.reason),
      success: 'Transfert approuvé · élève sorti de l\'effectif',
    );
  }

  Future<void> _reject(TransferRow t) async {
    final me = ref.read(authNotifierProvider).valueOrNull?.id;
    await runModuleWrite(
      context,
      () => rejectTransfer(transferId: t.id, approvedBy: me),
      success: 'Transfert rejeté',
    );
  }

  Future<void> _complete(TransferRow t) async {
    await runModuleWrite(context, () => completeTransfer(t.id),
        success: 'Transfert marqué terminé');
  }

  Future<void> _delete(TransferRow t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Supprimer ce transfert ?'),
        content: Text('Le transfert de « ${t.fullName} » sera supprimé '
            'définitivement du registre.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await runModuleWrite(context, () => deleteTransfer(t.id),
        success: 'Transfert supprimé');
  }

  void _previewPdf(List<TransferRow> rows) {
    if (rows.isEmpty) {
      _snack('Aucun transfert à exporter', kTextMuted);
      return;
    }
    final year = ref.read(activeYearProvider)?.label;
    showPdfPreviewDialog(
      context,
      title: 'Transferts',
      subtitle: '${_pl(rows.length, 'transfert', 'transferts')}'
          '${year != null ? ' · $year' : ''}',
      pdfFileName: 'Transferts.pdf',
      build: (format) =>
          TransfersPdfService.buildPdf(rows: rows, yearLabel: year),
      onDownload: () =>
          TransfersPdfService.downloadDoc(rows: rows, yearLabel: year),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(transfersProvider);
    final readOnly = ref.watch(yearReadOnlyProvider);
    // Un état vide n'est pas une porte ouverte : la barre d'outils passe par
    // le verbe `create`, l'`AdminEmptyState` doit le faire aussi. La RLS
    // exige ce verbe à l'INSERT ; un refus est un 42501, code FATAL pour le
    // connecteur PowerSync — le lot d'écritures entier est jeté.
    final canCreate =
        ref.watch(canProvider((slug: _kSlug, action: 'create'))) && !readOnly;
    return async.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(messageErreur(e), style: TextStyle(color: kRed)),
        ),
      ),
      data: (all) {
        final st = ref.watch(transferStatsProvider);
        final filtered = _apply(all);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Kpis(st: st),
              const SizedBox(height: 22),
              _FilterBar(
                searchCtrl: _search,
                status: _status,
                isTable: _isTable,
                readOnly: readOnly,
                onSearch: (_) => setState(() {}),
                onStatus: (v) => setState(() => _status = v),
                onToggleView: () => setState(() => _isTable = !_isTable),
                onReset: _resetFilters,
                onAdd: _openForm,
              ),
              const SizedBox(height: 16),
              _ResultHeader(
                total: all.length,
                filtered: filtered.length,
                onExportPdf:
                    filtered.isEmpty ? null : () => _previewPdf(filtered),
              ),
              const SizedBox(height: 12),
              if (all.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: AdminEmptyState(
                    icon: Icons.swap_horiz_rounded,
                    title: 'Aucun transfert',
                    message:
                        'Enregistrez le départ d\'un élève vers un autre '
                        'établissement. Le suivi (approbation, sortie de '
                        'l\'effectif) se fait ici.',
                    actionLabel: canCreate ? 'Nouveau transfert' : null,
                    onAction: canCreate ? _openForm : null,
                  ),
                )
              else if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 30),
                  child: AdminEmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Aucun résultat',
                    message: 'Ajustez la recherche ou les filtres.',
                  ),
                )
              else if (_isTable)
                _TransferTable(rows: filtered, onOpen: _openDetail)
              else
                _TransferCards(rows: filtered, onOpen: _openDetail),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

// ─── KPIs ─────────────────────────────────────────────────────────────────────
class _Kpis extends StatelessWidget {
  const _Kpis({required this.st});
  final TransferStats st;
  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, String, Color, String?)>[
      (Icons.swap_horiz_rounded, 'Transferts', '${st.total}', kNavy,
          'départs enregistrés'),
      (Icons.hourglass_top_rounded, 'En attente', '${st.pending}',
          st.pending > 0 ? kAccent : kTextMuted, 'à traiter'),
      (Icons.task_alt_rounded, 'Approuvés', '${st.approved}',
          const Color(0xFF0EA5E9), null),
      (Icons.check_circle_outline_rounded, 'Terminés', '${st.completed}',
          kGreen, null),
      (Icons.cancel_outlined, 'Rejetés', '${st.rejected}', kRed, null),
    ];
    return LayoutBuilder(builder: (ctx, cns) {
      final w = cns.maxWidth;
      final cols = w >= 1100 ? 5 : (w >= 720 ? 3 : (w >= 460 ? 2 : 1));
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 176,
        ),
        itemCount: items.length,
        itemBuilder: (ctx, i) {
          final (icon, label, value, color, sub) = items[i];
          return AdminStatCard(
              label: label,
              value: value,
              icon: icon,
              color: color,
              subtitle: sub);
        },
      );
    });
  }
}
