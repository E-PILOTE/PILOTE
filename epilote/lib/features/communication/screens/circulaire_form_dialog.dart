part of 'circulaires_emises_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  RÉDIGER UNE CIRCULAIRE
//
//  ── LE COMPTEUR DE DESTINATAIRES ──────────────────────────────────────────
//  Le formulaire affiche, EN CONTINU, combien d'établissements le ciblage
//  courant désigne — calculé sur le réseau réel, pas estimé. C'est la seule
//  protection contre le défaut le plus banal de ce genre d'écran : un filtre
//  posé par mégarde qui réduit l'envoi à trois écoles sans que personne ne le
//  remarque avant la relance téléphonique.
//
//  ⚠️ Rien ne part d'ici. Ce formulaire n'écrit qu'un BROUILLON ; la
//  publication est un second geste, explicite et confirmé.
// ════════════════════════════════════════════════════════════════════════════

class _CirculaireFormDialog extends ConsumerStatefulWidget {
  const _CirculaireFormDialog({this.edition});
  final Circulaire? edition;

  @override
  ConsumerState<_CirculaireFormDialog> createState() =>
      _CirculaireFormDialogState();
}

class _CirculaireFormDialogState extends ConsumerState<_CirculaireFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _objet = TextEditingController();
  final _reference = TextEditingController();
  final _corps = TextEditingController();

  CirculairePriorite _priorite = CirculairePriorite.normale;
  String? _secteur;
  String? _departement;
  bool _accuseRequis = true;
  DateTime? _echeance;
  bool _saving = false;

  bool get _edition => widget.edition != null;

  @override
  void initState() {
    super.initState();
    final c = widget.edition;
    if (c != null) {
      _objet.text = c.objet;
      _reference.text = c.reference ?? '';
      _corps.text = c.corps;
      _priorite = c.priorite;
      _secteur = c.cibleSecteur;
      _departement = c.cibleDepartement;
      _accuseRequis = c.accuseRequis;
      _echeance = c.echeance;
    }
  }

  @override
  void dispose() {
    _objet.dispose();
    _reference.dispose();
    _corps.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;
    final groupId = ref.read(authNotifierProvider).valueOrNull?.groupId;
    final tutelle = ref.read(tutelleDuGroupeProvider).valueOrNull;
    if (groupId == null || tutelle == null) return;

    setState(() => _saving = true);
    try {
      if (_edition) {
        await majCirculaire(ref, id: widget.edition!.id, champs: {
          'objet': _objet.text.trim(),
          'corps': _corps.text.trim(),
          'reference':
              _reference.text.trim().isEmpty ? null : _reference.text.trim(),
          'priorite': _priorite.name,
          'cible_secteur': _secteur,
          'cible_departement': _departement,
          'accuse_requis': _accuseRequis,
          'echeance': _echeance?.toIso8601String().substring(0, 10),
        });
      } else {
        await creerCirculaire(
          ref,
          groupId: groupId,
          tutelle: tutelle,
          objet: _objet.text,
          corps: _corps.text,
          reference: _reference.text,
          priorite: _priorite,
          cibleSecteur: _secteur,
          cibleDepartement: _departement,
          accuseRequis: _accuseRequis,
          echeance: _echeance,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(messageErreur(e, contexte: 'Circulaire')),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Le réseau réel, filtré par le ciblage courant. Sert au compteur.
  List<TutelleEcole> get _cibles {
    final reseau = ref.watch(tutelleReseauProvider).valueOrNull?.ecoles;
    if (reseau == null) return const [];
    return filtrerEcoles(
      reseau,
      FiltreReseau(secteur: _secteur, departement: _departement),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cibles = _cibles;
    final depts =
        departementsDe(ref.watch(tutelleReseauProvider).valueOrNull?.ecoles ?? []);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _Entete(edition: _edition, onFermer: () => Navigator.pop(context)),
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
                            controller: _objet,
                            decoration: const InputDecoration(
                              labelText: 'Objet *',
                              hintText: 'Ex. Rentrée scolaire 2026-2027',
                            ),
                            validator: (v) =>
                                (v ?? '').trim().isEmpty ? 'Requis' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _reference,
                            decoration: const InputDecoration(
                              labelText: 'Référence',
                              hintText: 'N° 042/MEPSA',
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _corps,
                        minLines: 6,
                        maxLines: 12,
                        decoration: const InputDecoration(
                          labelText: 'Texte de la circulaire *',
                          alignLabelWithHint: true,
                        ),
                        validator: (v) =>
                            (v ?? '').trim().isEmpty ? 'Requis' : null,
                      ),
                      const SizedBox(height: 18),
                      const _SousTitre('DESTINATAIRES'),
                      const SizedBox(height: 4),
                      Text(
                        'Sans filtre, la circulaire va à TOUS les établissements '
                        'de votre tutelle — y compris ceux que vous n\'exploitez '
                        'pas.',
                        style: TextStyle(
                            fontSize: 11.5, color: kTextMuted, height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            initialValue: _secteur,
                            isExpanded: true,
                            decoration:
                                const InputDecoration(labelText: 'Secteur'),
                            items: const [
                              DropdownMenuItem(
                                  value: null, child: Text('Public et privé')),
                              DropdownMenuItem(
                                  value: 'public', child: Text('Public')),
                              DropdownMenuItem(
                                  value: 'prive', child: Text('Privé')),
                            ],
                            onChanged: (v) => setState(() => _secteur = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            initialValue: _departement,
                            isExpanded: true,
                            decoration:
                                const InputDecoration(labelText: 'Département'),
                            items: [
                              const DropdownMenuItem(
                                  value: null, child: Text('Tous')),
                              for (final d in depts)
                                DropdownMenuItem(value: d, child: Text(d)),
                            ],
                            onChanged: (v) => setState(() => _departement = v),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      _CompteurCibles(ecoles: cibles),
                      const SizedBox(height: 18),
                      const _SousTitre('FORME'),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: DropdownButtonFormField<CirculairePriorite>(
                            initialValue: _priorite,
                            isExpanded: true,
                            decoration:
                                const InputDecoration(labelText: 'Priorité'),
                            items: [
                              for (final p in CirculairePriorite.values)
                                DropdownMenuItem(
                                    value: p, child: Text(prioriteLabel(p))),
                            ],
                            onChanged: (v) => setState(
                                () => _priorite = v ?? CirculairePriorite.normale),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: _ChampEcheance(
                          valeur: _echeance,
                          onChanged: (d) => setState(() => _echeance = d),
                        )),
                      ]),
                      const SizedBox(height: 6),
                      CheckboxListTile(
                        value: _accuseRequis,
                        onChanged: (v) =>
                            setState(() => _accuseRequis = v ?? true),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text('Exiger un accusé de lecture',
                            style: TextStyle(fontSize: 13)),
                        subtitle: Text(
                          'Sans accusé, vous ne pourrez pas prouver que '
                          'l\'établissement a reçu la circulaire.',
                          style: TextStyle(fontSize: 11, color: kTextMuted),
                        ),
                      ),
                    ]),
              ),
            ),
          ),
          _Pied(
            saving: _saving,
            edition: _edition,
            onAnnuler: () => Navigator.pop(context),
            onEnregistrer: _enregistrer,
          ),
        ]),
      ),
    );
  }
}

