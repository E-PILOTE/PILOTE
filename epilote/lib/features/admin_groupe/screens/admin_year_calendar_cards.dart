part of 'admin_year_calendar_dialog.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CALENDRIER — bandeau de verrou, résumé, carte de trimestre.
// ════════════════════════════════════════════════════════════════════════════

class _LockedBanner extends StatelessWidget {
  const _LockedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: kAccent.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kAccent.withValues(alpha: .3)),
      ),
      child: Row(children: [
        Icon(Icons.lock_outline_rounded, size: 18, color: kAccent),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Année archivée : le calendrier est figé. Pour le corriger, '
            'déverrouillez d\'abord l\'année depuis la liste.',
            style: TextStyle(fontSize: 12, color: kTextPrimary, height: 1.4),
          ),
        ),
      ]),
    );
  }
}

// ─── Bandeau résumé du calendrier ──────────────────────────────────────────────
class _CalendarSummary extends StatelessWidget {
  const _CalendarSummary({required this.trims, required this.year});
  final List<AdminTrimester> trims;
  final AdminYear year;

  /// Jours de l'année scolaire non couverts par un trimestre : le chiffre qui
  /// dit si le calendrier est complet, sans avoir à comparer les dates à la main.
  int get _joursNonCouverts {
    final total = year.endDate.difference(year.startDate).inDays;
    final couverts = trims.fold<int>(
        0, (a, t) => a + t.endDate.difference(t.startDate).inDays);
    return (total - couverts).clamp(0, total);
  }

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
    final trous = _joursNonCouverts;

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
            Expanded(
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: kTextPrimary)),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10.5, color: kTextMuted)),
              ]),
            ),
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
        stat(Icons.calendar_view_month_rounded, '${trims.length}/3',
            'trimestres', kNavy),
        stat(Icons.layers_rounded, '$nbSeq', 'séquences', kGreen),
        stat(
            Icons.play_circle_rounded,
            cur == null ? '—' : 'T${cur.number}',
            cur == null ? 'aucun courant' : 'en cours',
            cur == null ? kTextMuted : kAccent),
        stat(
            trous > 14
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline_rounded,
            '$trous',
            trous > 14 ? 'jours non couverts' : 'jours hors trimestre',
            trous > 14 ? kAccent : kGreen),
      ]),
    );
  }
}

class _CalendarEmpty extends StatelessWidget {
  const _CalendarEmpty({required this.readOnly});
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(children: [
        Icon(Icons.event_busy_rounded, size: 38, color: kTextMuted),
        const SizedBox(height: 10),
        Text('Aucun trimestre défini',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: kTextPrimary)),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            readOnly
                ? 'Cette année a été archivée sans calendrier.'
                : "Ajoutez un trimestre pour structurer l'année : sans "
                    'découpage, ni bulletins ni conseils de classe ne peuvent '
                    "être générés. Les écoles l'hériteront par synchro.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: kTextMuted, height: 1.45),
          ),
        ),
      ]),
    );
  }
}

// ─── Carte d'un trimestre + ses séquences ─────────────────────────────────────
class _TrimCard extends StatelessWidget {
  const _TrimCard({
    required this.trim,
    required this.readOnly,
    required this.onSetCurrent,
    required this.onEdit,
    required this.onDelete,
    required this.onAddSequence,
    required this.onEditSequence,
    required this.onDeleteSequence,
    required this.onSetCurrentSeq,
  });

  final AdminTrimester trim;
  final bool readOnly;
  final VoidCallback onSetCurrent, onEdit, onDelete, onAddSequence;
  final ValueChanged<AdminSequence> onEditSequence, onDeleteSequence;
  final ValueChanged<String> onSetCurrentSeq;

  @override
  Widget build(BuildContext context) {
    final complet = trim.sequences.length >= _kSequenceNumbers.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: trim.isCurrent ? kGreen : kBorder),
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
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800, color: kNavy)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(
                    child: Text(trim.label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: kTextPrimary)),
                  ),
                  const SizedBox(width: 8),
                  if (trim.isCurrent) AdminBadge('Courant', color: kGreen),
                ]),
                const SizedBox(height: 2),
                Text(
                    '${_fmt.format(trim.startDate)} → '
                    '${_fmt.format(trim.endDate)}'
                    '  ·  ${trim.endDate.difference(trim.startDate).inDays} jours',
                    style: TextStyle(fontSize: 11, color: kTextMuted)),
              ]),
            ),
            if (!readOnly) ...[
              if (!trim.isCurrent)
                TextButton(
                    onPressed: onSetCurrent,
                    child: const Text('Définir courant',
                        style: TextStyle(fontSize: 12))),
              IconButton(
                tooltip: 'Ajouter une séquence',
                icon: Icon(Icons.add_rounded,
                    size: 18, color: complet ? kTextMuted : kNavy),
                onPressed: complet ? null : onAddSequence,
              ),
              IconButton(
                tooltip: 'Modifier le trimestre',
                icon: Icon(Icons.edit_outlined, size: 17, color: kNavy),
                onPressed: onEdit,
              ),
              IconButton(
                tooltip: 'Supprimer le trimestre',
                icon: Icon(Icons.delete_outline_rounded, size: 18, color: kRed),
                onPressed: onDelete,
              ),
            ],
          ]),
        ),
        if (trim.sequences.isNotEmpty) ...[
          Divider(height: 1, color: kBorder),
          ...trim.sequences.map((s) => _SeqRow(
                seq: s,
                readOnly: readOnly,
                onSetCurrent: () => onSetCurrentSeq(s.id),
                onEdit: () => onEditSequence(s),
                onDelete: () => onDeleteSequence(s),
              )),
          const SizedBox(height: 6),
        ],
      ]),
    );
  }
}

class _SeqRow extends StatelessWidget {
  const _SeqRow({
    required this.seq,
    required this.readOnly,
    required this.onSetCurrent,
    required this.onEdit,
    required this.onDelete,
  });
  final AdminSequence seq;
  final bool readOnly;
  final VoidCallback onSetCurrent, onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 8, 4),
      child: Row(children: [
        Icon(Icons.fiber_manual_record,
            size: 8, color: seq.isCurrent ? kGreen : kTextMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Text('Séq. ${seq.number} · ${seq.label}',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: kTextPrimary)),
        ),
        Text(
            '${_fmt.format(seq.startDate)} → ${_fmt.format(seq.endDate)}',
            style: TextStyle(fontSize: 10.5, color: kTextMuted)),
        const SizedBox(width: 8),
        if (seq.isCurrent)
          AdminBadge('Courante', color: kGreen)
        else if (!readOnly)
          TextButton(
            onPressed: onSetCurrent,
            child: const Text('Courante', style: TextStyle(fontSize: 11)),
          ),
        if (!readOnly) ...[
          IconButton(
            tooltip: 'Modifier la séquence',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.edit_outlined, size: 15, color: kNavy),
            onPressed: onEdit,
          ),
          IconButton(
            tooltip: 'Supprimer la séquence',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.delete_outline_rounded, size: 16, color: kRed),
            onPressed: onDelete,
          ),
        ],
      ]),
    );
  }
}
