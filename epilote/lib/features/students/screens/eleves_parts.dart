part of 'eleves_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Briques de la page Élèves : graphes, barre de filtres, barre d'actions
//  groupées, table (sélection), cartes, avatar, sélecteur de classe.
// ════════════════════════════════════════════════════════════════════════════

// ─── Évolution de l'effectif (graphe mensuel) ────────────────────────────────
class _EffectifEvolution extends ConsumerWidget {
  const _EffectifEvolution();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pts = ref.watch(effectifEvolutionProvider).valueOrNull ?? const [];
    if (pts.length < 2) {
      return AdminCard(
        padding: const EdgeInsets.all(20),
        child: Row(children: [
          Icon(Icons.timeline_rounded, size: 18, color: kTextMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
                'Pas encore assez d\'historique pour tracer une évolution '
                '(les dates d\'inscription se cumulent au fil de l\'année).',
                style: TextStyle(fontSize: 12.5, color: kTextMuted)),
          ),
        ]),
      );
    }
    return MonthlyEvolutionCard(
      points: [for (final p in pts) EvoPoint(p.label, p.count, p.cumul)],
      barLabel: 'Élèves entrés',
      lineLabel: 'Effectif cumulé',
    );
  }
}

// ─── Barre de filtres ─────────────────────────────────────────────────────────
class _ElevesFilterBar extends StatelessWidget {
  const _ElevesFilterBar({
    required this.searchCtrl,
    required this.gender,
    required this.isTable,
    required this.readOnly,
    required this.onSearch,
    required this.onGender,
    required this.onToggleView,
    required this.onReset,
    required this.onAdd,
  });
  final TextEditingController searchCtrl;
  final String? gender;
  final bool isTable, readOnly;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onGender;
  final VoidCallback onToggleView, onReset, onAdd;

  @override
  Widget build(BuildContext context) {
    final hasFilter = searchCtrl.text.isNotEmpty || gender != null;
    return AdminCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
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
                  decoration: adminFilledInput('Rechercher (nom, matricule)',
                      icon: Icons.search_rounded),
                ),
              ),
              _Drop(
                hint: 'Tous les sexes',
                value: gender,
                items: const {'M': 'Garçons', 'F': 'Filles'},
                onChanged: onGender,
              ),
              if (hasFilter)
                TextButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  label: const Text('Réinitialiser'),
                  style: TextButton.styleFrom(foregroundColor: kTextMuted),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _ViewToggle(isTable: isTable, onToggle: onToggleView),
        if (!readOnly) ...[
          const SizedBox(width: 10),
          PermissionGate(
            slug: 'eleves',
            action: 'create',
            child: AdminPrimaryButton(
              label: 'Nouvel élève',
              icon: Icons.person_add_alt_1_rounded,
              color: kNavy,
              onTap: onAdd,
            ),
          ),
        ],
      ]),
    );
  }
}

// Bandeau de filtre actif (scope choisi dans le panneau de répartition).
class _ScopeChip extends StatelessWidget {
  const _ScopeChip({required this.label, required this.onClear});
  final String label;
  final VoidCallback onClear;
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 7, 6, 7),
          decoration: BoxDecoration(
            color: kNavy.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kNavy.withValues(alpha: 0.25)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.filter_alt_rounded, size: 14, color: kNavy),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700, color: kNavy)),
            const SizedBox(width: 2),
            InkWell(
              onTap: onClear,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Icon(Icons.close_rounded, size: 15, color: kNavy),
              ),
            ),
          ]),
        ),
      );
}

