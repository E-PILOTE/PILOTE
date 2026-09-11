part of '../admin_modules_screen.dart';

// Vues cartes et tableau du catalogue.

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
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
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
        color: kCardBg,
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
                            style: TextStyle(
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
                          Icon(Icons.verified_rounded,
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
