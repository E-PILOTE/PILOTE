part of '../admin_regional_view.dart';

// ─── Dialogue création / modification projet ─────────────────────────────────
class _ProjectFormDialog extends ConsumerStatefulWidget {
  const _ProjectFormDialog({
    required this.initialCoords,
    this.project,
    this.suggestedDepartment,
    required this.onSaved,
  });
  final LatLng initialCoords;
  final AdminProjectPin? project;

  /// Département pré-sélectionné (déduit du point tapé sur la carte) à la
  /// création. Ignoré s'il ne fait pas partie de [_departments].
  final String? suggestedDepartment;
  final VoidCallback onSaved;

  // Départements du Congo (réforme oct. 2024 : 15). Source unique pour le menu
  // ET pour valider la valeur reçue : un projet dont le `department` n'est pas
  // dans cette liste (nom hérité / accents) ferait planter le DropdownButton
  // (« exactly one item »). On le ramène alors à « Non précisé ».
  static const List<String> _departments = [
    'Bouenza', 'Brazzaville', 'Congo-Oubangui',
    'Cuvette', 'Cuvette-Ouest', 'Djoué-Léfini',
    'Kouilou', 'Lékoumou', 'Likouala', 'Niari',
    'Nkéni-Alima', 'Plateaux', 'Pointe-Noire',
    'Pool', 'Sangha',
  ];

  @override
  ConsumerState<_ProjectFormDialog> createState() => _ProjectFormDialogState();
}