class _Drop extends StatelessWidget {
  const _Drop(
      {required this.hint,
      required this.value,
      required this.items,
      required this.onChanged});
  final String hint;
  final String? value;
  final Map<String, String> items;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 175,
      child: DropdownButtonFormField<String>(
        initialValue: items.containsKey(value) ? value : null,
        isExpanded: true,
        style: TextStyle(fontSize: 13, color: kTextPrimary),
        icon: Icon(Icons.expand_more_rounded, size: 18, color: kTextMuted),
        decoration: adminFilledInput(hint),
        hint: Text(hint,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: kTextMuted)),
        items: [
          DropdownMenuItem(value: null, child: Text(hint)),
          for (final e in items.entries)
            DropdownMenuItem(value: e.key, child: Text(e.value)),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.isTable, required this.onToggle});
  final bool isTable;
  final VoidCallback onToggle;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: kSurface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kBorder)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(isTable ? Icons.grid_view_rounded : Icons.table_rows_rounded,
                size: 16, color: kNavy),
            const SizedBox(width: 7),
            Text(isTable ? 'Cartes' : 'Table',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: kNavy)),
          ]),
        ),
      ),
    );
  }
}

// ─── Barre d'actions groupées ────────────────────────────────────────────────
class _BulkBar extends StatelessWidget {
  const _BulkBar({
    required this.count,
    required this.onChangeClass,
    required this.onRevert,
    required this.onExport,
    required this.onClear,
  });
  final int count;
  final VoidCallback onChangeClass, onRevert, onExport, onClear;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kNavy,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Text('$count sélectionné${count > 1 ? 's' : ''}',
            style: const TextStyle(
                color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
        const Spacer(),
        _BulkBtn(
            icon: Icons.swap_horiz_rounded,
            label: 'Changer de classe',
            onTap: onChangeClass),
        _BulkBtn(
            icon: Icons.undo_rounded,
            label: 'Annuler l\'inscription',
            onTap: onRevert),
        _BulkBtn(
            icon: Icons.download_rounded, label: 'Exporter', onTap: onExport),
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

// ─── En-tête de résultats ────────────────────────────────────────────────────
class _ResultHeader extends StatelessWidget {
  const _ResultHeader(
      {required this.total, required this.filtered, this.onExportPdf});
  final int total, filtered;
  final VoidCallback? onExportPdf;
  @override
  Widget build(BuildContext context) {
    final txt = filtered == total
        ? _pl(total, 'élève', 'élèves')
        : '$filtered / ${_pl(total, 'élève', 'élèves')}';
    return Row(children: [
      Icon(Icons.groups_outlined, size: 16, color: kTextMuted),
      const SizedBox(width: 8),
      Text(txt,
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary)),
      const Spacer(),
      if (onExportPdf != null) AdminPdfButton(onTap: onExportPdf!),
    ]);
  }
}

// ─── Table ───────────────────────────────────────────────────────────────────
class _StudentTable extends StatelessWidget {
  const _StudentTable({
    required this.rows,
    required this.sortAsc,
    required this.selected,
    required this.readOnly,
    required this.onSort,
    required this.onSelect,
    required this.onSelectAll,
    required this.onOpen,
  });
  final List<StudentRow> rows;
  final bool sortAsc, readOnly;
  final Set<String> selected;
  final VoidCallback onSort;
  final void Function(String, bool) onSelect;
  final ValueChanged<bool> onSelectAll;
  final ValueChanged<StudentRow> onOpen;

  @override
  Widget build(BuildContext context) {
    final allSel = rows.isNotEmpty &&
        rows.every((r) => selected.contains(r.enrollmentId));
    return AdminCard(
      padding: EdgeInsets.zero,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(children: [
            if (!readOnly)
              _Check(value: allSel, onChanged: (v) => onSelectAll(v)),
            if (!readOnly) const SizedBox(width: 6),
            _Th('ÉLÈVE', flex: 4, onTap: onSort, asc: sortAsc),
            const _Th('MATRICULE', flex: 2),
            const _Th('SEXE · ÂGE', flex: 2),
            const _Th('CLASSE', flex: 3),
            const _Th('PARTICULARITÉS', flex: 3),
            const SizedBox(width: 36),
          ]),
        ),
        for (var i = 0; i < rows.length; i++)
          _StudentRow(
            s: rows[i],
            last: i == rows.length - 1,
            readOnly: readOnly,
            selected: selected.contains(rows[i].enrollmentId),
            onSelect: (v) => onSelect(rows[i].enrollmentId!, v),
            onOpen: () => onOpen(rows[i]),
          ),
      ]),
    );
  }
}

