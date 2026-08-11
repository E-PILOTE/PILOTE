part of 'admin_year_calendar_form.dart';

// ════════════════════════════════════════════════════════════════════════════
//  SAISIE D'UN JOUR NON OUVRÉ — férié ponctuel ou période de vacances.
//
//  Deux différences avec la saisie d'un trimestre : la période porte une
//  NATURE (férié / vacances), et elle peut légitimement en chevaucher une
//  autre — un férié tombant pendant les vacances de Noël n'est pas une erreur
//  de saisie. On ne contrôle donc que les bornes de l'année et l'ordre des
//  dates.
// ════════════════════════════════════════════════════════════════════════════

typedef HolidayEntry = ({
  String label,
  String kind,
  DateTime start,
  DateTime end,
});

/// Vérifie une période non ouvrée. `null` si tout va bien, sinon la phrase à
/// montrer telle quelle. Fonction pure — testable sans widget.
String? validateHolidayEntry({
  required String label,
  required DateTime? start,
  required DateTime? end,
  required DateTime yearStart,
  required DateTime yearEnd,
  required String yearLabel,
}) {
  if (label.trim().isEmpty) return 'Le libellé est requis.';
  if (start == null || end == null) {
    return 'Les dates de début et de fin sont requises.';
  }
  // Bornes incluses : un férié d'un seul jour a début == fin.
  if (end.isBefore(start)) {
    return 'La date de fin ne peut pas précéder la date de début.';
  }
  if (start.isBefore(yearStart) || end.isAfter(yearEnd)) {
    return 'La période doit rester dans l\'année $yearLabel '
        '(${_fmtEntry.format(yearStart)} → ${_fmtEntry.format(yearEnd)}).';
  }
  return null;
}

Future<HolidayEntry?> showHolidayDialog(
  BuildContext context, {
  required String yearLabel,
  required DateTime yearStart,
  required DateTime yearEnd,
  HolidayEntry? existing,
}) {
  return showDialog<HolidayEntry>(
    context: context,
    builder: (_) => _HolidayDialog(
      yearLabel: yearLabel,
      yearStart: yearStart,
      yearEnd: yearEnd,
      existing: existing,
    ),
  );
}

class _HolidayDialog extends StatefulWidget {
  const _HolidayDialog({
    required this.yearLabel,
    required this.yearStart,
    required this.yearEnd,
    this.existing,
  });
  final String yearLabel;
  final DateTime yearStart, yearEnd;
  final HolidayEntry? existing;

  @override
  State<_HolidayDialog> createState() => _HolidayDialogState();
}

class _HolidayDialogState extends State<_HolidayDialog> {
  late final TextEditingController _label =
      TextEditingController(text: widget.existing?.label ?? '');
  late String _kind = widget.existing?.kind ?? 'ferie';
  late DateTime? _start = widget.existing?.start;
  late DateTime? _end = widget.existing?.end;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  void _submit() {
    final err = validateHolidayEntry(
      label: _label.text,
      start: _start,
      end: _end,
      yearStart: widget.yearStart,
      yearEnd: widget.yearEnd,
      yearLabel: widget.yearLabel,
    );
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.pop(context, (
      label: _label.text.trim(),
      kind: _kind,
      start: _start!,
      end: _end!,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final jours =
        (_start != null && _end != null && !_end!.isBefore(_start!))
            ? _end!.difference(_start!).inDays + 1
            : null;

    return AdminFormDialog(
      icon: Icons.beach_access_rounded,
      title: _isEdit ? 'Modifier la période' : 'Nouvelle période non ouvrée',
      subtitle: 'Année ${widget.yearLabel} — héritée par toutes les écoles',
      width: 460,
      submitLabel: _isEdit ? 'Enregistrer' : 'Ajouter',
      submitIcon: Icons.check_rounded,
      onSubmit: _submit,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const AdminFormSectionLabel('NATURE'),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final (v, l) in kHolidayKinds) ...[
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _kind = v),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 11),
                      decoration: BoxDecoration(
                        color: _kind == v
                            ? kNavy.withValues(alpha: .07)
                            : kSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: _kind == v ? kNavy : kBorder,
                            width: _kind == v ? 1.4 : 1),
                      ),
                      child: Row(children: [
                        Icon(
                            v == 'ferie'
                                ? Icons.flag_rounded
                                : Icons.beach_access_rounded,
                            size: 16,
                            color: _kind == v ? kNavy : kTextMuted),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(l,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: _kind == v ? kNavy : kTextMuted)),
                        ),
                      ]),
                    ),
                  ),
                ),
                if (v != kHolidayKinds.last.$1) const SizedBox(width: 10),
              ],
            ],
          ),
          const AdminFormDivider(),
          const AdminFormSectionLabel('IDENTIFICATION'),
          const SizedBox(height: 14),
          TextField(
            controller: _label,
            autofocus: true,
            decoration: adminFilledInput(
                _kind == 'ferie'
                    ? 'Libellé (ex. Toussaint)'
                    : 'Libellé (ex. Vacances de Noël)',
                icon: Icons.label_outline_rounded),
            onSubmitted: (_) => _submit(),
          ),
          const AdminFormDivider(),
          const AdminFormSectionLabel('PÉRIODE'),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: AdminDateField(
                label: 'Début',
                value: _start,
                first: widget.yearStart,
                last: widget.yearEnd,
                onPick: (d) => setState(() {
                  _start = d;
                  // Un férié tient sur un jour : pré-remplir la fin évite une
                  // saisie sur deux qui ne sert à rien neuf fois sur dix.
                  _end ??= d;
                  if (_end != null && _end!.isBefore(d)) _end = d;
                  _error = null;
                }),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AdminDateField(
                label: 'Fin',
                value: _end,
                first: widget.yearStart,
                last: widget.yearEnd,
                onPick: (d) => setState(() {
                  _end = d;
                  _error = null;
                }),
              ),
            ),
          ]),
          if (jours != null) ...[
            const SizedBox(height: 10),
            Text(
                jours == 1
                    ? 'Une seule journée.'
                    : '$jours jours consécutifs, week-ends compris.',
                style: TextStyle(fontSize: 11.5, color: kTextMuted)),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            AdminErrorBanner(message: _error!),
          ],
        ],
      ),
    );
  }
}
