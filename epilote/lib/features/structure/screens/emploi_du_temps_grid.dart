part of 'emploi_du_temps_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Grille hebdomadaire : lignes = OSSATURE DE LA TRAME (séances de cours +
//  récréation/pause) ∪ plages réellement utilisées ; colonnes = Lun→Sam. La
//  trame sert de CANEVAS : même vide, une classe affiche ses cases de cours
//  cliquables (= ajouter). Les récré/pause sont des bandes pleine largeur.
//  Polyvalente selon la vue :
//    • classe     → case = matière + enseignant ; case vide cliquable = ajouter ;
//    • enseignant → case = matière + classe ; salle → + enseignant.
//  Un créneau en conflit est cerclé de rouge + pictogramme.
// ════════════════════════════════════════════════════════════════════════════
class _TimetableGrid extends StatelessWidget {
  const _TimetableGrid({
    required this.slots,
    required this.mode,
    required this.days,
    required this.trame,
    required this.conflictIds,
    required this.canAdd,
    required this.canDelete,
    required this.canMove,
    required this.onTapSlot,
    required this.onTapEmpty,
    required this.onDelete,
    required this.onMove,
  });
  final List<TimetableSlot> slots;
  final TtView mode;
  final List<int> days; // jours affichés (empan Jour = 1, Semaine = Lun→Sam)
  final List<SchoolPeriod> trame; // ossature (cours + récré/pause) du cycle
  final Set<String> conflictIds;
  final bool canAdd, canDelete, canMove;
  final ValueChanged<TimetableSlot> onTapSlot;
  final void Function(int day, String start, String end) onTapEmpty;
  final ValueChanged<TimetableSlot> onDelete;
  // Glisser-déposer : repositionner un créneau sur (jour, plage) cible.
  final void Function(TimetableSlot slot, int day, String start, String end) onMove;

  static const _timeColW = 92.0;
  static const _dayColW = 168.0;

  static Color _breakColor(String kind) => switch (kind) {
        'recreation' => const Color(0xFF0EA5E9),
        'pause_meridienne' => const Color(0xFFF59E0B),
        _ => kTextMuted,
      };
  static IconData _breakIcon(String kind) => switch (kind) {
        'recreation' => Icons.sports_handball_outlined,
        'pause_meridienne' => Icons.restaurant_outlined,
        _ => Icons.more_horiz_rounded,
      };

