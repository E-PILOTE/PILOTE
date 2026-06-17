import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/admin_academic_year_provider.dart';

final _fmt = DateFormat('d MMM yyyy', 'fr_FR');

/// Édition du calendrier d'une année (trimestres → séquences), niveau GROUPE.
class AdminYearCalendarDialog extends ConsumerWidget {
  const AdminYearCalendarDialog({
    super.key,
    required this.yearId,
    required this.yearLabel,
  });
  final String yearId;
  final String yearLabel;

  Future<void> _run(BuildContext context, WidgetRef ref,
      Future<void> Function() op, String ok) async {
    try {
      await op();
      ref.invalidate(adminYearCalendarProvider(yearId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: kGreen, content: Text(ok)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: kRed, content: Text('Erreur : $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminYearCalendarProvider(yearId));
    final svc = ref.read(adminCalendarServiceProvider);

    return AdminFormDialog(
      icon: Icons.event_note_rounded,
      title: 'Calendrier · $yearLabel',
      subtitle: 'Trimestres & séquences (hérités par toutes les écoles)',
      width: 620,
      maxHeight: 660,
      scrollable: false,
      bodyPadding: EdgeInsets.zero,
      footer: Row(children: [
        const Spacer(),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer', style: TextStyle(color: kTextMuted)),
        ),
      ]),
      body: async.when(
        loading: () => const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator(color: kNavy))),
        error: (e, _) => Padding(
            padding: const EdgeInsets.all(20),
            child: AdminErrorBanner(message: '$e')),
        data: (trims) => ListView(
          padding: const EdgeInsets.all(18),
          children: [
                  _CalendarSummary(trims: trims),
                  const SizedBox(height: 14),
                  if (trims.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      decoration: BoxDecoration(
                        color: kSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kBorder),
                      ),
                      child: const Column(children: [
                        Icon(Icons.event_busy_rounded,
                            size: 38, color: kTextMuted),
                        SizedBox(height: 10),
                        Text('Aucun trimestre défini',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: kTextPrimary)),
                        SizedBox(height: 4),
                        Text(
                          "Ajoutez un trimestre pour structurer l'année\n"
                          '(les écoles l\'hériteront par synchro).',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: kTextMuted),
                        ),
                      ]),
                    )
                  else
                    ...trims.map((t) => _TrimCard(
                          trim: t,
                          onSetCurrent: () => _run(context, ref,
                              () => svc.setCurrentTrimester(t.id, yearId),
                              'Trimestre courant mis à jour'),
                          onAddSequence: () async {
                            final r = await _askEntry(context,
                                title: 'Nouvelle séquence · ${t.label}',
                                numbers: const [1, 2]);
                            if (r != null && context.mounted) {
                              await _run(
                                  context,
                                  ref,
                                  () => svc.createSequence(
                                      trimesterId: t.id,
                                      label: r.label,
                                      number: r.number,
                                      start: r.start,
                                      end: r.end),
                                  'Séquence créée');
                            }
                          },
                          onSetCurrentSeq: (sid) => _run(context, ref,
                              () => svc.setCurrentSequence(sid, t.id),
                              'Séquence courante mise à jour'),
                        )),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final r = await _askEntry(context,
                          title: 'Nouveau trimestre', numbers: const [1, 2, 3]);
                      if (r != null && context.mounted) {
                        await _run(
                            context,
                            ref,
                            () => svc.createTrimester(
                                yearId: yearId,
                                label: r.label,
                                number: r.number,
                                start: r.start,
                                end: r.end),
                            'Trimestre créé');
                      }
                    },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Ajouter un trimestre'),
            style: OutlinedButton.styleFrom(
              foregroundColor: kNavy,
              side: const BorderSide(color: kBorder),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    ),
    );
  }
}

// ─── Bandeau résumé du calendrier ──────────────────────────────────────────────
class _CalendarSummary extends StatelessWidget {
  const _CalendarSummary({required this.trims});
  final List<AdminTrimester> trims;

  @override
  Widget build(BuildContext context) {
    final nbSeq = trims.fold<int>(0, (a, t) => a + t.sequences.length);
    AdminTrimester? cur;
    for (final t in trims) {
      if (t.isCurrent) {
        cur = t;
        break;
      }
    }
    Widget stat(IconData ic, String value, String label, Color c) => Expanded(
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9)),
              child: Icon(ic, size: 17, color: c),
            ),
            const SizedBox(width: 9),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary)),
              Text(label,
                  style: const TextStyle(fontSize: 10.5, color: kTextMuted)),
            ]),
          ]),
        );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Row(children: [
        stat(Icons.calendar_view_month_rounded, '${trims.length}', 'trimestres',
            kNavy),
        stat(Icons.layers_rounded, '$nbSeq', 'séquences', kGreen),
        stat(
            Icons.play_circle_rounded,
            cur == null ? '—' : 'T${cur.number}',
            cur == null ? 'aucun courant' : 'en cours',
            cur == null ? kTextMuted : kAccent),
      ]),
    );
  }
}

