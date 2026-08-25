import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/jours_non_ouvres.dart';
import '../../../core/widgets/admin_ui.dart';

part 'admin_year_holiday_form.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  SAISIE D'UNE PÉRIODE — trimestre ou séquence, création ou correction.
//
//  Un formulaire unique, parce que les règles sont les mêmes : un libellé, un
//  numéro libre, et une période qui tient dans son parent sans empiéter sur ses
//  voisines.
//
//  La validation est ici EN PLUS de celle en base, pas à sa place. La base
//  reste l'autorité — elle protège aussi des écritures qui ne passent pas par
//  cet écran. Mais faire un aller-retour réseau pour apprendre qu'on a inversé
//  deux dates, sur une liaison congolaise, ce n'est pas une validation : c'est
//  une punition.
// ══════════════════════════════════════════════════════════════════════════════

typedef CalendarEntry = ({
  String label,
  int number,
  DateTime start,
  DateTime end,
});

/// Une période déjà occupée par une voisine — pour refuser les chevauchements.
typedef OccupiedSpan = ({DateTime start, DateTime end, String label});

final _fmtEntry = DateFormat('d MMM yyyy', 'fr_FR');

/// Vérifie une période saisie. Renvoie `null` si tout va bien, sinon la phrase
/// à montrer telle quelle.
///
/// Fonction pure et publique : les mêmes règles s'appliquent au trimestre
/// (parent = l'année) et à la séquence (parent = le trimestre), et elles sont
/// testables sans monter un widget.
String? validateCalendarEntry({
  required String label,
  required DateTime? start,
  required DateTime? end,
  required DateTime parentStart,
  required DateTime parentEnd,
  required String parentLabel,
  List<OccupiedSpan> occupied = const [],
}) {
  if (label.trim().isEmpty) return 'Le libellé est requis.';
  if (start == null || end == null) {
    return 'Les dates de début et de fin sont requises.';
  }
  if (!end.isAfter(start)) {
    return 'La date de fin doit suivre la date de début.';
  }
  if (start.isBefore(parentStart) || end.isAfter(parentEnd)) {
    return 'La période doit rester dans $parentLabel '
        '(${_fmtEntry.format(parentStart)} → ${_fmtEntry.format(parentEnd)}).';
  }
  for (final o in occupied) {
    // Bornes incluses : deux périodes qui partagent un jour se chevauchent.
    if (!o.start.isAfter(end) && !start.isAfter(o.end)) {
      return 'Cette période chevauche « ${o.label} » '
          '(${_fmtEntry.format(o.start)} → ${_fmtEntry.format(o.end)}).';
    }
  }
  return null;
}

Future<CalendarEntry?> showCalendarEntryDialog(
  BuildContext context, {
  required String title,
  required String subtitle,
  required String parentLabel,
  required DateTime parentStart,
  required DateTime parentEnd,
  required List<int> availableNumbers,
  List<OccupiedSpan> occupied = const [],
  CalendarEntry? existing,
}) {
  return showDialog<CalendarEntry>(
    context: context,
    builder: (_) => _CalendarEntryDialog(
      title: title,
      subtitle: subtitle,
      parentLabel: parentLabel,
      parentStart: parentStart,
      parentEnd: parentEnd,
      availableNumbers: availableNumbers,
      occupied: occupied,
      existing: existing,
    ),
  );
}

class _CalendarEntryDialog extends StatefulWidget {
  const _CalendarEntryDialog({
    required this.title,
    required this.subtitle,
    required this.parentLabel,
    required this.parentStart,
    required this.parentEnd,
    required this.availableNumbers,
    required this.occupied,
    this.existing,
  });

  final String title, subtitle, parentLabel;
  final DateTime parentStart, parentEnd;
  final List<int> availableNumbers;
  final List<OccupiedSpan> occupied;
  final CalendarEntry? existing;

  @override
  State<_CalendarEntryDialog> createState() => _CalendarEntryDialogState();
}

class _CalendarEntryDialogState extends State<_CalendarEntryDialog> {
  static final _fmt = DateFormat('d MMM yyyy', 'fr_FR');

  late final TextEditingController _label =
      TextEditingController(text: widget.existing?.label ?? '');
  late int _number = widget.existing?.number ??
      (widget.availableNumbers.isEmpty ? 1 : widget.availableNumbers.first);
  late DateTime? _start = widget.existing?.start;
  late DateTime? _end = widget.existing?.end;
  String? _error;

  bool get _isEdit => widget.existing != null;

  /// Numéros proposés : les libres, plus celui de la période qu'on corrige.
  List<int> get _numbers {
    final s = {...widget.availableNumbers};
    if (widget.existing != null) s.add(widget.existing!.number);
    return s.toList()..sort();
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  String? _valider() => validateCalendarEntry(
        label: _label.text,
        start: _start,
        end: _end,
        parentStart: widget.parentStart,
        parentEnd: widget.parentEnd,
        parentLabel: widget.parentLabel,
        occupied: widget.occupied,
      );

  void _submit() {
    final err = _valider();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.pop(context, (
      label: _label.text.trim(),
      number: _number,
      start: _start!,
      end: _end!,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_numbers.isEmpty) {
      return AdminFormDialog(
        icon: Icons.event_busy_rounded,
        title: widget.title,
        width: 440,
        body: const AdminErrorBanner(
          message: 'Tous les numéros disponibles sont déjà utilisés. '
              'Supprimez ou renumérotez une période existante pour en '
              'ajouter une nouvelle.',
        ),
      );
    }

    return AdminFormDialog(
      icon: _isEdit ? Icons.edit_calendar_rounded : Icons.event_note_rounded,
      title: widget.title,
      subtitle: widget.subtitle,
      width: 460,
      submitLabel: _isEdit ? 'Enregistrer' : 'Créer',
      submitIcon: Icons.check_rounded,
      onSubmit: _submit,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const AdminFormSectionLabel('IDENTIFICATION'),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _label,
                autofocus: true,
                decoration: adminFilledInput('Libellé',
                    icon: Icons.label_outline_rounded),
                onSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: _numbers.contains(_number) ? _number : _numbers.first,
                decoration: adminFilledInput('N°'),
                items: _numbers
                    .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                    .toList(),
                onChanged: (v) => setState(() => _number = v ?? _number),
              ),
            ),
          ]),
          const AdminFormDivider(),
          const AdminFormSectionLabel('PÉRIODE'),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: AdminDateField(
                label: 'Début',
                value: _start,
                first: widget.parentStart,
                last: widget.parentEnd,
                onPick: (d) => setState(() {
                  _start = d;
                  _error = null;
                }),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AdminDateField(
                label: 'Fin',
                value: _end,
                first: widget.parentStart,
                last: widget.parentEnd,
                onPick: (d) => setState(() {
                  _end = d;
                  _error = null;
                }),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: kNavy.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, size: 16, color: kNavy),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Doit tenir dans ${widget.parentLabel} : '
                  '${_fmt.format(widget.parentStart)} → '
                  '${_fmt.format(widget.parentEnd)}'
                  '${widget.occupied.isEmpty ? '' : ', sans chevaucher les ${widget.occupied.length} période(s) déjà définie(s)'}.',
                  style:
                      TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.4),
                ),
              ),
            ]),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            AdminErrorBanner(message: _error!),
          ],
        ],
      ),
    );
  }
}