/// Combien d'établissements ce ciblage désigne — calculé sur le réseau réel.
class _CompteurCibles extends StatelessWidget {
  const _CompteurCibles({required this.ecoles});
  final List<TutelleEcole> ecoles;

  @override
  Widget build(BuildContext context) {
    final n = ecoles.length;
    final groupes = ecoles.map((e) => e.groupId).toSet().length;
    // Zéro destinataire est une erreur de ciblage, pas un cas limite : la
    // publication la refusera. Autant le dire ici, pendant qu'elle se corrige.
    final vide = n == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: (vide ? const Color(0xFFEF4444) : kGreen).withValues(alpha: .08),
        border: Border.all(
            color: (vide ? const Color(0xFFEF4444) : kGreen)
                .withValues(alpha: .3)),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(children: [
        Icon(vide ? Icons.error_outline_rounded : Icons.groups_rounded,
            size: 17, color: vide ? const Color(0xFFEF4444) : kGreen),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            vide
                ? 'Ce ciblage ne désigne AUCUN établissement — la circulaire '
                    'ne partirait à personne.'
                : '$n établissement${n > 1 ? 's' : ''} dans '
                    '$groupes groupe${groupes > 1 ? 's' : ''} recevront cette '
                    'circulaire.',
            style: const TextStyle(fontSize: 12.5, height: 1.4),
          ),
        ),
      ]),
    );
  }
}

class _ChampEcheance extends StatelessWidget {
  const _ChampEcheance({required this.valeur, required this.onChanged});
  final DateTime? valeur;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final texte = valeur == null
        ? ''
        : '${valeur!.day.toString().padLeft(2, '0')}/'
            '${valeur!.month.toString().padLeft(2, '0')}/${valeur!.year}';
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final d = await showDatePicker(
          context: context,
          initialDate: valeur ?? now,
          firstDate: now,
          lastDate: DateTime(now.year + 3),
          helpText: 'Échéance de la circulaire',
        );
        if (d != null) onChanged(d);
      },
      borderRadius: BorderRadius.circular(8),
      mouseCursor: SystemMouseCursors.click,
      child: IgnorePointer(
        child: TextFormField(
          key: ValueKey(texte),
          initialValue: texte,
          decoration: InputDecoration(
            labelText: 'Échéance',
            suffixIcon: valeur == null
                ? const Icon(Icons.event_rounded, size: 17)
                : IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 16),
                    onPressed: () => onChanged(null),
                    tooltip: 'Effacer',
                  ),
          ),
        ),
      ),
    );
  }
}

class _Entete extends StatelessWidget {
  const _Entete({required this.edition, required this.onFermer});
  final bool edition;
  final VoidCallback onFermer;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(22, 18, 14, 16),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: kBorder))),
        child: Row(children: [
          Icon(Icons.edit_note_rounded, size: 21, color: kNavy),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(edition ? 'Modifier la circulaire' : 'Nouvelle circulaire',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800)),
                  Text('Enregistrée en brouillon — rien ne part maintenant.',
                      style: TextStyle(fontSize: 11.5, color: kTextMuted)),
                ]),
          ),
          IconButton(
              onPressed: onFermer, icon: const Icon(Icons.close_rounded, size: 19)),
        ]),
      );
}

class _Pied extends StatelessWidget {
  const _Pied({
    required this.saving,
    required this.edition,
    required this.onAnnuler,
    required this.onEnregistrer,
  });

  final bool saving, edition;
  final VoidCallback onAnnuler, onEnregistrer;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: kBorder))),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton(onPressed: saving ? null : onAnnuler,
              child: const Text('Annuler')),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: saving ? null : onEnregistrer,
            icon: saving
                ? const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_rounded, size: 16),
            label: Text(edition ? 'Enregistrer' : 'Créer le brouillon'),
          ),
        ]),
      );
}

class _SousTitre extends StatelessWidget {
  const _SousTitre(this.texte);
  final String texte;

  @override
  Widget build(BuildContext context) => Text(texte,
      style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: .6,
          color: kTextMuted));
}