  @override
  Widget build(BuildContext context) {
    // Lignes : on fusionne les plages de COURS (trame + créneaux réels) et les
    // bandes récré/pause de la trame, triées chronologiquement.
    final courseRanges = <String, (String, String)>{};
    for (final p in trame) {
      if (p.isCourse) courseRanges['${p.hhmmStart}-${p.hhmmEnd}'] = (p.hhmmStart, p.hhmmEnd);
    }
    for (final s in slots) {
      courseRanges['${s.hhmmStart}-${s.hhmmEnd}'] = (s.hhmmStart, s.hhmmEnd);
    }
    final breaks = [for (final p in trame) if (!p.isCourse) p];

    // Liste ordonnée de lignes : (isBreak, start, end, label, kind).
    final rows = <({bool isBreak, String start, String end, String label, String kind})>[
      for (final r in courseRanges.values)
        (isBreak: false, start: r.$1, end: r.$2, label: '', kind: 'cours'),
      for (final b in breaks)
        (isBreak: true, start: b.hhmmStart, end: b.hhmmEnd, label: b.label, kind: b.kind),
    ]..sort((a, b) => a.start.compareTo(b.start));

    List<TimetableSlot> slotsAt(int day, String start, String end) => [
          for (final s in slots)
            if (s.dayOfWeek == day && s.hhmmStart == start && s.hhmmEnd == end) s,
        ];

    final dayAreaW = days.length * (_dayColW + 6);

    return AdminCard(
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // En-tête jours.
          Row(children: [
            const SizedBox(width: _timeColW),
            for (final d in days)
              Container(
                width: _dayColW,
                padding: const EdgeInsets.symmetric(vertical: 9),
                margin: const EdgeInsets.only(left: 6, bottom: 6),
                decoration: BoxDecoration(
                  color: kSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(frDays[d],
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: kTextPrimary)),
                ),
              ),
          ]),
          for (final r in rows)
            if (r.isBreak)
              _breakBand(r.start, r.end, r.label, r.kind, dayAreaW)
            else
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: _timeColW,
                  height: 92,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, right: 6),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(r.start,
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: kTextPrimary)),
                          Text(r.end,
                              style: TextStyle(
                                  fontSize: 11, color: kTextMuted)),
                        ]),
                  ),
                ),
                for (final d in days)
                  Padding(
                    padding: const EdgeInsets.only(left: 6, bottom: 6),
                    child: _Cell(
                      cellSlots: slotsAt(d, r.start, r.end),
                      mode: mode,
                      conflictIds: conflictIds,
                      width: _dayColW,
                      canAdd: canAdd,
                      canDelete: canDelete,
                      canMove: canMove,
                      onTapSlot: onTapSlot,
                      onTapEmpty: () => onTapEmpty(d, r.start, r.end),
                      onDelete: onDelete,
                      onMoveHere: (s) => onMove(s, d, r.start, r.end),
                    ),
                  ),
              ]),
        ]),
      ),
    );
  }

  // Bande pleine largeur récréation / pause méridienne.
  Widget _breakBand(
      String start, String end, String label, String kind, double dayAreaW) {
    final color = _breakColor(kind);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: _timeColW,
        child: Padding(
          padding: const EdgeInsets.only(top: 4, right: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(start,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: kTextMuted)),
            Text(end, style: TextStyle(fontSize: 10, color: kTextMuted)),
          ]),
        ),
      ),
      Container(
        width: dayAreaW,
        margin: const EdgeInsets.only(left: 6, bottom: 6),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Row(children: [
          Icon(_breakIcon(kind), size: 14, color: color),
          const SizedBox(width: 8),
          Text(label.isEmpty ? periodKindLabel(kind) : label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(width: 8),
          Text('$start–$end',
              style: TextStyle(fontSize: 11, color: kTextMuted)),
        ]),
      ),
    ]);
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.cellSlots,
    required this.mode,
    required this.conflictIds,
    required this.width,
    required this.canAdd,
    required this.canDelete,
    required this.canMove,
    required this.onTapSlot,
    required this.onTapEmpty,
    required this.onDelete,
    required this.onMoveHere,
  });
  final List<TimetableSlot> cellSlots;
  final TtView mode;
  final Set<String> conflictIds;
  final double width;
  final bool canAdd, canDelete, canMove;
  final ValueChanged<TimetableSlot> onTapSlot;
  final VoidCallback onTapEmpty;
  final ValueChanged<TimetableSlot> onDelete;
  final ValueChanged<TimetableSlot> onMoveHere; // créneau déposé ici

  // Tuile glissable (vue classe éditable) — sinon tuile simple.
  Widget _draggable(TimetableSlot s, Widget tile) {
    if (!canMove || mode != TtView.classe) return tile;
    return Draggable<TimetableSlot>(
      data: s,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.92,
          child: SizedBox(
              width: width - 12, height: 60, child: _MoveGhost(slot: s)),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: tile),
      child: tile,
    );
  }

  @override
  Widget build(BuildContext context) {
    // En vue classe éditable, toute case est une cible de dépôt.
    final isTarget = canMove && mode == TtView.classe;
    final inner = _content();
    if (!isTarget) return inner;
    return DragTarget<TimetableSlot>(
      onAcceptWithDetails: (d) => onMoveHere(d.data),
      builder: (ctx, cand, rej) {
        if (cand.isEmpty) return inner;
        // Survol d'un créneau en cours de glissement → surligner la cible.
        return DecoratedBox(
          decoration: BoxDecoration(
            color: kNavy.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kNavy, width: 1.5),
          ),
          child: inner,
        );
      },
    );
  }

  Widget _content() {
    if (cellSlots.isEmpty) {
      // Vue classe : case vide = ajouter (si droit de création).
      final addable = canAdd && mode == TtView.classe;
      return InkWell(
        onTap: addable ? onTapEmpty : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: width,
          height: 86,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kBorder),
          ),
          child: addable
              ? Center(
                  child: Icon(Icons.add_rounded, size: 18, color: kBorder))
              : null,
        ),
      );
    }
    // Plusieurs créneaux sur la même case (vue prof/salle = collision visible) :
    // on empile. Sinon une seule tuile pleine hauteur.
    if (cellSlots.length == 1) {
      return SizedBox(
        width: width,
        height: 86,
        child: _draggable(
          cellSlots.first,
          _SlotTile(
            slot: cellSlots.first,
            mode: mode,
            conflict: conflictIds.contains(cellSlots.first.id),
            canDelete: canDelete,
            onTap: () => onTapSlot(cellSlots.first),
            onDelete: () => onDelete(cellSlots.first),
          ),
        ),
      );
    }
    return SizedBox(
      width: width,
      height: 86,
      child: Column(children: [
        for (final s in cellSlots)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: _SlotTile(
                slot: s,
                mode: mode,
                conflict: true, // empilement = forcément collision
                canDelete: canDelete,
                dense: true,
                onTap: () => onTapSlot(s),
                onDelete: () => onDelete(s),
              ),
            ),
          ),
      ]),
    );
  }
}

