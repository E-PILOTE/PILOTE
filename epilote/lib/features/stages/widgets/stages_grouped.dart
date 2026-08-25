import 'package:flutter/material.dart';

import '../../../core/utils/class_grouping.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/list_chrome.dart' show kListPurple;
import '../../examens/widgets/examens_widgets.dart' show formatDate;
import '../providers/stages_provider.dart';
import 'stages_views.dart' show stageTone;

// ════════════════════════════════════════════════════════════════════════════
//  STAGES — rendu GROUPÉ PAR CLASSE + VIRTUALISÉ (slivers).
//  Même grammaire que les candidats d'examen : en-têtes de classe pliables
//  (badge filière + compteurs stages/attestations/dues), lignes virtualisées.
// ════════════════════════════════════════════════════════════════════════════

List<Widget> internshipSlivers({
  required List<InternshipRow> rows,
  required Set<String?> collapsed,
  required bool canEdit,
  required bool isTable,
  required bool showFiliere,
  required void Function(String? classId) onToggleGroup,
  required void Function(InternshipRow) onAttestation,
  required void Function(InternshipRow) onOpen,
}) {
  final groups = groupByClass<InternshipRow>(
    rows,
    classId: (r) => r.classId,
    className: (r) => r.className ?? '—',
    filiere: (r) => r.filiereLabel,
    levelOrder: (r) => r.levelOrder,
  );

  if (isTable) {
    final flat = flattenGroups<InternshipRow>(groups, collapsed);
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        sliver: SliverList.builder(
          itemCount: flat.length,
          itemBuilder: (context, i) {
            final e = flat[i];
            if (e is GroupHeaderRow<InternshipRow>) {
              return StageGroupHeader(
                group: e.group,
                collapsed: collapsed.contains(e.group.classId),
                showFiliere: showFiliere,
                showColumns: true,
                onToggle: () => onToggleGroup(e.group.classId),
              );
            }
            final row = (e as GroupItemRow<InternshipRow>).item;
            return StageRowTile(
              row: row,
              canEdit: canEdit,
              onAttestation: onAttestation,
              onOpen: onOpen,
            );
          },
        ),
      ),
    ];
  }

  final slivers = <Widget>[];
  for (final g in groups) {
    slivers.add(SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverToBoxAdapter(
        child: StageGroupHeader(
          group: g,
          collapsed: collapsed.contains(g.classId),
          showFiliere: showFiliere,
          showColumns: false,
          onToggle: () => onToggleGroup(g.classId),
        ),
      ),
    ));
    if (!collapsed.contains(g.classId)) {
      slivers.add(SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 420,
            mainAxisExtent: 158,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemCount: g.items.length,
          itemBuilder: (context, i) => StageGridCard(
            row: g.items[i],
            canEdit: canEdit,
            onAttestation: onAttestation,
            onOpen: onOpen,
          ),
        ),
      ));
    }
  }
  return slivers;
}

// ─── En-tête de groupe (pliable) ──────────────────────────────────────────────
class StageGroupHeader extends StatelessWidget {
  const StageGroupHeader({
    super.key,
    required this.group,
    required this.collapsed,
    required this.showFiliere,
    required this.showColumns,
    required this.onToggle,
  });

  final ClassGroup<InternshipRow> group;
  final bool collapsed;
  final bool showFiliere;
  final bool showColumns;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final items = group.items;
    final attest = items.where((r) => r.hasAttestation).length;
    final due = items.where((r) => r.attestationOverdue).length;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: kNavy.withValues(alpha: 0.05),
        borderRadius: BorderRadius.vertical(
          top: const Radius.circular(10),
          bottom: Radius.circular(collapsed ? 10 : 0),
        ),
        border: Border.all(color: kBorder),
      ),
      child: Column(children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
            child: Row(children: [
              Icon(collapsed ? Icons.chevron_right_rounded : Icons.expand_more_rounded,
                  size: 20, color: kNavy),
              const SizedBox(width: 6),
              Flexible(
                child: Text(group.className,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: kTextPrimary)),
              ),
              if (showFiliere && group.filiereLabel != null) ...[
                const SizedBox(width: 8),
                _FiliereBadge(label: group.filiereLabel!),
              ],
              const Spacer(),
              _HeaderStat(label: 'stages', value: items.length, tone: kNavy),
              const SizedBox(width: 14),
              _HeaderStat(label: 'attest.', value: attest, tone: kGreen),
              const SizedBox(width: 14),
              _HeaderStat(
                  label: 'dues', value: due, tone: due > 0 ? kRed : kTextMuted),
            ]),
          ),
        ),
        if (showColumns && !collapsed) const _ColumnLabels(),
      ]),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat(
      {required this.label, required this.value, required this.tone});
  final String label;
  final int value;
  final Color tone;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('$value',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: tone)),
          Text(label, style: TextStyle(fontSize: 9.5, color: kTextMuted)),
        ],
      );
}

class _ColumnLabels extends StatelessWidget {
  const _ColumnLabels();

  Widget _h(String t, {required int flex}) => Expanded(
        flex: flex,
        child: Text(t,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: kTextMuted)),
      );

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: kBorder)),
        ),
        child: Row(children: [
          _h('STAGIAIRE · ENTREPRISE', flex: 4),
          _h('PÉRIODE', flex: 3),
          _h('CONV.', flex: 1),
          _h('STATUT', flex: 2),
          _h('ATTEST.', flex: 1),
        ]),
      );
}

