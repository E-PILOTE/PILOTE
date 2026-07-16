part of 'annuaire_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Briques de la page Annuaire : barre de filtres, en-tête, table & cartes
//  familles, bandeau de filtre actif.
// ════════════════════════════════════════════════════════════════════════════

// ─── Barre de filtres ─────────────────────────────────────────────────────────
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.searchCtrl,
    required this.isTable,
    required this.onlyGaps,
    required this.onSearch,
    required this.onToggleGaps,
    required this.onToggleView,
    required this.onReset,
  });
  final TextEditingController searchCtrl;
  final bool isTable, onlyGaps;
  final ValueChanged<String> onSearch;
  final VoidCallback onToggleGaps, onToggleView, onReset;

  @override
  Widget build(BuildContext context) {
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
                width: 260,
                child: TextField(
                  controller: searchCtrl,
                  onChanged: onSearch,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: adminFilledInput('Rechercher (élève, parent, n°…)',
                      icon: Icons.search_rounded),
                ),
              ),
              _GapToggle(active: onlyGaps, onTap: onToggleGaps),
              if (onlyGaps) _ResetChip(onTap: onReset),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _ViewToggle(isTable: isTable, onToggle: onToggleView),
      ]),
    );
  }
}

class _GapToggle extends StatelessWidget {
  const _GapToggle({required this.active, required this.onTap});
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: active ? kRed.withValues(alpha: 0.10) : kSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: active ? kRed.withValues(alpha: 0.35) : kBorder),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.person_off_rounded,
                  size: 15, color: active ? kRed : kTextMuted),
              const SizedBox(width: 6),
              Text('Sans contact',
                  style: TextStyle(
                      color: active ? kRed : kTextMuted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.isTable, required this.onToggle});
  final bool isTable;
  final VoidCallback onToggle;
  @override
  Widget build(BuildContext context) {
    Widget seg(bool table, IconData icon, String label) {
      final sel = isTable == table;
      return GestureDetector(
        onTap: sel ? null : onToggle,
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
        seg(true, Icons.table_rows_rounded, 'Table'),
        seg(false, Icons.grid_view_rounded, 'Cartes'),
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
                      color: kRed, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      );
}

// ─── Bandeau de filtre actif ──────────────────────────────────────────────────
class _ActiveFilterChip extends StatelessWidget {
  const _ActiveFilterChip({required this.label, required this.onClear});
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

// ─── En-tête résultats ────────────────────────────────────────────────────────
class _ResultHeader extends StatelessWidget {
  const _ResultHeader(
      {required this.count, required this.total, this.onExportPdf});
  final int count, total;
  final VoidCallback? onExportPdf;
  @override
  Widget build(BuildContext context) {
    final noun = total <= 1 ? 'famille' : 'familles';
    final txt = count == total ? '$total $noun' : '$count / $total $noun';
    return Row(children: [
      Icon(Icons.groups_2_outlined, size: 16, color: kTextMuted),
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
class _FamilyTable extends StatelessWidget {
  const _FamilyTable(
      {required this.rows, required this.onOpen, required this.onCall});
  final List<FamilyRow> rows;
  final ValueChanged<FamilyRow> onOpen;
  final ValueChanged<String> onCall;
  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: EdgeInsets.zero,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: const Row(children: [
            _Th('ÉLÈVE', flex: 4),
            _Th('CLASSE', flex: 2),
            _Th('CONTACT PRINCIPAL', flex: 4),
            _Th('TÉLÉPHONE', flex: 3),
            SizedBox(width: 40),
          ]),
        ),
        for (var i = 0; i < rows.length; i++)
          _FamilyRowTile(
            f: rows[i],
            last: i == rows.length - 1,
            onOpen: () => onOpen(rows[i]),
            onCall: onCall,
          ),
      ]),
    );
  }
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
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: kTextMuted)),
      );
}

