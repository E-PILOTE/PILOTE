part of '../economie_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA LICENCE ANNUELLE DE TUTELLE — SAISIE
//
//  Tout est modifiable, tout le temps : un marché public se négocie, se révise
//  par avenant et se règle en tranches. D'où TROIS montants distincts et non
//  un seul — le dû, l'avance de démarrage, et ce qui est réellement encaissé.
//
//  ⚠️ Cette licence NE COMMANDE AUCUN ACCÈS. La vue de tutelle dépend de
//  `administre_referentiel_national` (migration 0155), pas d'ici. Une licence
//  échue ne coupe donc pas un ministère : on ne ferme pas l'État pour un
//  mandat en retard, et un logiciel qui se venge d'un impayé perd le client
//  ET le marché.
// ════════════════════════════════════════════════════════════════════════════

class _LicenceFormDialog extends ConsumerStatefulWidget {
  const _LicenceFormDialog({this.edition});
  final LicenceTutelle? edition;

  @override
  ConsumerState<_LicenceFormDialog> createState() => _LicenceFormDialogState();
}

class _LicenceFormDialogState extends ConsumerState<_LicenceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _intitule = TextEditingController(text: 'Licence annuelle de tutelle');
  final _reference = TextEditingController();
  final _signataire = TextEditingController();
  // ⚠️ Proposé, pas imposé : c'est le montant de DÉPART d'une licence de
  // tutelle (40 M), et un marché public se négocie. Un champ à « 0 » sur la
  // saisie d'un marché national invitait à l'oubli — et une licence à 0 F
  // ressemble à une licence gracieuse dans tous les écrans qui la lisent.
  final _montant =
      TextEditingController(text: '$kLicenceMontantDepartXaf');
  final _avance = TextEditingController(text: '0');
  final _regle = TextEditingController(text: '0');
  final _notes = TextEditingController();

  String? _groupId;
  String _statut = 'brouillon';
  DateTime _debut = DateTime(DateTime.now().year, 1, 1);
  DateTime _fin = DateTime(DateTime.now().year, 12, 31);
  bool _saving = false;

  bool get _edition => widget.edition != null;

  @override
  void initState() {
    super.initState();
    final l = widget.edition;
    if (l != null) {
      _groupId = l.groupId;
      _intitule.text = l.intitule;
      _reference.text = l.referenceMarche ?? '';
      _signataire.text = l.signataire ?? '';
      _montant.text = l.montantXaf.toString();
      _avance.text = l.avanceXaf.toString();
      _regle.text = l.montantRegleXaf.toString();
      _notes.text = l.notes ?? '';
      _statut = l.statut;
      _debut = l.dateDebut;
      _fin = l.dateFin;
    }
  }

  @override
  void dispose() {
    for (final c in [_intitule, _reference, _signataire, _montant, _avance,
        _regle, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  int _n(TextEditingController c) =>
      int.tryParse(c.text.trim().replaceAll(' ', '')) ?? 0;

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;
    if (_groupId == null) return;
    setState(() => _saving = true);
    try {
      await enregistrerLicence(ref, id: widget.edition?.id, champs: {
        'group_id': _groupId,
        // `tutelle` est recopiée du groupe par déclencheur : la saisir ici
        // permettrait une licence MEPSA posée sur le groupe METP, et le
        // contrat désignerait un périmètre que la plateforme ne sert pas.
        'tutelle': ref
            .read(groupesSuperviseursProvider)
            .valueOrNull
            ?.firstWhere((g) => g.id == _groupId)
            .tutelle,
        'intitule': _intitule.text.trim(),
        'reference_marche':
            _reference.text.trim().isEmpty ? null : _reference.text.trim(),
        'signataire':
            _signataire.text.trim().isEmpty ? null : _signataire.text.trim(),
        'date_debut': _debut.toIso8601String().substring(0, 10),
        'date_fin': _fin.toIso8601String().substring(0, 10),
        'montant_xaf': _n(_montant),
        'avance_xaf': _n(_avance),
        'montant_regle_xaf': _n(_regle),
        'statut': _statut,
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(messageErreur(e, contexte: 'Licence de tutelle')),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _supprimer() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette licence ?'),
        content: const Text('L\'historique du contrat sera perdu. Préférez le '
            'statut « résiliée » si le marché a existé.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444)),
              child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await supprimerLicence(ref, widget.edition!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final groupes = ref.watch(groupesSuperviseursProvider).valueOrNull ?? [];
    final montant = _n(_montant);
    final regle = _n(_regle);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 700),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _EnteteDialog(
            icone: Icons.account_balance_rounded,
            titre: _edition ? 'Modifier la licence' : 'Nouvelle licence de tutelle',
            sousTitre: 'Montants libres, modifiables à tout moment.',
            onFermer: () => Navigator.pop(context),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Form(
                key: _formKey,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _groupId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Ministère *',
                          helperText: 'Seuls les groupes qui supervisent un '
                              'réseau peuvent recevoir une licence de tutelle.',
                        ),
                        items: [
                          for (final g in groupes)
                            DropdownMenuItem(value: g.id, child: Text(g.nom)),
                        ],
                        onChanged: _edition
                            ? null
                            : (v) => setState(() => _groupId = v),
                        validator: (v) => v == null ? 'Requis' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _intitule,
                        decoration: const InputDecoration(labelText: 'Intitulé *'),
                        validator: (v) =>
                            (v ?? '').trim().isEmpty ? 'Requis' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(child: _ChampDate(
                          label: 'Début *',
                          valeur: _debut,
                          onChanged: (d) => setState(() => _debut = d),
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _ChampDate(
                          label: 'Fin *',
                          valeur: _fin,
                          onChanged: (d) => setState(() => _fin = d),
                        )),
                      ]),
                      if (!_fin.isAfter(_debut))
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'La fin doit être postérieure au début.',
                            style: TextStyle(
                                fontSize: 11.5, color: Color(0xFFEF4444)),
                          ),
                        ),
                      const SizedBox(height: 18),
                      const _SousTitreDialog('MONTANTS (FCFA)'),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: TextFormField(
                          controller: _montant,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Montant dû *'),
                          onChanged: (_) => setState(() {}),
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: TextFormField(
                          controller: _avance,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Avance de démarrage'),
                          onChanged: (_) => setState(() {}),
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: TextFormField(
                          controller: _regle,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Encaissé'),
                          onChanged: (_) => setState(() {}),
                        )),
                      ]),
                      const SizedBox(height: 10),
                      _ResumeMontants(montant: montant, regle: regle,
                          avance: _n(_avance), debut: _debut, fin: _fin),
                      const SizedBox(height: 18),
                      Row(children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _statut,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Statut'),
                            // Le menu se DÉDUIT du référentiel partagé : une valeur
                            // ajoutée à l'énumération en base ne peut plus
                            // manquer ici sans que personne le voie.
                            items: [
                              for (final st in kStatutsLicence)
                                DropdownMenuItem(
                                    value: st,
                                    child:
                                        Text(libelleStatutLicenceOuTiret(st))),
                            ],
                            onChanged: (v) =>
                                setState(() => _statut = v ?? 'brouillon'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: TextFormField(
                          controller: _reference,
                          decoration: const InputDecoration(
                              labelText: 'Référence du marché'),
                        )),
                      ]),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _signataire,
                        decoration: const InputDecoration(
                            labelText: 'Signataire côté ministère'),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _notes,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          alignLabelWithHint: true,
                        ),
                      ),
                    ]),
              ),
            ),
          ),
          _PiedDialog(
            saving: _saving,
            onAnnuler: () => Navigator.pop(context),
            onSupprimer: _edition ? _supprimer : null,
            onEnregistrer: _fin.isAfter(_debut) ? _enregistrer : null,
          ),
        ]),
      ),
    );
  }
}