class _FiliereBadge extends StatelessWidget {
  const _FiliereBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: kListPurple.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: kListPurple.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.account_tree_rounded, size: 11, color: kListPurple),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: kListPurple)),
        ]),
      );
}

// ─── Ligne de tableau (un stage) ──────────────────────────────────────────────
class StageRowTile extends StatelessWidget {
  const StageRowTile({
    super.key,
    required this.row,
    required this.canEdit,
    required this.onAttestation,
    required this.onOpen,
  });
  final InternshipRow row;
  final bool canEdit;
  final void Function(InternshipRow) onAttestation;
  final void Function(InternshipRow) onOpen;

  @override
  Widget build(BuildContext context) {
    final r = row;
    final (tone, label) = stageTone(r.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kCardBg,
        border: Border(
          left: BorderSide(color: kBorder),
          right: BorderSide(color: kBorder),
          bottom: BorderSide(color: kBorder),
        ),
      ),
      child: Row(children: [
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.studentName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary)),
              Text(r.companyName ?? 'entreprise non renseignée',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: kTextMuted)),
            ],
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            r.startDate == null
                ? '—'
                : '${formatDate(r.startDate)} → ${formatDate(r.endDate)}',
            style: TextStyle(fontSize: 11.5, color: kTextMuted),
          ),
        ),
        Expanded(
          flex: 1,
          child: Icon(
              r.conventionSigned
                  ? Icons.check_circle_rounded
                  : Icons.remove_circle_outline_rounded,
              size: 16,
              color: r.conventionSigned ? kGreen : kTextMuted),
        ),
        Expanded(
          flex: 2,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700, color: tone)),
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              // La fiche est une LECTURE : offerte même sans droit d'écriture.
              IconButton(
                onPressed: () => onOpen(r),
                icon: const Icon(Icons.badge_outlined, size: 18),
                color: kNavy,
                tooltip: 'Fiche du stage',
                visualDensity: VisualDensity.compact,
              ),
              canEdit
                ? IconButton(
                    onPressed: () => onAttestation(r),
                    icon: Icon(
                        r.hasAttestation
                            ? Icons.verified_rounded
                            : (r.attestationOverdue
                                ? Icons.error_outline_rounded
                                : Icons.workspace_premium_outlined),
                        size: 18),
                    color: r.hasAttestation
                        ? kGreen
                        : (r.attestationOverdue ? kRed : kTextMuted),
                    tooltip: r.hasAttestation
                        ? 'Attestation délivrée'
                        : (r.attestationOverdue
                            ? 'Stage terminé — attestation à délivrer'
                            : 'Délivrer l\'attestation'),
                    visualDensity: VisualDensity.compact,
                  )
                : Icon(
                    r.hasAttestation
                        ? Icons.verified_rounded
                        : (r.attestationOverdue
                            ? Icons.error_outline_rounded
                            : Icons.remove_rounded),
                    size: 16,
                    color: r.hasAttestation
                        ? kGreen
                        : (r.attestationOverdue ? kRed : kTextMuted),
                  ),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ─── Carte (un stage) ─────────────────────────────────────────────────────────
class StageGridCard extends StatelessWidget {
  const StageGridCard({
    super.key,
    required this.row,
    required this.canEdit,
    required this.onAttestation,
    required this.onOpen,
  });
  final InternshipRow row;
  final bool canEdit;
  final void Function(InternshipRow) onAttestation;
  final void Function(InternshipRow) onOpen;

  @override
  Widget build(BuildContext context) {
    final r = row;
    final (tone, label) = stageTone(r.status);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: r.attestationOverdue ? kRed.withValues(alpha: 0.5) : kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(r.studentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 10.5, fontWeight: FontWeight.w700, color: tone)),
            ),
          ]),
          const SizedBox(height: 4),
          Text(r.companyName ?? 'entreprise non renseignée',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: kTextMuted)),
          Text(
            r.startDate != null
                ? '${formatDate(r.startDate)} → ${formatDate(r.endDate)}'
                : 'période non renseignée',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: kTextMuted),
          ),
          const Spacer(),
          Row(children: [
            Icon(
                r.conventionSigned
                    ? Icons.description_rounded
                    : Icons.description_outlined,
                size: 15,
                color: r.conventionSigned ? kGreen : kTextMuted),
            const SizedBox(width: 4),
            Text('Convention', style: TextStyle(fontSize: 11, color: kTextMuted)),
            const Spacer(),
            IconButton(
              onPressed: () => onOpen(r),
              icon: const Icon(Icons.badge_outlined, size: 16),
              color: kNavy,
              tooltip: 'Fiche du stage',
              visualDensity: VisualDensity.compact,
            ),
            if (canEdit)
              TextButton.icon(
                onPressed: () => onAttestation(r),
                icon: Icon(
                    r.hasAttestation
                        ? Icons.verified_rounded
                        : Icons.workspace_premium_outlined,
                    size: 15),
                label: Text(r.hasAttestation ? 'Attestation' : 'Délivrer',
                    style: const TextStyle(fontSize: 11.5)),
                style: TextButton.styleFrom(
                  foregroundColor: r.hasAttestation
                      ? kGreen
                      : (r.attestationOverdue ? kRed : kNavy),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
              )
            else
              Icon(
                  r.hasAttestation ? Icons.verified_rounded : Icons.pending_outlined,
                  size: 16,
                  color: r.hasAttestation ? kGreen : kTextMuted),
          ]),
        ],
      ),
    );
  }
}