class _Th extends StatelessWidget {
  const _Th(this.label, {required this.flex, this.onTap, this.asc});
  final String label;
  final int flex;
  final VoidCallback? onTap;
  final bool? asc;
  @override
  Widget build(BuildContext context) {
    final child = Row(children: [
      Flexible(
        child: Text(label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: kTextMuted)),
      ),
      if (asc != null)
        Icon(asc! ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 12, color: kTextMuted),
    ]);
    return Expanded(
        flex: flex,
        child: onTap == null ? child : InkWell(onTap: onTap, child: child));
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({
    required this.s,
    required this.last,
    required this.readOnly,
    required this.selected,
    required this.onSelect,
    required this.onOpen,
  });
  final StudentRow s;
  final bool last, readOnly, selected;
  final ValueChanged<bool> onSelect;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final sexe = s.gender == 'F' ? 'F' : (s.gender == 'M' ? 'M' : '—');
    final age = s.age;
    final tags = <String>[
      if (s.isBoarder) 'Interne',
      if (s.isAffecte) 'Affecté',
      if (s.hasScholarship) 'Boursier',
      if (s.hasSocialAid) 'Aide sociale',
    ];
    return InkWell(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? kNavy.withValues(alpha: 0.04) : null,
          border:
              last ? null : Border(bottom: BorderSide(color: kBorder)),
        ),
        child: Row(children: [
          if (!readOnly)
            _Check(value: selected, onChanged: onSelect),
          if (!readOnly) const SizedBox(width: 6),
          Expanded(
            flex: 4,
            child: Row(children: [
              _Avatar(name: s.fullName, photoUrl: s.photoUrl, size: 34),
              const SizedBox(width: 10),
              Flexible(
                child: Text(s.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: kTextPrimary)),
              ),
            ]),
          ),
          Expanded(
            flex: 2,
            child: Text(s.matricule.isEmpty ? '—' : s.matricule,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: kTextMuted)),
          ),
          Expanded(
            flex: 2,
            child: Text('$sexe${age != null ? '  ·  $age ans' : ''}',
                style: TextStyle(fontSize: 12.5, color: kTextPrimary)),
          ),
          Expanded(
            flex: 3,
            child: Row(children: [
              AdminBadge(s.className ?? '—', color: _cycColor(s.cycleCode)),
            ]),
          ),
          Expanded(
            flex: 3,
            child: tags.isEmpty
                ? Text('—',
                    style: TextStyle(fontSize: 12.5, color: kTextMuted))
                : Text(tags.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: kTextMuted)),
          ),
          SizedBox(
            width: 36,
            child: Icon(Icons.chevron_right_rounded, color: kTextMuted),
          ),
        ]),
      ),
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
          side: BorderSide(color: kTextMuted, width: 1.5),
        ),
      );
}

