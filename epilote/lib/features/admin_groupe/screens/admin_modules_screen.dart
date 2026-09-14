import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../core/constants/routes.dart';
import '../../../core/widgets/app_shell.dart';
import '../providers/admin_access_provider.dart'
    show PermRow, accessProfilePermsProvider, adminAccessServiceProvider;
import '../providers/admin_module_provider.dart';
import '../providers/admin_nav_provider.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/utils/message_erreur.dart';

part 'admin_modules/admin_module_panel.dart';
part 'admin_modules/admin_module_panel_bits.dart';
part 'admin_modules/admin_module_panel_tabs.dart';
part 'admin_modules/admin_modules_catalog.dart';
part 'admin_modules/admin_modules_chart.dart';
part 'admin_modules/admin_modules_chart_parts.dart';
part 'admin_modules/admin_modules_filters.dart';
part 'admin_modules/admin_modules_kpis.dart';
part 'admin_modules/admin_modules_views.dart';

// ─── Palette catégorie (8 teintes, ADN plateforme) ───────────────────────────
const List<Color> _kCatPalette = [
  Color(0xFF1B3A6B), // Navy      — Administration / Gouvernance
  Color(0xFF7C3AED), // Purple    — Vie scolaire
  Color(0xFF059669), // Emerald   — Finances / Comptabilité
  Color(0xFF0284C7), // Sky       — Pédagogie / Enseignement
  Color(0xFFD97706), // Amber     — Communication
  Color(0xFFBE185D), // Rose      — RH / Personnel
  Color(0xFF0891B2), // Cyan      — Infrastructure / Bâtiment
  Color(0xFF65A30D), // Lime      — Documents / Rapports
];

/// Retourne la couleur associée à une catégorie d'après son index dans le
/// catalogue (stable car les catégories sont triées par `display_order`).
Color _catColorOf(int categoryIndex) =>
    _kCatPalette[categoryIndex % _kCatPalette.length];

// ─── Constantes de niveau (identiques à l'éditeur matrice) ───────────────────
const Color _kPurple       = Color(0xFF7C3AED);
const String _levelNone    = 'Aucun accès';
const String _levelRead    = 'Lecture seule';
const String _levelContrib = 'Contribution';
const String _levelManage  = 'Gestion complète';
const List<String> _allLevels = [_levelNone, _levelRead, _levelContrib, _levelManage];

Color _levelColor(String l) => switch (l) {
      _levelManage  => kGreen,
      _levelContrib => kNavy,
      _levelRead    => kAccent,
      _             => kTextMuted,
    };

IconData _levelIcon(String l) => switch (l) {
      _levelManage  => Icons.shield_outlined,
      _levelContrib => Icons.edit_outlined,
      _levelRead    => Icons.visibility_outlined,
      _             => Icons.lock_outline_rounded,
    };

String _levelOf(PermRow? p) {
  if (p == null || p.isEmpty) return _levelNone;
  if (p.canManage || (p.canDelete && p.canUpdate && p.canCreate)) return _levelManage;
  if (p.canCreate || p.canUpdate || p.canValidate || p.canApprove) return _levelContrib;
  if (p.canRead) return _levelRead;
  return _levelNone;
}

PermRow _presetFor(String level, String scope) => switch (level) {
      _levelRead    => PermRow(canRead: true, dataScope: scope),
      _levelContrib => PermRow(canRead: true, canCreate: true, canUpdate: true, dataScope: scope),
      _levelManage  => PermRow(
          canRead: true, canCreate: true, canUpdate: true, canDelete: true,
          canExport: true, canImport: true, canValidate: true, canApprove: true,
          canManage: true, dataScope: scope),
      _             => PermRow(dataScope: scope),
    };

bool _sameActions(PermRow a, PermRow b) =>
    a.canRead == b.canRead && a.canCreate == b.canCreate &&
    a.canUpdate == b.canUpdate && a.canDelete == b.canDelete &&
    a.canExport == b.canExport && a.canImport == b.canImport &&
    a.canValidate == b.canValidate && a.canApprove == b.canApprove &&
    a.canManage == b.canManage;