class _ProjectFormDialogState extends ConsumerState<_ProjectFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _budgetCtrl;
  late final TextEditingController _benCtrl;
  late final TextEditingController _commentsCtrl;
  String _status   = 'etude';
  String _priority = 'moyenne';
  String? _schoolType;
  String? _department;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.project;
    _nameCtrl     = TextEditingController(text: p?.name ?? '');
    _descCtrl     = TextEditingController(text: p?.description ?? '');
    _cityCtrl     = TextEditingController(text: p?.city ?? '');
    _budgetCtrl   = TextEditingController(
        text: p?.budgetXaf?.toString() ?? '');
    _benCtrl      = TextEditingController(
        text: p?.beneficiariesEst?.toString() ?? '');
    _commentsCtrl = TextEditingController(text: p?.comments ?? '');
    _status       = p?.status ?? 'etude';
    _priority     = p?.priority ?? 'moyenne';
    _schoolType   = p?.schoolType;
    // Édition : département du projet ; création : suggestion depuis la carte.
    // Coercition à null si hors liste → jamais de crash du DropdownButton.
    final dept = p?.department ?? widget.suggestedDepartment;
    _department = _ProjectFormDialog._departments.contains(dept) ? dept : null;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _cityCtrl.dispose();
    _budgetCtrl.dispose();
    _benCtrl.dispose();
    _commentsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final svc = ref.read(adminProjectServiceProvider);
      if (widget.project == null) {
        await svc.createProject(
          name:             _nameCtrl.text.trim(),
          latitude:         widget.initialCoords.latitude,
          longitude:        widget.initialCoords.longitude,
          status:           _status,
          description:      _descCtrl.text.trim().isNotEmpty
              ? _descCtrl.text.trim() : null,
          schoolType:       _schoolType,
          department:       _department,
          city:             _cityCtrl.text.trim().isNotEmpty
              ? _cityCtrl.text.trim() : null,
          budgetXaf:        int.tryParse(_budgetCtrl.text.trim()),
          beneficiariesEst: int.tryParse(_benCtrl.text.trim()),
          priority:         _priority,
          comments:         _commentsCtrl.text.trim().isNotEmpty
              ? _commentsCtrl.text.trim() : null,
        );
      } else {
        await svc.updateProject(
          id:               widget.project!.id,
          name:             _nameCtrl.text.trim(),
          status:           _status,
          description:      _descCtrl.text.trim().isNotEmpty
              ? _descCtrl.text.trim() : null,
          schoolType:       _schoolType,
          department:       _department,
          city:             _cityCtrl.text.trim().isNotEmpty
              ? _cityCtrl.text.trim() : null,
          budgetXaf:        int.tryParse(_budgetCtrl.text.trim()),
          beneficiariesEst: int.tryParse(_benCtrl.text.trim()),
          priority:         _priority,
          comments:         _commentsCtrl.text.trim().isNotEmpty
              ? _commentsCtrl.text.trim() : null,
        );
      }
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: kRed),
        );
      }
    }
  }

  // Sélecteur de statut visuel (même langage que _StatusPipeline du détail),
  // mais éditable : on tape une étape pour la définir.
  Widget _statusSelector() {
    const steps = [
      ('etude', 'Étude', Icons.search_rounded),
      ('validation', 'Validation', Icons.fact_check_rounded),
      ('budgetisation', 'Budget', Icons.account_balance_rounded),
      ('construction', 'Constr.', Icons.construction_rounded),
      ('acheve', 'Achevé', Icons.check_circle_rounded),
    ];
    final curIdx = steps.indexWhere((s) => s.$1 == _status);
    return Row(children: [
      for (var i = 0; i < steps.length; i++) ...[
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _status = steps[i].$1),
            child: Column(children: [
              Stack(alignment: Alignment.center, children: [
                Row(children: [
                  Expanded(
                      child: Container(
                          height: 2,
                          color: i == 0
                              ? Colors.transparent
                              : (i <= curIdx ? kGreen : kBorder))),
                  Expanded(
                      child: Container(
                          height: 2,
                          color: i == steps.length - 1
                              ? Colors.transparent
                              : (i < curIdx ? kGreen : kBorder))),
                ]),
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: i < curIdx
                        ? kGreen
                        : (i == curIdx
                            ? _projectStatusColor(_status)
                            : kCardBg),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: i <= curIdx
                            ? Colors.transparent
                            : kBorder,
                        width: 1.5),
                  ),
                  child: Icon(
                      i < curIdx ? Icons.check_rounded : steps[i].$3,
                      size: 14,
                      color: i <= curIdx ? Colors.white : kTextMuted),
                ),
              ]),
              const SizedBox(height: 4),
              Text(steps[i].$2,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 8.5,
                      fontWeight:
                          i == curIdx ? FontWeight.w800 : FontWeight.w500,
                      color: i == curIdx
                          ? _projectStatusColor(_status)
                          : kTextMuted)),
            ]),
          ),
        ),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.project != null;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Container(
        width: 560,
        constraints: const BoxConstraints(maxHeight: 660),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 32, offset: const Offset(0, 8)),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0xFFFF5500), _kOrange],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(children: [
                const Icon(Icons.add_location_alt_rounded,
                    color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(
                        isEdit ? 'Modifier le projet' : 'Nouveau projet scolaire',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16, fontWeight: FontWeight.w800))),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white70, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ]),
            ),
            // Coords badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              color: kSurface,
              child: Row(children: [
                const Icon(Icons.location_on_rounded, size: 13, color: _kOrange),
                const SizedBox(width: 6),
                Text(
                    '${widget.initialCoords.latitude.toStringAsFixed(5)}, '
                    '${widget.initialCoords.longitude.toStringAsFixed(5)}',
                    style: TextStyle(
                        fontSize: 11, color: kTextMuted,
                        fontFamily: 'monospace')),
              ]),
            ),
            // Form body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  // ── Identification ──
                  const _ProjSection(
                      icon: Icons.badge_outlined, label: 'Identification'),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: adminInputDecoration('Nom du projet *'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Champ obligatoire' : null,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descCtrl,
                    decoration: adminInputDecoration('Description (optionnel)'),
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                  ),

                  // ── Pilotage ──
                  const SizedBox(height: 18),
                  const _ProjSection(
                      icon: Icons.flag_outlined, label: 'Pilotage'),
                  Text("État d'avancement",
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: kTextMuted)),
                  const SizedBox(height: 8),
                  _statusSelector(),
                  const SizedBox(height: 14),
                  Text('Priorité',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: kTextMuted)),
                  const SizedBox(height: 8),
                  Row(children: [
                    for (final pr in const [
                      ('haute', 'Haute'),
                      ('moyenne', 'Moyenne'),
                      ('basse', 'Basse'),
                    ]) ...[
                      Expanded(
                        child: _PriorityChip(
                          label: pr.$2,
                          color: _priorityColor(pr.$1),
                          selected: _priority == pr.$1,
                          onTap: () => setState(() => _priority = pr.$1),
                        ),
                      ),
                      if (pr.$1 != 'basse') const SizedBox(width: 8),
                    ],
                  ]),

                  // ── Localisation ──
                  const SizedBox(height: 18),
                  const _ProjSection(
                      icon: Icons.place_outlined, label: 'Localisation'),
                  Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: _department,
                        decoration: adminInputDecoration('Département'),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('— Non précisé')),
                          ..._ProjectFormDialog._departments.map(
                              (d) => DropdownMenuItem(value: d, child: Text(d))),
                        ],
                        onChanged: (v) => setState(() => _department = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _cityCtrl,
                        decoration: adminInputDecoration('Ville / Localité'),
                        textCapitalization: TextCapitalization.words,
                      ),
                    ),
                  ]),

                  // ── Impact ──
                  const SizedBox(height: 18),
                  const _ProjSection(
                      icon: Icons.insights_outlined, label: 'Impact attendu'),
                  Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: _schoolType,
                        decoration: adminInputDecoration("Type d'école"),
                        items: const [
                          DropdownMenuItem(
                              value: null, child: Text('— Non précisé')),
                          DropdownMenuItem(
                              value: 'public', child: Text('Public')),
                          DropdownMenuItem(
                              value: 'prive', child: Text('Privé')),
                          DropdownMenuItem(
                              value: 'mixte', child: Text('Mixte')),
                        ],
                        onChanged: (v) => setState(() => _schoolType = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _benCtrl,
                        decoration:
                            adminInputDecoration('Bénéficiaires est.'),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _budgetCtrl,
                    decoration: adminInputDecoration('Budget (FCFA)'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),

                  // ── Notes ──
                  const SizedBox(height: 18),
                  const _ProjSection(
                      icon: Icons.sticky_note_2_outlined, label: 'Notes'),
                  TextFormField(
                    controller: _commentsCtrl,
                    decoration: adminInputDecoration('Commentaires internes'),
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 16),
                ]),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: kBorder)),
              ),
              child: Row(children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    side: BorderSide(color: kBorder),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Annuler',
                      style: TextStyle(color: kTextMuted)),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded, size: 16),
                  label: Text(isEdit ? 'Enregistrer' : 'Créer le projet'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// En-tête de section du formulaire projet (icône + libellé + filet).
class _ProjSection extends StatelessWidget {
  const _ProjSection({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Icon(icon, size: 14, color: _kOrange),
          const SizedBox(width: 7),
          Text(label.toUpperCase(),
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w800,
                  color: kTextPrimary, letterSpacing: 0.6)),
          const SizedBox(width: 10),
          Expanded(child: Divider(height: 1, color: kBorder)),
        ]),
      );
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.12) : kSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: selected ? color : kBorder,
                width: selected ? 1.5 : 1),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 7, height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? color : kTextMuted)),
          ]),
        ),
      );
}

