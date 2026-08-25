import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/exam_candidates_provider.dart';
import '../providers/transmission_provider.dart';
import 'examens_widgets.dart' show ExamSectionLabel;

// ════════════════════════════════════════════════════════════════════════════
//  PANNEAU TRANSMISSIONS — figer et prouver le dépôt à la DEC (migration 0054).
//
//  Le dépôt ENGAGE l'établissement : c'est l'acte du chef d'établissement (gated
//  `validate`, accordé au Directeur/Proviseur). On fige la liste AFFICHÉE — on
//  soumet ce qu'on voit, comme l'export — en une transmission opposable et
//  immuable. L'historique reste visible : une liste de février ne se réécrit pas
//  en juin, on émet un RECTIFICATIF lié.
// ════════════════════════════════════════════════════════════════════════════

class TransmissionsPanel extends ConsumerWidget {
  const TransmissionsPanel({
    super.key,
    required this.sessionId,
    required this.tutelle,
    required this.yearLabel,
    required this.candidates,
    required this.canValidate,
    required this.scopeLabel,
  });

  final String sessionId;
  final String? tutelle;
  final String? yearLabel;
  final List<ExamCandidateRow> candidates;
  final bool canValidate;

  /// Le périmètre affiché (« Terminale A » …) — figé dans la transmission.
  final String? scopeLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sessionTransmissionsProvider(sessionId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: ExamSectionLabel(
              'Transmissions à la DEC',
              trailing: async.valueOrNull == null
                  ? null
                  : '${async.value!.length} dépôt(s)',
            ),
          ),
          if (canValidate)
            FilledButton.icon(
              onPressed: candidates.isEmpty
                  ? null
                  : () => _submit(context, ref),
              icon: const Icon(Icons.outbox_rounded, size: 16),
              label: const Text('Soumettre à la DEC'),
              style: FilledButton.styleFrom(
                backgroundColor: kNavy,
                visualDensity: VisualDensity.compact,
              ),
            ),
        ]),
        const SizedBox(height: 10),
        async.when(
          loading: () => Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
                child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: kNavy))),
          ),
          error: (e, _) =>
              Text('$e', style: TextStyle(fontSize: 12, color: kRed)),
          data: (list) => list.isEmpty
              ? _EmptyHint(canValidate: canValidate)
              : Column(
                  children: [
                    for (final t in list)
                      _TransmissionTile(
                          row: t,
                          onAcknowledge:
                              canValidate ? () => _acknowledge(context, ref, t) : null),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    final notesCtrl = TextEditingController();
    final recipient = tutelle == 'mepsa' ? 'DEC MEPSA' : 'DEC METP';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Soumettre à la $recipient',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: kTextPrimary)),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kNavy.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kNavy.withValues(alpha: 0.15)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.lock_clock_rounded, size: 18, color: kNavy),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Vous figez ${candidates.length} candidat(s)'
                      '${scopeLabel != null ? ' · $scopeLabel' : ''}. '
                      'Cette liste devient OPPOSABLE et n\'est plus modifiable — '
                      'une correction se fait par rectificatif. Elle sert de '
                      'feuille de frappe DEC et de bordereau des dossiers papier.',
                      style: TextStyle(fontSize: 12.5, color: kTextPrimary, height: 1.4),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                style: TextStyle(fontSize: 13, color: kTextPrimary),
                decoration: InputDecoration(
                  labelText: 'Note (facultatif)',
                  hintText: 'ex. dépôt physique n°… ',
                  labelStyle: TextStyle(color: kTextMuted),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Annuler', style: TextStyle(color: kTextMuted)),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: kNavy),
            icon: const Icon(Icons.outbox_rounded, size: 16),
            label: const Text('Figer et soumettre'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final res = await createTransmission(
      ref,
      sessionId: sessionId,
      tutelle: tutelle,
      yearLabel: yearLabel,
      candidates: candidates,
      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: res == null ? kRed : kGreen,
      content: Text(res == null
          ? 'Aucun candidat à soumettre.'
          : 'Transmission ${res.reference} figée — ${res.count} candidat(s).'),
    ));
  }

  Future<void> _acknowledge(
      BuildContext context, WidgetRef ref, TransmissionRow t) async {
    final refCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Accusé de réception',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: kTextPrimary)),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              'La DEC a reçu la transmission ${t.reference}. Saisissez sa '
              'référence d\'accusé si elle en a fourni une.',
              style: TextStyle(fontSize: 12.5, color: kTextMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: refCtrl,
              style: TextStyle(fontSize: 13, color: kTextPrimary),
              decoration: InputDecoration(
                labelText: 'Réf. accusé (facultatif)',
                labelStyle: TextStyle(color: kTextMuted),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Annuler', style: TextStyle(color: kTextMuted)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: kGreen),
            child: const Text('Confirmer réception'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await acknowledgeTransmission(t.id,
        acknowledgmentRef: refCtrl.text.trim().isEmpty ? null : refCtrl.text.trim());
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.canValidate});
  final bool canValidate;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorder),
        ),
        child: Row(children: [
          Icon(Icons.inventory_2_outlined, size: 18, color: kTextMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              canValidate
                  ? 'Aucun dépôt encore. « Soumettre » fige la liste affichée en '
                      'un bordereau opposable, daté.'
                  : 'Aucun dépôt. La soumission à la DEC est réservée à la '
                      'direction (chef d\'établissement).',
              style: TextStyle(fontSize: 12.5, color: kTextMuted),
            ),
          ),
        ]),
      );
}

class _TransmissionTile extends StatelessWidget {
  const _TransmissionTile({required this.row, this.onAcknowledge});
  final TransmissionRow row;
  final VoidCallback? onAcknowledge;

  @override
  Widget build(BuildContext context) {
    final (tone, label) = _statusTone(row);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Row(children: [
        Icon(row.isRectificatif ? Icons.edit_note_rounded : Icons.outbox_rounded,
            size: 20, color: tone),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Flexible(
                  child: Text(row.reference,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: kTextPrimary)),
                ),
                if (row.isRectificatif) ...[
                  const SizedBox(width: 8),
                  const _Badge('rectificatif', kListOrangeLocal),
                ],
              ]),
              const SizedBox(height: 3),
              Text(
                '${row.itemCount} candidat(s)'
                '${row.transmittedAt != null ? ' · ${_fmt(row.transmittedAt!)}' : ''}'
                '${row.acknowledgmentLine}',
                style: TextStyle(fontSize: 11.5, color: kTextMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _Badge(label, tone),
        if (onAcknowledge != null && !row.isAcknowledged) ...[
          const SizedBox(width: 6),
          IconButton(
            onPressed: onAcknowledge,
            icon: const Icon(Icons.mark_email_read_rounded, size: 18),
            color: kGreen,
            visualDensity: VisualDensity.compact,
            tooltip: 'Enregistrer l\'accusé de réception',
          ),
        ],
      ]),
    );
  }

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

(Color, String) _statusTone(TransmissionRow r) => switch (r.status) {
      'brouillon' => (kTextMuted, 'Brouillon'),
      'transmis' => (kNavy, 'Transmis'),
      'accuse_reception' => (kGreen, 'Accusé reçu'),
      'traite' => (kGreen, 'Traité'),
      'rejete' => (kRed, 'Rejeté'),
      _ => (kTextMuted, r.status),
    };

const kListOrangeLocal = Color(0xFFFF6B35);

extension on TransmissionRow {
  String get acknowledgmentLine =>
      acknowledgedAt != null ? ' · accusé le ${_TransmissionTile._fmt(acknowledgedAt!)}' : '';
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
      );
}
