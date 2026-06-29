import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../../navigation/providers/permissions_provider.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../vie_scolaire/widgets/vs_form_chrome.dart';
import '../../vie_scolaire/widgets/vs_kit.dart';
import '../providers/payroll_provider.dart';
import '../providers/staff_directory_provider.dart';
import '../widgets/staff_kit.dart';

part 'paie_form.dart';

const _kSlug = 'paie';

// ════════════════════════════════════════════════════════════════════════════
//  PAIE — bulletins de salaire par période (mois/année). Sélecteur de période →
//  KPI hero (masse salariale, payés, en attente, agents) → liste des bulletins
//  (net, statut, marquer payé) → formulaire (base + primes − retenues = net).
//  SENSIBLE (sync_finance). 100% offline.
// ════════════════════════════════════════════════════════════════════════════
class PaieScreen extends ConsumerWidget {
  const PaieScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => const ModuleScaffold(
        slug: _kSlug,
        title: 'Paie',
        child: _Body(),
      );
}

class _Body extends ConsumerStatefulWidget {
  const _Body();
  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  late int _month = DateTime.now().month;
  late int _year = DateTime.now().year;
  StaffAxis _axis = StaffAxis.categorie;
  String? _seg;

  String get _key => '$_year-${_month.toString().padLeft(2, '0')}';
  String get _prevKey {
    var m = _month - 1, y = _year;
    if (m < 1) {
      m = 12;
      y--;
    }
    return '$y-${m.toString().padLeft(2, '0')}';
  }

  void _openForm({PayrollLine? line}) => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _PayrollForm(month: _month, year: _year, line: line),
      );

  Future<void> _confirm(PayrollLine l) async {
    await runModuleWrite(context, () => confirmPayroll(l.id),
        success: 'Bulletin marqué payé');
  }

  Future<void> _carryOver() async {
    final p = ref.read(authNotifierProvider).valueOrNull;
    final prev = _prevKey.split('-');
    final fm = int.parse(prev.last), fy = int.parse(prev.first);
    final n = await carryOverPayroll(
      groupId: p?.groupId ?? '',
      schoolId: p?.schoolId ?? '',
      fromMonth: fm,
      fromYear: fy,
      toMonth: _month,
      toYear: _year,
      createdBy: p?.id ?? '',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(n == 0
            ? 'Aucun bulletin à reporter depuis ${kMonthNames[fm - 1]}'
            : '$n bulletin${n > 1 ? 's' : ''} reporté${n > 1 ? 's' : ''}'),
        backgroundColor: n == 0 ? kTextMuted : kGreen));
  }

  Future<void> _confirmAll(List<PayrollLine> lines) async {
    final ids = [
      for (final l in lines) if (l.status == 'pending') l.id
    ];
    if (ids.isEmpty) return;
    await runModuleWrite(context, () => confirmPayrollBulk(ids),
        success: '${ids.length} bulletin${ids.length > 1 ? 's' : ''} marqué'
            '${ids.length > 1 ? 's' : ''} payé${ids.length > 1 ? 's' : ''}');
  }

  Future<void> _delete(PayrollLine l) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Supprimer ce bulletin ?'),
        content: Text('Le bulletin de ${l.staffName} sera supprimé.'),
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
    await runModuleWrite(context, () => deletePayroll(l.id),
        success: 'Bulletin supprimé');
  }

  void _shiftMonth(int delta) {
    var m = _month + delta, y = _year;
    if (m < 1) {
      m = 12;
      y--;
    } else if (m > 12) {
      m = 1;
      y++;
    }
    setState(() {
      _month = m;
      _year = y;
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(payrollProvider(_key));
    final agents = ref.watch(staffDirectoryProvider).valueOrNull ?? const [];
    final canCreate = ref.watch(canProvider((slug: _kSlug, action: 'create')));
    final canEdit = ref.watch(canProvider((slug: _kSlug, action: 'update')));
    final canDelete = ref.watch(canProvider((slug: _kSlug, action: 'delete')));

    final byId = {for (final a in agents) a.id: a};

    return async.when(
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur : $e')),
      data: (lines) {
        final mass = lines.fold(0, (a, l) => a + l.net);
        final paid = lines.where((l) => l.status == 'confirmed').toList();
        final paidMass = paid.fold(0, (a, l) => a + l.net);
        final pending = lines.length - paid.length;

        // Segments selon l'axe : on classe chaque bulletin via l'agent lié.
        // total = bulletins du segment, ok = bulletins payés.
        final segMap = <String, StaffSegment>{};
        for (final l in lines) {
          final a = byId[l.staffId];
          final key = a == null ? '—' : staffSegKey(a, _axis);
          final seg = segMap.putIfAbsent(key, () => StaffSegment(key, _axis));
          seg.total++;
          if (l.status == 'confirmed') seg.ok++;
        }
        final segs = segMap.values.toList()
          ..sort((x, y) =>
              staffSegOrder(x.key, _axis).compareTo(staffSegOrder(y.key, _axis)));

        final shown = _seg == null
            ? lines
            : [
                for (final l in lines)
                  if ((byId[l.staffId] == null ? '—' : staffSegKey(byId[l.staffId]!, _axis)) == _seg)
                    l
              ];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            VsHeader(
              title: 'Paie du personnel',
              subtitle: '${kMonthNames[_month - 1]} $_year',
              trailing: canCreate
                  ? _AddBtn(label: 'Bulletin', onTap: () => _openForm())
                  : null,
            ),
            const SizedBox(height: 12),
            _PeriodBar(
              label: '${kMonthNames[_month - 1]} $_year',
              onPrev: () => _shiftMonth(-1),
              onNext: () => _shiftMonth(1),
            ),
            const SizedBox(height: 16),
            VsHeroKpis(cards: [
              (Icons.account_balance_wallet_rounded, 'Masse salariale',
                  fmtCompact(mass), kNavy, 'FCFA (net)'),
              (Icons.check_circle_rounded, 'Versé', fmtCompact(paidMass),
                  kGreen, '${paid.length} payés'),
              (Icons.hourglass_bottom_rounded, 'En attente', '$pending',
                  pending == 0 ? kTextMuted : const Color(0xFFF59E0B),
                  'à verser'),
              (Icons.groups_2_rounded, 'Agents', '${lines.length}',
                  const Color(0xFF0EA5E9), 'ce mois'),
            ]),
            const SizedBox(height: 18),
            // Distinction par axe + actions groupées
            Row(children: [
              const Text('Répartir par',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: kTextMuted)),
              const SizedBox(width: 10),
              StaffAxisToggle(
                  axis: _axis,
                  onChanged: (a) => setState(() {
                        _axis = a;
                        _seg = null;
                      })),
            ]),
            if (segs.isNotEmpty) ...[
              const SizedBox(height: 12),
              StaffSegmentBar(
                segments: segs,
                selected: _seg,
                onSelect: (s) => setState(() => _seg = s),
                metricLabel: 'payés',
              ),
            ],
            if (canCreate || canEdit) ...[
              const SizedBox(height: 14),
              Wrap(spacing: 10, runSpacing: 8, children: [
                if (canCreate)
                  StaffBulkButton(
                    icon: Icons.content_copy_rounded,
                    label: 'Reporter ${kMonthNames[(_month - 2 + 12) % 12]}',
                    onTap: _carryOver,
                  ),
                if (canEdit)
                  StaffBulkButton(
                    icon: Icons.done_all_rounded,
                    label: 'Marquer tous payés ($pending)',
                    color: kGreen,
                    onTap: pending == 0 ? null : () => _confirmAll(shown),
                  ),
              ]),
            ],
            const SizedBox(height: 16),
            if (lines.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: AdminEmptyState(
                  icon: Icons.payments_outlined,
                  title: 'Aucun bulletin',
                  message:
                      'Aucun bulletin de paie pour ${kMonthNames[_month - 1]} $_year. '
                      'Reportez le mois précédent ou créez un bulletin.',
                  actionLabel: canCreate ? 'Nouveau bulletin' : null,
                  onAction: canCreate ? () => _openForm() : null,
                ),
              )
            else
              for (final l in shown)
                _PayCard(
                  line: l,
                  canEdit: canEdit,
                  canDelete: canDelete,
                  onConfirm: () => _confirm(l),
                  onEdit: () => _openForm(line: l),
                  onDelete: () => _delete(l),
                ),
            const SizedBox(height: 24),
          ]),
        );
      },
    );
  }
}