class _TrimCard extends StatelessWidget {
  const _TrimCard({
    required this.trim,
    required this.onSetCurrent,
    required this.onAddSequence,
    required this.onSetCurrentSeq,
  });
  final AdminTrimester trim;
  final VoidCallback onSetCurrent;
  final VoidCallback onAddSequence;
  final ValueChanged<String> onSetCurrentSeq;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: kNavy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8)),
              child: Text('T${trim.number}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800, color: kNavy)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(trim.label,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700, color: kTextPrimary)),
                  const SizedBox(width: 8),
                  if (trim.isCurrent) const AdminBadge('Courant', color: kGreen),
                ]),
                const SizedBox(height: 2),
                Text('${_fmt.format(trim.startDate)} → ${_fmt.format(trim.endDate)}',
                    style: const TextStyle(fontSize: 11, color: kTextMuted)),
              ]),
            ),
            if (!trim.isCurrent)
              TextButton(
                  onPressed: onSetCurrent,
                  child: const Text('Définir courant',
                      style: TextStyle(fontSize: 12))),
            IconButton(
              tooltip: 'Ajouter une séquence',
              icon: const Icon(Icons.add_rounded, size: 18, color: kNavy),
              onPressed: onAddSequence,
            ),
          ]),
        ),
        if (trim.sequences.isNotEmpty) ...[
          const Divider(height: 1, color: kBorder),
          ...trim.sequences.map((s) => Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 14, 8),
                child: Row(children: [
                  const Icon(Icons.fiber_manual_record, size: 8, color: kTextMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Séq. ${s.number} · ${s.label}',
                        style: const TextStyle(fontSize: 12.5, color: kTextPrimary)),
                  ),
                  Text('${_fmt.format(s.startDate)} → ${_fmt.format(s.endDate)}',
                      style: const TextStyle(fontSize: 10.5, color: kTextMuted)),
                  if (s.isCurrent) ...[
                    const SizedBox(width: 8),
                    const AdminBadge('Courante', color: kGreen),
                  ] else
                    TextButton(
                      onPressed: () => onSetCurrentSeq(s.id),
                      child: const Text('Courante', style: TextStyle(fontSize: 11)),
                    ),
                ]),
              )),
          const SizedBox(height: 6),
        ],
      ]),
    );
  }
}

// ─── Petit formulaire (libellé + n° + dates) ───────────────────────────────────
typedef _Entry = ({String label, int number, DateTime start, DateTime end});

Future<_Entry?> _askEntry(BuildContext context,
    {required String title, required List<int> numbers}) {
  return showDialog<_Entry>(
    context: context,
    builder: (_) => _CalEntryDialog(title: title, numbers: numbers),
  );
}

class _CalEntryDialog extends StatefulWidget {
  const _CalEntryDialog({required this.title, required this.numbers});
  final String title;
  final List<int> numbers;
  @override
  State<_CalEntryDialog> createState() => _CalEntryDialogState();
}

class _CalEntryDialogState extends State<_CalEntryDialog> {
  final _label = TextEditingController();
  late int _number = widget.numbers.first;
  DateTime? _start, _end;
  String? _error;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  void _submit() {
    if (_label.text.trim().isEmpty || _start == null || _end == null) {
      setState(() => _error = 'Libellé et dates requis');
      return;
    }
    if (!_end!.isAfter(_start!)) {
      setState(() => _error = 'La date de fin doit suivre le début');
      return;
    }
    Navigator.pop(context,
        (label: _label.text.trim(), number: _number, start: _start!, end: _end!));
  }

  @override
  Widget build(BuildContext context) {
    return AdminFormDialog(
      icon: Icons.event_note_rounded,
      title: widget.title,
      width: 440,
      submitLabel: 'Créer',
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
                  decoration: adminFilledInput('Libellé',
                      icon: Icons.label_outline_rounded)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: _number,
                decoration: adminFilledInput('N°'),
                items: widget.numbers
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
                child: _DateField(
                    label: 'Début',
                    value: _start,
                    onPick: (d) => setState(() => _start = d))),
            const SizedBox(width: 12),
            Expanded(
                child: _DateField(
                    label: 'Fin',
                    value: _end,
                    onPick: (d) => setState(() => _end = d))),
          ]),
          if (_error != null) ...[
            const SizedBox(height: 14),
            AdminErrorBanner(message: _error!),
          ],
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.value, required this.onPick});
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPick;
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: kNavy)),
      const SizedBox(height: 6),
      InkWell(
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: value ?? now,
            firstDate: DateTime(now.year - 2),
            lastDate: DateTime(now.year + 4),
          );
          if (picked != null) onPick(picked);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kBorder),
          ),
          child: Row(children: [
            const Icon(Icons.calendar_today_rounded, size: 15, color: kTextMuted),
            const SizedBox(width: 8),
            Text(value != null ? _fmt.format(value!) : 'Choisir…',
                style: TextStyle(
                    fontSize: 13, color: value != null ? kNavy : kTextMuted)),
          ]),
        ),
      ),
    ]);
  }
}
