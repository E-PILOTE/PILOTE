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
import '../widgets/admin_ui.dart';

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
                  const Center(child: CircularProgressIndicator(color: kNavy)),
              error: (e, _) => ListView(children: [
                const SizedBox(height: 120),
                Center(child: AdminErrorBanner(message: 'Erreur : $e')),
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

class _CatalogBody extends StatelessWidget {
  const _CatalogBody({
    required this.catalog,
    required this.filtered,
    required this.isCardView,
    required this.sortBy,
    required this.sortAsc,
    required this.filterCat,
    required this.filterStatus,
    required this.filterModuleId,
    required this.filterSchoolId,
    required this.schoolNames,
    required this.searchCtrl,
    required this.onModuleTap,
    required this.onSearchChange,
    required this.onFilterCat,
    required this.onFilterStatus,
    required this.onFilterModule,
    required this.onFilterSchool,
    required this.onSort,
    required this.onToggleView,
    required this.onReset,
    this.openSlug,
  });
  final AdminModulesCatalog catalog;
  final List<_FlatModule> filtered;
  final bool isCardView;
  final String sortBy;
  final bool sortAsc;
  final String filterCat;
  final String filterStatus;
  final String? filterModuleId;
  final String? filterSchoolId;
  final Map<String, String> schoolNames;
  final TextEditingController searchCtrl;
  final String? openSlug;
  final void Function(String) onModuleTap;
  final void Function(String) onSearchChange;
  final void Function(String) onFilterCat;
  final void Function(String) onFilterStatus;
  final void Function(String?) onFilterModule;
  final void Function(String?) onFilterSchool;
  final void Function(String) onSort;
  final VoidCallback onToggleView;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    if (catalog.isEmpty) {
      return ListView(children: const [
        SizedBox(height: 100),
        AdminEmptyState(
          icon: Icons.apps_rounded,
          title: 'Aucun module',
          message:
              "Le plan d'abonnement de votre groupe n'inclut aucun module accessible pour l'instant.",
        ),
      ]);
    }

    // Couleurs stables par catégorie (même palette que _applyFilters)
    final catColors = <String, Color>{
      for (var i = 0; i < catalog.categories.length; i++)
        catalog.categories[i].slug: _catColorOf(i),
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
      children: [
        _KpiStrip(catalog: catalog, catColors: catColors),
        const SizedBox(height: 20),
        _ModuleAdoptionChart(
          filterModuleId: filterModuleId,
          filterSchoolId: filterSchoolId,
        ),
        const SizedBox(height: 16),
        _ModuleFilterBar(
          catalog: catalog,
          catColors: catColors,
          searchCtrl: searchCtrl,
          filterCat: filterCat,
          filterStatus: filterStatus,
          filterModuleId: filterModuleId,
          filterSchoolId: filterSchoolId,
          schoolNames: schoolNames,
          sortBy: sortBy,
          sortAsc: sortAsc,
          isCardView: isCardView,
          onSearchChange: onSearchChange,
          onFilterCat: onFilterCat,
          onFilterStatus: onFilterStatus,
          onFilterModule: onFilterModule,
          onFilterSchool: onFilterSchool,
          onSort: onSort,
          onToggleView: onToggleView,
          onReset: onReset,
          resultCount: filtered.length,
          totalCount: catalog.moduleCount,
        ),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: AdminEmptyState(
              icon: Icons.search_off_rounded,
              title: 'Aucun résultat',
              message: 'Aucun module ne correspond aux filtres sélectionnés.',
            ),
          )
        else if (isCardView)
          _CardGrid(
            filtered: filtered,
            totalProfiles: catalog.totalProfiles,
            openSlug: openSlug,
            onTap: onModuleTap,
          )
        else
          _TableView(
            filtered: filtered,
            totalProfiles: catalog.totalProfiles,
            openSlug: openSlug,
            sortBy: sortBy,
            sortAsc: sortAsc,
            onSort: onSort,
            onTap: onModuleTap,
          ),
      ],
    );
  }
}

// ── KPI strip (style identique au Tableau de bord) ───────────────────────────

class _KpiStrip extends StatelessWidget {
  const _KpiStrip({required this.catalog, required this.catColors});
  final AdminModulesCatalog catalog;
  final Map<String, Color> catColors;

