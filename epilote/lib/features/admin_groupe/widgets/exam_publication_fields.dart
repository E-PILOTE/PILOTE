import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/exam_archives_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CHAMPS DU DÉPÔT D'UNE PUBLICATION — périmètre, pièce jointe, date de
//  proclamation, rappel de la règle de calcul. Sortis du panneau, qui n'a plus
//  à porter que l'enchaînement de la saisie.
// ════════════════════════════════════════════════════════════════════════════
// ─── Périmètre ──────────────────────────────────────────────────────────────
class ScopePicker extends StatelessWidget {
  const ScopePicker({super.key, required this.scope, required this.onChanged});
  final PubScope scope;
  final ValueChanged<PubScope> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        children: [
          for (final s in PubScope.values)
            ChoiceChip(
              label: Text(s.label, style: const TextStyle(fontSize: 12.5)),
              selected: scope == s,
              onSelected: (_) => onChanged(s),
            ),
        ],
      );
}

// ─── Fichier ────────────────────────────────────────────────────────────────
class FileTile extends StatelessWidget {
  const FileTile({super.key, required this.file, required this.onPick});
  final PlatformFile? file;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final f = file;
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: f == null ? kBorder : kGreen),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Icon(f == null ? Icons.upload_file_rounded : Icons.description_rounded,
              size: 20, color: f == null ? kTextMuted : kGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              f == null
                  ? 'Joindre le PDF publié par la DEC'
                  : '${f.name}  ·  ${(f.size / 1024).round()} Ko',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: f == null ? kTextMuted : kTextPrimary),
            ),
          ),
          if (f != null)
            Text('Changer',
                style: TextStyle(fontSize: 11.5, color: kTextMuted)),
        ]),
      ),
    );
  }
}

// ─── Date de proclamation ───────────────────────────────────────────────────
class DatePick extends StatelessWidget {
  const DatePick({super.key, required this.value, required this.onChanged});
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () async {
          final now = DateTime.now();
          final d = await showDatePicker(
            context: context,
            initialDate: value ?? now,
            firstDate: DateTime(now.year - 30),
            lastDate: now,
            helpText: 'Date de publication par la DEC',
          );
          if (d != null) onChanged(d);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              border: Border.all(color: kBorder),
              borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            Icon(Icons.event_rounded, size: 18, color: kTextMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value == null
                    ? 'Date de publication par la DEC (recommandée)'
                    : 'Publié le ${value!.day.toString().padLeft(2, '0')}/'
                        '${value!.month.toString().padLeft(2, '0')}/${value!.year}',
                style: TextStyle(
                    fontSize: 12.5,
                    color: value == null ? kTextMuted : kTextPrimary),
              ),
            ),
          ]),
        ),
      );
}

// ─── Rappel de la règle de calcul ───────────────────────────────────────────
class FiguresNote extends StatelessWidget {
  const FiguresNote({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: kNavy.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.calculate_rounded, size: 17, color: kNavy),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Chiffres officiels portés par ce document (facultatif). Le taux '
              'se calcule sur les PRÉSENTS, jamais sur les inscrits : les '
              'absents sortent du dénominateur. Si la publication ne donne '
              'qu\'un pourcentage, saisissez-le tel quel.',
              style: TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.4),
            ),
          ),
        ]),
      );
}
