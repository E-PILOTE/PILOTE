part of '../admin_modules_screen.dart';

// Corps du catalogue.

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