  @override
  Widget build(BuildContext context) {
    final totalMods = catalog.moduleCount;
    final activatedMods = catalog.categories
        .expand((c) => c.modules)
        .where((m) => m.authorizedProfiles > 0)
        .length;
    final profiles    = catalog.totalProfiles;
    final coveragePct = totalMods > 0
        ? (activatedMods / totalMods * 100).round()
        : 0;
    // Catégories ayant au moins 1 module activé (profil attribué)
    final activeCats = catalog.categories
        .where((c) => c.modules.any((m) => m.authorizedProfiles > 0))
        .length;
    final catCoverage = catalog.categories.isNotEmpty
        ? activeCats / catalog.categories.length
        : 0.0;
    // Profils : taux de couverture modules activés
    final profileCoverage =
        totalMods > 0 ? activatedMods / totalMods : 0.0;

    return LayoutBuilder(
      builder: (_, constraints) {
        final w    = constraints.maxWidth;
        final cols = w >= 1000 ? 4 : (w >= 600 ? 2 : 1);
        const gap  = 16.0;
        final itemW = (w - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            SizedBox(
              width: itemW,
              child: _ModKpiCard(
                color: kNavy,
                icon: Icons.widgets_rounded,
                value: '$totalMods',
                label: 'Modules',
                sub: 'inclus dans le plan',
                progress: totalMods > 0 ? activatedMods / totalMods : 0.0,
              ),
            ),
            SizedBox(
              width: itemW,
              child: _ModKpiCard(
                color: kGreen,
                icon: Icons.shield_rounded,
                value: '$activatedMods',
                label: 'Modules activés',
                sub: '$coveragePct% de couverture',
                progress: totalMods > 0 ? activatedMods / totalMods : 0.0,
              ),
            ),
            SizedBox(
              width: itemW,
              child: _ModKpiCard(
                color: kNavy,
                icon: Icons.groups_rounded,
                value: '$profiles',
                label: "Profils d'accès",
                sub: '$coveragePct% des modules couverts',
                progress: profileCoverage,
              ),
            ),
            SizedBox(
              width: itemW,
              child: _ModKpiCard(
                color: kAccent,
                icon: Icons.category_rounded,
                value: '${catalog.categories.length}',
                label: 'Catégories',
                sub: '$activeCats catégorie${activeCats > 1 ? 's' : ''} active${activeCats > 1 ? 's' : ''}',
                progress: catCoverage,
                catSwatches: [
                  for (final c in catalog.categories)
                    catColors[c.slug] ?? kNavy,
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Carte KPI verticale — même design que le Tableau de bord :
/// barre couleur (4 px) + icon (44 px) + valeur (24 px) + label + spark.
class _ModKpiCard extends StatelessWidget {
  const _ModKpiCard({
    required this.color,
    required this.icon,
    required this.value,
    required this.label,
    required this.sub,
    this.progress,
    this.catSwatches,
  });
  final Color        color;
  final IconData     icon;
  final String       value;
  final String       label;
  final String       sub;
  final double?      progress;    // null = pas de spark
  final List<Color>? catSwatches; // mini swatches de couleurs catégories

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Barre accent top
            Container(height: 4, color: color),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icône
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(height: 14),
                  // Valeur
                  Text(value,
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: kTextPrimary)),
                  const SizedBox(height: 2),
                  // Label
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5,
                          color: kTextMuted,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  // Sous-titre
                  Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade400)),
                  const SizedBox(height: 12),
                  // Mini swatches catégories (carte "Catégories" uniquement)
                  if (catSwatches != null && catSwatches!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final c in catSwatches!)
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: c,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                      ],
                    ),
                  ],
                  // Spark (barre de progression ou espace vide)
                  if (progress != null) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress!.clamp(0.0, 1.0),
                        minHeight: 7,
                        backgroundColor: kBorder,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${(progress! * 100).round()}%',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Données graphe adoption ───────────────────────────────────────────────────

class _AdoptData {
  const _AdoptData({
    required this.label,
    required this.pct,
    required this.color,
    required this.detail,
  });
  final String label;
  final double pct;   // 0–100
  final Color  color;
  final String detail; // '3/5'
}

class _DonutSlice {
  const _DonutSlice(this.label, this.count, this.color);
  final String label;
  final int    count;
  final Color  color;
}

// ── Graphe décisionnel : adoption des modules par école ───────────────────────

class _ModuleAdoptionChart extends ConsumerWidget {
  const _ModuleAdoptionChart({
    this.filterModuleId,
    this.filterSchoolId,
  });
  final String? filterModuleId;
  final String? filterSchoolId;

  // ── helpers ────────────────────────────────────────────────────────────────

  Color _barColor(double pct) => pct >= 80
      ? kGreen
      : pct >= 50
          ? kNavy
          : pct > 0
              ? kAccent
              : kTextMuted;

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminModuleAdoptionProvider);

    return AdminCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── En-tête ────────────────────────────────────────────────
            Row(children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: kNavy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.insights_rounded,
                    size: 18, color: kNavy),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Adoption des modules par école',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: kTextPrimary)),
                    const SizedBox(height: 2),
                    Text(
                      filterModuleId != null
                          ? 'Filtré sur un module — écoles utilisatrices en surbrillance'
                          : filterSchoolId != null
                              ? 'Filtré sur une école — modules actifs à droite'
                              : 'Modules adoptés par école (% du catalogue)',
                      style: const TextStyle(fontSize: 11.5, color: kTextMuted),
                    ),
                  ],
                ),
              ),
            ]),

            const SizedBox(height: 16),

            // ── Légende ────────────────────────────────────────────────
            const Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _Legend(color: kGreen,     label: '≥ 80 % du catalogue'),
                _Legend(color: kNavy,      label: '≥ 50 %'),
                _Legend(color: kAccent,    label: '< 50 %'),
                _Legend(color: kTextMuted, label: 'Aucun module'),
              ],
            ),

            const SizedBox(height: 16),

            // ── Contenu async ──────────────────────────────────────────
            async.when(
              skipLoadingOnReload: true,
              skipLoadingOnRefresh: true,
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                    child: CircularProgressIndicator(
                        color: kNavy, strokeWidth: 2)),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Erreur : $e',
                    style: const TextStyle(color: kRed, fontSize: 12)),
              ),
              data: _buildData,
            ),
          ],
        ),
      ),
    );
  }

  // ── contenu data ───────────────────────────────────────────────────────────

  Widget _buildData(ModuleAdoptionData data) {
    if (data.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Aucune donnée — configurez des profils d\'accès '
          'et assignez-les aux utilisateurs.',
          style: TextStyle(fontSize: 12.5, color: kTextMuted),
        ),
      );
    }

    // Calcul : nb de modules utilisés par chaque école
    final schoolModCount = <String, int>{};
    for (final e in data.ranking) {
      for (final sid in e.schoolIds) {
        schoolModCount[sid] = (schoolModCount[sid] ?? 0) + 1;
      }
    }
    // Écoles triées par nb décroissant de modules adoptés
    final schools = data.schoolNames.entries.toList()
      ..sort((a, b) =>
          (schoolModCount[b.key] ?? 0).compareTo(schoolModCount[a.key] ?? 0));

    return LayoutBuilder(builder: (_, cx) {
      final wide   = cx.maxWidth > 600;
      final total  = data.ranking.length;
      final chartH = (schools.length * 42.0 + 40.0).clamp(120.0, 360.0);

      final leftPanel =
          _buildSchoolsChart(schools, schoolModCount, data, chartH, total);
      final rightPanel = filterModuleId != null
          ? _buildModuleBreakdown(data)
          : filterSchoolId != null
              ? _buildSchoolDetail(schoolModCount, data)
              : _buildDonutPanel(data);

      if (wide) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: leftPanel),
            const SizedBox(width: 20),
            Container(width: 1, color: kBorder, height: chartH + 50),
            const SizedBox(width: 20),
            SizedBox(width: 210, child: rightPanel),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          leftPanel,
          const SizedBox(height: 16),
          const Divider(color: kBorder),
          const SizedBox(height: 16),
          rightPanel,
        ],
      );
    });
  }

  // ── panel gauche : écoles (barres % catalogue) ────────────────────────────

  Widget _buildSchoolsChart(
      List<MapEntry<String, String>> schools,
      Map<String, int> schoolModCount,
      ModuleAdoptionData data,
      double chartH,
      int totalMods) {
    if (schools.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('Aucune école configurée.',
            style: TextStyle(fontSize: 12.5, color: kTextMuted)),
      );
    }

    // IDs des écoles utilisant le module filtré
    final moduleSchoolIds = filterModuleId != null
        ? (data.ranking
                .where((e) => e.moduleId == filterModuleId)
                .firstOrNull
                ?.schoolIds ??
            const <String>{})
        : null;

    final bars = schools.map((s) {
      final modCount = schoolModCount[s.key] ?? 0;
      final pct = totalMods > 0
          ? (modCount / totalMods * 100).clamp(0.0, 100.0)
          : 0.0;
      final baseColor = _barColor(pct);

      Color barColor;
      if (filterModuleId != null) {
        // Surligner les écoles qui utilisent ce module
        barColor = (moduleSchoolIds?.contains(s.key) ?? false)
            ? baseColor
            : kTextMuted.withValues(alpha: 0.22);
      } else if (filterSchoolId != null) {
        // Surligner l'école sélectionnée
        barColor = (s.key == filterSchoolId)
            ? baseColor
            : kTextMuted.withValues(alpha: 0.22);
      } else {
        barColor = baseColor;
      }

      final name =
          s.value.length > 16 ? '${s.value.substring(0, 14)}…' : s.value;
      return _AdoptData(
        label: name,
        pct: pct,
        color: barColor,
        detail: '$modCount/$totalMods',
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Modules adoptés par école',
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: kTextMuted),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: chartH,
          child: SfCartesianChart(
            plotAreaBackgroundColor: Colors.transparent,
            borderWidth: 0,
            margin: const EdgeInsets.only(right: 8),
            primaryXAxis: const CategoryAxis(
              majorGridLines: MajorGridLines(width: 0),
              axisLine: AxisLine(width: 0),
              labelStyle: TextStyle(
                  fontSize: 11,
                  color: kTextMuted,
                  fontWeight: FontWeight.w600),
            ),
            primaryYAxis: const NumericAxis(
              minimum: 0,
              maximum: 100,
              labelFormat: '{value}%',
              majorGridLines: MajorGridLines(color: kBorder, width: 0.6),
              axisLine: AxisLine(width: 0),
              labelStyle: TextStyle(fontSize: 10, color: kTextMuted),
            ),
            tooltipBehavior: TooltipBehavior(
              enable: true,
              format: 'point.x  •  point.y% des modules',
              color: kNavy,
              textStyle:
                  const TextStyle(color: Colors.white, fontSize: 11),
            ),
            series: <CartesianSeries>[
              BarSeries<_AdoptData, String>(
                dataSource: bars,
                xValueMapper: (d, _) => d.label,
                yValueMapper: (d, _) => d.pct,
                pointColorMapper: (d, _) => d.color,
                borderRadius:
                    const BorderRadius.horizontal(right: Radius.circular(6)),
                width: 0.5,
                animationDuration: 500,
                dataLabelSettings: const DataLabelSettings(
                  isVisible: true,
                  labelAlignment: ChartDataLabelAlignment.outer,
                  textStyle: TextStyle(
                      fontSize: 10.5,
                      color: kTextPrimary,
                      fontWeight: FontWeight.w700),
                ),
                dataLabelMapper: (d, _) => d.detail,
              ),
              BarSeries<_AdoptData, String>(
                dataSource: bars,
                xValueMapper: (d, _) => d.label,
                yValueMapper: (d, _) => 100 - d.pct,
                pointColorMapper: (d, _) =>
                    d.color.withValues(alpha: 0.07),
                borderRadius:
                    const BorderRadius.horizontal(right: Radius.circular(6)),
                width: 0.5,
                animationDuration: 500,
                isVisibleInLegend: false,
                enableTooltip: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── panel droit : donut vue globale ───────────────────────────────────────

  Widget _buildDonutPanel(ModuleAdoptionData data) {
    double rate(ModuleAdoptionEntry e) =>
        data.totalSchools > 0 ? e.schoolCount / data.totalSchools : 0.0;

    final excellent = data.ranking.where((e) => rate(e) >= 0.8).length;
    final bon =
        data.ranking.where((e) => rate(e) >= 0.5 && rate(e) < 0.8).length;
    final faible =
        data.ranking.where((e) => rate(e) > 0 && rate(e) < 0.5).length;
    final inactif = data.ranking.where((e) => e.schoolCount == 0).length;
    final activeCount =
        data.ranking.where((e) => e.schoolCount > 0).length;

    final slices = [
      if (excellent > 0) _DonutSlice('Excellent ≥ 80 %', excellent, kGreen),
      if (bon > 0)       _DonutSlice('Bon ≥ 50 %',       bon,       kNavy),
      if (faible > 0)    _DonutSlice('Faible < 50 %',    faible,    kAccent),
      if (inactif > 0)   _DonutSlice('Inactif',          inactif,   kTextMuted),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Distribution globale',
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: kTextMuted),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 190,
          child: slices.isEmpty
              ? const Center(
                  child: Text('—', style: TextStyle(color: kTextMuted)))
              : SfCircularChart(
                  margin: EdgeInsets.zero,
                  annotations: <CircularChartAnnotation>[
                    CircularChartAnnotation(
                      widget: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$activeCount',
                              style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: kNavy)),
                          Text(
                            activeCount == 1
                                ? 'module actif'
                                : 'modules actifs',
                            style: const TextStyle(
                                fontSize: 10, color: kTextMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                  series: <CircularSeries>[
                    DoughnutSeries<_DonutSlice, String>(
                      dataSource: slices,
                      xValueMapper: (d, _) => d.label,
                      yValueMapper: (d, _) => d.count,
                      pointColorMapper: (d, _) => d.color,
                      innerRadius: '62%',
                      radius: '88%',
                      animationDuration: 700,
                      strokeColor: Colors.white,
                      strokeWidth: 2,
                      dataLabelSettings:
                          const DataLabelSettings(isVisible: false),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 4),
        for (final s in slices)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: s.color,
                    borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(s.label,
                    style: const TextStyle(
                        fontSize: 11.5, color: kTextMuted)),
              ),
              Text('${s.count}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary)),
            ]),
          ),
      ],
    );
  }

  // ── panel droit : quelles écoles utilisent le module filtré ───────────────

  Widget _buildModuleBreakdown(ModuleAdoptionData data) {
    final entry = data.ranking
        .where((e) => e.moduleId == filterModuleId)
        .firstOrNull;
    if (entry == null) {
      return const Text('Module non trouvé dans les données d\'adoption.',
          style: TextStyle(fontSize: 12.5, color: kTextMuted));
    }
    final pct = data.totalSchools > 0
        ? entry.schoolCount / data.totalSchools
        : 0.0;
    final color = _barColor(pct * 100);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          if (entry.icon != null) ...[
            Text(entry.icon!, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              entry.moduleName,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
        const SizedBox(height: 4),
        Text(
          '${entry.schoolCount} / ${data.totalSchools} '
          'école${data.totalSchools > 1 ? 's' : ''}',
          style: const TextStyle(fontSize: 11.5, color: kTextMuted),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: kBorder,
            color: color,
          ),
        ),
        const SizedBox(height: 12),
        // Liste de toutes les écoles : ✅ utilisent / ○ n'utilisent pas
        ...data.schoolNames.entries.map((s) {
          final uses = entry.schoolIds.contains(s.key);
          return Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Row(children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: uses ? color : Colors.transparent,
                  border:
                      Border.all(color: uses ? color : kBorder, width: 1.5),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: uses ? kTextPrimary : kTextMuted,
                    fontWeight:
                        uses ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (uses) Icon(Icons.check_rounded, size: 13, color: color),
            ]),
          );
        }),
      ],
    );
  }

  // ── panel droit : modules actifs de l'école filtrée ──────────────────────

  Widget _buildSchoolDetail(
      Map<String, int> schoolModCount, ModuleAdoptionData data) {
    final schoolName  = data.schoolNames[filterSchoolId] ?? '—';
    final modCount    = schoolModCount[filterSchoolId] ?? 0;
    final total       = data.ranking.length;
    final pct         = total > 0 ? modCount / total : 0.0;
    final color       = _barColor(pct * 100);
    final usedModules = data.ranking
        .where((e) => e.schoolIds.contains(filterSchoolId))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          schoolName,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          '$modCount / $total module${total > 1 ? 's' : ''} utilisé${modCount > 1 ? 's' : ''}',
          style: const TextStyle(fontSize: 11.5, color: kTextMuted),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: kBorder,
            color: color,
          ),
        ),
        const SizedBox(height: 12),
        if (usedModules.isEmpty)
          const Text(
            'Aucun module configuré pour cette école.',
            style: TextStyle(fontSize: 12, color: kTextMuted),
          )
        else ...[
          const Text('Modules actifs',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: kTextMuted)),
          const SizedBox(height: 6),
          ...usedModules.take(8).map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(children: [
                  if (e.icon != null) ...[
                    Text(e.icon!, style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 6),
                  ] else ...[
                    Icon(Icons.widgets_outlined,
                        size: 13,
                        color: kNavy.withValues(alpha: 0.6)),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      e.moduleName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11.5,
                          color: kTextPrimary,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                  Icon(Icons.check_rounded, size: 13, color: color),
                ]),
              )),
          if (usedModules.length > 8)
            Text(
              '+ ${usedModules.length - 8} autres',
              style: const TextStyle(fontSize: 11, color: kTextMuted),
            ),
        ],
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color  color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 10, height: 10,
        decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(3)),
      ),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 11, color: kTextMuted)),
    ]);
  }
}


