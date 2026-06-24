part of 'programmes_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Briques de la page Programmes : répartition par niveau, barre de filtres,
//  table, cartes, en-tête, actions groupées.
// ════════════════════════════════════════════════════════════════════════════

// ─── Répartition par niveau (barres cliquables → filtre) ─────────────────────
class _LevelBreakdown extends StatelessWidget {
  const _LevelBreakdown(
      {required this.byLevel, required this.active, required this.onPick});
  final List<ProgLevelCount> byLevel;
  final String? active;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final maxN = byLevel.fold<int>(0, (m, e) => e.total > m ? e.total : m);
    return AdminCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.stairs_outlined, size: 16, color: kNavy),
          SizedBox(width: 8),
          Text('Programmes par niveau',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: kNavy)),
          Spacer(),
          Text('cliquez pour filtrer',
              style: TextStyle(fontSize: 11.5, color: kTextMuted)),
        ]),
        const SizedBox(height: 12),
        for (final e in byLevel)
          _LevelBar(
            label: e.code,
            count: e.total,
            ratio: maxN == 0 ? 0 : e.total / maxN,
            color: _cyc(e.cycleCode),
            active: active == e.code,
            onTap: () => onPick(e.code),
          ),
      ]),
    );
  }
}

class _LevelBar extends StatelessWidget {
  const _LevelBar({
    required this.label,
    required this.count,
    required this.ratio,
    required this.color,
    required this.active,
    required this.onTap,
  });
  final String label;
  final int count;
  final double ratio;
  final Color color;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.10) : null,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: active ? color.withValues(alpha: 0.4) : Colors.transparent),
        ),
        child: Row(children: [
          SizedBox(
            width: 96,
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio.clamp(0.02, 1.0),
                minHeight: 16,
                backgroundColor: kSurface,
                valueColor: AlwaysStoppedAnimation(color.withValues(alpha: 0.85)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: Text(_pl(count, 'programme', 'programmes'),
                textAlign: TextAlign.end,
                style: const TextStyle(fontSize: 11.5, color: kTextMuted)),
          ),
        ]),
      ),
    );
  }
}

// ─── Barre de filtres ─────────────────────────────────────────────────────────
class _ProgFilterBar extends StatelessWidget {
  const _ProgFilterBar({
    required this.searchCtrl,
    required this.view,
    required this.readOnly,
    required this.subject,
    required this.level,
    required this.trimester,
    required this.type,
    required this.subjectsPresent,
    required this.levelsPresent,
    required this.trimestersPresent,
    required this.onSearch,
    required this.onSubject,
    required this.onLevel,
    required this.onTrimester,
    required this.onType,
    required this.onView,
    required this.onReset,
    required this.onAdd,
  });
  final TextEditingController searchCtrl;
  final String view;
  final bool readOnly;
  final String? subject, level, trimester;
  final String type;
  final Map<String, String> subjectsPresent, trimestersPresent;
  final Map<String, int> levelsPresent;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onSubject, onLevel, onTrimester;
  final ValueChanged<String> onType, onView;
  final VoidCallback onReset, onAdd;

  bool get _hasFilters =>
      subject != null || level != null || trimester != null || type != 'all';

