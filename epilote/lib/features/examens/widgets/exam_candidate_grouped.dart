import 'package:flutter/material.dart';

import '../../../core/utils/class_grouping.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/list_chrome.dart' show kListPurple;
import '../providers/exam_candidates_provider.dart';
import 'exam_candidate_views.dart';
import 'examens_widgets.dart' show formatDate;

// ════════════════════════════════════════════════════════════════════════════
//  CANDIDATS — rendu GROUPÉ PAR CLASSE + VIRTUALISÉ (slivers).
//
//  À l'échelle nationale, une session peut porter des centaines de candidats.
//  On ne les affiche donc jamais à plat : ils sont regroupés par classe (badge
//  filière + compteurs), en-têtes PLIABLES, et rendus dans des slivers pour ne
//  construire que les lignes visibles. Le « lot » (organisationnel) n'apparaît
//  pas ici : il reste au moment de la transmission/PDF.
// ════════════════════════════════════════════════════════════════════════════

/// Construit les slivers de la liste candidats, prêts à insérer dans le
/// `CustomScrollView` de l'écran Session. Table = une `SliverList` aplatie ;
/// cartes = un en-tête + une grille par groupe (chaque groupe virtualisé).
List<Widget> examCandidateSlivers({
  required List<ExamCandidateRow> rows,
  required Set<String?> collapsed,
  required bool canEdit,
  required bool isTable,
  required bool showFiliere,
  required String sessionId,
  required String examCode,
  required Set<String> selected,
  required void Function(String? classId) onToggleGroup,
  required void Function(ClassGroup<ExamCandidateRow> group) onToggleGroupSelect,
  required void Function(String id) onToggleItem,
}) {
  final groups = groupByClass<ExamCandidateRow>(
    rows,
    classId: (r) => r.classId,
    className: (r) => r.className ?? '—',
    filiere: (r) => r.filiereLabel,
    levelOrder: (r) => r.levelOrder,
  );

  bool groupAllSelected(ClassGroup<ExamCandidateRow> g) =>
      g.items.isNotEmpty && g.items.every((r) => selected.contains(r.id));

  if (isTable) {
    final flat = flattenGroups<ExamCandidateRow>(groups, collapsed);
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverList.builder(
          itemCount: flat.length,
          itemBuilder: (context, i) {
            final e = flat[i];
            if (e is GroupHeaderRow<ExamCandidateRow>) {
              return ExamGroupHeader(
                group: e.group,
                collapsed: collapsed.contains(e.group.classId),
                canEdit: canEdit,
                showFiliere: showFiliere,
                showColumns: true,
                allSelected: groupAllSelected(e.group),
                onToggle: () => onToggleGroup(e.group.classId),
                onToggleSelect: () => onToggleGroupSelect(e.group),
              );
            }
            final row = (e as GroupItemRow<ExamCandidateRow>).item;
            return ExamCandidateTile(
              row: row,
              canEdit: canEdit,
              showFiliere: showFiliere,
              sessionId: sessionId,
              examCode: examCode,
              checked: selected.contains(row.id),
              onToggle: () => onToggleItem(row.id),
            );
          },
        ),
      ),
    ];
  }

  // Mode cartes : un en-tête + (si déplié) une grille par groupe.
  final slivers = <Widget>[];
  for (final g in groups) {
    slivers.add(SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverToBoxAdapter(
        child: ExamGroupHeader(
          group: g,
          collapsed: collapsed.contains(g.classId),
          canEdit: canEdit,
          showFiliere: showFiliere,
          showColumns: false,
          allSelected: groupAllSelected(g),
          onToggle: () => onToggleGroup(g.classId),
          onToggleSelect: () => onToggleGroupSelect(g),
        ),
      ),
    ));
    if (!collapsed.contains(g.classId)) {
      slivers.add(SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 420,
            mainAxisExtent: 150,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemCount: g.items.length,
          itemBuilder: (context, i) {
            final row = g.items[i];
            return ExamCandidateGridCard(
              row: row,
              canEdit: canEdit,
              sessionId: sessionId,
              examCode: examCode,
              checked: selected.contains(row.id),
              onToggle: () => onToggleItem(row.id),
            );
          },
        ),
      ));
    }
  }
  return slivers;
}

// ─── En-tête de groupe (pliable) ──────────────────────────────────────────────
class ExamGroupHeader extends StatelessWidget {
  const ExamGroupHeader({
    super.key,
    required this.group,
    required this.collapsed,
    required this.canEdit,
    required this.showFiliere,
    required this.showColumns,
    required this.allSelected,
    required this.onToggle,
    required this.onToggleSelect,
  });

  final ClassGroup<ExamCandidateRow> group;
  final bool collapsed;
  final bool canEdit;
  final bool showFiliere;
  final bool showColumns;
  final bool allSelected;
  final VoidCallback onToggle;
  final VoidCallback onToggleSelect;

