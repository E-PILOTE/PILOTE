part of 'academic_structure_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  UN NIVEAU — son en-tête et sa table de classes
// ════════════════════════════════════════════════════════════════════════════

class _NiveauBlock extends StatelessWidget {
  const _NiveauBlock({
    required this.level,
    required this.classes,
    required this.color,
    required this.readOnly,
    required this.narrow,
    required this.onAdd,
    required this.onEdit,
  });
  final StructLevel level;
  final List<StructClass> classes;
  final Color color;
  final bool readOnly, narrow;
  final VoidCallback onAdd;
  final void Function(StructClass) onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // En-tête niveau
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(level.name,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: color)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                  classes.isEmpty
                      ? 'Aucune classe'
                      : '${_pl(classes.length, 'classe', 'classes')} · ${level.enrolled}'
                          '${level.capacity > 0 ? '/${level.capacity}' : ''} ${level.enrolled <= 1 ? 'élève' : 'élèves'}',
                  style: TextStyle(fontSize: 11.5, color: kTextMuted)),
            ),
            if (!readOnly)
              _MiniAddBtn(color: color, onTap: onAdd),
          ]),
        ),
        if (classes.isNotEmpty)
          narrow
              ? Column(children: [
                  for (final c in classes)
                    _ClassCard(
                        cls: c,
                        color: color,
                        onTap: readOnly ? null : () => onEdit(c)),
                ])
              : _ClassTable(
                  classes: classes,
                  color: color,
                  onEdit: readOnly ? null : onEdit,
                )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Text(
                readOnly
                    ? '—'
                    : 'Ce niveau n\'a pas encore de classe. Cliquez « + » pour en créer une.',
                style: TextStyle(
                    fontSize: 12,
                    color: kTextMuted,
                    fontStyle: FontStyle.italic)),
          ),
      ]),
    );
  }
}

class _MiniAddBtn extends StatelessWidget {
  const _MiniAddBtn({required this.color, required this.onTap});
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add_rounded, size: 15, color: color),
              const SizedBox(width: 4),
              Text('Classe',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: color)),
            ]),
          ),
        ),
      );
}