// ─── Carte bulletin ──────────────────────────────────────────────────────────
class _PayCard extends StatelessWidget {
  const _PayCard({
    required this.line,
    required this.canEdit,
    required this.canDelete,
    required this.onConfirm,
    required this.onEdit,
    required this.onDelete,
  });
  final PayrollLine line;
  final bool canEdit, canDelete;
  final VoidCallback onConfirm, onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    final l = line;
    final paid = l.status == 'confirmed';
    final c = paid ? kGreen : (l.status == 'pending' ? const Color(0xFFF59E0B) : kTextMuted);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(l.staffName.isEmpty ? '—' : l.staffName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w800)),
          ),
          Text(fmtXaf(l.net),
              style: const TextStyle(
                  fontSize: 14.5, fontWeight: FontWeight.w800, color: kNavy)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: c.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6)),
            child: Text(payStatusLabel(l.status),
                style: TextStyle(
                    fontSize: 10.5, fontWeight: FontWeight.w800, color: c)),
          ),
          if (canEdit || canDelete)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded,
                  size: 18, color: kTextMuted),
              onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (_) => [
                if (canEdit)
                  const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                if (canDelete)
                  const PopupMenuItem(
                      value: 'delete',
                      child: Text('Supprimer', style: TextStyle(color: kRed))),
              ],
            )
          else
            const SizedBox(width: 8),
        ]),
        const SizedBox(height: 6),
        Text(
            'Base ${fmtXaf(l.base)} · Primes ${fmtXaf(l.bonuses)} · '
            'Retenues ${fmtXaf(l.deductions)}'
            '${l.method != null ? ' · ${payMethodLabel(l.method)}' : ''}',
            style: const TextStyle(fontSize: 11.5, color: kTextMuted)),
        if (canEdit && !paid) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: onConfirm,
              style: FilledButton.styleFrom(
                  backgroundColor: kGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text('Marquer payé'),
            ),
          ),
        ],
      ]),
    );
  }
}

// ─── Barre période (mois précédent / suivant) ────────────────────────────────
class _PeriodBar extends StatelessWidget {
  const _PeriodBar({required this.label, required this.onPrev, required this.onNext});
  final String label;
  final VoidCallback onPrev, onNext;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        IconButton(
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left_rounded, color: kNavy)),
        Text(label,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800, color: kNavy)),
        IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded, color: kNavy)),
      ]),
    );
  }
}

class _AddBtn extends StatelessWidget {
  const _AddBtn({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [kNavyDark, kNavy],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.add_rounded, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );
}
