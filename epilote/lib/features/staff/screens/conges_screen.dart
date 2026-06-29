import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../../navigation/providers/permissions_provider.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../vie_scolaire/widgets/vs_form_chrome.dart';
import '../../vie_scolaire/widgets/vs_kit.dart';
import '../providers/leave_provider.dart';
import '../providers/staff_directory_provider.dart';
import '../widgets/staff_kit.dart';

part 'conges_form.dart';

const _kSlug = 'conges';

Color _leaveColor(String s) => switch (s) {
      'approved' => kGreen,
      'pending' => const Color(0xFFF59E0B),
      'rejected' => kRed,
      _ => kTextMuted,
    };

// ════════════════════════════════════════════════════════════════════════════
//  CONGÉS & ABSENCES — KPI hero (en attente / approuvés / jours / agents) →
//  filtre par statut → liste des demandes (approuver / refuser) → formulaire
//  nouvelle demande. 100% offline.
// ════════════════════════════════════════════════════════════════════════════
class CongesScreen extends ConsumerWidget {
  const CongesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => const ModuleScaffold(
        slug: _kSlug,
        title: 'Congés',
        child: _Body(),
      );
}

class _Body extends ConsumerStatefulWidget {
  const _Body();
  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  String? _filter; // null = tous (statut)
  StaffAxis _axis = StaffAxis.categorie;
  String? _seg; // segment métier/statut

  void _openForm({LeaveRequest? req}) => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _LeaveForm(request: req),
      );

  Future<void> _approveAll(List<LeaveRequest> reqs) async {
    final ids = [for (final r in reqs) if (r.isPending) r.id];
    if (ids.isEmpty) return;
    final p = ref.read(authNotifierProvider).valueOrNull;
    await runModuleWrite(
      context,
      () => approveLeaveBulk(ids, p?.id ?? ''),
      success: '${ids.length} demande${ids.length > 1 ? 's' : ''} approuvée'
          '${ids.length > 1 ? 's' : ''}',
    );
  }

  Future<void> _approve(LeaveRequest r) async {
    final p = ref.read(authNotifierProvider).valueOrNull;
    await runModuleWrite(
      context,
      () => reviewLeaveRequest(
          id: r.id, status: 'approved', reviewedBy: p?.id ?? ''),
      success: 'Congé approuvé',
    );
  }

  Future<void> _reject(LeaveRequest r) async {
    final reason = await _askReason();
    if (reason == null) return;
    final p = ref.read(authNotifierProvider).valueOrNull;
    if (!mounted) return;
    await runModuleWrite(
      context,
      () => reviewLeaveRequest(
          id: r.id,
          status: 'rejected',
          reviewedBy: p?.id ?? '',
          rejectionReason: reason.isEmpty ? null : reason),
      success: 'Demande refusée',
    );
  }

  Future<String?> _askReason() {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Motif du refus'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: adminFilledInput('Motif (facultatif)',
              icon: Icons.notes_rounded),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Refuser'),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(LeaveRequest r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Supprimer cette demande ?'),
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
    await runModuleWrite(context, () => deleteLeaveRequest(r.id),
        success: 'Demande supprimée');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(leaveRequestsProvider);
    final canCreate = ref.watch(canProvider((slug: _kSlug, action: 'create')));
    final canReview = ref.watch(canProvider((slug: _kSlug, action: 'update')));
    final canDelete = ref.watch(canProvider((slug: _kSlug, action: 'delete')));

    final agentsAll = ref.watch(staffDirectoryProvider).valueOrNull ?? const [];
    final byId = {for (final a in agentsAll) a.id: a};

    return async.when(
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur : $e')),
      data: (all) {
        final pending = all.where((r) => r.isPending).length;
        final approved = all.where((r) => r.status == 'approved').toList();
        final days = approved.fold(0, (a, r) => a + r.daysCount);
        final agents = {for (final r in approved) r.staffId}.length;

        // Segments par axe (métier/statut) sur l'agent lié ; ok = approuvées.
        String segOf(LeaveRequest r) {
          final a = byId[r.staffId];
          return a == null ? '—' : staffSegKey(a, _axis);
        }
        final segMap = <String, StaffSegment>{};
        for (final r in all) {
          final seg = segMap.putIfAbsent(segOf(r), () => StaffSegment(segOf(r), _axis));
          seg.total++;
          if (r.status == 'approved') seg.ok++;
        }
        final segs = segMap.values.toList()
          ..sort((x, y) =>
              staffSegOrder(x.key, _axis).compareTo(staffSegOrder(y.key, _axis)));

        final list = [
          for (final r in all)
            if ((_filter == null || r.status == _filter) &&
                (_seg == null || segOf(r) == _seg))
              r
        ];
        final pendingVisible = list.where((r) => r.isPending).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            VsHeader(
              title: 'Congés & absences',
              subtitle: 'Demandes, validation et suivi du personnel',
              trailing: canCreate
                  ? _AddBtn(label: 'Demande', onTap: () => _openForm())
                  : null,
            ),
            const SizedBox(height: 20),
            VsHeroKpis(cards: [
              (Icons.hourglass_bottom_rounded, 'En attente', '$pending',
                  pending == 0 ? kTextMuted : const Color(0xFFF59E0B),
                  'à traiter'),
              (Icons.event_available_rounded, 'Approuvés', '${approved.length}',
                  kGreen, 'demandes'),
              (Icons.today_rounded, 'Jours', '$days', kNavy, 'accordés'),
              (Icons.groups_2_rounded, 'Agents', '$agents',
                  const Color(0xFF0EA5E9), 'concernés'),
            ]),
            const SizedBox(height: 18),
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
                metricLabel: 'approuvés',
              ),
            ],
            const SizedBox(height: 14),
            _FilterBar(
                active: _filter,
                onSelect: (s) => setState(() => _filter = s)),
            if (canReview && pendingVisible.isNotEmpty) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: StaffBulkButton(
                  icon: Icons.done_all_rounded,
                  label: 'Approuver les ${pendingVisible.length} en attente',
                  color: kGreen,
                  onTap: () => _approveAll(pendingVisible),
                ),
              ),
            ],
            const SizedBox(height: 14),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: AdminEmptyState(
                  icon: Icons.beach_access_outlined,
                  title: 'Aucune demande',
                  message: _filter == null
                      ? 'Aucune demande de congé enregistrée.'
                      : 'Aucune demande « ${leaveStatusLabel(_filter)} ».',
                  actionLabel: canCreate ? 'Nouvelle demande' : null,
                  onAction: canCreate ? () => _openForm() : null,
                ),
              )
            else
              for (final r in list)
                _LeaveCard(
                  req: r,
                  canReview: canReview,
                  canDelete: canDelete,
                  onApprove: () => _approve(r),
                  onReject: () => _reject(r),
                  onEdit: () => _openForm(req: r),
                  onDelete: () => _delete(r),
                ),
            const SizedBox(height: 24),
          ]),
        );
      },
    );
  }
}

