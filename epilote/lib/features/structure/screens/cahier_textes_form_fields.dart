part of 'cahier_textes_screen.dart';

// ─── Champs du formulaire de séance ────────────────────────────────────────

class _DropField extends StatelessWidget {
  const _DropField(this.label, this.icon, this.value, this.items, this.onChanged);
  final String label;
  final IconData icon;
  final String? value;
  final Map<String, String> items;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Lbl(label),
          DropdownButtonFormField<String>(
            initialValue: items.containsKey(value) ? value : null,
            isExpanded: true,
            style: TextStyle(fontSize: 13, color: kTextPrimary),
            icon: Icon(Icons.expand_more_rounded,
                size: 18, color: kTextMuted),
            decoration: adminFilledInput(label, icon: icon),
            items: [
              for (final e in items.entries)
                DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value,
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: onChanged,
          ),
        ],
      );
}

class _Multi extends StatelessWidget {
  const _Multi(this.label, this.controller, this.hint);
  final String label, hint;
  final TextEditingController controller;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Lbl(label),
          TextField(
            controller: controller,
            minLines: 2,
            maxLines: 5,
            style: const TextStyle(fontSize: 13.5),
            decoration: adminFilledInput(hint),
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

const _weekdayNames = [
  'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'
];

/// Séances de l'emploi du temps pour la classe + le jour choisis : un clic
/// pré-remplit matière + enseignant (cohérence EDT ↔ Cahier de textes).
class _SeancePicker extends StatelessWidget {
  const _SeancePicker({
    required this.weekday,
    required this.slots,
    required this.pickedId,
    required this.onPick,
  });
  final int weekday; // 1=lun … 7=dim
  final List<TimetableSlot> slots;
  final String? pickedId;
  final ValueChanged<TimetableSlot> onPick;

  @override
  Widget build(BuildContext context) {
    final dayName = _weekdayNames[(weekday - 1).clamp(0, 6)];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.calendar_view_week_rounded, size: 14, color: kNavy),
        const SizedBox(width: 6),
        Text('Séance de l\'emploi du temps · $dayName',
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w700, color: kTextPrimary)),
      ]),
      const SizedBox(height: 8),
      if (slots.isEmpty)
        Text('Aucune séance programmée ce jour pour cette classe.',
            style: TextStyle(fontSize: 11.5, color: kTextMuted))
      else
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in slots)
              _SeanceChip(
                slot: s,
                selected: s.id == pickedId,
                onTap: () => onPick(s),
              ),
          ],
        ),
    ]);
  }
}

class _SeanceChip extends StatelessWidget {
  const _SeanceChip(
      {required this.slot, required this.selected, required this.onTap});
  final TimetableSlot slot;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? kNavy : kSurface,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: selected ? kNavy : kBorder),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.schedule_rounded,
                  size: 12, color: selected ? Colors.white70 : kTextMuted),
              const SizedBox(width: 4),
              Text(slot.timeLabel,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : kTextMuted)),
            ]),
            const SizedBox(height: 2),
            Text(slot.subjectName ?? 'Matière',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : kTextPrimary)),
            if ((slot.teacherName ?? '').isNotEmpty)
              Text(slot.teacherName!,
                  style: TextStyle(
                      fontSize: 10.5,
                      color: selected ? Colors.white70 : kTextMuted)),
          ]),
        ),
      ),
    );
  }
}