  @override
  Widget build(BuildContext context) {
    final items = group.items;
    final complete = items.where((r) => r.isComplete).length;
    final submitted = items.where((r) => r.isSubmitted).length;

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
            padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
            child: Row(children: [
              if (canEdit)
                SizedBox(
                  width: 34,
                  child: Checkbox(
                    value: allSelected,
                    onChanged: (_) => onToggleSelect(),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
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
              _HeaderStat(label: 'candidats', value: items.length, tone: kNavy),
              const SizedBox(width: 14),
              _HeaderStat(
                  label: 'complets',
                  value: complete,
                  tone: complete == items.length ? kGreen : kRed),
              const SizedBox(width: 14),
              _HeaderStat(label: 'déposés', value: submitted, tone: kGreen),
            ]),
          ),
        ),
        if (showColumns && !collapsed) _ColumnLabels(canEdit: canEdit),
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
  const _ColumnLabels({required this.canEdit});
  final bool canEdit;

  Widget _h(String t, {required int flex, double? width}) {
    final child = Text(t,
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: kTextMuted));
    return width != null
        ? SizedBox(width: width, child: child)
        : Expanded(flex: flex, child: child);
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 16, 6),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: kBorder)),
        ),
        child: Row(children: [
          const SizedBox(width: 34),
          _h('CANDIDAT', flex: 4),
          _h('N° CANDIDAT', flex: 2),
          _h('DOSSIER', flex: 2),
          _h('RÉSULTAT', flex: 2),
          const SizedBox(width: 8),
          _h('', flex: 0, width: canEdit ? 148 : 40),
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

// ─── Ligne de tableau (un candidat) ───────────────────────────────────────────
class ExamCandidateTile extends StatelessWidget {
  const ExamCandidateTile({
    super.key,
    required this.row,
    required this.canEdit,
    required this.showFiliere,
    required this.sessionId,
    required this.examCode,
    required this.checked,
    required this.onToggle,
  });

  final ExamCandidateRow row;
  final bool canEdit;
  final bool showFiliere;
  final String sessionId;
  final String examCode;
  final bool checked;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = row;
    final (tone, label) = candidateDossierTone(c.dossierStatus, c.missingCount);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
      decoration: BoxDecoration(
        color: checked ? kNavy.withValues(alpha: 0.05) : kCardBg,
        border: Border(
          left: BorderSide(color: kBorder),
          right: BorderSide(color: kBorder),
          bottom: BorderSide(color: kBorder),
        ),
      ),
      child: Row(children: [
        SizedBox(
          width: 34,
          child: canEdit
              ? Checkbox(
                  value: checked,
                  onChanged: (_) => onToggle(),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )
              : const SizedBox.shrink(),
        ),
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c.fullName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary)),
              Text(
                '${c.matricule ?? 'sans matricule'}'
                '${c.dateOfBirth != null ? ' · né(e) le ${formatDate(c.dateOfBirth)}' : ''}',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: kTextMuted),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(c.candidateNumber ?? 'n° à venir',
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    c.candidateNumber != null ? FontWeight.w700 : FontWeight.w400,
                color: c.candidateNumber != null ? kTextPrimary : kTextMuted,
              )),
        ),
        Expanded(
          flex: 2,
          child: Align(
              alignment: Alignment.centerLeft,
              child: CandidatePill(label: label, tone: tone)),
        ),
        Expanded(
          flex: 2,
          child: c.hasResult
              ? ResultChip(result: c.result!, average: c.average)
              : Text('en attente',
                  style: TextStyle(fontSize: 11, color: kTextMuted)),
        ),
        const SizedBox(width: 8),
        ExamCandidateActions(
            row: c, canEdit: canEdit, sessionId: sessionId, examCode: examCode),
      ]),
    );
  }
}

// ─── Carte (un candidat) ──────────────────────────────────────────────────────
class ExamCandidateGridCard extends StatelessWidget {
  const ExamCandidateGridCard({
    super.key,
    required this.row,
    required this.canEdit,
    required this.sessionId,
    required this.examCode,
    required this.checked,
    required this.onToggle,
  });

  final ExamCandidateRow row;
  final bool canEdit;
  final String sessionId;
  final String examCode;
  final bool checked;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = row;
    final (tone, label) = candidateDossierTone(c.dossierStatus, c.missingCount);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: checked ? kNavy.withValues(alpha: 0.6) : kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (canEdit)
              SizedBox(
                width: 30,
                height: 30,
                child: Checkbox(
                  value: checked,
                  onChanged: (_) => onToggle(),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            Expanded(
              child: Text(c.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary)),
            ),
          ]),
          Padding(
            padding: EdgeInsets.only(left: canEdit ? 30 : 0),
            child: Text(c.candidateNumber ?? 'n° à venir',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: kTextMuted)),
          ),
          const Spacer(),
          Row(children: [
            CandidatePill(label: label, tone: tone),
            const SizedBox(width: 6),
            if (c.hasResult)
              Flexible(child: ResultChip(result: c.result!, average: c.average)),
            const Spacer(),
            ExamCandidateActions(
                row: c,
                canEdit: canEdit,
                sessionId: sessionId,
                examCode: examCode),
          ]),
        ],
      ),
    );
  }
}
