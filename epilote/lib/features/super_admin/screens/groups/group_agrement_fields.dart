part of '../school_groups_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  L'AGRÉMENT — UNE MENTION, PAS UNE PROCÉDURE
//
//  ⚠️ CETTE PLATEFORME NE DÉLIVRE AUCUN AGRÉMENT. Elle ne l'instruit pas, ne
//  le valide pas, ne l'expire pas. L'agrément est accordé par la commission du
//  ministère, hors de tout logiciel — le MEPSA a examiné 1 192 dossiers
//  d'enseignement général, le METP 108 puis 151 pour le technique.
//
//  Ici on ENREGISTRE ce qui a été accordé, comme un numéro sur un en-tête.
//  D'où l'absence totale de workflow : trois champs, aucun bouton « valider »,
//  aucun statut calculé, aucun blocage. Si un jour quelque chose refuse une
//  action « faute d'agrément », ce sera une règle que NOUS aurons inventée.
//
//  ── POURQUOI SUR LE GROUPE ────────────────────────────────────────────────
//  Un groupe privé congolais est une personne morale unique : c'est elle qui
//  est agréée. Les écoles en héritent par déclencheur (migration 0158),
//  exactement comme le secteur et la tutelle.
//
//  ── À QUOI ÇA SERT, HONNÊTEMENT ───────────────────────────────────────────
//  À IMPRIMER (le numéro figure sur les attestations d'un établissement privé)
//  et à COMPTER (« combien d'écoles de ma tutelle ont déclaré un agrément ? »).
//  Rien de plus aujourd'hui — le champ ne vaut que rempli.
// ════════════════════════════════════════════════════════════════════════════

class _AgrementFields extends StatelessWidget {
  const _AgrementFields({
    required this.numero,
    required this.type,
    required this.date,
    required this.onType,
    required this.onDate,
  });

  final TextEditingController numero;
  final String? type;
  final DateTime? date;
  final ValueChanged<String?> onType;
  final ValueChanged<DateTime?> onDate;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 18),
      const _FormLabel('AGRÉMENT'),
      Text(
        'Facultatif, et sans effet automatique : E-PILOTE enregistre le numéro '
        'accordé par la commission du ministère, il ne l\'instruit pas. Les '
        'écoles du groupe en héritent.',
        style: TextStyle(fontSize: 11, color: _kMuted, height: 1.4),
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: numero,
            decoration: _inputDeco("Numéro d'agrément").copyWith(
              prefixIcon:
                  Icon(Icons.verified_outlined, size: 15, color: _kMuted),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<String?>(
            initialValue: type,
            isExpanded: true,
            decoration: _inputDeco('Type'),
            items: const [
              DropdownMenuItem(value: null, child: Text('— Non précisé —')),
              DropdownMenuItem(value: 'provisoire', child: Text('Provisoire')),
              DropdownMenuItem(value: 'definitif', child: Text('Définitif')),
            ],
            onChanged: onType,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: _AgrementDateField(date: date, onChanged: onDate)),
      ]),
    ]);
  }
}

/// La date d'obtention. Bornée au passé : un agrément se constate, il ne se
/// programme pas.
class _AgrementDateField extends StatelessWidget {
  const _AgrementDateField({required this.date, required this.onChanged});

  final DateTime? date;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final texte = date == null
        ? ''
        : '${date!.day.toString().padLeft(2, '0')}/'
            '${date!.month.toString().padLeft(2, '0')}/${date!.year}';
    return InkWell(
      onTap: () async {
        final maintenant = DateTime.now();
        final choisie = await showDatePicker(
          context: context,
          initialDate: date ?? maintenant,
          firstDate: DateTime(1960),
          lastDate: maintenant,
          helpText: "Date d'obtention de l'agrément",
        );
        if (choisie != null) onChanged(choisie);
      },
      borderRadius: BorderRadius.circular(8),
      mouseCursor: SystemMouseCursors.click,
      child: IgnorePointer(
        child: TextFormField(
          key: ValueKey(texte),
          initialValue: texte,
          decoration: _inputDeco("Date d'obtention").copyWith(
            prefixIcon:
                Icon(Icons.event_rounded, size: 15, color: _kMuted),
            // Le seul moyen d'effacer une date déjà posée : sans ce bouton,
            // une saisie erronée serait définitive.
            suffixIcon: date == null
                ? null
                : IconButton(
                    icon: Icon(Icons.clear_rounded, size: 15, color: _kMuted),
                    onPressed: () => onChanged(null),
                    tooltip: 'Effacer la date',
                  ),
          ),
        ),
      ),
    );
  }
}
