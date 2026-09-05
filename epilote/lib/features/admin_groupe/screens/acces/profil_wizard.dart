part of '../admin_access_screen.dart';

// Assistant de creation d’un profil : etat, enregistrement, coquille.

class ProfileWizardDialog extends ConsumerStatefulWidget {
  const ProfileWizardDialog({
    super.key,
    this.profile,
    required this.categories,
    this.initialStep = 0,
  });
  final AccessProfile? profile;
  final List<ModuleCategory> categories;
  final int initialStep;

  @override
  ConsumerState<ProfileWizardDialog> createState() => _ProfileWizardDialogState();
}

class _ProfileWizardDialogState extends ConsumerState<ProfileWizardDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _desc;
  final _search = TextEditingController();

  late int _step; // 0 = identité, 1 = permissions
  String? _roleType;
  String? _selectedPreset;
  final Map<String, PermRow> _edits = {};
  final Set<String> _collapsed = {};
  bool _permsLoaded = false;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.profile != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile?.name ?? '');
    _desc = TextEditingController(text: widget.profile?.description ?? '');
    _roleType = widget.profile?.roleType;
    _step = _isEdit ? widget.initialStep.clamp(0, 1) : 0;
    if (!_isEdit) _permsLoaded = true;
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _search.dispose();
    super.dispose();
  }

  PermRow _rowFor(String moduleId) => _edits[moduleId] ?? const PermRow();
  void _update(String moduleId, PermRow row) {
    setState(() {
      if (row.isEmpty) {
        _edits.remove(moduleId);
      } else {
        _edits[moduleId] = row;
      }
    });
  }

  int get _grantedCount => _edits.values.where((r) => !r.isEmpty).length;
  int get _sensitiveCount =>
      _edits.values.fold<int>(0, (s, r) => s + r.sensitiveCount);

  void _applyPreset(_Preset p) {
    final next = <String, PermRow>{};
    for (final cat in widget.categories) {
      for (final m in cat.modules) {
        if (!m.accessible) continue; // hors plan : jamais accordé
        final g = p.grantFor(cat.slug, m.slug);
        if (g != null) next[m.id] = g.toRow();
      }
    }
    setState(() {
      _edits
        ..clear()
        ..addAll(next);
      _roleType = p.roleType;
      _selectedPreset = p.roleType;
    });
    if (p.name.isNotEmpty) _name.text = p.name;
    _desc.text = p.description;
  }

  void _bulkCategory(ModuleCategory cat, {required bool grant}) {
    setState(() {
      for (final m in cat.modules) {
        if (!m.accessible) continue;
        if (grant) {
          _edits[m.id] = _rowFor(m.id).copyWith(canRead: true);
        } else {
          _edits.remove(m.id);
        }
      }
    });
  }

  Future<void> _submit() async {
    // À l'étape Permissions, le Form de l'étape Identité est démonté :
    // _formKey.currentState est alors null. On valide donc directement le
    // contenu du champ Nom (seul champ requis) au lieu de l'état du Form,
    // sinon la soumission renverrait toujours en arrière sans rien enregistrer.
    if (_name.text.trim().isEmpty) {
      setState(() {
        _step = 0;
        _error = 'Le nom du profil est requis.';
      });
      // Laisse le Form se reconstruire avant de déclencher sa validation.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _formKey.currentState?.validate();
      });
      return;
    }

    // Garde-fou : un profil sans aucune permission n'a aucun accès.
    final perms = <Map<String, dynamic>>[];
    _edits.forEach((mid, row) {
      if (!row.isEmpty) perms.add(row.toJson(mid));
    });
    if (perms.isEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (_) => _ConfirmEmptyPermsDialog(isEdit: _isEdit),
      );
      if (proceed != true) return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final svc = ref.read(adminAccessServiceProvider);
      String id;
      if (_isEdit) {
        id = widget.profile!.id;
        await svc.updateProfile(
          id: id,
          name: _name.text.trim(),
          description: _desc.text.trim(),
          roleType: _roleType,
        );
      } else {
        id = await svc.createProfile(
          name: _name.text.trim(),
          description: _desc.text.trim(),
          roleType: _roleType,
        );
      }
      await svc.savePermissions(id, perms);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: kGreen,
          content: Text(_isEdit ? 'Profil mis à jour' : 'Profil créé'),
        ));
      }
    } catch (e) {
      setState(() {
        _saving = false;
        _error = _friendlyError(e);
        // En cas d'échec de validation du formulaire (nom manquant), on est
        // déjà à l'étape 0 ; sinon on garde l'étape courante pour réessayer.
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget? body;
    Widget? footer;

    if (_isEdit && !_permsLoaded) {
      final async = ref.watch(accessProfilePermsProvider(widget.profile!.id));
      if (async.hasError) {
        body = Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.cloud_off_rounded, size: 44, color: kTextMuted),
              const SizedBox(height: 14),
              Text('Impossible de charger les permissions du profil.\n'
                  '${_friendlyError(async.error!)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kTextMuted, fontSize: 13)),
              const SizedBox(height: 16),
              Row(mainAxisSize: MainAxisSize.min, children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kTextMuted,
                    side: BorderSide(color: kBorder),
                  ),
                  child: const Text('Fermer'),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: () =>
                      ref.invalidate(accessProfilePermsProvider(widget.profile!.id)),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Réessayer'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _kPurple, foregroundColor: Colors.white,
                  ),
                ),
              ]),
            ]),
          ),
        );
      } else if (async.hasValue) {
        _edits.addAll(async.value ?? const {});
        _permsLoaded = true;
      }
    }

    if (_permsLoaded) {
      body = _step == 0 ? _buildIdentity() : _buildPermissions();
      footer = _buildFooter();
    }
    body ??= SizedBox(
        height: 280,
        child: Center(child: CircularProgressIndicator(color: kNavy)));

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 860),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 30,
                offset: const Offset(0, 8))
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _buildHeader(),
          Flexible(child: body),
          ?footer,
        ]),
      ),
    );
  }

  // ── En-tête + indicateur d'étape ───────────────────────────────────────────

  /// Rafraichit l’ecran depuis les panneaux sortis en extension :
  /// `setState` est protege hors de la classe.
  void rafraichir(VoidCallback f) => setState(f);
}
