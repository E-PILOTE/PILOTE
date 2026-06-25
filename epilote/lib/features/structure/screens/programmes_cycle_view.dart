part of 'programmes_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  VUE « PAR CYCLE » — premium : sections dépliables par cycle (ordre
//  pédagogique), sous-regroupées par NIVEAU, en-têtes riches (compteurs
//  programmes / niveaux / officiels), animations d'ouverture. Réutilise _ProgRow.
// ════════════════════════════════════════════════════════════════════════════
class _ProgByCycle extends ConsumerStatefulWidget {
  const _ProgByCycle({
    required this.rows,
    required this.onEdit,
    required this.onDelete,
    required this.onOpen,
  });
  final List<ProgrammeRow> rows;
  final ValueChanged<ProgrammeRow> onEdit, onDelete, onOpen;
  @override
  ConsumerState<_ProgByCycle> createState() => _ProgByCycleState();
}

class _ProgByCycleState extends ConsumerState<_ProgByCycle> {
  final Set<String> _collapsed = {};

  @override
  Widget build(BuildContext context) {
    final canEdit = ref.watch(canProvider((slug: _kSlug, action: 'update')));
    final canDelete = ref.watch(canProvider((slug: _kSlug, action: 'delete')));

    final structure =
        ref.watch(academicStructureProvider).valueOrNull ?? AcademicStructure.empty;
    final cycleTotalNiveaux = {
      for (final c in structure.cycles) c.code: c.levels.length,
    };

    final groups = <String, List<ProgrammeRow>>{};
    for (final p in widget.rows) {
      groups.putIfAbsent(p.cycleCode ?? 'autre', () => []).add(p);
    }
    final keys = groups.keys.toList()
      ..sort((a, b) => _cycOrder(a).compareTo(_cycOrder(b)));
    for (final k in keys) {
      groups[k]!.sort((a, b) {
        final o = a.levelOrder.compareTo(b.levelOrder);
        return o != 0
            ? o
            : a.subjectName.toLowerCase().compareTo(b.subjectName.toLowerCase());
      });
    }
    final allCollapsed = keys.every(_collapsed.contains);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Contrôle global déplier / replier.
      Padding(
        padding: const EdgeInsets.only(bottom: 10, right: 2),
        child: Align(
          alignment: Alignment.centerRight,
          child: _MiniAction(
            icon: allCollapsed
                ? Icons.unfold_more_rounded
                : Icons.unfold_less_rounded,
            label: allCollapsed ? 'Tout déplier' : 'Tout replier',
            onTap: () => setState(() {
              if (allCollapsed) {
                _collapsed.clear();
              } else {
                _collapsed.addAll(keys);
              }
            }),
          ),
        ),
      ),
      for (final k in keys)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _CycleSection(
            cycleCode: k,
            cycleName: _cycName(k, groups[k]!.first.cycleName),
            items: groups[k]!,
            totalNiveaux: cycleTotalNiveaux[k] ?? 0,
            expanded: !_collapsed.contains(k),
            onToggle: () => setState(() {
              if (_collapsed.contains(k)) {
                _collapsed.remove(k);
              } else {
                _collapsed.add(k);
              }
            }),
            canEdit: canEdit,
            canDelete: canDelete,
            onEdit: widget.onEdit,
            onDelete: widget.onDelete,
            onOpen: widget.onOpen,
          ),
        ),
    ]);
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: kSurface,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kBorder)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 15, color: kNavy),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: kNavy)),
            ]),
          ),
        ),
      );
}

class _CycleSection extends StatelessWidget {
  const _CycleSection({
    required this.cycleCode,
    required this.cycleName,
    required this.items,
    required this.totalNiveaux,
    required this.expanded,
    required this.onToggle,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
    required this.onOpen,
  });
  final String cycleCode, cycleName;
  final List<ProgrammeRow> items;
  final int totalNiveaux;
  final bool expanded, canEdit, canDelete;
  final VoidCallback onToggle;
  final ValueChanged<ProgrammeRow> onEdit, onDelete, onOpen;

