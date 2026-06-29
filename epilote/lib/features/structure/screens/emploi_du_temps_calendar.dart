part of 'emploi_du_temps_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CALENDRIER MAÎTRE — un seul grand calendrier hebdomadaire (jours × créneaux)
//  qui REGROUPE TOUS les cours de la sélection. Une cellule (jour × plage) peut
//  contenir PLUSIEURS cours simultanés (classes différentes) = NORMAL, en blocs
//  pleine largeur ; au-delà de 4, repli « +N autres ». Vrai conflit (même prof/
//  salle/classe) = cerclé de rouge. Colonne du JOUR COURANT teintée. Cellules
//  vides discrètes. Couleur par CLASSE (multi) ou par MATIÈRE (une seule classe).
// ════════════════════════════════════════════════════════════════════════════
class _MasterCalendar extends StatelessWidget {
  const _MasterCalendar({
    required this.slots,
    required this.days,
    required this.trameRanges,
    required this.conflictIds,
    required this.colorByClass,
    required this.editable,
    required this.onTapSlot,
    required this.onTapEmpty,
  });

  final List<TimetableSlot> slots;
  final List<int> days; // jours affichés (empan Jour = 1, Semaine = Lun→Sam)
  final List<(String, String)> trameRanges; // ossature horaire (trame école)
  final Set<String> conflictIds;
  final bool colorByClass; // true = couleur par classe ; false = par matière
  final bool editable; // cellule vide cliquable (= ajouter) si true
  final ValueChanged<TimetableSlot> onTapSlot;
  final void Function(int day, String start, String end) onTapEmpty;

  @override
  Widget build(BuildContext context) {
    // Lignes = union (trame ∪ plages réellement utilisées), triées.
    final ranges = <String, (String, String)>{};
    for (final r in trameRanges) {
      ranges['${r.$1}-${r.$2}'] = r;
    }
    for (final s in slots) {
      ranges['${s.hhmmStart}-${s.hhmmEnd}'] = (s.hhmmStart, s.hhmmEnd);
    }
    final rows = ranges.values.toList()..sort((a, b) => a.$1.compareTo(b.$1));
    final today = DateTime.now().weekday; // 1=lun … 7=dim

    List<TimetableSlot> at(int day, String start, String end) => [
          for (final s in slots)
            if (s.dayOfWeek == day && s.hhmmStart == start && s.hhmmEnd == end) s,
        ];

    const timeW = 60.0;

    Widget dayHeader(int d) {
      final isToday = d == today;
      return Expanded(
        child: Container(
          margin: const EdgeInsets.only(left: 6, bottom: 6),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isToday ? kNavy : kSurface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(frDays[d],
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: isToday ? Colors.white : kTextPrimary)),
          ),
        ),
      );
    }

    return AdminCard(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [const SizedBox(width: timeW), for (final d in days) dayHeader(d)]),
        if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 34),
            child: Center(
              child: Text('Aucun créneau pour cette sélection.',
                  style: TextStyle(fontSize: 13, color: kTextMuted)),
            ),
          )
        else
          for (final r in rows)
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SizedBox(
                  width: timeW,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, right: 6),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(r.$1,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: kTextPrimary)),
                          Text(r.$2,
                              style: const TextStyle(
                                  fontSize: 10, color: kTextMuted)),
                        ]),
                  ),
                ),
                for (final d in days)
                  Expanded(
                    child: _CalCell(
                      slots: at(d, r.$1, r.$2),
                      conflictIds: conflictIds,
                      colorByClass: colorByClass,
                      editable: editable,
                      isToday: d == today,
                      onTapSlot: onTapSlot,
                      onTapEmpty: () => onTapEmpty(d, r.$1, r.$2),
                    ),
                  ),
              ]),
            ),
      ]),
    );
  }
}

// ─── Cellule (jour × plage) : blocs pleine largeur empilés (+N si trop) ───────
class _CalCell extends StatelessWidget {
  const _CalCell({
    required this.slots,
    required this.conflictIds,
    required this.colorByClass,
    required this.editable,
    required this.isToday,
    required this.onTapSlot,
    required this.onTapEmpty,
  });
  final List<TimetableSlot> slots;
  final Set<String> conflictIds;
  final bool colorByClass, editable, isToday;
  final ValueChanged<TimetableSlot> onTapSlot;
  final VoidCallback onTapEmpty;

  static const _maxBlocks = 4;

  @override
  Widget build(BuildContext context) {
    final base = isToday ? kNavy.withValues(alpha: 0.04) : null;
    if (slots.isEmpty) {
      return InkWell(
        onTap: editable ? onTapEmpty : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.only(left: 6, bottom: 6),
          constraints: const BoxConstraints(minHeight: 46),
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kBorder.withValues(alpha: 0.6)),
          ),
          child: editable
              ? Center(
                  child: Icon(Icons.add_rounded,
                      size: 15, color: kBorder.withValues(alpha: 0.9)))
              : null,
        ),
      );
    }
    final shown = slots.take(_maxBlocks).toList();
    final extra = slots.length - shown.length;
    return Container(
      margin: const EdgeInsets.only(left: 6, bottom: 6),
      padding: base != null ? const EdgeInsets.all(3) : EdgeInsets.zero,
      decoration: base != null
          ? BoxDecoration(color: base, borderRadius: BorderRadius.circular(8))
          : null,
      child: Column(children: [
        for (final s in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: _CalBlock(
              slot: s,
              colorByClass: colorByClass,
              conflict: conflictIds.contains(s.id),
              onTap: () => onTapSlot(s),
            ),
          ),
        if (extra > 0)
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text('+$extra autre${extra > 1 ? 's' : ''}',
                style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: kTextMuted)),
          ),
      ]),
    );
  }
}

// ─── Bloc d'un cours (pleine largeur de la colonne du jour) ──────────────────
class _CalBlock extends StatelessWidget {
  const _CalBlock({
    required this.slot,
    required this.colorByClass,
    required this.conflict,
    required this.onTap,
  });
  final TimetableSlot slot;
  final bool colorByClass, conflict;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _subjectColor(colorByClass ? slot.classId : slot.subjectId);
    final primary = colorByClass
        ? (slot.className ?? 'Classe')
        : (slot.subjectName ?? 'Matière');
    final secondary = colorByClass
        ? (slot.subjectName ?? '')
        : (slot.teacherName ?? '');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(8, 5, 7, 6),
        decoration: BoxDecoration(
          color: conflict
              ? kRed.withValues(alpha: 0.08)
              : color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(7),
          border: conflict
              ? Border.all(color: kRed, width: 1.3)
              : Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (conflict) ...[
              const Icon(Icons.warning_amber_rounded, size: 11, color: kRed),
              const SizedBox(width: 3),
            ],
            Expanded(
              child: Text(primary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: conflict ? kRed : color)),
            ),
            if ((slot.room ?? '').trim().isNotEmpty)
              Text(slot.room!.trim(),
                  style: const TextStyle(fontSize: 9.5, color: kTextMuted)),
          ]),
          if (secondary.trim().isNotEmpty)
            Text(secondary.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: kTextPrimary)),
        ]),
      ),
    );
  }
}
