part of 'programmes_screen.dart';

// ─── Barre de filtres, bascule de vue, en-tête de résultats ─────────────────

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
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.lock_clock_rounded, size: 15, color: kAccent),
                const SizedBox(width: 6),
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
          style: TextStyle(fontSize: 13, color: kTextPrimary),
          icon: Icon(Icons.expand_more_rounded,
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
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.filter_alt_off_rounded, size: 14, color: kRed),
              const SizedBox(width: 5),
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

class _ResultHeader extends StatelessWidget {
  const _ResultHeader(
      {required this.total, required this.filtered, this.onExportPdf});
  final int total, filtered;
  final VoidCallback? onExportPdf;
  @override
  Widget build(BuildContext context) {
    final txt = filtered == total
        ? _pl(total, 'programme', 'programmes')
        : '$filtered / ${_pl(total, 'programme', 'programmes')}';
    return Row(children: [
      Icon(Icons.article_outlined, size: 16, color: kTextMuted),
      const SizedBox(width: 8),
      Text(txt,
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary)),
      const Spacer(),
      if (onExportPdf != null) AdminPdfButton(onTap: onExportPdf!),
    ]);
  }
}
