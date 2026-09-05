part of 'academic_structure_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LES CLASSES — table large, carte étroite, effectif et barre d'occupation
//
//  La barre d'occupation dit d'un coup d'œil qu'une classe déborde : c'est la
//  seule information de cette page qui se lit sans compter.
// ════════════════════════════════════════════════════════════════════════════

class _ClassTable extends StatelessWidget {
  const _ClassTable(
      {required this.classes, required this.color, required this.onEdit});
  final List<StructClass> classes;
  final Color color;
  final void Function(StructClass)? onEdit;
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // En-tête colonnes
      Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        color: kCardBg,
        child: const Row(children: [
          Expanded(flex: 3, child: _Th('CLASSE')),
          Expanded(flex: 2, child: _Th('FILIÈRE')),
          Expanded(flex: 3, child: _Th('EFFECTIF')),
          Expanded(flex: 3, child: _Th('PROF. PRINCIPAL')),
          Expanded(flex: 2, child: _Th('SALLE')),
          SizedBox(width: 36),
        ]),
      ),
      for (final c in classes)
        _ClassRow(cls: c, color: color, onTap: onEdit == null ? null : () => onEdit!(c)),
    ]);
  }
}

class _Th extends StatelessWidget {
  const _Th(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: kTextMuted));
}

class _ClassRow extends StatelessWidget {
  const _ClassRow({required this.cls, required this.color, required this.onTap});
  final StructClass cls;
  final Color color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: kCardBg,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
              border: Border(top: BorderSide(color: kBorder))),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(children: [
            Expanded(
              flex: 3,
              child: Row(children: [
                Container(
                    width: 7,
                    height: 7,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(cls.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: kTextPrimary)),
                ),
              ]),
            ),
            Expanded(
                flex: 2,
                child: Text(cls.filiereLabel ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: kTextMuted))),
            Expanded(flex: 3, child: _EffectifCell(cls: cls, color: color)),
            Expanded(
              flex: 3,
              child: cls.teacherName != null
                  ? Text(cls.teacherName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12.5, color: kTextPrimary))
                  : Text('Non assigné',
                      style: TextStyle(
                          fontSize: 12,
                          color: kTextMuted,
                          fontStyle: FontStyle.italic)),
            ),
            Expanded(
                flex: 2,
                child: Text(cls.room ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: kTextMuted))),
            SizedBox(
              width: 36,
              child: onTap == null
                  ? const SizedBox.shrink()
                  : Icon(Icons.edit_outlined, size: 16, color: kTextMuted),
            ),
          ]),
        ),
      ),
    );
  }
}

class _EffectifCell extends StatelessWidget {
  const _EffectifCell({required this.cls, required this.color});
  final StructClass cls;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final txtColor = cls.isOver
        ? kRed
        : (cls.isNearFull ? const Color(0xFFF59E0B) : kTextPrimary);
    return Row(children: [
      Expanded(
          child: _FillBar(
              ratio: cls.fillRatio,
              color: cls.isOver
                  ? kRed
                  : (cls.isNearFull ? const Color(0xFFF59E0B) : color))),
      const SizedBox(width: 8),
      Text(
          cls.capacity != null
              ? '${cls.enrolled}/${cls.capacity}'
              : '${cls.enrolled}',
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: txtColor)),
    ]);
  }
}

// Carte classe (étroit)

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.cls, required this.color, required this.onTap});
  final StructClass cls;
  final Color color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: kCardBg,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
              border: Border(top: BorderSide(color: kBorder))),
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                  width: 7,
                  height: 7,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(cls.name,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary)),
              if (cls.filiereLabel != null) ...[
                const SizedBox(width: 8),
                Text(cls.filiereLabel!,
                    style: TextStyle(fontSize: 11.5, color: kTextMuted)),
              ],
              const Spacer(),
              if (onTap != null)
                Icon(Icons.edit_outlined, size: 15, color: kTextMuted),
            ]),
            const SizedBox(height: 8),
            _EffectifCell(cls: cls, color: color),
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.person_outline_rounded,
                  size: 14, color: kTextMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(cls.teacherName ?? 'Prof. non assigné',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11.5,
                        color: cls.teacherName != null
                            ? kTextPrimary
                            : kTextMuted)),
              ),
              if (cls.room != null) ...[
                Icon(Icons.meeting_room_outlined,
                    size: 14, color: kTextMuted),
                const SizedBox(width: 4),
                Text(cls.room!,
                    style: TextStyle(fontSize: 11.5, color: kTextMuted)),
              ],
            ]),
          ]),
        ),
      ),
    );
  }
}

class _FillBar extends StatelessWidget {
  const _FillBar({required this.ratio, required this.color, this.showPct = false});
  final double? ratio;
  final Color color;
  final bool showPct;
  @override
  Widget build(BuildContext context) {
    final r = ratio == null ? 0.0 : ratio!.clamp(0.0, 1.0);
    final over = ratio != null && ratio! > 1.0;
    return Row(children: [
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(children: [
            Container(height: 6, color: kBorder),
            FractionallySizedBox(
              widthFactor: ratio == null ? 0 : (over ? 1.0 : r),
              child: Container(height: 6, color: over ? kRed : color),
            ),
          ]),
        ),
      ),
      if (showPct) ...[
        const SizedBox(width: 8),
        Text(ratio == null ? '—' : '${(ratio! * 100).round()}%',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: over ? kRed : kTextMuted)),
      ],
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  MODAL — créer / modifier une classe (filière, prof principal, salle).
// ════════════════════════════════════════════════════════════════════════════
