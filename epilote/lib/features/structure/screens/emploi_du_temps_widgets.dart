part of 'emploi_du_temps_screen.dart';

// ─── Sélecteur générique (enseignant / salle) ────────────────────────────────
class _EntityPicker extends StatelessWidget {
  const _EntityPicker({
    required this.icon,
    required this.label,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final IconData icon;
  final String label, hint;
  final String? value;
  final List<(String, String)> items; // (id, libellé)
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(),
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: kTextMuted)),
        const SizedBox(height: 10),
        if (items.isEmpty)
          Text('Aucune donnée — construisez l\'emploi du temps par classe.',
              style: TextStyle(fontSize: 12.5, color: kTextMuted))
        else
          DropdownButtonFormField<String>(
            initialValue: value,
            isExpanded: true,
            decoration: adminFilledInput(hint, icon: icon),
            items: [
              for (final (id, lbl) in items)
                DropdownMenuItem(
                    value: id,
                    child: Text(lbl,
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: onChanged,
          ),
      ]),
    );
  }
}

// ─── Bandeau de conflits (visible si le filtre courant en contient) ──────────
class _ConflictBanner extends StatelessWidget {
  const _ConflictBanner({required this.slots, required this.conflictIds});
  final List<TimetableSlot> slots;
  final Set<String> conflictIds;

  @override
  Widget build(BuildContext context) {
    final hit = slots.where((s) => conflictIds.contains(s.id)).toList();
    if (hit.isEmpty) return const SizedBox.shrink();
    // Conflits restreints à la sélection (dédoublonnés par paire).
    final conflicts = detectConflicts(hit);
    final labels = <String>{for (final c in conflicts) c.label()}.toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: kRed.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kRed.withValues(alpha: 0.30)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: kRed),
          const SizedBox(width: 8),
          Text(
              '${hit.length} créneau${hit.length > 1 ? 'x' : ''} en conflit',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: kRed)),
        ]),
        if (labels.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final l in labels.take(4))
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('•  $l',
                  style: TextStyle(fontSize: 12, color: kTextPrimary)),
            ),
          if (labels.length > 4)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('•  +${labels.length - 4} autre(s)…',
                  style: TextStyle(fontSize: 12, color: kTextMuted)),
            ),
        ],
      ]),
    );
  }
}

// ─── KPIs ─────────────────────────────────────────────────────────────────────
class _Kpis extends StatelessWidget {
  const _Kpis({required this.slots, required this.mode});
  final List<TimetableSlot> slots;
  final TtView mode;
  @override
  Widget build(BuildContext context) {
    final totalMin = slots.fold<int>(0, (s, e) => s + e.durationMinutes);
    final hours = (totalMin / 60);
    final subjects = slots.map((s) => s.subjectId).toSet().length;
    // 4e KPI : enseignants (vue classe/salle) OU classes (vue enseignant).
    final fourth = mode == TtView.enseignant
        ? (Icons.groups_2_rounded, 'Classes',
            '${slots.map((s) => s.classId).toSet().length}',
            const Color(0xFF8B5CF6))
        : (Icons.person_outline_rounded, 'Enseignants',
            '${slots.map((s) => s.staffId).toSet().length}',
            const Color(0xFF8B5CF6));
    // Surcharge enseignant : au-delà du seuil hebdo conseillé → alerte.
    final overload = mode == TtView.enseignant && hours > kTeacherMaxWeeklyHours;
    final items = <(IconData, String, String, Color, String?)>[
      (Icons.event_available_rounded, 'Créneaux', '${slots.length}', kNavy,
          'cette semaine'),
      (
        overload ? Icons.warning_amber_rounded : Icons.schedule_rounded,
        'Heures / semaine',
        hours == hours.roundToDouble()
            ? '${hours.toInt()}h'
            : '${hours.toStringAsFixed(1)}h',
        overload ? kRed : const Color(0xFF0EA5E9),
        mode == TtView.enseignant
            ? (overload
                ? 'Surcharge (> $kTeacherMaxWeeklyHours h)'
                : 'max $kTeacherMaxWeeklyHours h')
            : null
      ),
      (Icons.menu_book_rounded, 'Matières', '$subjects', kGreen, null),
      (fourth.$1, fourth.$2, fourth.$3, fourth.$4, null),
    ];
    return LayoutBuilder(builder: (ctx, cns) {
      final w = cns.maxWidth;
      final cols = w >= 920 ? 4 : (w >= 620 ? 2 : 1);
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 176,
        ),
        itemCount: items.length,
        itemBuilder: (ctx, i) {
          final (icon, label, value, color, sub) = items[i];
          return AdminStatCard(
              label: label, value: value, icon: icon, color: color, subtitle: sub);
        },
      );
    });
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Petits widgets du FORMULAIRE de créneau (part partagée pour rester ≤500).
// ════════════════════════════════════════════════════════════════════════════