  @override
  Widget build(BuildContext context) {
    final levelsSorted = levelsPresent.keys.toList()
      ..sort((a, b) => levelsPresent[a]!.compareTo(levelsPresent[b]!));
    return AdminCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 230,
                  child: TextField(
                    controller: searchCtrl,
                    onChanged: onSearch,
                    style: const TextStyle(fontSize: 13.5),
                    decoration: adminFilledInput('Rechercher (titre, matière…)',
                        icon: Icons.search_rounded),
                  ),
                ),
                _Dd(
                  width: 210,
                  value: subjectsPresent.containsKey(subject) ? subject : null,
                  entries: [
                    const (null, 'Toutes les matières'),
                    for (final e in subjectsPresent.entries) (e.key, e.value),
                  ],
                  onChanged: onSubject,
                ),
                _Dd(
                  width: 170,
                  value: levelsPresent.containsKey(level) ? level : null,
                  entries: [
                    const (null, 'Tous les niveaux'),
                    for (final c in levelsSorted) (c, c),
                  ],
                  onChanged: onLevel,
                ),
                if (trimestersPresent.isNotEmpty)
                  _Dd(
                    width: 195,
                    value: trimestersPresent.containsKey(trimester)
                        ? trimester
                        : null,
                    entries: [
                      const (null, 'Tous les trimestres'),
                      for (final e in trimestersPresent.entries) (e.key, e.value),
                    ],
                    onChanged: onTrimester,
                  ),
                _TypeSegment(value: type, onChanged: onType),
                if (_hasFilters)
                  _ResetChip(onTap: onReset),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _ViewToggle(value: view, onChanged: onView),
          const SizedBox(width: 10),
          if (readOnly)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: kAccent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kAccent.withValues(alpha: 0.30)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.lock_clock_rounded, size: 15, color: kAccent),
                SizedBox(width: 6),
                Text('Année verrouillée',
                    style: TextStyle(
                        color: kAccent,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700)),
              ]),
            )
          else
            PermissionGate(
              slug: _kSlug,
              action: 'create',
              child: AdminPrimaryButton(
                label: 'Nouveau programme',
                icon: Icons.add_rounded,
                color: kNavy,
                onTap: onAdd,
              ),
            ),
        ]),
      ]),
    );
  }
}

// Sélecteur compact : le texte affiché reste sur UNE ligne (ellipsis) — plus de
// tronquage / retour à la ligne dans le bouton fermé.
class _Dd extends StatelessWidget {
  const _Dd(
      {required this.width,
      required this.value,
      required this.entries,
      required this.onChanged});
  final double width;
  final String? value;
  final List<(String?, String)> entries;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: DropdownButtonFormField<String?>(
          initialValue: value,
          isExpanded: true,
          style: const TextStyle(fontSize: 13, color: kTextPrimary),
          icon: const Icon(Icons.expand_more_rounded,
              size: 18, color: kTextMuted),
          decoration: adminFilledInput(entries.first.$2),
          selectedItemBuilder: (context) => [
            for (final e in entries)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(e.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        color: e.$1 == null ? kTextMuted : kTextPrimary)),
              ),
          ],
          items: [
            for (final e in entries)
              DropdownMenuItem(
                  value: e.$1,
                  child: Text(e.$2,
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: onChanged,
        ),
      );
}

// Bascule de vue 3 modes : Table / Cartes / Par cycle.
class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    Widget seg(String v, IconData icon, String label) {
      final sel = value == v;
      return GestureDetector(
        onTap: () => onChanged(v),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
              color: sel ? kNavy : Colors.transparent,
              borderRadius: BorderRadius.circular(6)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15, color: sel ? Colors.white : kTextMuted),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : kTextMuted)),
          ]),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kBorder)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        seg('table', Icons.table_rows_rounded, 'Table'),
        seg('cartes', Icons.grid_view_rounded, 'Cartes'),
        seg('cycle', Icons.account_tree_outlined, 'Par cycle'),
      ]),
    );
  }
}

class _TypeSegment extends StatelessWidget {
  const _TypeSegment({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    Widget seg(String v, String label) {
      final sel = value == v;
      return GestureDetector(
        onTap: () => onChanged(v),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
              color: sel ? kNavy : Colors.transparent,
              borderRadius: BorderRadius.circular(6)),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: sel ? Colors.white : kTextMuted)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kBorder)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        seg('all', 'Tous'),
        seg('officiel', 'Officiels'),
        seg('perso', 'Perso'),
      ]),
    );
  }
}

class _ResetChip extends StatelessWidget {
  const _ResetChip({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: kRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kRed.withValues(alpha: 0.25)),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.filter_alt_off_rounded, size: 14, color: kRed),
              SizedBox(width: 5),
              Text('Réinitialiser',
                  style: TextStyle(
                      color: kRed,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      );
}

// ─── En-tête résultats ────────────────────────────────────────────────────────
class _ResultHeader extends StatelessWidget {
  const _ResultHeader({required this.total, required this.filtered});
  final int total, filtered;
  @override
  Widget build(BuildContext context) {
    final txt = filtered == total
        ? _pl(total, 'programme', 'programmes')
        : '$filtered / ${_pl(total, 'programme', 'programmes')}';
    return Row(children: [
      const Icon(Icons.article_outlined, size: 16, color: kTextMuted),
      const SizedBox(width: 8),
      Text(txt,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary)),
    ]);
  }
}

