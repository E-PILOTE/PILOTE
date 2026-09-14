part of '../economie_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  UN COÛT D'EXPLOITATION — SAISIE
//
//  ⚠️ LE MONTANT QUI FAIT FOI EST EN FCFA : ce que la banque a réellement
//  débité. Le montant en devise et sa devise ne sont là que pour la mémoire.
//  Aucun taux de change n'est stocké et aucune conversion n'est calculée — un
//  taux figé en base devient faux le mois suivant, et personne ne le voit.
//
//  ⚠️ Le poste qui surprend n'est pas le nombre d'élèves : c'est le nombre
//  d'APPAREILS. PowerSync facture les clients simultanés (1 000 inclus, puis
//  30 $ par tranche de 1 000). À ~8 postes par école, 125 écoles saturent
//  l'inclus. Le coût suit les postes, pas les effectifs.
// ════════════════════════════════════════════════════════════════════════════

const _kCategories = <String, String>{
  'base_de_donnees': 'Base de données',
  'synchronisation': 'Synchronisation',
  'stockage': 'Stockage',
  'domaine': 'Domaine / DNS',
  'messagerie': 'Messagerie',
  'boutique': 'Boutique / distribution',
  'autre': 'Autre',
};

class _CoutFormDialog extends ConsumerStatefulWidget {
  const _CoutFormDialog({this.edition});
  final CoutPlateforme? edition;

  @override
  ConsumerState<_CoutFormDialog> createState() => _CoutFormDialogState();
}

class _CoutFormDialogState extends ConsumerState<_CoutFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _label = TextEditingController();
  final _fournisseur = TextEditingController();
  final _montant = TextEditingController(text: '0');
  final _origine = TextEditingController();
  final _devise = TextEditingController(text: 'USD');
  final _notes = TextEditingController();

  String _categorie = 'autre';
  String _periodicite = 'mensuel';
  bool _actif = true;
  bool _saving = false;

  bool get _edition => widget.edition != null;

  @override
  void initState() {
    super.initState();
    final c = widget.edition;
    if (c != null) {
      _label.text = c.label;
      _fournisseur.text = c.fournisseur ?? '';
      _montant.text = c.montantXaf.toString();
      _origine.text = c.montantOrigine?.toStringAsFixed(2) ?? '';
      _devise.text = c.deviseOrigine ?? '';
      _notes.text = c.notes ?? '';
      _categorie = c.categorie;
      _periodicite = c.periodicite;
      _actif = c.isActive;
    }
  }

  @override
  void dispose() {
    for (final c in [_label, _fournisseur, _montant, _origine, _devise, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await enregistrerCout(ref, id: widget.edition?.id, champs: {
        'label': _label.text.trim(),
        'fournisseur':
            _fournisseur.text.trim().isEmpty ? null : _fournisseur.text.trim(),
        'categorie': _categorie,
        'montant_xaf':
            int.tryParse(_montant.text.trim().replaceAll(' ', '')) ?? 0,
        'periodicite': _periodicite,
        'montant_origine': double.tryParse(_origine.text.trim().replaceAll(',', '.')),
        'devise_origine':
            _devise.text.trim().isEmpty ? null : _devise.text.trim().toUpperCase(),
        'is_active': _actif,
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(messageErreur(e, contexte: 'Coût')),
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
        title: const Text('Supprimer ce coût ?'),
        content: const Text('Préférez le décocher « actif » : l\'historique de '
            'ce que la plateforme a coûté reste alors lisible.'),
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
    await supprimerCout(ref, widget.edition!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final montant = int.tryParse(_montant.text.trim().replaceAll(' ', '')) ?? 0;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 660),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          EnteteDialog(
            icone: Icons.dns_rounded,
            titre: _edition ? 'Modifier le coût' : 'Nouveau coût d\'exploitation',
            sousTitre: 'Le montant en FCFA est celui qui fait foi.',
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
                      Row(children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _label,
                            decoration: const InputDecoration(
                              labelText: 'Libellé *',
                              hintText: 'Ex. Supabase Pro',
                            ),
                            validator: (v) =>
                                (v ?? '').trim().isEmpty ? 'Requis' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _fournisseur,
                            decoration:
                                const InputDecoration(labelText: 'Fournisseur'),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _categorie,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Catégorie'),
                        items: [
                          for (final e in _kCategories.entries)
                            DropdownMenuItem(value: e.key, child: Text(e.value)),
                        ],
                        onChanged: (v) =>
                            setState(() => _categorie = v ?? 'autre'),
                      ),
                      const SizedBox(height: 18),
                      const SousTitreDialog('MONTANT'),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _montant,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Débité (FCFA) *',
                              helperText: 'Ce qui fait foi',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            initialValue: _periodicite,
                            isExpanded: true,
                            decoration:
                                const InputDecoration(labelText: 'Périodicité'),
                            items: [
                              for (final e in kBillingPeriods.entries)
                                DropdownMenuItem(
                                    value: e.key, child: Text(e.value)),
                            ],
                            onChanged: (v) => setState(
                                () => _periodicite = v ?? 'mensuel'),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 13, vertical: 10),
                        decoration: BoxDecoration(
                          color: kSurface,
                          border: Border.all(color: kBorder),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Row(children: [
                          Icon(Icons.calculate_rounded, size: 15, color: kTextMuted),
                          const SizedBox(width: 9),
                          Text(
                              'Soit ${fmtXaf(monthlyEquivalent(montant, _periodicite))} '
                              'par mois',
                              style: const TextStyle(
                                  fontSize: 12.5, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _origine,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Montant en devise',
                              helperText: 'Pour mémoire seulement',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _devise,
                            decoration: const InputDecoration(
                                labelText: 'Devise', hintText: 'USD'),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        value: _actif,
                        onChanged: (v) => setState(() => _actif = v),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Coût actif',
                            style: TextStyle(fontSize: 13)),
                        subtitle: Text(
                          'Décocher plutôt que supprimer : l\'historique de ce '
                          'que la plateforme a coûté reste lisible.',
                          style: TextStyle(fontSize: 11, color: kTextMuted),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _notes,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          alignLabelWithHint: true,
                          hintText: 'Ce qui est inclus, ce qui se facture en plus…',
                        ),
                      ),
                    ]),
              ),
            ),
          ),
          PiedDialog(
            saving: _saving,
            onAnnuler: () => Navigator.pop(context),
            onSupprimer: _edition ? _supprimer : null,
            onEnregistrer: _enregistrer,
          ),
        ]),
      ),
    );
  }
}

// ─── Chrome partagé par les deux formulaires ────────────────────────────────