// ── Filter bar ────────────────────────────────────────────────────────────────

class _ModuleFilterBar extends StatelessWidget {
  const _ModuleFilterBar({
    required this.catalog,
    required this.catColors,
    required this.searchCtrl,
    required this.filterCat,
    required this.filterStatus,
    required this.filterModuleId,
    required this.filterSchoolId,
    required this.schoolNames,
    required this.sortBy,
    required this.sortAsc,
    required this.isCardView,
    required this.onSearchChange,
    required this.onFilterCat,
    required this.onFilterStatus,
    required this.onFilterModule,
    required this.onFilterSchool,
    required this.onSort,
    required this.onToggleView,
    required this.onReset,
    required this.resultCount,
    required this.totalCount,
  });
  final AdminModulesCatalog catalog;
  final Map<String, Color> catColors;
  final TextEditingController searchCtrl;
  final String filterCat;
  final String filterStatus;
  final String? filterModuleId;
  final String? filterSchoolId;
  final Map<String, String> schoolNames;
  final String sortBy;
  final bool sortAsc;
  final bool isCardView;
  final void Function(String) onSearchChange;
  final void Function(String) onFilterCat;
  final void Function(String) onFilterStatus;
  final void Function(String?) onFilterModule;
  final void Function(String?) onFilterSchool;
  final void Function(String) onSort;
  final VoidCallback onToggleView;
  final VoidCallback onReset;
  final int resultCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final catOptions = <(String, String)>[
      ('tous', 'Toutes catégories'),
      for (final c in catalog.categories) (c.slug, c.name),
    ];
    // Options écoles pour le dropdown
    final schoolOptions = <(String?, String)>[
      (null, 'Toutes les écoles'),
      for (final e in schoolNames.entries) (e.key, e.value),
    ];
    // Options modules : restreintes à la catégorie sélectionnée si nécessaire
    final moduleOptions = <(String?, String)>[
      (null, 'Tous les modules'),
      for (final cat in catalog.categories)
        if (filterCat == 'tous' || cat.slug == filterCat)
          for (final m in cat.modules)
            if (m.id != null) (m.id, m.name),
    ];