// ─── Table ───────────────────────────────────────────────────────────────────
class _ProgTable extends ConsumerWidget {
  const _ProgTable({
    required this.rows,
    required this.selected,
    required this.onSelect,
    required this.onSelectAll,
    required this.onEdit,
    required this.onDelete,
    required this.onOpen,
  });
  final List<ProgrammeRow> rows;
  final Set<String> selected;
  final void Function(String, bool) onSelect;
  final ValueChanged<bool> onSelectAll;
  final ValueChanged<ProgrammeRow> onEdit, onDelete, onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canEdit = ref.watch(canProvider((slug: _kSlug, action: 'update')));
    final canDelete = ref.watch(canProvider((slug: _kSlug, action: 'delete')));
    final canBulk = canEdit || canDelete;
    final allSel =
        rows.isNotEmpty && rows.every((p) => selected.contains(p.id));
    return AdminCard(
      padding: EdgeInsets.zero,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: const BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(children: [
            if (canBulk) ...[
              _Check(value: allSel, onChanged: onSelectAll),
              const SizedBox(width: 6),
            ],
            const _Th('PROGRAMME', flex: 6),
            const _Th('MATIÈRE', flex: 3),
            const _Th('NIVEAU', flex: 2),
            const _Th('TRIMESTRE', flex: 2),
            const _Th('TYPE', flex: 2),
            const SizedBox(width: 120),
          ]),
        ),
        for (var i = 0; i < rows.length; i++)
          _ProgRow(
            p: rows[i],
            last: i == rows.length - 1,
            canEdit: canEdit,
            canDelete: canDelete,
            canBulk: canBulk,
            selected: selected.contains(rows[i].id),
            onSelect: (v) => onSelect(rows[i].id, v),
            onEdit: () => onEdit(rows[i]),
            onDelete: () => onDelete(rows[i]),
            onOpen: () => onOpen(rows[i]),
          ),
      ]),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 24,
        height: 24,
        child: Checkbox(
          value: value,
          onChanged: (v) => onChanged(v ?? false),
          activeColor: kNavy,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          side: const BorderSide(color: kTextMuted, width: 1.5),
        ),
      );
}

class _Th extends StatelessWidget {
  const _Th(this.label, {required this.flex});
  final String label;
  final int flex;
  @override
  Widget build(BuildContext context) => Expanded(
        flex: flex,
        child: Text(label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: kTextMuted)),
      );
}

class _ProgRow extends StatelessWidget {
  const _ProgRow({
    required this.p,
    required this.last,
    required this.canEdit,
    required this.canDelete,
    required this.canBulk,
    required this.selected,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
    required this.onOpen,
  });
  final ProgrammeRow p;
  final bool last, canEdit, canDelete, canBulk, selected;
  final ValueChanged<bool> onSelect;
  final VoidCallback onEdit, onDelete, onOpen;

  @override
  Widget build(BuildContext context) {
    final col = _cyc(p.cycleCode);
    final canMutate = !p.isShared; // les programmes partagés (groupe) sont en lecture seule
    return InkWell(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? kNavy.withValues(alpha: 0.04) : null,
          border:
              last ? null : const Border(bottom: BorderSide(color: kBorder)),
        ),
        child: Row(children: [
          if (canBulk) ...[
            _Check(value: selected, onChanged: canMutate ? onSelect : (_) {}),
            const SizedBox(width: 6),
          ],
          Expanded(
            flex: 6,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: kTextPrimary)),
                  if (p.hasContent) ...[
                    const SizedBox(height: 2),
                    Text(p.preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11.5, color: kTextMuted)),
                  ],
                ]),
          ),
          Expanded(
            flex: 3,
            child: Text(p.subjectName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary)),
          ),
          Expanded(
            flex: 2,
            child: Align(
                alignment: Alignment.centerLeft,
                child: AdminBadge(p.levelLabel, color: col)),
          ),
          Expanded(
            flex: 2,
            child: Text(p.trimesterLabelOrAll,
                style: const TextStyle(fontSize: 12, color: kTextMuted)),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: p.isOfficial
                  ? const AdminBadge('Officiel', color: kGreen)
                  : AdminBadge(p.isShared ? 'Partagé' : 'Perso',
                      color: p.isShared ? kNavy : const Color(0xFFF59E0B)),
            ),
          ),
          SizedBox(
            width: 120,
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (canEdit && canMutate)
                IconButton(
                  tooltip: 'Modifier',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.edit_outlined, size: 18, color: kNavy),
                  onPressed: onEdit,
                ),
              if (canDelete && canMutate)
                IconButton(
                  tooltip: 'Supprimer',
                  visualDensity: VisualDensity.compact,
                  icon:
                      const Icon(Icons.delete_outline_rounded, size: 18, color: kRed),
                  onPressed: onDelete,
                ),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: kTextMuted),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─── Cartes ──────────────────────────────────────────────────────────────────