bool _isCustom(PermRow? p) =>
    p != null && !p.isEmpty && !_sameActions(p, _presetFor(_levelOf(p), p.dataScope));

// ─── Module aplati (catalogue + catégorie + couleur) ─────────────────────────
class _FlatModule {
  const _FlatModule({
    required this.module,
    required this.categoryName,
    required this.categorySlug,
    required this.color,
  });
  final AdminCatalogModule module;
  final String categoryName;
  final String categorySlug;
  /// Couleur de la catégorie parente (issue de `_kCatPalette`).
  final Color color;
  /// UUID DB du module — pour la liaison avec les données d'adoption.
  String? get moduleId => module.id;
}

// ═══════════════════════════════════════════════════════════════════════════════
// ÉCRAN PRINCIPAL
// ═══════════════════════════════════════════════════════════════════════════════

class AdminModulesScreen extends ConsumerStatefulWidget {
  const AdminModulesScreen({super.key});
  @override
  ConsumerState<AdminModulesScreen> createState() => _AdminModulesScreenState();
}

class _AdminModulesScreenState extends ConsumerState<AdminModulesScreen>
    with SingleTickerProviderStateMixin {
  // ── Panneau latéral ──
  late final AnimationController _panelAnim;
  late final Animation<Offset>   _slideAnim;
  String? _openSlug;

  // ── Filtres & vue ──
  final _searchCtrl = TextEditingController();
  String  _filterCat      = 'tous';
  String  _filterStatus   = 'tous';
  String  _sortBy         = 'nom';
  bool    _sortAsc        = true;
  bool    _isCardView     = true;
  // Filtres transversaux (affectent charts + cards + table)
  String? _filterModuleId; // UUID DB du module sélectionné
  String? _filterSchoolId; // UUID DB de l'école sélectionnée

  @override
  void initState() {
    super.initState();
    _panelAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _slideAnim = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _panelAnim, curve: Curves.easeInOut));
    _panelAnim.addStatusListener((s) {
      if (s == AnimationStatus.dismissed && mounted) {
        setState(() => _openSlug = null);
      }
    });
  }

  @override
  void dispose() {
    _panelAnim.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openPanel(String slug) {
    if (_openSlug == slug && _panelAnim.isCompleted) return;
    setState(() => _openSlug = slug);
    _panelAnim.forward();
  }

  void _closePanel() => _panelAnim.reverse();

  List<_FlatModule> _applyFilters(
      AdminModulesCatalog catalog, [ModuleAdoptionData? adoptionData]) {
    final q = _searchCtrl.text.trim().toLowerCase();
    // Couleur stable par catégorie (index = position dans display_order)
    var flat = <_FlatModule>[
      for (var ci = 0; ci < catalog.categories.length; ci++)
        for (final m in catalog.categories[ci].modules)
          _FlatModule(
              module: m,
              categoryName: catalog.categories[ci].name,
              categorySlug: catalog.categories[ci].slug,
              color: _catColorOf(ci)),
    ];
    if (q.isNotEmpty) {
      flat = flat
          .where((f) =>
              f.module.name.toLowerCase().contains(q) ||
              f.categoryName.toLowerCase().contains(q) ||
              (f.module.description?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    // ── Filtre catégorie (ignoré si un module précis est déjà sélectionné) ──
    if (_filterCat != 'tous' && _filterModuleId == null) {
      flat = flat.where((f) => f.categorySlug == _filterCat).toList();
    }
    if (_filterStatus == 'active') {
      flat = flat.where((f) => f.module.authorizedProfiles > 0).toList();
    } else if (_filterStatus == 'inactive') {
      flat = flat.where((f) => f.module.authorizedProfiles == 0).toList();
    }
    // ── Filtre module (prioritaire sur catégorie + école) ──────────────────
    if (_filterModuleId != null) {
      flat = flat.where((f) => f.module.id == _filterModuleId).toList();
    }
    // ── Filtre école (uniquement si aucun module précis n'est sélectionné) ─
    // Quand filterModuleId est actif, filterSchoolId n'affecte que les charts.
    if (_filterSchoolId != null && _filterModuleId == null &&
        adoptionData != null) {
      final schoolModIds = adoptionData.ranking
          .where((e) => e.schoolIds.contains(_filterSchoolId))
          .map((e) => e.moduleId)
          .toSet();
      flat = flat
          .where((f) =>
              f.module.id != null && schoolModIds.contains(f.module.id))
          .toList();
    }
    flat.sort((a, b) {
      final c = switch (_sortBy) {
        'couverture' =>
          a.module.authorizedProfiles.compareTo(b.module.authorizedProfiles),
        'categorie' => a.categoryName.compareTo(b.categoryName),
        _           => a.module.name.compareTo(b.module.name),
      };
      return _sortAsc ? c : -c;
    });
    return flat;
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync  = ref.watch(adminModulesCatalogProvider);
    final adoptionData  = ref.watch(adminModuleAdoptionProvider).valueOrNull;
    final schoolNames   = adoptionData?.schoolNames ?? const <String, String>{};

    return AppShell(
      title: 'Modules',
      child: Stack(
        children: [
          // ── Contenu principal ─────────────────────────────────────────
          RefreshIndicator(
            color: kNavy,
            onRefresh: () async {
              ref.invalidate(adminModulesCatalogProvider);
              ref.invalidate(adminModuleAdoptionProvider);
              await ref.read(adminModulesCatalogProvider.future);
            },
            child: catalogAsync.when(
              skipLoadingOnReload: true,
              skipLoadingOnRefresh: true,
              loading: () =>
                  Center(child: CircularProgressIndicator(color: kNavy)),
              error: (e, _) => ListView(children: [
                const SizedBox(height: 120),
                Center(child: AdminErrorBanner(message: messageErreur(e))),
              ]),
              data: (catalog) => _CatalogBody(
                catalog: catalog,
                filtered: _applyFilters(catalog, adoptionData),
                isCardView: _isCardView,
                sortBy: _sortBy,
                sortAsc: _sortAsc,
                filterCat: _filterCat,
                filterStatus: _filterStatus,
                filterModuleId: _filterModuleId,
                filterSchoolId: _filterSchoolId,
                schoolNames: schoolNames,
                searchCtrl: _searchCtrl,
                openSlug: _openSlug,
                onModuleTap: _openPanel,
                onSearchChange: (_) => setState(() {}),
                onFilterCat: (v) => setState(() {
                  _filterCat = v;
                  // Si le module sélectionné n'appartient pas à la nouvelle
                  // catégorie, on le réinitialise pour éviter un résultat vide.
                  if (v != 'tous' && _filterModuleId != null) {
                    final stillVisible = catalog.categories
                        .where((c) => c.slug == v)
                        .expand((c) => c.modules)
                        .any((m) => m.id == _filterModuleId);
                    if (!stillVisible) _filterModuleId = null;
                  }
                }),
                onFilterStatus: (v) => setState(() => _filterStatus = v),
                onFilterModule: (id) => setState(() => _filterModuleId = id),
                onFilterSchool: (id) => setState(() => _filterSchoolId = id),
                onSort: (field) => setState(() {
                  if (_sortBy == field) {
                    _sortAsc = !_sortAsc;
                  } else {
                    _sortBy = field;
                    _sortAsc = true;
                  }
                }),
                onToggleView: () => setState(() => _isCardView = !_isCardView),
                onReset: () => setState(() {
                  _searchCtrl.clear();
                  _filterCat    = 'tous';
                  _filterStatus = 'tous';
                  _filterModuleId = null;
                  _filterSchoolId = null;
                }),
              ),
            ),
          ),

          // ── Dim overlay + Panneau ──────────────────────────────────────
          if (_openSlug != null) ...[
            AnimatedBuilder(
              animation: _panelAnim,
              builder: (_, _) => GestureDetector(
                onTap: _closePanel,
                child: ColoredBox(
                  color: Colors.black
                      .withValues(alpha: _panelAnim.value * 0.38),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: SlideTransition(
                position: _slideAnim,
                child: _ModulePanel(
                  slug: _openSlug!,
                  onClose: _closePanel,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CATALOGUE
// ═══════════════════════════════════════════════════════════════════════════════