    final hasFilter = searchCtrl.text.isNotEmpty ||
        filterCat != 'tous' ||
        filterStatus != 'tous' ||
        filterModuleId != null ||
        filterSchoolId != null;

    // Ligne 1 : filtres (Wrap pour éviter tout overflow)
    final filterRow = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Recherche
        SizedBox(
          width: 200,
          height: 36,
          child: TextField(
            controller: searchCtrl,
            onChanged: onSearchChange,
            decoration: InputDecoration(
              hintText: 'Rechercher…',
              hintStyle: const TextStyle(fontSize: 13, color: kTextMuted),
              prefixIcon: const Icon(Icons.search_rounded,
                  size: 17, color: kTextMuted),
              suffixIcon: searchCtrl.text.isNotEmpty
                  ? GestureDetector(
                      onTap: () => onSearchChange(''),
                      child: const Icon(Icons.clear_rounded,
                          size: 15, color: kTextMuted),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 0),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: kBorder)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: kBorder)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: kNavy, width: 1.5)),
            ),
            style: const TextStyle(fontSize: 13),
          ),
        ),
        // Catégorie (avec point coloré par catégorie)
        _DropFilter<String>(
          value: filterCat,
          items: catOptions.map((t) {
            final dotColor = t.$1 == 'tous' ? null : catColors[t.$1];
            return DropdownMenuItem<String>(
              value: t.$1,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (dotColor != null) ...[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: dotColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(t.$2),
                ],
              ),
            );
          }).toList(),
          onChanged: (v) => onFilterCat(v ?? 'tous'),
        ),
        // Statut
        _DropFilter<String>(
          value: filterStatus,
          items: const [
            DropdownMenuItem(value: 'tous', child: Text('Tous statuts')),
            DropdownMenuItem(value: 'active', child: Text('Activés')),
            DropdownMenuItem(
                value: 'inactive', child: Text('Non activés')),
          ],
          onChanged: (v) => onFilterStatus(v ?? 'tous'),
        ),
        // École (filtrage transversal)
        if (schoolOptions.length > 1)
          _DropFilter<String?>(
            value: filterSchoolId,
            items: schoolOptions
                .map((t) => DropdownMenuItem<String?>(
                    value: t.$1,
                    child: Text(
                      t.$2.length > 20
                          ? '${t.$2.substring(0, 18)}…'
                          : t.$2,
                    )))
                .toList(),
            onChanged: (v) => onFilterSchool(v),
          ),
        // Module spécifique (filtrage transversal)
        if (moduleOptions.length > 1)
          _DropFilter<String?>(
            value: filterModuleId,
            items: moduleOptions
                .map((t) => DropdownMenuItem<String?>(
                    value: t.$1,
                    child: Text(
                      t.$2.length > 22
                          ? '${t.$2.substring(0, 20)}…'
                          : t.$2,
                    )))
                .toList(),
            onChanged: (v) => onFilterModule(v),
          ),
        // Tri
        _DropFilter<String>(
          value: sortBy,
          items: const [
            DropdownMenuItem(value: 'nom', child: Text('Trier : Nom')),
            DropdownMenuItem(
                value: 'couverture',
                child: Text('Trier : Couverture')),
            DropdownMenuItem(
                value: 'categorie',
                child: Text('Trier : Catégorie')),
          ],
          onChanged: (v) => onSort(v ?? 'nom'),
        ),
        // ASC/DESC
        Tooltip(
          message: sortAsc ? 'Croissant' : 'Décroissant',
          child: InkWell(
            onTap: () => onSort(sortBy),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 34,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kBorder),
              ),
              child: Icon(
                sortAsc
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 16,
                color: kNavy,
              ),
            ),
          ),
        ),
        // Reset (si filtre actif)
        if (hasFilter)
          Tooltip(
            message: 'Réinitialiser tous les filtres',
            child: InkWell(
              onTap: onReset,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 34,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kBorder),
                ),
                child: const Icon(Icons.filter_alt_off_rounded,
                    size: 16, color: kRed),
              ),
            ),
          ),
      ],
    );

    // Ligne 2 : compteur + toggle vue
    final summaryRow = Row(children: [
      Text(
        '$resultCount / $totalCount module${totalCount > 1 ? "s" : ""}',
        style: const TextStyle(fontSize: 12.5, color: kTextMuted),
      ),
      const Spacer(),
      Container(
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _ViewBtn(
            icon: Icons.grid_view_rounded,
            active: isCardView,
            onTap: isCardView ? null : onToggleView,
            isLeft: true,
          ),
          Container(width: 1, color: kBorder),
          _ViewBtn(
            icon: Icons.table_rows_rounded,
            active: !isCardView,
            onTap: isCardView ? onToggleView : null,
            isLeft: false,
          ),
        ]),
      ),
    ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        filterRow,
        const SizedBox(height: 8),
        summaryRow,
      ],
    );
  }
}