class _FamilyRowTile extends StatelessWidget {
  const _FamilyRowTile(
      {required this.f,
      required this.last,
      required this.onOpen,
      required this.onCall});
  final FamilyRow f;
  final bool last;
  final VoidCallback onOpen;
  final ValueChanged<String> onCall;
  @override
  Widget build(BuildContext context) {
    final p = f.primary;
    final phone = f.phones.isNotEmpty ? f.phones.first : null;
    return InkWell(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: kBorder)),
        ),
        child: Row(children: [
          Expanded(
            flex: 4,
            child: Row(children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: kNavy.withValues(alpha: 0.10),
                child: Text(
                  f.student.firstName.isNotEmpty
                      ? f.student.firstName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                      color: kNavy, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.student.lastFirst,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: kTextPrimary)),
                      Text(f.student.matricule,
                          style: TextStyle(
                              fontSize: 11.5, color: kTextMuted)),
                    ]),
              ),
            ]),
          ),
          Expanded(
            flex: 2,
            child: f.student.className != null
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: AdminBadge(f.student.className!, color: kNavy))
                : Text('—', style: TextStyle(color: kTextMuted)),
          ),
          Expanded(
            flex: 4,
            child: p == null
                ? const _NoContactTag()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: kTextPrimary)),
                      Text(
                          [
                            p.relationshipLabel,
                            if (f.tutorCount > 1) '+${f.tutorCount - 1}'
                          ].join(' · '),
                          style: TextStyle(
                              fontSize: 11.5, color: _relColor(p.relationship))),
                    ],
                  ),
          ),
          Expanded(
            flex: 3,
            child: phone == null
                ? Text('—', style: TextStyle(color: kTextMuted))
                : _PhoneChip(phone: phone, onCall: () => onCall(phone)),
          ),
          SizedBox(
            width: 40,
            child: Icon(Icons.chevron_right_rounded,
                size: 18, color: kTextMuted),
          ),
        ]),
      ),
    );
  }
}

// ─── Cartes ──────────────────────────────────────────────────────────────────
class _FamilyCards extends StatelessWidget {
  const _FamilyCards(
      {required this.rows, required this.onOpen, required this.onCall});
  final List<FamilyRow> rows;
  final ValueChanged<FamilyRow> onOpen;
  final ValueChanged<String> onCall;
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, cns) {
      final w = cns.maxWidth;
      final cols = w >= 1180 ? 3 : (w >= 760 ? 2 : 1);
      const gap = 14.0;
      final cardW = (w - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final f in rows)
            SizedBox(
                width: cardW,
                child: _FamilyCard(
                    f: f, onOpen: () => onOpen(f), onCall: onCall)),
        ],
      );
    });
  }
}

class _FamilyCard extends StatelessWidget {
  const _FamilyCard(
      {required this.f, required this.onOpen, required this.onCall});
  final FamilyRow f;
  final VoidCallback onOpen;
  final ValueChanged<String> onCall;
  @override
  Widget build(BuildContext context) {
    final p = f.primary;
    final accent = f.hasContact ? kNavy : kRed;
    return AdminCard(
      padding: const EdgeInsets.all(16),
      accent: accent,
      onTap: onOpen,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: accent.withValues(alpha: 0.12),
            child: Text(
              f.student.firstName.isNotEmpty
                  ? f.student.firstName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                  color: accent, fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.student.lastFirst,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: kTextPrimary)),
                  Row(children: [
                    if (f.student.className != null) ...[
                      Flexible(
                        child: Text(f.student.className!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11.5, color: kTextMuted)),
                      ),
                      Text(' · ',
                          style: TextStyle(fontSize: 11.5, color: kTextMuted)),
                    ],
                    Text(f.student.matricule,
                        style:
                            TextStyle(fontSize: 11.5, color: kTextMuted)),
                  ]),
                ]),
          ),
          if (f.tutorCount > 0)
            AdminBadge('${f.tutorCount}', color: kNavy)
          else
            const _NoContactTag(),
        ]),
        const SizedBox(height: 12),
        if (p == null)
          Text('Aucun tuteur enregistré',
              style: TextStyle(fontSize: 12.5, color: kRed))
        else ...[
          Row(children: [
            Icon(Icons.person_outline_rounded,
                size: 14, color: _relColor(p.relationship)),
            const SizedBox(width: 8),
            Expanded(
              child: Text('${p.fullName} · ${p.relationshipLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: kTextPrimary)),
            ),
          ]),
          const SizedBox(height: 8),
          for (final ph in f.phones.take(2))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _PhoneChip(phone: ph, onCall: () => onCall(ph)),
            ),
        ],
      ]),
    );
  }
}

class _PhoneChip extends StatelessWidget {
  const _PhoneChip({required this.phone, required this.onCall});
  final String phone;
  final VoidCallback onCall;
  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onCall,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: kGreen.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.call_rounded, size: 13, color: kGreen),
              const SizedBox(width: 6),
              Flexible(
                child: Text(phone,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: kGreen)),
              ),
            ]),
          ),
        ),
      );
}

class _NoContactTag extends StatelessWidget {
  const _NoContactTag();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: kRed.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6)),
        child: Text('Sans contact',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: kRed)),
      );
}