class _ProgCards extends ConsumerWidget {
  const _ProgCards(
      {required this.rows,
      required this.onEdit,
      required this.onDelete,
      required this.onOpen});
  final List<ProgrammeRow> rows;
  final ValueChanged<ProgrammeRow> onEdit, onDelete, onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canEdit = ref.watch(canProvider((slug: _kSlug, action: 'update')));
    final canDelete = ref.watch(canProvider((slug: _kSlug, action: 'delete')));
    return LayoutBuilder(builder: (ctx, cns) {
      final w = cns.maxWidth;
      final cols = w >= 1180 ? 3 : (w >= 760 ? 2 : 1);
      const gap = 14.0;
      final cardW = (w - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final p in rows)
            SizedBox(
              width: cardW,
              child: _ProgCard(
                p: p,
                canEdit: canEdit && !p.isShared,
                canDelete: canDelete && !p.isShared,
                onEdit: () => onEdit(p),
                onDelete: () => onDelete(p),
                onOpen: () => onOpen(p),
              ),
            ),
        ],
      );
    });
  }
}

class _ProgCard extends StatelessWidget {
  const _ProgCard({
    required this.p,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
    required this.onOpen,
  });
  final ProgrammeRow p;
  final bool canEdit, canDelete;
  final VoidCallback onEdit, onDelete, onOpen;

  @override
  Widget build(BuildContext context) {
    final col = _cyc(p.cycleCode);
    return AdminCard(
      padding: const EdgeInsets.all(16),
      accent: col,
      onTap: onOpen,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(p.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary)),
          ),
          if (canEdit)
            IconButton(
              tooltip: 'Modifier',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.edit_outlined, size: 17, color: kNavy),
              onPressed: onEdit,
            ),
          if (canDelete)
            IconButton(
              tooltip: 'Supprimer',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 17, color: kRed),
              onPressed: onDelete,
            ),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          AdminBadge(p.subjectName, color: col),
          AdminBadge(p.levelLabel, color: kNavy),
          AdminBadge(p.trimesterLabelOrAll, color: kTextMuted),
          if (p.isOfficial)
            const AdminBadge('Officiel', color: kGreen)
          else if (p.isShared)
            const AdminBadge('Partagé', color: kNavy),
        ]),
        if (p.hasContent) ...[
          const SizedBox(height: 10),
          Text(p.preview,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12, color: kTextMuted, height: 1.4)),
        ],
      ]),
    );
  }
}

// (Vue « Par cycle » premium → programmes_cycle_view.dart)

// ─── Barre d'actions groupées ────────────────────────────────────────────────
class _ProgBulkBar extends StatelessWidget {
  const _ProgBulkBar({
    required this.count,
    required this.onDelete,
    required this.onExport,
    required this.onClear,
  });
  final int count;
  final VoidCallback onDelete, onExport, onClear;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration:
          BoxDecoration(color: kNavy, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Text('$count sélectionné${count > 1 ? 's' : ''}',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w700)),
        const Spacer(),
        _BulkBtn(icon: Icons.download_rounded, label: 'Exporter', onTap: onExport),
        _BulkBtn(
            icon: Icons.delete_outline_rounded,
            label: 'Supprimer',
            onTap: onDelete),
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'Désélectionner',
          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
          onPressed: onClear,
        ),
      ]),
    );
  }
}

class _BulkBtn extends StatelessWidget {
  const _BulkBtn(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Material(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 15, color: Colors.white),
                const SizedBox(width: 6),
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
      );
}
