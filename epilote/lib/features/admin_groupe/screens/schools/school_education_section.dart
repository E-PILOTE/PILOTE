part of '../admin_schools_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Offre éducative d'une école — cycles ▸ filières ▸ niveaux.
//
//  Extraite du formulaire (qui dépassait 1000 lignes) : c'est une
//  responsabilité autonome — son propre chargement, ses propres mutations du
//  référentiel (créer une filière, un niveau…), sa propre sélection. Le
//  formulaire ne connaît plus que le CONTRÔLEUR — même patron que
//  `SchoolLocationController`.
// ════════════════════════════════════════════════════════════════════════════

/// Sélection d'offre éducative, partagée entre la section et le formulaire.
class SchoolEducationController extends ChangeNotifier {
  final Set<String> cycleIds   = {};
  final Set<String> programIds = {};
  final Set<String> levelIds   = {};

  void write({
    required Set<String> cycles,
    required Set<String> programs,
    required Set<String> levels,
  }) {
    cycleIds..clear()..addAll(cycles);
    programIds..clear()..addAll(programs);
    levelIds..clear()..addAll(levels);
  }
}

/// Section « Cycles d'enseignement » du formulaire école.
/// [schoolId] non nul = édition → la sélection enregistrée est rechargée.
class SchoolEducationSection extends ConsumerStatefulWidget {
  const SchoolEducationSection({
    super.key,
    required this.controller,
    this.schoolId,
  });

  final SchoolEducationController controller;
  final String? schoolId;

  @override
  ConsumerState<SchoolEducationSection> createState() =>
      _SchoolEducationSectionState();
}

