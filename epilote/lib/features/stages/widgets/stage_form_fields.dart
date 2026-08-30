part of 'stage_form_dialog.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LES CHAMPS DU FORMULAIRE DE STAGE
//
//  Découpé de `stage_form_dialog.dart` le 2026-08-30, quand l'ajout du mode
//  CORRECTION a porté le fichier au-delà des 500 lignes du dépôt. La coupe suit
//  une couture de cohésion, pas une ligne arbitraire : d'un côté ce que le
//  formulaire DÉCIDE (validité, enregistrement, création ou correction), de
//  l'autre ce avec quoi il se dessine.
//
//  `part` plutôt qu'un import : ces widgets sont privés au formulaire et n'ont
//  aucune raison de devenir publics pour changer de fichier.
// ════════════════════════════════════════════════════════════════════════════

/// Rendre visible la déduction, plutôt que de la laisser surprendre l'agent.
class _StatusHint extends StatelessWidget {
  const _StatusHint({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      'en_cours' => 'En cours',
      'termine' => 'Terminé',
      _ => 'Prévu',
    };
    return Row(children: [
      Icon(Icons.auto_awesome_rounded, size: 13, color: kTextMuted),
      const SizedBox(width: 6),
      Text('Statut déduit des dates : $label',
          style: TextStyle(fontSize: 11, color: kTextMuted)),
    ]);
  }
}

class _CompanyField extends StatelessWidget {
  const _CompanyField({
    required this.companies,
    required this.value,
    required this.onChanged,
    required this.onCreated,
  });

  final List<CompanyRow> companies;
  final String? value;
  final ValueChanged<String?> onChanged;
  final ValueChanged<String> onCreated;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: value,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Entreprise *',
              border: const OutlineInputBorder(),
              isDense: true,
              labelStyle: TextStyle(color: kTextMuted),
            ),
            style: TextStyle(fontSize: 13, color: kTextPrimary),
            items: [
              for (final c in companies)
                DropdownMenuItem(
                  value: c.id,
                  child: Text(
                    '${c.name}${c.sector != null ? ' · ${c.sector}' : ''}'
                    '${c.isShared ? ' · groupe' : ''}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          onPressed: () async {
            final id = await showCompanyDialog(context);
            if (id != null) onCreated(id);
          },
          icon: const Icon(Icons.add_business_rounded, size: 18),
          tooltip: 'Nouvelle entreprise',
        ),
      ]);
}

// ── Création d'entreprise ───────────────────────────────────────────────────

Future<String?> showCompanyDialog(BuildContext context) =>
    showDialog<String>(
      context: context,
      builder: (_) => const _CompanyDialog(),
    );

class _CompanyDialog extends ConsumerStatefulWidget {
  const _CompanyDialog();

  @override
  ConsumerState<_CompanyDialog> createState() => _CompanyState();
}

class _CompanyState extends ConsumerState<_CompanyDialog> {
  final _name = TextEditingController();
  final _sector = TextEditingController();
  final _address = TextEditingController();
  final _contact = TextEditingController();
  final _phone = TextEditingController();
  bool _shared = true;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _sector, _address, _contact, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Nouvelle entreprise',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: kTextPrimary)),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _Text(_name, 'Nom *', hint: 'ex. SOTEC'),
              const SizedBox(height: 12),
              _Text(_sector, 'Secteur', hint: 'ex. Métallurgie'),
              const SizedBox(height: 12),
              _Text(_address, 'Adresse'),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _Text(_contact, 'Contact')),
                const SizedBox(width: 10),
                Expanded(child: _Text(_phone, 'Téléphone')),
              ]),
              const SizedBox(height: 8),
              // Par défaut PARTAGÉE : les écoles d'un même groupe envoient leurs
              // élèves chez les mêmes employeurs. Re-saisir « SOTEC » par école
              // produirait des doublons impossibles à recouper.
              SwitchListTile(
                value: _shared,
                onChanged: (v) => setState(() => _shared = v),
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeThumbColor: kGreen,
                title: Text('Partagée avec tout le groupe',
                    style: TextStyle(fontSize: 12.5, color: kTextPrimary)),
                subtitle: Text(
                  _shared
                      ? 'Les autres écoles du groupe pourront l\'utiliser.'
                      : 'Visible par cette école seulement.',
                  style: TextStyle(fontSize: 11, color: kTextMuted),
                ),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: Text('Annuler', style: TextStyle(color: kTextMuted)),
          ),
          FilledButton(
            onPressed: _saving || _name.text.trim().isEmpty ? null : _save,
            style: FilledButton.styleFrom(backgroundColor: kNavy),
            child: Text(_saving ? 'Création…' : 'Créer'),
          ),
        ],
      );

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final id = await createCompany(
        ref,
        name: _name.text,
        sector: _sector.text,
        address: _address.text,
        contactName: _contact.text,
        contactPhone: _phone.text,
        shared: _shared,
      );
      if (mounted) Navigator.of(context).pop(id);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ── Champs ──────────────────────────────────────────────────────────────────

class _Text extends StatelessWidget {
  const _Text(this.controller, this.label, {this.hint});
  final TextEditingController controller;
  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        style: TextStyle(fontSize: 13, color: kTextPrimary),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          isDense: true,
          labelStyle: TextStyle(color: kTextMuted),
        ),
      );
}

// ⚠️ Les dates d'un stage partent sur `internships`, qui porte
// `academic_year_id` : le repli « année civile ± 3 » laissait dater un stage
// hors de l'année scolaire qui le porte. Même défaut que les huit formulaires
// relevés ce jour — celui-ci m'avait échappé parce que ma requête interrogeait
// une liste de tables écrite à la main, où `internships` ne figurait pas.
class _DateField extends ConsumerWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onPick,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = value == null
        ? label
        : '${value!.day.toString().padLeft(2, '0')}/'
            '${value!.month.toString().padLeft(2, '0')}/${value!.year}';

    return OutlinedButton.icon(
      onPressed: () async {
        final d = await choisirDateScolaire(context, ref,
            initiale: value ?? DateTime.now(), aide: label);
        if (d != null) onPick(d);
      },
      icon: Icon(Icons.event_rounded, size: 15, color: kTextMuted),
      label: Align(
        alignment: Alignment.centerLeft,
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 12,
                color: value == null ? kTextMuted : kTextPrimary)),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: kBorder),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
      ),
    );
  }
}

/// L'élève d'un stage en cours de correction : montré, jamais modifiable.
///
/// Le taire serait pire que de le figer — l'agent doit voir sur QUI porte la
/// correction avant de changer des dates.
class _EleveFige extends StatelessWidget {
  const _EleveFige({required this.nom, required this.classe});
  final String nom;
  final String? classe;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorder),
        ),
        child: Row(children: [
          Icon(Icons.person_rounded, size: 18, color: kTextMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nom,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                Text(
                  classe == null
                      ? 'L’élève d’un stage ne se change pas.'
                      : '$classe · l’élève d’un stage ne se change pas.',
                  style: TextStyle(fontSize: 11.5, color: kTextMuted),
                ),
              ],
            ),
          ),
        ]),
      );
}