class _DropFilter<T> extends StatelessWidget {
  const _DropFilter({
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final T value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          isDense: true,
          style: const TextStyle(fontSize: 13, color: kTextPrimary),
          icon: const Icon(Icons.expand_more_rounded,
              size: 16, color: kTextMuted),
        ),
      ),
    );
  }
}

class _ViewBtn extends StatelessWidget {
  const _ViewBtn({
    required this.icon,
    required this.active,
    required this.isLeft,
    this.onTap,
  });
  final IconData icon;
  final bool active;
  final bool isLeft;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: isLeft
          ? const BorderRadius.horizontal(left: Radius.circular(7))
          : const BorderRadius.horizontal(right: Radius.circular(7)),
      child: Container(
        width: 40,
        height: 36,
        alignment: Alignment.center,
        color: active
            ? kNavy.withValues(alpha: 0.08)
            : Colors.transparent,
        child: Icon(icon, size: 18, color: active ? kNavy : kTextMuted),
      ),
    );
  }
}

// ── Card grid ─────────────────────────────────────────────────────────────────

class _CardGrid extends StatelessWidget {
  const _CardGrid({
    required this.filtered,
    required this.totalProfiles,
    required this.onTap,
    this.openSlug,
  });
  final List<_FlatModule> filtered;
  final int totalProfiles;
  final String? openSlug;
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 280,
        mainAxisExtent: 148,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: filtered.length,
      itemBuilder: (_, i) {
        final f = filtered[i];
        return _ModuleCard(
          module: f.module,
          totalProfiles: totalProfiles,
          catColor: f.color,
          isSelected: openSlug == f.module.slug,
          onTap: () => onTap(f.module.slug),
        );
      },
    );
  }
}

// ── Table view ────────────────────────────────────────────────────────────────

class _TableView extends StatelessWidget {
  const _TableView({
    required this.filtered,
    required this.totalProfiles,
    required this.sortBy,
    required this.sortAsc,
    required this.onSort,
    required this.onTap,
    this.openSlug,
  });
  final List<_FlatModule> filtered;
  final int totalProfiles;
  final String? openSlug;
  final String sortBy;
  final bool sortAsc;
  final void Function(String) onSort;
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: Column(children: [
        // Header row
        Container(
          height: 40,
          decoration: const BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
          ),
          child: Row(children: [
            const SizedBox(width: 16),
            _SortHeader(
                label: 'Module',
                field: 'nom',
                sortBy: sortBy,
                sortAsc: sortAsc,
                onSort: onSort,
                flex: 3),
            _SortHeader(
                label: 'Catégorie',
                field: 'categorie',
                sortBy: sortBy,
                sortAsc: sortAsc,
                onSort: onSort,
                flex: 2),
            _SortHeader(
                label: 'Couverture',
                field: 'couverture',
                sortBy: sortBy,
                sortAsc: sortAsc,
                onSort: onSort,
                flex: 2),
            const SizedBox(width: 48),
          ]),
        ),
        const Divider(height: 1, thickness: 1),
        // Data rows
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filtered.length,
          separatorBuilder: (_, _) =>
              const Divider(height: 1, thickness: 1),
          itemBuilder: (_, i) => _TableRow(
            flat: filtered[i],
            totalProfiles: totalProfiles,
            isSelected: openSlug == filtered[i].module.slug,
            onTap: () => onTap(filtered[i].module.slug),
          ),
        ),
      ]),
    );
  }
}