// ─── Sélecteur multi-jours (création) ────────────────────────────────────────
class _DayChips extends StatelessWidget {
  const _DayChips(
      {required this.selected, required this.blocked, required this.onToggle});
  final Set<int> selected;
  final Set<int> blocked; // jour sélectionné mais en conflit dur
  final ValueChanged<int> onToggle;
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        for (var d = 1; d <= 6; d++)
          () {
            final on = selected.contains(d);
            final ko = on && blocked.contains(d);
            final bg = ko ? kRed : (on ? kNavy : kSurface);
            final fg = (on || ko) ? Colors.white : kTextPrimary;
            return InkWell(
              onTap: () => onToggle(d),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ko ? kRed : (on ? kNavy : kBorder)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (ko) ...[
                    const Icon(Icons.warning_amber_rounded,
                        size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                  ],
                  Text(frDaysShort[d],
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: fg)),
                ]),
              ),
            );
          }(),
      ],
    );
  }
}

// ─── Bandeau conflit dans le formulaire ──────────────────────────────────────
class _FormConflict extends StatelessWidget {
  const _FormConflict(
      {required this.hard, required this.roomC, required this.allBlocked});
  final List<SlotConflict> hard, roomC;
  final bool allBlocked;
  @override
  Widget build(BuildContext context) {
    final isHard = hard.isNotEmpty;
    final color = isHard ? kRed : const Color(0xFFF59E0B);
    final lines = <String>{
      for (final c in hard) c.label(),
      for (final c in roomC) c.label(),
    }.toList();
    final title = !isHard
        ? 'Salle déjà occupée — vérifiez'
        : allBlocked
            ? 'Conflit bloquant — corrigez avant d\'enregistrer'
            : 'Certains jours sont en conflit — ils seront ignorés';
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Text(title,
                style: TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w800, color: color)),
          ),
        ]),
        for (final l in lines.take(3))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('•  $l',
                style: TextStyle(fontSize: 11.5, color: kTextPrimary)),
          ),
      ]),
    );
  }
}

// ─── Puces « séance standard » (trame d'horaires) ────────────────────────────
class _PeriodChips extends StatelessWidget {
  const _PeriodChips(
      {required this.start, required this.end, required this.onPick});
  final String start, end;
  final void Function(String start, String end) onPick;
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        for (final (s, e) in kStdPeriods)
          () {
            final active = s == start && e == end;
            return InkWell(
              onTap: () => onPick(s, e),
              borderRadius: BorderRadius.circular(7),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: active ? kNavy : kSurface,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: active ? kNavy : kBorder),
                ),
                child: Text('$s–$e',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: active ? Colors.white : kTextPrimary)),
              ),
            );
          }(),
      ],
    );
  }
}

// ─── Avertissement de capacité (salle plus petite que l'effectif) ────────────
class _CapacityNote extends StatelessWidget {
  const _CapacityNote({required this.effectif, required this.capacity});
  final int effectif, capacity;
  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFF59E0B);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      decoration: BoxDecoration(
        color: amber.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: amber.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        const Icon(Icons.reduce_capacity_rounded, size: 16, color: amber),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
              'Salle trop petite : effectif $effectif > $capacity place(s). '
              'Vérifiez le choix de salle.',
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: amber)),
        ),
      ]),
    );
  }
}

// ─── Avertissement de disponibilité enseignant ───────────────────────────────
class _AvailNote extends StatelessWidget {
  const _AvailNote({required this.hard, required this.soft});
  final bool hard, soft;
  @override
  Widget build(BuildContext context) {
    final color = hard ? kRed : const Color(0xFFF59E0B);
    final text = hard
        ? 'Enseignant indisponible sur ce créneau — le(s) jour(s) concerné(s) '
            'seront ignorés.'
        : 'Créneau à éviter pour cet enseignant (préférence déclarée).';
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        Icon(hard ? Icons.event_busy_rounded : Icons.schedule_rounded,
            size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ),
      ]),
    );
  }
}

// ─── Note d'information (programme vide) ─────────────────────────────────────
class _InfoNote extends StatelessWidget {
  const _InfoNote(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorder),
        ),
        child: Row(children: [
          Icon(Icons.info_outline_rounded, size: 16, color: kTextMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 12, color: kTextMuted)),
          ),
        ]),
      );
}

class _Lbl extends StatelessWidget {
  const _Lbl(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Text(text,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: kTextPrimary)),
      );
}

class _TimeField extends StatelessWidget {
  const _TimeField(this.label, this.value, this.onTap);
  final String label, value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Lbl(label),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kBorder),
              ),
              child: Row(children: [
                Icon(Icons.schedule_rounded, size: 16, color: kTextMuted),
                const SizedBox(width: 8),
                Text(value,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: kTextPrimary)),
              ]),
            ),
          ),
        ],
      );
}