// ─── Filtre par statut ───────────────────────────────────────────────────────
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.active, required this.onSelect});
  final String? active;
  final ValueChanged<String?> onSelect;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(scrollDirection: Axis.horizontal, children: [
        _chip('Toutes', active == null, () => onSelect(null)),
        for (final (slug, label) in kLeaveStatuses)
          _chip(label, active == slug, () => onSelect(slug)),
      ]),
    );
  }

  Widget _chip(String label, bool sel, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: sel,
          onSelected: (_) => onTap(),
          labelStyle: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: sel ? Colors.white : kTextMuted),
          selectedColor: kNavy,
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: kBorder)),
        ),
      );
}

// ─── Carte demande ───────────────────────────────────────────────────────────
class _LeaveCard extends StatelessWidget {
  const _LeaveCard({
    required this.req,
    required this.canReview,
    required this.canDelete,
    required this.onApprove,
    required this.onReject,
    required this.onEdit,
    required this.onDelete,
  });
  final LeaveRequest req;
  final bool canReview, canDelete;
  final VoidCallback onApprove, onReject, onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    final r = req;
    final c = _leaveColor(r.status);
    final period = [
      if ((r.startDate ?? '').isNotEmpty) r.startDate!,
      if ((r.endDate ?? '').isNotEmpty) r.endDate!,
    ].join(' → ');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(r.staffName.isEmpty ? '—' : r.staffName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w800)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: c.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6)),
            child: Text(leaveStatusLabel(r.status),
                style: TextStyle(
                    fontSize: 10.5, fontWeight: FontWeight.w800, color: c)),
          ),
          if (canDelete || (canReview && r.status != 'pending'))
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded,
                  size: 18, color: kTextMuted),
              onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (_) => [
                if (canReview && r.isPending)
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
        const SizedBox(height: 4),
        Text(
            '${leaveTypeLabel(r.leaveType)} · ${r.daysCount} jour'
            '${r.daysCount > 1 ? 's' : ''}${period.isNotEmpty ? ' · $period' : ''}',
            style: const TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w600, color: kNavy)),
        if ((r.reason ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(r.reason!.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: kTextMuted)),
        ],
        if (r.status == 'rejected' && (r.rejectionReason ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 3),
          Text('Refus : ${r.rejectionReason!.trim()}',
              style: const TextStyle(fontSize: 11.5, color: kRed)),
        ],
        if (canReview && r.isPending) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onReject,
                style: OutlinedButton.styleFrom(
                    foregroundColor: kRed,
                    side: const BorderSide(color: kRed),
                    padding: const EdgeInsets.symmetric(vertical: 8)),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Refuser'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: onApprove,
                style: FilledButton.styleFrom(
                    backgroundColor: kGreen,
                    padding: const EdgeInsets.symmetric(vertical: 8)),
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Approuver'),
              ),
            ),
          ]),
        ],
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
