import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/jours_non_ouvres.dart';
import '../../../core/utils/message_erreur.dart';
import '../../../core/widgets/admin_ui.dart';
import '../providers/admin_academic_year_provider.dart';
import '../providers/admin_calendar_service.dart';
import 'admin_year_calendar_form.dart';

part 'admin_year_calendar_cards.dart';
part 'admin_year_holidays_section.dart';

final _fmt = DateFormat('d MMM yyyy', 'fr_FR');

/// Numéros autorisés par la base : `trimester_number` ∈ 1..3,
/// `sequence_number` ∈ 1..6. L'écran ne proposait que 1 et 2 en séquence — la
/// moitié du domaine était inatteignable depuis l'interface.
const _kTrimesterNumbers = [1, 2, 3];
const _kSequenceNumbers = [1, 2, 3, 4, 5, 6];

/// Édition du calendrier d'une année (trimestres → séquences), niveau GROUPE.
///
/// [year] porte les bornes ET l'état de verrou : une année archivée s'ouvre en
/// lecture seule. La version précédente n'inspectait jamais `isLocked` — on
/// pouvait créer un trimestre dans une année pourtant « archivée ».
class AdminYearCalendarDialog extends ConsumerWidget {
  const AdminYearCalendarDialog({super.key, required this.year});

  final AdminYear year;

  bool get _readOnly => year.isLocked;

