part of 'eleves_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Briques de la page Élèves : barre de filtres, en-tête, table, cartes, avatar.
// ════════════════════════════════════════════════════════════════════════════

// ─── Barre de filtres ─────────────────────────────────────────────────────────
class _ElevesFilterBar extends StatelessWidget {
  const _ElevesFilterBar({
    required this.searchCtrl,
    required this.gender,
    required this.status,
    required this.isTable,
    required this.readOnly,
    required this.onSearch,
    required this.onGender,
    required this.onStatus,
    required this.onToggleView,
    required this.onReset,
    required this.onAdd,
  });
  final TextEditingController searchCtrl;
  final String? gender;
  final String status;
  final bool isTable, readOnly;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onGender, onStatus;
  final VoidCallback onToggleView, onReset, onAdd;

  @override
  Widget build(BuildContext context) {
    final hasFilter =
        searchCtrl.text.isNotEmpty || gender != null || status != 'all';
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
                width: 240,
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
              _Drop(
                hint: 'Tous les statuts',
                value: status == 'all' ? null : status,
                items: const {
                  'active': 'Inscrits',
                  'pending_validation': 'En attente',
                  'none': 'Non inscrits',
                },
                onChanged: onStatus,
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

class _Drop extends StatelessWidget {
  const _Drop({
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String hint;
  final String? value;
  final Map<String, String> items;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: DropdownButtonFormField<String>(
        initialValue: items.containsKey(value) ? value : null,
        isExpanded: true,
        style: const TextStyle(fontSize: 13, color: kTextPrimary),
        icon: const Icon(Icons.expand_more_rounded, size: 18, color: kTextMuted),
        decoration: adminFilledInput(hint),
        hint: Text(hint,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: kTextMuted)),
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
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: kNavy)),
          ]),
        ),
      ),
    );
  }
}

// ─── En-tête de résultats ────────────────────────────────────────────────────
class _ResultHeader extends StatelessWidget {
  const _ResultHeader({required this.total, required this.filtered});
  final int total, filtered;
  @override
  Widget build(BuildContext context) {
    final txt = filtered == total
        ? _pl(total, 'élève', 'élèves')
        : '$filtered / ${_pl(total, 'élève', 'élèves')}';
    return Row(children: [
      const Icon(Icons.groups_outlined, size: 16, color: kTextMuted),
      const SizedBox(width: 8),
      Text(txt,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary)),
    ]);
  }
}

// ─── Table ───────────────────────────────────────────────────────────────────
class _StudentTable extends StatelessWidget {
  const _StudentTable({
    required this.rows,
    required this.sortAsc,
    required this.onSort,
    required this.onOpen,
  });
  final List<StudentRow> rows;
  final bool sortAsc;
  final VoidCallback onSort;
  final ValueChanged<StudentRow> onOpen;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: EdgeInsets.zero,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(children: [
            _Th('ÉLÈVE', flex: 4, onTap: onSort, asc: sortAsc),
            const _Th('MATRICULE', flex: 2),
            const _Th('SEXE · ÂGE', flex: 2),
            const _Th('CLASSE', flex: 3),
            const _Th('STATUT', flex: 2),
            const SizedBox(width: 44),
          ]),
        ),
        for (var i = 0; i < rows.length; i++)
          _StudentRow(
            s: rows[i],
            last: i == rows.length - 1,
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
            style: const TextStyle(
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
  const _StudentRow(
      {required this.s, required this.last, required this.onOpen});
  final StudentRow s;
  final bool last;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final sexe = s.gender == 'F' ? 'F' : (s.gender == 'M' ? 'M' : '—');
    final age = s.age;
    return InkWell(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border:
              last ? null : const Border(bottom: BorderSide(color: kBorder)),
        ),
        child: Row(children: [
          Expanded(
            flex: 4,
            child: Row(children: [
              _Avatar(name: s.fullName, photoUrl: s.photoUrl, size: 36),
              const SizedBox(width: 10),
              Flexible(
                child: Text(s.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
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
                style: const TextStyle(fontSize: 12.5, color: kTextMuted)),
          ),
          Expanded(
            flex: 2,
            child: Text('$sexe${age != null ? '  ·  $age ans' : ''}',
                style: const TextStyle(fontSize: 12.5, color: kTextPrimary)),
          ),
          Expanded(
            flex: 3,
            child: s.className == null
                ? const Text('—',
                    style: TextStyle(fontSize: 12.5, color: kTextMuted))
                : Row(children: [
                    Flexible(
                      child: Text(s.className!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: kTextPrimary)),
                    ),
                  ]),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: AdminBadge(_enrollLabel(s.enrollmentStatus),
                  color: _enrollColor(s.enrollmentStatus)),
            ),
          ),
          const SizedBox(
            width: 44,
            child: Icon(Icons.chevron_right_rounded, color: kTextMuted),
          ),
        ]),
      ),
    );
  }
}

// ─── Cartes ──────────────────────────────────────────────────────────────────
class _StudentCards extends StatelessWidget {
  const _StudentCards({required this.rows, required this.onOpen});
  final List<StudentRow> rows;
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
              child: _StudentCard(s: s, onOpen: () => onOpen(s)),
            ),
        ],
      );
    });
  }
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({required this.s, required this.onOpen});
  final StudentRow s;
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
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary)),
              Text(
                  '$sexe${age != null ? ' · $age ans' : ''}'
                  '${s.matricule.isNotEmpty ? ' · ${s.matricule}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: kTextMuted)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          AdminBadge(_enrollLabel(s.enrollmentStatus),
              color: _enrollColor(s.enrollmentStatus)),
          const Spacer(),
          if (s.className != null)
            Flexible(
              child: Text(s.className!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: kTextPrimary)),
            ),
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
            style: const TextStyle(
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