class _SchoolEducationSectionState
    extends ConsumerState<SchoolEducationSection> {
  Set<String> _cycleIds   = {};
  Set<String> _programIds = {};
  Set<String> _levelIds   = {};
  bool _eduLoaded = false;

  @override
  void initState() {
    super.initState();
    final id = widget.schoolId;
    if (id == null) {
      _eduLoaded = true;
      return;
    }
    Future.microtask(() async {
      try {
        final sel = await ref.read(schoolEducationProvider(id).future);
        if (!mounted) return;
        setState(() {
          _cycleIds   = {...sel.cycleIds};
          _programIds = {...sel.programIds};
          _levelIds   = {...sel.levelIds};
          _eduLoaded  = true;
        });
      } catch (_) {
        if (mounted) setState(() => _eduLoaded = true);
      }
    });
  }

  /// Publie la sélection au contrôleur — seul lien avec le formulaire, qui la
  /// lira au moment d'enregistrer.
  void _publish() => widget.controller.write(
        cycles: _cycleIds,
        programs: _programIds,
        levels: _levelIds,
      );

  InputDecoration _inputDec(String hint) => schoolInputDec(hint);

  void _eduSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: error ? kRed : kGreen,
      content: Text(msg),
    ));
  }

  @override
  Widget build(BuildContext context) {
    // Publier ICI plutôt qu'à chaque mutation : toute modification de la
    // sélection passe forcément par `setState`, donc par un build. Aucun chemin
    // ne peut être oublié (cascade, ajout de filière, désactivation…).
    _publish();
    return _buildEducationSection();
  }

  // ════════════════════════════════════════════════════════════════════════
  //  Section « Cycles d'enseignement » — 100 % piloté par le référentiel
  // ════════════════════════════════════════════════════════════════════════
  Widget _buildEducationSection() {
    final catAsync = ref.watch(educationCatalogProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SchFormLabel('CYCLES D\'ENSEIGNEMENT'),
      const SizedBox(height: 4),
      Text(
        'Sélectionnez les cycles proposés par l\'établissement, puis les niveaux '
        'exacts. Une école peut combiner plusieurs cycles simultanément.',
        style: TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.4),
      ),
      const SizedBox(height: 14),
      catAsync.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: _eduSpinner,
        error: (e, _) => eduError('Référentiel indisponible : $e'),
        data: (cat) => _eduLoaded ? _eduSelector(cat) : _eduSpinner(),
      ),
    ]);
  }

  Widget _eduSpinner() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Center(
          child: SizedBox(
            width: 22, height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: kNavy),
          ),
        ),
      );

  Widget _eduSelector(EducationCatalog cat) {
    final cycles = cat.activeCycles;
    if (cycles.isEmpty) {
      return eduError('Aucun cycle dans le référentiel.');
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _modeles(cat),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final c in cycles)
          eduChip(
            label: c.name,
            selected: _cycleIds.contains(c.id),
            color: kNavy,
            onTap: () => _toggleCycle(c, cat),
          ),
      ]),
      for (final c in cycles.where((c) => _cycleIds.contains(c.id))) ...[
        const SizedBox(height: 12),
        _cycleCard(c, cat),
      ],
      if (_cycleIds.isEmpty) ...[
        const SizedBox(height: 6),
        Text('Aucun cycle sélectionné pour l\'instant.',
            style: TextStyle(fontSize: 11, color: kTextMuted, fontStyle: FontStyle.italic)),
      ],
    ]);
  }

  // ── Modèles d'établissement ────────────────────────────────────────────
  //
  // Ils ne s'affichent que sur une offre VIDE. Sur une école déjà configurée,
  // un modèle remplacerait tout d'un clic : le serveur refuserait d'emporter
  // des classes, mais la sélection à l'écran serait déjà détruite et
  // l'utilisateur croirait avoir tout perdu. On se contente alors de nommer
  // la forme reconnue — « c'est un CEG ».
  Widget _modeles(EducationCatalog cat) {
    if (_cycleIds.isNotEmpty) {
      final codes = cat.activeCycles
          .where((c) => _cycleIds.contains(c.id))
          .map((c) => c.code);
      final m = modelePour(codes);
      if (m == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(children: [
          Icon(Icons.verified_outlined, size: 14, color: kGreen),
          const SizedBox(width: 6),
          Text('Correspond au modèle « ${m.nom} »',
              style: TextStyle(fontSize: 11.5, color: kTextMuted)),
        ]),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Partir d\'un modèle',
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: kTextPrimary)),
        const SizedBox(height: 2),
        Text('Il coche les cycles et leurs niveaux. Tout reste modifiable '
            'ensuite.',
            style: TextStyle(fontSize: 11, color: kTextMuted, height: 1.35)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final m in kModelesEtablissement)
            Tooltip(
              message: m.description,
              child: OutlinedButton.icon(
                onPressed: () => _appliquerModele(m, cat),
                icon: const Icon(Icons.auto_awesome_outlined, size: 14),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kNavy,
                  side: BorderSide(color: kNavy.withValues(alpha: 0.35)),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
                label: Text(m.nom, style: const TextStyle(fontSize: 11.5)),
              ),
            ),
        ]),
      ]),
    );
  }

  Widget _cycleCard(EducationCycle c, EducationCatalog cat) {
    final children = <Widget>[
      Row(children: [
        Icon(_cycleIcon(c.code), size: 16, color: kNavy),
        const SizedBox(width: 8),
        Expanded(child: Text(c.name, style: TextStyle(
            fontSize: 12.5, fontWeight: FontWeight.w800, color: kTextPrimary))),
      ]),
      const SizedBox(height: 10),
    ];

    if (c.hasPrograms) {
      // Cycle à filières (ex. Formation Professionnelle)
      final progs = cat
          .programsOf(c.id)
          .where((p) => p.isActive || _programIds.contains(p.id))
          .toList();
      children
        ..add(eduSubHeader('Filières', onAdd: () => _addProgram(c)))
        ..add(const SizedBox(height: 8))
        ..add(progs.isEmpty
            ? Text('Aucune filière. Ajoutez-en une.',
                style: TextStyle(fontSize: 11, color: kTextMuted))
            : Wrap(spacing: 8, runSpacing: 8, children: [
                for (final p in progs)
                  eduChip(
                    label: p.name,
                    selected: _programIds.contains(p.id),
                    color: _kBlue,
                    custom: p.isCustom,
                    onTap: () => _toggleProgram(p, cat),
                    onMenu: p.isCustom ? (a) => _programMenu(a, p) : null,
                  ),
              ]));
      for (final p in progs.where((p) => _programIds.contains(p.id))) {
        final lvls = cat
            .levelsOfProgram(p.id)
            .where((l) => l.isActive || _levelIds.contains(l.id))
            .toList();
        children
          ..add(const SizedBox(height: 10))
          ..add(Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kBorder),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              eduSubHeader('Niveaux · ${p.name}',
                  onAdd: () => _addLevel(c, program: p)),
              const SizedBox(height: 8),
              if (lvls.isEmpty)
                Text('Aucun niveau. Ajoutez-en un.',
                    style: TextStyle(fontSize: 11, color: kTextMuted))
              else
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final l in lvls)
                    eduChip(
                      label: l.name,
                      selected: _levelIds.contains(l.id),
                      color: kGreen,
                      custom: l.isCustom,
                      onTap: () => _toggleLevel(l),
                    ),
                ]),
            ]),
          ));
      }
    } else {
      // Cycle à niveaux directs (préscolaire, primaire, collège, lycée)
      final lvls = cat
          .generalLevelsOf(c.id)
          .where((l) => l.isActive || _levelIds.contains(l.id))
          .toList();
      children
        ..add(eduSubHeader('Niveaux', onAdd: () => _addLevel(c)))
        ..add(const SizedBox(height: 8))
        ..add(lvls.isEmpty
            ? Text('Aucun niveau. Ajoutez-en un.',
                style: TextStyle(fontSize: 11, color: kTextMuted))
            : Wrap(spacing: 8, runSpacing: 8, children: [
                for (final l in lvls)
                  eduChip(
                    label: l.name,
                    selected: _levelIds.contains(l.id),
                    color: kGreen,
                    custom: l.isCustom,
                    onTap: () => _toggleLevel(l),
                  ),
              ]));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kNavy.withValues(alpha: 0.22)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  IconData _cycleIcon(String code) {
    switch (code) {
      case 'prescolaire':   return Icons.child_care_rounded;
      case 'primaire':      return Icons.menu_book_rounded;
      case 'college':       return Icons.school_rounded;
      case 'lycee':         return Icons.account_balance_rounded;
      case 'formation_pro': return Icons.engineering_rounded;
      default:              return Icons.category_rounded;
    }
  }

  // ── Sélection (toggles avec cascade pour éviter les orphelins) ──────────
  void _toggleCycle(EducationCycle c, EducationCatalog cat) {
    setState(() {
      if (_cycleIds.contains(c.id)) {
        _cycleIds.remove(c.id);
        final progIds = cat.programsOf(c.id).map((p) => p.id).toSet();
        final lvlIds  = cat.levels
            .where((l) => l.cycleId == c.id).map((l) => l.id).toSet();
        _programIds.removeWhere(progIds.contains);
        _levelIds.removeWhere(lvlIds.contains);
      } else {
        _cycleIds.add(c.id);
        // Un CEG a ses quatre niveaux, une EPP ses six : cocher un cycle, c'est
        // vouloir ce que ce cycle contient. Les faire cocher un par un, mille
        // fois, c'est mille occasions d'en oublier un — et un niveau oublié,
        // c'est une classe qu'on ne peut pas ouvrir en novembre. Tout reste
        // décochable ensuite.
        //
        // Sauf les cycles à filières : la formation professionnelle compte
        // 63 niveaux, et aucun établissement du pays ne les offre tous.
        if (!c.hasPrograms) {
          _levelIds.addAll(cat.activeGeneralLevelsOf(c.id).map((l) => l.id));
        }
      }
    });
  }

  /// Applique un modèle d'établissement : il désigne des cycles, la cascade
  /// habituelle fait le reste. Rien de codé en dur — les niveaux viennent du
  /// référentiel national, comme partout ailleurs.
  void _appliquerModele(ModeleEtablissement m, EducationCatalog cat) {
    final cibles = cat.activeCycles.where((c) => m.cycles.contains(c.code));
    setState(() {
      _cycleIds.clear();
      _programIds.clear();
      _levelIds.clear();
      for (final c in cibles) {
        _cycleIds.add(c.id);
        if (!c.hasPrograms) {
          _levelIds.addAll(cat.activeGeneralLevelsOf(c.id).map((l) => l.id));
        }
      }
    });
  }

  void _toggleProgram(EducationProgram p, EducationCatalog cat) {
    setState(() {
      if (_programIds.contains(p.id)) {
        _programIds.remove(p.id);
        final lvlIds = cat.levelsOfProgram(p.id).map((l) => l.id).toSet();
        _levelIds.removeWhere(lvlIds.contains);
      } else {
        _programIds.add(p.id);
        _cycleIds.add(p.cycleId);
      }
    });
  }

  void _toggleLevel(EducationLevel l) {
    setState(() {
      if (_levelIds.contains(l.id)) {
        _levelIds.remove(l.id);
      } else {
        _levelIds.add(l.id);
        _cycleIds.add(l.cycleId);
        if (l.programId != null) _programIds.add(l.programId!);
      }
    });
  }

  // ── Gestion dynamique du référentiel (filières / niveaux du groupe) ─────
  Future<void> _addProgram(EducationCycle c) async {
    final name = await _promptName('Nouvelle filière', hint: 'Nom de la filière');
    if (name == null || name.trim().isEmpty) return;
    try {
      final id = await ref.read(educationServiceProvider)
          .createProgram(cycleId: c.id, name: name.trim());
      if (!mounted) return;
      setState(() { _programIds.add(id); _cycleIds.add(c.id); });
    } catch (e) {
      if (mounted) _eduSnack('Erreur : $e', error: true);
    }
  }

  Future<void> _addLevel(EducationCycle c, {EducationProgram? program}) async {
    final name = await _promptName(
      program == null ? 'Nouveau niveau' : 'Nouveau niveau · ${program.name}',
      hint: 'Ex. 4ème année',
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      final id = await ref.read(educationServiceProvider).createLevel(
          cycleId: c.id, programId: program?.id, name: name.trim());
      if (!mounted) return;
      setState(() {
        _levelIds.add(id);
        _cycleIds.add(c.id);
        if (program != null) _programIds.add(program.id);
      });
    } catch (e) {
      if (mounted) _eduSnack('Erreur : $e', error: true);
    }
  }

  Future<void> _programMenu(String action, EducationProgram p) async {
    if (action == 'rename') {
      final name = await _promptName('Renommer la filière', initial: p.name);
      if (name == null || name.trim().isEmpty) return;
      try {
        await ref.read(educationServiceProvider).updateProgram(
            id: p.id, name: name.trim(), description: p.description);
        if (mounted) _eduSnack('Filière renommée');
      } catch (e) {
        if (mounted) _eduSnack('Erreur : $e', error: true);
      }
    } else if (action == 'disable') {
      try {
        await ref.read(educationServiceProvider).setProgramActive(p.id, false);
        if (!mounted) return;
        setState(() => _programIds.remove(p.id));
        _eduSnack('Filière désactivée');
      } catch (e) {
        if (mounted) _eduSnack('Erreur : $e', error: true);
      }
    }
  }

  Future<String?> _promptName(String title, {String? hint, String? initial}) async {
    final ctrl = TextEditingController(text: initial ?? '');
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(title, style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w800, color: kTextPrimary)),
        content: SizedBox(
          width: 360,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: _inputDec(hint ?? 'Nom'),
            onSubmitted: (v) => Navigator.of(ctx).pop(v),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(foregroundColor: kTextMuted),
            child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: kNavy, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            child: const Text('Valider')),
        ],
      ),
    );
    ctrl.dispose();
    return res;
  }
}