class _SortHeader extends StatelessWidget {
  const _SortHeader({
    required this.label,
    required this.field,
    required this.sortBy,
    required this.sortAsc,
    required this.onSort,
    this.flex = 1,
  });
  final String label;
  final String field;
  final String sortBy;
  final bool sortAsc;
  final void Function(String) onSort;
  final int flex;

  @override
  Widget build(BuildContext context) {
    final active = sortBy == field;
    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: () => onSort(field),
        child: Row(children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: active ? kNavy : kTextMuted,
                  letterSpacing: 0.3)),
          const SizedBox(width: 4),
          Icon(
            active
                ? (sortAsc
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded)
                : Icons.unfold_more_rounded,
            size: 13,
            color: active ? kNavy : kTextMuted,
          ),
        ]),
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.flat,
    required this.totalProfiles,
    required this.onTap,
    this.isSelected = false,
  });
  final _FlatModule flat;
  final int totalProfiles;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final m = flat.module;
    final auth = m.authorizedProfiles;
    final pct = totalProfiles > 0 ? auth / totalProfiles : 0.0;
    final color = auth == 0
        ? kTextMuted
        : (totalProfiles > 0 && auth >= totalProfiles * 0.8
            ? kGreen
            : kNavy);

    return InkWell(
      onTap: onTap,
      child: Container(
        height: 52,
        color: isSelected
            ? kNavy.withValues(alpha: 0.04)
            : Colors.transparent,
        child: Row(children: [
          const SizedBox(width: 16),
          // Module icon + name
          Expanded(
            flex: 3,
            child: Row(children: [
              _ModuleIcon(emoji: m.icon, selected: isSelected),
              const SizedBox(width: 10),
              Expanded(
                child: Text(m.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? kNavy : kTextPrimary)),
              ),
            ]),
          ),
          // Category — colored pill badge
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: flat.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: flat.color.withValues(alpha: 0.25), width: 1),
                ),
                child: Text(flat.categoryName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: flat.color)),
              ),
            ),
          ),
          // Coverage bar + count
          Expanded(
            flex: 2,
            child: Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: pct.clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor: kBorder,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('$auth/$totalProfiles',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ]),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded,
              size: 18,
              color: isSelected ? kNavy : Colors.grey.shade400),
          const SizedBox(width: 8),
        ]),
      ),
    );
  }
}

// ── Module card ───────────────────────────────────────────────────────────────

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.module,
    required this.totalProfiles,
    required this.catColor,
    required this.onTap,
    this.isSelected = false,
  });
  final AdminCatalogModule module;
  final int totalProfiles;
  final Color catColor;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final auth = module.authorizedProfiles;
    final pct = totalProfiles > 0 ? auth / totalProfiles : 0.0;
    final accentColor = auth == 0
        ? kTextMuted
        : (totalProfiles > 0 && auth >= totalProfiles * 0.8
            ? kGreen
            : kNavy);
    // Couleur effective de l'accent selon l'état de sélection
    final topBarColor = isSelected ? kNavy : catColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? kNavy : catColor.withValues(alpha: 0.35),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? kNavy.withValues(alpha: 0.14)
                : catColor.withValues(alpha: 0.06),
            blurRadius: isSelected ? 16 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Barre accent catégorie (3 px) ─────────────────────
                Container(height: 3, color: topBarColor),
                // ── Contenu ───────────────────────────────────────────
                Expanded(
                  child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // ── Top : icône + nom + chevron ──────────────────────
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ModuleIcon(
                              emoji: module.icon,
                              color: topBarColor,
                              selected: isSelected),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(module.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        isSelected ? kNavy : kTextPrimary,
                                    height: 1.25)),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: isSelected ? kNavy : Colors.grey.shade400,
                          ),
                        ],
                      ),
                      if (module.description != null &&
                          module.description!.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Text(module.description!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11.5,
                                color: kTextMuted,
                                height: 1.3)),
                      ],
                    ],
                  ),

                  // ── Bottom : barre de progression + label ────────────
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: pct.clamp(0.0, 1.0),
                          minHeight: 4,
                          backgroundColor: kBorder,
                          color: accentColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(children: [
                        Expanded(
                          child: Text(
                            auth == 0
                                ? 'Aucun profil autorisé'
                                : '$auth/$totalProfiles profil${totalProfiles > 1 ? "s" : ""}',
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: auth > 0 ? accentColor : kTextMuted),
                          ),
                        ),
                        if (auth > 0 &&
                            totalProfiles > 0 &&
                            auth >= totalProfiles)
                          const Icon(Icons.verified_rounded,
                              size: 13, color: kGreen),
                      ]),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  ),
),
);
  }
}

class _ModuleIcon extends StatelessWidget {
  const _ModuleIcon({this.emoji, this.color, this.selected = false});
  final String? emoji;
  final Color?  color;   // couleur catégorie (null → kNavy par défaut)
  final bool    selected;