  @override
  Widget build(BuildContext context) {
    final col = _cyc(cycleCode);
    final niveaux = items.map((p) => p.levelLabel).toSet().length;
    final official = items.where((p) => p.isOfficial).length;

    // Regroupement par niveau (l'ordre est déjà pédagogique).
    final byLevel = <String, List<ProgrammeRow>>{};
    for (final p in items) {
      byLevel.putIfAbsent(p.levelLabel, () => []).add(p);
    }
    final levelKeys = byLevel.keys.toList();

    return AdminCard(
      padding: EdgeInsets.zero,
      child: Column(children: [
        // En-tête cliquable (déplier / replier).
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onToggle,
            borderRadius: expanded
                ? const BorderRadius.vertical(top: Radius.circular(12))
                : BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    col.withValues(alpha: 0.12),
                    col.withValues(alpha: 0.02),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: expanded
                    ? const BorderRadius.vertical(top: Radius.circular(12))
                    : BorderRadius.circular(12),
                border: expanded
                    ? const Border(bottom: BorderSide(color: kBorder))
                    : null,
              ),
              child: Row(children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                      color: col.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.account_tree_rounded, size: 19, color: col),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cycleName,
                            style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: col)),
                        const SizedBox(height: 5),
                        Wrap(spacing: 6, runSpacing: 4, children: [
                          _Pill(
                              _pl(items.length, 'programme', 'programmes'),
                              col),
                          _Pill(_pl(niveaux, 'niveau', 'niveaux'), kTextMuted),
                          if (official > 0) _Pill('$official officiel${official > 1 ? 's' : ''}', kGreen),
                        ]),
                        if (totalNiveaux > 0) ...[
                          const SizedBox(height: 9),
                          _CompletionBar(
                              covered: niveaux, total: totalNiveaux, color: col),
                        ],
                      ]),
                ),
                AnimatedRotation(
                  duration: const Duration(milliseconds: 180),
                  turns: expanded ? 0.5 : 0,
                  child: Icon(Icons.expand_more_rounded,
                      size: 24, color: col.withValues(alpha: 0.8)),
                ),
              ]),
            ),
          ),
        ),
        // Corps (sous-groupes par niveau), animé.
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.topCenter,
          curve: Curves.easeOut,
          child: expanded
              ? Column(
                  children: [
                    for (var gi = 0; gi < levelKeys.length; gi++)
                      _NiveauGroup(
                        levelLabel: levelKeys[gi],
                        items: byLevel[levelKeys[gi]]!,
                        color: col,
                        isLastGroup: gi == levelKeys.length - 1,
                        canEdit: canEdit,
                        canDelete: canDelete,
                        onEdit: onEdit,
                        onDelete: onDelete,
                        onOpen: onOpen,
                      ),
                  ],
                )
              : const SizedBox(width: double.infinity),
        ),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label, this.color);
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      );
}

// Barre de complétude : niveaux du cycle disposant d'au moins un programme.
class _CompletionBar extends StatelessWidget {
  const _CompletionBar(
      {required this.covered, required this.total, required this.color});
  final int covered, total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = covered > total ? total : covered;
    final ratio = total == 0 ? 0.0 : c / total;
    final pct = (ratio * 100).round();
    final done = c >= total && total > 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: kBorder,
              valueColor: AlwaysStoppedAnimation(done ? kGreen : color),
            ),
          ),
        ),
        const SizedBox(width: 9),
        Text('$pct %',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: done ? kGreen : color)),
      ]),
      const SizedBox(height: 4),
      Row(children: [
        Icon(done ? Icons.check_circle_rounded : Icons.donut_large_rounded,
            size: 12, color: done ? kGreen : kTextMuted),
        const SizedBox(width: 4),
        Text('$c/$total ${total <= 1 ? 'niveau couvert' : 'niveaux couverts'}',
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: kTextMuted)),
      ]),
    ]);
  }
}

class _NiveauGroup extends StatelessWidget {
  const _NiveauGroup({
    required this.levelLabel,
    required this.items,
    required this.color,
    required this.isLastGroup,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
    required this.onOpen,
  });
  final String levelLabel;
  final List<ProgrammeRow> items;
  final Color color;
  final bool isLastGroup, canEdit, canDelete;
  final ValueChanged<ProgrammeRow> onEdit, onDelete, onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Sous-en-tête niveau.
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
        color: kSurface.withValues(alpha: 0.6),
        child: Row(children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 9),
          Text(levelLabel.toUpperCase(),
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: kTextPrimary)),
          const SizedBox(width: 8),
          Text('· ${_pl(items.length, 'programme', 'programmes')}',
              style: const TextStyle(fontSize: 11, color: kTextMuted)),
        ]),
      ),
      for (var i = 0; i < items.length; i++)
        _ProgRow(
          p: items[i],
          last: isLastGroup && i == items.length - 1,
          canEdit: canEdit,
          canDelete: canDelete,
          canBulk: false,
          selected: false,
          onSelect: (_) {},
          onEdit: () => onEdit(items[i]),
          onDelete: () => onDelete(items[i]),
          onOpen: () => onOpen(items[i]),
        ),
    ]);
  }
}
