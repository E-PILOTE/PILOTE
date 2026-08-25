// ════════════════════════════════════════════════════════════════════════════
//  LES PIÈCES COMMUNES DES TROIS MOUVEMENTS
//
//  Muter, radier et réintégrer partagent la même mécanique administrative : une
//  DATE D'EFFET, la RÉFÉRENCE DE L'ACTE qui fonde le mouvement, une
//  observation. Trois copies de ces champs divergeraient, et le jour où le
//  ministère exigerait le numéro d'arrêté, un des trois écrans l'aurait oublié.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';

String jourFr(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Pied de modale avec un bouton principal RÉELLEMENT désactivable — le chrome
/// partagé n'en propose pas : `AdminPrimaryButton.onTap` est non nullable, et
/// `AdminFormDialog` supprime tout le pied (bouton Annuler compris) quand
/// `onSubmit` est null. Or ici l'action doit rester visible mais inerte tant
/// que la date d'effet et le motif ne sont pas saisis.
class PiedMouvement extends StatelessWidget {
  const PiedMouvement({
    super.key,
    required this.label,
    required this.icon,
    required this.couleur,
    required this.saving,
    required this.onSubmit,
  });

  final String label;
  final IconData icon;
  final Color couleur;
  final bool saving;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) => Row(children: [
        TextButton.icon(
          onPressed: saving ? null : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded, size: 16),
          label: const Text('Annuler'),
        ),
        const Spacer(),
        FilledButton.icon(
          onPressed: saving ? null : onSubmit,
          icon: saving
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Icon(icon, size: 18),
          label: Text(label),
          style: FilledButton.styleFrom(
            backgroundColor: couleur,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
        ),
      ]);
}

/// Champ date compact — un mouvement administratif a toujours une date d'effet.
class ChampDate extends StatelessWidget {
  const ChampDate({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.helper,
  });

  final String label;
  final DateTime? value;
  final String? helper;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(DateTime.now().year + 5),
          locale: const Locale('fr', 'FR'),
        );
        if (d != null) onChanged(d);
      },
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          helperMaxLines: 2,
          prefixIcon: const Icon(Icons.event_outlined, size: 20),
          border: const OutlineInputBorder(),
        ),
        child: Text(value == null ? 'Choisir une date' : jourFr(value!)),
      ),
    );
  }
}

/// Les champs communs à tout mouvement : l'acte qui le fonde, et l'observation.
class ChampsActe extends StatelessWidget {
  const ChampsActe({
    super.key,
    required this.reference,
    required this.notes,
    required this.acteDate,
    required this.onActeDate,
  });

  final TextEditingController reference, notes;
  final DateTime? acteDate;
  final ValueChanged<DateTime> onActeDate;

  @override
  Widget build(BuildContext context) => Column(children: [
        Row(children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: reference,
              decoration: const InputDecoration(
                labelText: 'Référence de l\'acte',
                hintText: 'Arrêté n° 1234/METP/CAB/2026',
                helperText: 'Facultatif, mais c\'est lui qui rend le registre '
                    'opposable.',
                helperMaxLines: 2,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ChampDate(
                label: 'Date de l\'acte',
                value: acteDate,
                onChanged: onActeDate),
          ),
        ]),
        const SizedBox(height: 14),
        TextField(
          controller: notes,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Observations',
            border: OutlineInputBorder(),
          ),
        ),
      ]);
}

// ─── Bandeau explicatif ─────────────────────────────────────────────────────

class NoteExplicative extends StatelessWidget {
  const NoteExplicative(
      {super.key, required this.icon, required this.texte, this.couleur});
  final IconData icon;
  final String texte;
  final Color? couleur;

  @override
  Widget build(BuildContext context) {
    final c = couleur ?? kNavy;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withValues(alpha: 0.22)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: c),
        const SizedBox(width: 10),
        Expanded(
          child: Text(texte,
              style: const TextStyle(fontSize: 12.5, height: 1.45)),
        ),
      ]),
    );
  }
}
