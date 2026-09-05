part of '../admin_modules_screen.dart';

// Panneau lateral d’un module : etat et actions.

class _ModulePanel extends ConsumerStatefulWidget {
  const _ModulePanel({
    required this.slug,
    required this.onClose,
  });
  final String slug;
  final VoidCallback onClose;

  @override
  ConsumerState<_ModulePanel> createState() => _ModulePanelState();
}

class _ModulePanelState extends ConsumerState<_ModulePanel>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _filterCtrl;
  late final TabController _tabCtrl;
  bool _bulkLoading = false;
  double _panelWidth = 480.0;

  @override
  void initState() {
    super.initState();
    _filterCtrl = TextEditingController();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void didUpdateWidget(_ModulePanel old) {
    super.didUpdateWidget(old);
    if (old.slug != widget.slug) {
      _filterCtrl.clear();
      _tabCtrl.animateTo(0);
      if (_bulkLoading) setState(() => _bulkLoading = false);
    }
  }

  @override
  void dispose() {
    _filterCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _applyLevel(
      ModuleProfileAccess p, String moduleId, String level) async {
    final svc = ref.read(adminAccessServiceProvider);
    final map = {...await ref.read(accessProfilePermsProvider(p.id).future)};
    final scope = map[moduleId]?.dataScope ?? 'own_school';
    if (level == _levelNone) {
      map.remove(moduleId);
    } else {
      map[moduleId] = _presetFor(level, scope);
    }
    final perms = [
      for (final e in map.entries)
        if (!e.value.isEmpty) e.value.toJson(e.key),
    ];
    await svc.savePermissions(p.id, perms);
  }

  Future<void> _bulkSet(ModuleOverview module, String level) async {
    setState(() => _bulkLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final targets = level == _levelNone
          ? module.profiles.where((p) => p.authorized).toList()
          : module.profiles;
      await Future.wait([
        for (final p in targets) _applyLevel(p, module.id, level),
      ]);
      ref.invalidate(adminModuleProvider(widget.slug));
      ref.invalidate(adminModulesCatalogProvider);
      final msg = level == _levelNone
          ? 'Accès révoqués pour tous les profils'
          : 'Accès « $level » accordé à tous les profils';
      messenger.showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: level == _levelNone ? kRed : kNavy,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(messageErreur(e)),
        backgroundColor: kRed,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _bulkLoading = false);
    }
  }

  void _confirmRevoke(BuildContext ctx, ModuleOverview module) {
    showDialog<void>(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Révoquer tous les accès ?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text(
          "Cela va supprimer l'accès à « ${module.name} » pour "
          '${module.authorizedProfiles} profil${module.authorizedProfiles > 1 ? "s" : ""}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () {
              Navigator.pop(ctx);
              _bulkSet(module, _levelNone);
            },
            child: const Text('Révoquer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminModuleProvider(widget.slug));

    return Material(
      elevation: 16,
      color: kCardBg,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle (bord gauche) ────────────────────────────────────
          _PanelResizeHandle(
            onDrag: (dx) => setState(() {
              _panelWidth = (_panelWidth - dx).clamp(360.0, 700.0);
            }),
          ),

          // ── Corps du panneau ─────────────────────────────────────────────
          SizedBox(
            width: _panelWidth,
            height: double.infinity,
            child: Column(children: [
              // ── Mini-header (close + module name) ───────────────────────
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: kCardBg,
                  border: Border(bottom: BorderSide(color: kBorder)),
                ),
                child: Row(children: [
                  IconButton(
                    onPressed: widget.onClose,
                    icon: Icon(Icons.close_rounded, size: 20, color: kTextMuted),
                    tooltip: 'Fermer',
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      async.valueOrNull?.name ?? widget.slug,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: kTextPrimary),
                    ),
                  ),
                ]),
              ),

              // ── Barre d'onglets ──────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: kCardBg,
                  border: Border(bottom: BorderSide(color: kBorder)),
                ),
                child: TabBar(
                  controller: _tabCtrl,
                  labelColor: kNavy,
                  unselectedLabelColor: kTextMuted,
                  indicatorColor: kNavy,
                  indicatorWeight: 2.5,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                  labelStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                  unselectedLabelStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                  tabs: const [
                    Tab(text: 'Présentation'),
                    Tab(text: 'Accès profils'),
                  ],
                ),
              ),

              // ── Contenu ──────────────────────────────────────────────────
              Expanded(
                child: async.when(
                  skipLoadingOnReload: true,
                  skipLoadingOnRefresh: true,
                  loading: () =>
                      Center(child: CircularProgressIndicator(color: kNavy)),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(messageErreur(e),
                          style: TextStyle(color: kTextMuted, fontSize: 13)),
                    ),
                  ),
                  data: (module) => module == null
                      ? Center(
                          child: Text('Module introuvable',
                              style: TextStyle(color: kTextMuted)))
                      : TabBarView(
                          controller: _tabCtrl,
                          children: [
                            _buildPresentationTab(context, module),
                            _buildAccessTab(context, module),
                          ],
                        ),
                ),
              ),
            ]),
          ),    // SizedBox
        ],      // Row.children
      ),        // Row
    );
  }

  // ── Onglet 1 : Présentation ────────────────────────────────────────────────


  /// Rafraichit l’ecran depuis les onglets sortis en extension :
  /// `setState` est protege hors de la classe.
  void rafraichir(VoidCallback f) => setState(f);
}