  @override
  Widget build(BuildContext context) {
    final c = color ?? kNavy;
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected
            ? c.withValues(alpha: 0.16)
            : c.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(10),
      ),
      child: (emoji != null && emoji!.isNotEmpty)
          ? Text(emoji!, style: const TextStyle(fontSize: 19))
          : Icon(Icons.widgets_outlined,
              size: 19,
              color: selected ? c : c.withValues(alpha: 0.75)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PANNEAU LATÉRAL — gouvernance complète d'un module
// ═══════════════════════════════════════════════════════════════════════════════

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
        content: Text('Erreur : $e'),
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
      color: Colors.white,
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
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: kBorder)),
                ),
                child: Row(children: [
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close_rounded, size: 20, color: kTextMuted),
                    tooltip: 'Fermer',
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      async.valueOrNull?.name ?? widget.slug,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: kTextPrimary),
                    ),
                  ),
                ]),
              ),

              // ── Barre d'onglets ──────────────────────────────────────────
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
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
                      const Center(child: CircularProgressIndicator(color: kNavy)),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text('Erreur : $e',
                          style: const TextStyle(color: kTextMuted, fontSize: 13)),
                    ),
                  ),
                  data: (module) => module == null
                      ? const Center(
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

  Widget _buildPresentationTab(BuildContext context, ModuleOverview module) {
    final totalMembers = module.profiles
        .where((p) => p.authorized)
        .fold<int>(0, (s, p) => s + p.memberCount);
    final adoption = ref.watch(adminModuleAdoptionProvider).valueOrNull;
    final adoptEntry = adoption?.ranking
        .where((e) => e.moduleId == module.id)
        .firstOrNull;
    final totalSchools = adoption?.totalSchools ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Avertissement hors-plan
        if (!module.accessible)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: kAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kAccent.withValues(alpha: 0.28)),
            ),
            child: const Row(children: [
              Icon(Icons.warning_amber_rounded, color: kAccent, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Ce module n'est pas inclus dans votre plan d'abonnement.",
                  style: TextStyle(fontSize: 13, color: kTextPrimary),
                ),
              ),
            ]),
          ),

        // Identité
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 64, height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: kNavy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: (module.icon != null && module.icon!.isNotEmpty)
                ? Text(module.icon!, style: const TextStyle(fontSize: 32))
                : const Icon(Icons.widgets_outlined, size: 32, color: kNavy),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(module.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800, color: kTextPrimary)),
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [
                if (module.categoryName != null)
                  AdminBadge(module.categoryName!, color: kNavy),
                AdminBadge(
                  module.accessible ? 'Inclus dans le plan' : 'Hors plan',
                  color: module.accessible ? kGreen : kAccent,
                  icon: module.accessible
                      ? Icons.check_circle_outline_rounded
                      : Icons.info_outline_rounded,
                ),
              ]),
            ]),
          ),
        ]),

        if (module.description != null && module.description!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(module.description!,
              style: const TextStyle(fontSize: 13.5, color: kTextMuted, height: 1.5)),
        ],

        const SizedBox(height: 20),

        // Stats en boîtes
        Row(children: [
          Expanded(
            child: _StatBox(
              icon: Icons.people_rounded,
              value: '$totalMembers',
              label: 'Membres autorisés',
              color: kNavy,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatBox(
              icon: Icons.shield_rounded,
              value: '${module.authorizedProfiles}/${module.totalProfiles}',
              label: 'Profils habilités',
              color: module.authorizedProfiles > 0 ? kGreen : kTextMuted,
            ),
          ),
        ]),

        // Adoption par école
        if (adoptEntry != null && adoption != null &&
            adoption.schoolNames.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(children: [
            const Expanded(
              child: Text('Adoption par école',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: kTextMuted,
                      letterSpacing: 0.3)),
            ),
            Text(
              '${adoptEntry.schoolCount}/$totalSchools école${totalSchools > 1 ? "s" : ""}',
              style: const TextStyle(fontSize: 12, color: kTextMuted),
            ),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: totalSchools > 0
                  ? (adoptEntry.schoolCount / totalSchools).clamp(0.0, 1.0)
                  : 0.0,
              minHeight: 6,
              backgroundColor: kBorder,
              color: adoptEntry.schoolCount == totalSchools
                  ? kGreen
                  : adoptEntry.schoolCount > 0
                      ? kNavy
                      : kTextMuted,
            ),
          ),
          const SizedBox(height: 14),
          for (final s in adoption.schoolNames.entries) ...[
            _SchoolAdoptRow(
              name: s.value,
              uses: adoptEntry.schoolIds.contains(s.key),
            ),
            const SizedBox(height: 8),
          ],
        ],

        const SizedBox(height: 20),
      ]),
    );
  }

  // ── Onglet 2 : Accès profils ────────────────────────────────────────────────

  Widget _buildAccessTab(BuildContext context, ModuleOverview module) {
    final filter = _filterCtrl.text.toLowerCase();
    final profiles = (filter.isEmpty
            ? module.profiles
            : module.profiles
                .where((p) => p.name.toLowerCase().contains(filter))
                .toList())
      ..sort((a, b) {
        final ra = _allLevels.indexOf(_levelOf(a.perm));
        final rb = _allLevels.indexOf(_levelOf(b.perm));
        if (ra != rb) return rb.compareTo(ra);
        return a.name.compareTo(b.name);
      });

    return Column(
      children: [
        // Actions rapides — fixées en haut
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: const BoxDecoration(
            color: kSurface,
            border: Border(bottom: BorderSide(color: kBorder)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ACTIONS RAPIDES',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: kTextMuted,
                    letterSpacing: 0.8)),
            const SizedBox(height: 10),
            if (_bulkLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(child: CircularProgressIndicator(color: kNavy, strokeWidth: 2)),
              )
            else
              Wrap(spacing: 8, runSpacing: 8, children: [
                _ActionChip(
                  label: 'Lecture — tous',
                  icon: Icons.visibility_outlined,
                  color: kAccent,
                  enabled: module.accessible,
                  onTap: () => _bulkSet(module, _levelRead),
                ),
                _ActionChip(
                  label: 'Contribution — tous',
                  icon: Icons.edit_outlined,
                  color: kNavy,
                  enabled: module.accessible,
                  onTap: () => _bulkSet(module, _levelContrib),
                ),
                _ActionChip(
                  label: 'Gestion — tous',
                  icon: Icons.admin_panel_settings_outlined,
                  color: kGreen,
                  enabled: module.accessible,
                  onTap: () => _bulkSet(module, _levelManage),
                ),
                _ActionChip(
                  label: 'Révoquer tous',
                  icon: Icons.lock_outline_rounded,
                  color: kRed,
                  enabled: module.accessible && module.authorizedProfiles > 0,
                  onTap: () => _confirmRevoke(context, module),
                ),
              ]),
          ]),
        ),

        // Liste profils — scrollable
        Expanded(
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Expanded(
                      child: AdminSectionTitle(
                        'Qui peut utiliser ce module',
                        icon: Icons.lock_person_outlined,
                        subtitle: 'Changements appliqués immédiatement',
                      ),
                    ),
                    const SizedBox(width: 8),
                    AdminBadge(
                      '${module.authorizedProfiles}/${module.totalProfiles}',
                      color: module.authorizedProfiles > 0 ? kGreen : kTextMuted,
                    ),
                  ]),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _filterCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un profil…',
                      hintStyle: const TextStyle(fontSize: 13, color: kTextMuted),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: kTextMuted),
                      suffixIcon: _filterCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16, color: kTextMuted),
                              onPressed: () => setState(() => _filterCtrl.clear()),
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      filled: true,
                      fillColor: kSurface,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(9),
                          borderSide: const BorderSide(color: kBorder)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(9),
                          borderSide: const BorderSide(color: kBorder)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(9),
                          borderSide: const BorderSide(color: kNavy, width: 1.5)),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ]),
              ),

              if (profiles.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      _filterCtrl.text.isEmpty
                          ? 'Aucun profil dans ce groupe'
                          : 'Aucun profil correspondant',
                      style: const TextStyle(color: kTextMuted, fontSize: 13),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: profiles.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, indent: 48),
                  itemBuilder: (_, i) => _PanelProfileRow(
                    slug: widget.slug,
                    moduleId: module.id,
                    profile: profiles[i],
                    enabled: module.accessible,
                  ),
                ),

              // Pied de page
              const SizedBox(height: 8),
              const Divider(height: 1, thickness: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  const Icon(Icons.tune_rounded, size: 14, color: kTextMuted),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      "Réglage fin (9 actions, périmètre) profil par profil : ouvrez Profils d'accès.",
                      style: TextStyle(fontSize: 12, color: kTextMuted, height: 1.4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => context.go(Routes.adminProfils),
                    child: const Text("Profils d'accès",
                        style: TextStyle(color: kNavy, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ],
    );
  }
}