/// Ce que les trois montants veulent dire une fois posés côte à côte.
class _ResumeMontants extends StatelessWidget {
  const _ResumeMontants({
    required this.montant,
    required this.regle,
    required this.avance,
    required this.debut,
    required this.fin,
  });

  final int montant, regle, avance;
  final DateTime debut, fin;

  @override
  Widget build(BuildContext context) {
    final mois = ((fin.difference(debut).inDays) / 30.44).round();
    final m = mois < 1 ? 1 : mois;
    final solde = montant - regle;
    // Une avance supérieure au montant est refusée en base (contrainte CHECK).
    // Le dire ici évite de découvrir l'erreur au moment d'enregistrer.
    final avanceExcessive = avance > montant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: (avanceExcessive ? const Color(0xFFEF4444) : kSurface)
            .withValues(alpha: avanceExcessive ? .08 : 1),
        border: Border.all(
            color: avanceExcessive
                ? const Color(0xFFEF4444).withValues(alpha: .4)
                : kBorder),
        borderRadius: BorderRadius.circular(9),
      ),
      child: avanceExcessive
          ? const Text(
              'L\'avance de démarrage ne peut pas dépasser le montant dû.',
              style: TextStyle(fontSize: 12, color: Color(0xFFEF4444)))
          : Wrap(spacing: 22, runSpacing: 8, children: [
              _Chiffre(label: 'Sur $m mois',
                  valeur: '${fmtXaf((montant / m).round())} / mois'),
              _Chiffre(
                  label: 'Reste à encaisser',
                  valeur: fmtXaf(solde),
                  couleur: solde <= 0 ? kGreen : const Color(0xFFFF6B35)),
            ]),
    );
  }
}

class _Chiffre extends StatelessWidget {
  const _Chiffre({required this.label, required this.valeur, this.couleur});
  final String label, valeur;
  final Color? couleur;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: kTextMuted)),
          const SizedBox(height: 2),
          Text(valeur,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: couleur ?? kTextPrimary)),
        ],
      );
}

class _ChampDate extends StatelessWidget {
  const _ChampDate({
    required this.label,
    required this.valeur,
    required this.onChanged,
  });

  final String label;
  final DateTime valeur;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final texte = '${valeur.day.toString().padLeft(2, '0')}/'
        '${valeur.month.toString().padLeft(2, '0')}/${valeur.year}';
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: valeur,
          firstDate: DateTime(2020),
          lastDate: DateTime(2040),
          helpText: label,
        );
        if (d != null) onChanged(d);
      },
      borderRadius: BorderRadius.circular(8),
      mouseCursor: SystemMouseCursors.click,
      child: IgnorePointer(
        child: TextFormField(
          key: ValueKey('$label$texte'),
          initialValue: texte,
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: const Icon(Icons.event_rounded, size: 17),
          ),
        ),
      ),
    );
  }
}