// Aperçu flottant pendant le glissement d'un créneau.
class _MoveGhost extends StatelessWidget {
  const _MoveGhost({required this.slot});
  final TimetableSlot slot;
  @override
  Widget build(BuildContext context) {
    final color = _subjectColor(slot.subjectId);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1.4),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(children: [
        Icon(Icons.drag_indicator_rounded, size: 14, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(slot.subjectName ?? 'Cours',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w800, color: color)),
        ),
      ]),
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({
    required this.slot,
    required this.mode,
    required this.conflict,
    required this.canDelete,
    required this.onTap,
    required this.onDelete,
    this.dense = false,
  });
  final TimetableSlot slot;
  final TtView mode;
  final bool conflict;
  final bool canDelete;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final s = slot;
    final color = _subjectColor(s.subjectId);
    // Ligne secondaire = qui/quoi selon la vue.
    final secondary = switch (mode) {
      TtView.enseignant => s.className ?? '',
      TtView.salle => s.className ?? '',
      _ => s.teacherName ?? '',
    };
    // En vue salle, l'enseignant passe en ligne tertiaire à la place de la salle.
    final showRoom = mode != TtView.salle;
    final tertiaryTrailing = mode == TtView.salle ? s.teacherName : s.room;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.fromLTRB(10, dense ? 4 : 8, 6, dense ? 4 : 8),
        decoration: BoxDecoration(
          color: conflict
              ? kRed.withValues(alpha: 0.07)
              : color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: conflict
              ? Border.all(color: kRed, width: 1.4)
              : Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                if (conflict) ...[
                  Icon(Icons.warning_amber_rounded,
                      size: 13, color: kRed),
                  const SizedBox(width: 3),
                ],
                Expanded(
                  child: Text(s.subjectName ?? 'Matière',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: dense ? 11.5 : 12.5,
                          fontWeight: FontWeight.w800,
                          color: conflict ? kRed : color)),
                ),
                if (canDelete)
                  InkWell(
                    onTap: onDelete,
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(Icons.close_rounded,
                          size: 14, color: kTextMuted),
                    ),
                  ),
              ]),
              if (secondary.trim().isNotEmpty && !dense)
                Text(secondary.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11.5, color: kTextPrimary)),
              Row(children: [
                Icon(Icons.schedule_rounded, size: 11, color: kTextMuted),
                const SizedBox(width: 4),
                Text(s.timeLabel,
                    style: TextStyle(fontSize: 10.5, color: kTextMuted)),
                if ((tertiaryTrailing ?? '').trim().isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Icon(showRoom ? Icons.place_outlined : Icons.person_outline,
                      size: 11, color: kTextMuted),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(tertiaryTrailing!.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(fontSize: 10.5, color: kTextMuted)),
                  ),
                ],
              ]),
            ]),
      ),
    );
  }
}