// ─── Widgets helpers panneau ─────────────────────────────────────────────────

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String   value;
  final String   label;
  final Color    color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 8),
        Text(value,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: kTextMuted)),
      ]),
    );
  }
}

class _SchoolAdoptRow extends StatelessWidget {
  const _SchoolAdoptRow({required this.name, required this.uses});
  final String name;
  final bool   uses;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 9, height: 9,
        decoration: BoxDecoration(
          color: uses ? kGreen : Colors.transparent,
          border: Border.all(
              color: uses ? kGreen : kBorder, width: 1.5),
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 12.5,
                color: uses ? kTextPrimary : kTextMuted,
                fontWeight:
                    uses ? FontWeight.w600 : FontWeight.normal)),
      ),
      if (uses)
        const Icon(Icons.check_rounded, size: 13, color: kGreen),
    ]);
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: enabled ? 1.0 : 0.4,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(9),
              border:
                  Border.all(color: color.withValues(alpha: 0.30)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// LIGNE DE PROFIL DANS LE PANNEAU — éditeur de niveau inline
// ═══════════════════════════════════════════════════════════════════════════════

class _PanelProfileRow extends ConsumerStatefulWidget {
  const _PanelProfileRow({
    required this.slug,
    required this.moduleId,
    required this.profile,
    required this.enabled,
  });
  final String slug;
  final String moduleId;
  final ModuleProfileAccess profile;
  final bool enabled;

  @override
  ConsumerState<_PanelProfileRow> createState() => _PanelProfileRowState();
}

class _PanelProfileRowState extends ConsumerState<_PanelProfileRow> {
  bool _saving = false;

  Future<void> _setLevel(String level) async {
    if (_saving) return;
    final p = widget.profile;
    final current = _levelOf(p.perm);
    if (level == current && !_isCustom(p.perm)) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final svc = ref.read(adminAccessServiceProvider);
      final map = {...await ref.read(accessProfilePermsProvider(p.id).future)};
      final scope = map[widget.moduleId]?.dataScope ?? 'own_school';
      if (level == _levelNone) {
        map.remove(widget.moduleId);
      } else {
        map[widget.moduleId] = _presetFor(level, scope);
      }
      final perms = [
        for (final e in map.entries)
          if (!e.value.isEmpty) e.value.toJson(e.key),
      ];
      await svc.savePermissions(p.id, perms);
      ref.invalidate(adminModuleProvider(widget.slug));
      ref.invalidate(adminModulesCatalogProvider);
      messenger.showSnackBar(SnackBar(
        content: Text(level == _levelNone
            ? '${p.name} : accès retiré'
            : '${p.name} : ${level.toLowerCase()}'),
        backgroundColor: kNavy,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Échec de la mise à jour : $e'),
        backgroundColor: kRed,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final level = _levelOf(p.perm);
    final color = _levelColor(level);
    final custom = _isCustom(p.perm);
    final on = level != _levelNone;
    final sub = <String>[
      if (p.roleType != null && p.roleType!.isNotEmpty) p.roleType!,
      '${p.memberCount} membre${p.memberCount > 1 ? "s" : ""}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: (on ? color : kTextMuted).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(_levelIcon(level),
              color: on ? color : kTextMuted, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(p.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary)),
            const SizedBox(height: 2),
            Row(children: [
              Flexible(
                child: Text(sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 12, color: kTextMuted)),
              ),
              if (custom) ...[
                const SizedBox(width: 6),
                Tooltip(
                  message: "Permissions personnalisées définies dans Profils d'accès — "
                      'changer le niveau ici les remplacera.',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: _kPurple.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Text('réglage fin',
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: _kPurple)),
                  ),
                ),
              ],
            ]),
          ]),
        ),
        const SizedBox(width: 10),
        _selector(level, color),
      ]),
    );
  }

  Widget _selector(String level, Color color) {
    final isEnabled = widget.enabled && !_saving;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: widget.enabled ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (_saving)
          const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: kNavy))
        else
          Icon(_levelIcon(level),
              size: 15, color: widget.enabled ? color : kTextMuted),
        const SizedBox(width: 6),
        Text(level,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: widget.enabled ? kTextPrimary : kTextMuted)),
        if (widget.enabled) ...[
          const SizedBox(width: 4),
          const Icon(Icons.expand_more_rounded,
              size: 16, color: kTextMuted),
        ],
      ]),
    );

    if (!isEnabled) return Opacity(opacity: widget.enabled ? 1 : 0.7, child: chip);

    return PopupMenuButton<String>(
      tooltip: "Modifier le niveau d'accès",
      onSelected: _setLevel,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      itemBuilder: (_) => [
        for (final l in _allLevels)
          PopupMenuItem<String>(
            value: l,
            child: Row(children: [
              Icon(_levelIcon(l), size: 16, color: _levelColor(l)),
              const SizedBox(width: 10),
              Text(l,
                  style: const TextStyle(
                      fontSize: 13, color: kTextPrimary)),
              if (l == level) ...[
                const Spacer(),
                const Icon(Icons.check_rounded,
                    size: 16, color: kGreen),
              ],
            ]),
          ),
      ],
      child: chip,
    );
  }
}

// ─── Drag handle panneau (bord gauche) ───────────────────────────────────────

class _PanelResizeHandle extends StatefulWidget {
  const _PanelResizeHandle({required this.onDrag});
  final ValueChanged<double> onDrag;

  @override
  State<_PanelResizeHandle> createState() => _PanelResizeHandleState();
}

class _PanelResizeHandleState extends State<_PanelResizeHandle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onHorizontalDragUpdate: (d) => widget.onDrag(d.delta.dx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 5,
          color: _hovered
              ? kGreen.withValues(alpha: 0.55)
              : kBorder.withValues(alpha: 0.60),
        ),
      ),
    );
  }
}