  Future<void> _run(BuildContext context, WidgetRef ref,
      Future<void> Function() op, String ok) async {
    try {
      await op();
      ref.invalidate(adminYearCalendarProvider(year.id));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: kGreen, content: Text(ok)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: kRed, content: Text(messageErreur(e))));
      }
    }
  }

  // ── Trimestres ────────────────────────────────────────────────────────────

  Future<void> _ajouterTrimestre(
      BuildContext context, WidgetRef ref, List<AdminTrimester> trims) async {
    final pris = {for (final t in trims) t.number};
    final r = await showCalendarEntryDialog(
      context,
      title: 'Nouveau trimestre',
      subtitle: 'Année ${year.label}',
      parentLabel: "l'année ${year.label}",
      parentStart: year.startDate,
      parentEnd: year.endDate,
      availableNumbers:
          _kTrimesterNumbers.where((n) => !pris.contains(n)).toList(),
      occupied: [
        for (final t in trims)
          (start: t.startDate, end: t.endDate, label: t.label)
      ],
    );
    if (r == null || !context.mounted) return;
    await _run(
        context,
        ref,
        () => ref.read(adminCalendarServiceProvider).createTrimester(
            yearId: year.id,
            label: r.label,
            number: r.number,
            start: r.start,
            end: r.end),
        'Trimestre créé');
  }

  Future<void> _modifierTrimestre(BuildContext context, WidgetRef ref,
      AdminTrimester t, List<AdminTrimester> trims) async {
    final pris = {for (final o in trims) if (o.id != t.id) o.number};
    final r = await showCalendarEntryDialog(
      context,
      title: 'Modifier le trimestre',
      subtitle: '${t.label} · année ${year.label}',
      parentLabel: "l'année ${year.label}",
      parentStart: year.startDate,
      parentEnd: year.endDate,
      availableNumbers:
          _kTrimesterNumbers.where((n) => !pris.contains(n)).toList(),
      occupied: [
        for (final o in trims)
          if (o.id != t.id)
            (start: o.startDate, end: o.endDate, label: o.label)
      ],
      existing: (
        label: t.label,
        number: t.number,
        start: t.startDate,
        end: t.endDate
      ),
    );
    if (r == null || !context.mounted) return;
    await _run(
        context,
        ref,
        () => ref.read(adminCalendarServiceProvider).updateTrimester(
            id: t.id,
            label: r.label,
            number: r.number,
            start: r.start,
            end: r.end),
        'Trimestre modifié');
  }

  Future<void> _supprimerTrimestre(
      BuildContext context, WidgetRef ref, AdminTrimester t) async {
    final n = t.sequences.length;
    final ok = await showAdminConfirm(
      context,
      danger: true,
      title: 'Supprimer ${t.label}',
      confirmLabel: 'Supprimer',
      message: n == 0
          ? 'Le trimestre « ${t.label} » sera supprimé de l\'année '
              '${year.label}.\n\nLes écoles le verront disparaître à leur '
              'prochaine synchronisation.'
          : 'Le trimestre « ${t.label} » et ses $n séquence'
              '${n > 1 ? 's' : ''} seront supprimés de l\'année '
              '${year.label}.\n\nLes notes et bulletins déjà rattachés à ces '
              'périodes perdraient leur référence : ne le faites que sur un '
              'calendrier non encore utilisé.',
    );
    if (!ok || !context.mounted) return;
    await _run(
        context,
        ref,
        () => ref.read(adminCalendarServiceProvider).deleteTrimester(t.id),
        'Trimestre supprimé');
  }

  // ── Séquences ─────────────────────────────────────────────────────────────

  Future<void> _ajouterSequence(
      BuildContext context, WidgetRef ref, AdminTrimester t) async {
    final pris = t.takenSequenceNumbers;
    final r = await showCalendarEntryDialog(
      context,
      title: 'Nouvelle séquence',
      subtitle: '${t.label} · année ${year.label}',
      parentLabel: 'le trimestre « ${t.label} »',
      parentStart: t.startDate,
      parentEnd: t.endDate,
      availableNumbers:
          _kSequenceNumbers.where((n) => !pris.contains(n)).toList(),
      occupied: [
        for (final s in t.sequences)
          (start: s.startDate, end: s.endDate, label: s.label)
      ],
    );
    if (r == null || !context.mounted) return;
    await _run(
        context,
        ref,
        () => ref.read(adminCalendarServiceProvider).createSequence(
            trimesterId: t.id,
            label: r.label,
            number: r.number,
            start: r.start,
            end: r.end),
        'Séquence créée');
  }

  Future<void> _modifierSequence(BuildContext context, WidgetRef ref,
      AdminTrimester t, AdminSequence s) async {
    final pris = {for (final o in t.sequences) if (o.id != s.id) o.number};
    final r = await showCalendarEntryDialog(
      context,
      title: 'Modifier la séquence',
      subtitle: 'Séq. ${s.number} · ${t.label}',
      parentLabel: 'le trimestre « ${t.label} »',
      parentStart: t.startDate,
      parentEnd: t.endDate,
      availableNumbers:
          _kSequenceNumbers.where((n) => !pris.contains(n)).toList(),
      occupied: [
        for (final o in t.sequences)
          if (o.id != s.id)
            (start: o.startDate, end: o.endDate, label: o.label)
      ],
      existing: (
        label: s.label,
        number: s.number,
        start: s.startDate,
        end: s.endDate
      ),
    );
    if (r == null || !context.mounted) return;
    await _run(
        context,
        ref,
        () => ref.read(adminCalendarServiceProvider).updateSequence(
            id: s.id,
            label: r.label,
            number: r.number,
            start: r.start,
            end: r.end),
        'Séquence modifiée');
  }

  Future<void> _supprimerSequence(
      BuildContext context, WidgetRef ref, AdminSequence s) async {
    final ok = await showAdminConfirm(
      context,
      danger: true,
      title: 'Supprimer la séquence ${s.number}',
      confirmLabel: 'Supprimer',
      message: 'La séquence « ${s.label} » sera supprimée.\n\n'
          'Les notes déjà saisies sur cette séquence perdraient leur '
          'référence.',
    );
    if (!ok || !context.mounted) return;
    await _run(
        context,
        ref,
        () => ref.read(adminCalendarServiceProvider).deleteSequence(s.id),
        'Séquence supprimée');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminYearCalendarProvider(year.id));
    final svc = ref.read(adminCalendarServiceProvider);

    return AdminFormDialog(
      icon: Icons.event_note_rounded,
      title: 'Calendrier · ${year.label}',
      subtitle: _readOnly
          ? 'Année archivée — consultation seule'
          : 'Trimestres & séquences (hérités par toutes les écoles)',
      accent: _readOnly ? kTextMuted : null,
      width: 660,
      maxHeight: 680,
      scrollable: false,
      bodyPadding: EdgeInsets.zero,
      footer: Row(children: [
        const Spacer(),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Fermer', style: TextStyle(color: kTextMuted)),
        ),
      ]),
      body: async.when(
        loading: () => const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Padding(
            padding: const EdgeInsets.all(20),
            child: AdminErrorBanner(message: messageErreur(e))),
        data: (trims) => ListView(
          padding: const EdgeInsets.all(18),
          children: [
            if (_readOnly) ...[
              const _LockedBanner(),
              const SizedBox(height: 14),
            ],
            _CalendarSummary(trims: trims, year: year),
            const SizedBox(height: 14),
            if (trims.isEmpty)
              _CalendarEmpty(readOnly: _readOnly)
            else
              ...trims.map((t) => _TrimCard(
                    trim: t,
                    readOnly: _readOnly,
                    onSetCurrent: () => _run(context, ref,
                        () => svc.setCurrentTrimester(t.id),
                        'Trimestre courant mis à jour'),
                    onEdit: () => _modifierTrimestre(context, ref, t, trims),
                    onDelete: () => _supprimerTrimestre(context, ref, t),
                    onAddSequence: () => _ajouterSequence(context, ref, t),
                    onEditSequence: (s) =>
                        _modifierSequence(context, ref, t, s),
                    onDeleteSequence: (s) =>
                        _supprimerSequence(context, ref, s),
                    onSetCurrentSeq: (sid) => _run(context, ref,
                        () => svc.setCurrentSequence(sid),
                        'Séquence courante mise à jour'),
                  )),
            if (!_readOnly) ...[
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: trims.length >= _kTrimesterNumbers.length
                    ? null
                    : () => _ajouterTrimestre(context, ref, trims),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(trims.length >= _kTrimesterNumbers.length
                    ? 'Les 3 trimestres sont définis'
                    : 'Ajouter un trimestre'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kNavy,
                  side: BorderSide(color: kBorder),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
            const SizedBox(height: 22),
            Divider(height: 1, color: kBorder),
            const SizedBox(height: 18),
            _HolidaysSection(year: year, readOnly: _readOnly),
          ],
        ),
      ),
    );
  }
}
