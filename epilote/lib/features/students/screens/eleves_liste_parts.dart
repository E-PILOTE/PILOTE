part of 'eleves_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  COMMENT UN ÉLÈVE S'AFFICHE : la table (avec sélection), les cartes, et
//  l'avatar photo-ou-initiales commun aux deux.
// ════════════════════════════════════════════════════════════════════════════
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
            // L'identifiant national ne figurait nulle part dans la liste, alors
            // que c'est lui qui suit l'enfant d'une école à l'autre — et lui
            // qu'on relit à voix haute au téléphone.
            const _Th('IDENT. NATIONAL', flex: 3),
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
            flex: 3,
            child: Text(
                // Un élève saisi hors ligne n'en a pas encore : le dire vaut
                // mieux qu'un tiret, qu'on lirait comme un oubli de saisie.
                s.ine == null ? 'en attente' : formatIne(s.ine),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12.5,
                    color: kTextMuted,
                    fontStyle:
                        s.ine == null ? FontStyle.italic : FontStyle.normal)),
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