// ─── Cartes ──────────────────────────────────────────────────────────────────
class _StudentCards extends StatelessWidget {
  const _StudentCards({
    required this.rows,
    required this.selected,
    required this.readOnly,
    required this.onSelect,
    required this.onOpen,
  });
  final List<StudentRow> rows;
  final Set<String> selected;
  final bool readOnly;
  final void Function(String, bool) onSelect;
  final ValueChanged<StudentRow> onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, cns) {
      final w = cns.maxWidth;
      final cols = w >= 1180 ? 4 : (w >= 880 ? 3 : (w >= 560 ? 2 : 1));
      const gap = 14.0;
      final cardW = (w - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final s in rows)
            SizedBox(
              width: cardW,
              child: _StudentCard(
                s: s,
                readOnly: readOnly,
                selected: selected.contains(s.enrollmentId),
                onSelect: (v) => onSelect(s.enrollmentId!, v),
                onOpen: () => onOpen(s),
              ),
            ),
        ],
      );
    });
  }
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({
    required this.s,
    required this.readOnly,
    required this.selected,
    required this.onSelect,
    required this.onOpen,
  });
  final StudentRow s;
  final bool readOnly, selected;
  final ValueChanged<bool> onSelect;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final age = s.age;
    final sexe = s.gender == 'F' ? 'Fille' : (s.gender == 'M' ? 'Garçon' : '—');
    return AdminCard(
      onTap: onOpen,
      padding: const EdgeInsets.all(16),
      accent: _cycColor(s.cycleCode),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _Avatar(name: s.fullName, photoUrl: s.photoUrl, size: 46),
          const SizedBox(width: 11),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary)),
              Text(
                  '$sexe${age != null ? ' · $age ans' : ''}'
                  '${s.matricule.isNotEmpty ? ' · ${s.matricule}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: kTextMuted)),
            ]),
          ),
          if (!readOnly) _Check(value: selected, onChanged: onSelect),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          AdminBadge(s.className ?? '—', color: _cycColor(s.cycleCode)),
          const Spacer(),
          if ((s.levelCode ?? '').isNotEmpty)
            Text(s.levelCode!,
                style: TextStyle(fontSize: 12, color: kTextMuted)),
        ]),
        if (s.isBoarder || s.hasScholarship || s.hasSocialAid || s.isAffecte) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            if (s.isBoarder) const _Tag('Interne'),
            if (s.isAffecte) const _Tag('Affecté'),
            if (s.hasScholarship) const _Tag('Boursier'),
            if (s.hasSocialAid) const _Tag('Aide sociale'),
          ]),
        ],
      ]),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: kBorder),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, color: kTextMuted, fontWeight: FontWeight.w600)),
      );
}

// ─── Avatar (photo ou initiales) ─────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  const _Avatar(
      {required this.name, required this.photoUrl, required this.size});
  final String name;
  final String? photoUrl;
  final double size;
  @override
  Widget build(BuildContext context) {
    final url = photoUrl;
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: kSurface,
        backgroundImage: CachedNetworkImageProvider(url),
      );
    }
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts.isEmpty
        ? '?'
        : (parts.length == 1
            ? parts.first.characters.take(2).toString()
            : '${parts.first.characters.first}${parts.last.characters.first}');
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: kNavy.withValues(alpha: 0.10),
      child: Text(initials.toUpperCase(),
          style: TextStyle(
              color: kNavy,
              fontSize: size * 0.34,
              fontWeight: FontWeight.w800)),
    );
  }
}

// ─── Sélecteur de classe (cascade) — renvoie l'id de classe choisi ───────────
class _ClassChooserDialog extends ConsumerStatefulWidget {
  const _ClassChooserDialog({required this.title, required this.subtitle});
  final String title, subtitle;
  @override
  ConsumerState<_ClassChooserDialog> createState() =>
      _ClassChooserDialogState();
}

class _ClassChooserDialogState extends ConsumerState<_ClassChooserDialog> {
  String? _classId;

  ClassPickerEntry _entry(ClassModel c) {
    final cyc = inscriptionCycleFromCode(c.cycleCode, c.name);
    return ClassPickerEntry(
      id: c.id,
      name: c.name,
      cycleCode: cyc.code,
      cycleLabel: cyc.label,
      cycleOrder: cyc.order,
      levelCode: c.levelCode ?? '',
      levelOrder: c.levelOrder ?? 999,
      capacity: c.capacity,
      count: c.studentCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(classesProvider);
    return AdminFormDialog(
      icon: Icons.swap_horiz_rounded,
      title: widget.title,
      subtitle: widget.subtitle,
      width: 520,
      submitLabel: 'Valider',
      submitIcon: Icons.check_rounded,
      onSubmit: () {
        if (_classId == null) return;
        Navigator.pop(context, _classId);
      },
      body: classesAsync.when(
        loading: () => const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator())),
        error: (e, _) =>
            Text(messageErreur(e), style: TextStyle(color: kRed)),
        data: (classes) {
          if (classes.isEmpty) {
            return Text('Aucune classe disponible.',
                style: TextStyle(color: kTextMuted, fontSize: 13));
          }
          return CycleLevelClassPicker(
            entries: [for (final c in classes) _entry(c)],
            classId: _classId,
            onChanged: (v) => setState(() => _classId = v),
          );
        },
      ),
    );
  }
}
