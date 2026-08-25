import 'package:flutter/material.dart';

import 'admin_ui.dart';

// ════════════════════════════════════════════════════════════════════════════
//  BARRE DE FILTRES D'ANNUAIRE — un seul jeu de widgets pour TOUS les annuaires
//
//  Ce kit vient de l'écran « Utilisateurs » de l'admin groupe, où il était né
//  privé. La page Personnel de l'école affiche la même chose — un annuaire de
//  personnes qu'on cherche, qu'on filtre, qu'on regarde en cartes ou en tableau
//  — et l'avait redessinée à sa façon. Deux dessins pour un même geste : deux
//  apprentissages pour l'agent qui passe d'un écran à l'autre, et deux endroits
//  à corriger.
//
//  ── LA RÈGLE DE COMPOSITION ────────────────────────────────────────────────
//  Tout ce qui AGIT SUR LA LISTE se tient juste au-dessus d'elle, dans cette
//  carte : la recherche, les filtres, la bascule cartes/tableau, l'export et
//  l'action principale. Rien de tout cela ne remonte dans l'en-tête de page :
//  un bouton posé à trente centimètres de ce qu'il modifie oblige l'œil à
//  faire l'aller-retour pour comprendre ce qui vient de changer.
//
//  Deux rangées, toujours dans cet ordre :
//    1. chercher (le geste le plus fréquent) → voir → agir ;
//    2. restreindre (les filtres) → et le moyen de tout relâcher d'un clic.
// ════════════════════════════════════════════════════════════════════════════

/// Un filtre déroulant de la deuxième rangée.
///
/// Générique sur la valeur pour qu'un appelant puisse filtrer sur autre chose
/// qu'une chaîne sans convertir ses clés en texte au passage.
class AnnuaireDropdown<T> extends StatelessWidget {
  const AnnuaireDropdown({
    super.key,
    required this.icon,
    required this.label,
    required this.items,
    required this.value,
    required this.onChanged,
    required this.active,
  });

  final IconData icon;
  final String label;
  final List<DropdownMenuItem<T>> items;
  final T value;
  final ValueChanged<T?> onChanged;

  /// Un filtre posé se voit : bordure et texte prennent la couleur d'accent.
  /// Sans ce signal, une liste filtrée se lit comme une liste vide.
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
        height: 38,
        constraints: const BoxConstraints(minWidth: 160, maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: active ? kNavy.withValues(alpha: 0.06) : kSurface,
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: active ? kNavy.withValues(alpha: 0.35) : kBorder),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            icon: Icon(Icons.expand_more_rounded,
                size: 14, color: active ? kNavy : kTextMuted),
            isExpanded: true,
            style: TextStyle(
              color: active ? kNavy : kTextPrimary,
              fontSize: 12.5,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
            items: items,
            onChanged: onChanged,
          ),
        ),
      );
}

/// Segment Tous / Actifs / Inactifs.
class AnnuaireStatusSegment extends StatelessWidget {
  const AnnuaireStatusSegment({
    super.key,
    required this.value,
    required this.onChanged,
    this.labels = const [
      ('all', 'Tous'),
      ('active', 'Actifs'),
      ('inactive', 'Inactifs'),
    ],
  });

  final String value;
  final ValueChanged<String> onChanged;
  final List<(String, String)> labels;

  @override
  Widget build(BuildContext context) {
    Widget seg(String v, String label) {
      final sel = value == v;
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => onChanged(v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: sel ? kNavy : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: sel ? Colors.white : kTextMuted,
                )),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [for (final (v, l) in labels) seg(v, l)],
      ),
    );
  }
}

/// Bascule cartes ⇄ tableau.
class AnnuaireViewToggle extends StatelessWidget {
  const AnnuaireViewToggle(
      {super.key, required this.isTable, required this.onToggle});
  final bool isTable;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Tooltip(
          message: isTable ? 'Vue en cartes' : 'Vue en tableau',
          child: InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kBorder),
              ),
              child: Icon(
                  isTable ? Icons.grid_view_rounded : Icons.table_rows_rounded,
                  size: 18,
                  color: kNavy),
            ),
          ),
        ),
      );
}

/// Bouton carré à icône (export, actualiser…) de la première rangée.
class AnnuaireIconAction extends StatelessWidget {
  const AnnuaireIconAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String tooltip;

  /// `null` désactive : le bouton reste visible mais éteint. Une action qui
  /// disparaît laisse croire qu'elle n'existe pas ; une action grisée dit
  /// qu'elle existe mais pas maintenant.
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = onTap == null ? kTextMuted : (color ?? kNavy);
    return MouseRegion(
      cursor: onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kBorder),
            ),
            child: Icon(icon, size: 18, color: c),
          ),
        ),
      ),
    );
  }
}

/// L'action principale de l'annuaire (créer). Pleine, en dégradé : c'est la
/// seule action de la barre qui écrit.
class AnnuairePrimaryAction extends StatelessWidget {
  const AnnuairePrimaryAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF1A2F5A), kNavy],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: kNavy.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 15, color: Colors.white),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  )),
            ]),
          ),
        ),
      );
}

/// La carte complète : rangée « chercher / voir / agir », puis rangée filtres.
///
/// [filters] est la liste des `AnnuaireDropdown` et autres segments de la
/// deuxième rangée — l'appelant les compose, ce kit ne présume pas de leur
/// nombre. [hasActiveFilters] pilote l'apparition du bouton « Réinitialiser » :
/// il ne s'affiche que s'il a quelque chose à relâcher.
class AnnuaireFilterBar extends StatelessWidget {
  const AnnuaireFilterBar({
    super.key,
    required this.searchCtrl,
    required this.searchHint,
    required this.onSearchChange,
    required this.isTableView,
    required this.onToggleView,
    required this.onReset,
    required this.hasActiveFilters,
    this.filters = const [],
    this.actions = const [],
    this.primaryAction,
    this.width,
  });

  final TextEditingController searchCtrl;
  final String searchHint;
  final ValueChanged<String> onSearchChange;
  final bool isTableView;
  final VoidCallback onToggleView;
  final VoidCallback onReset;
  final bool hasActiveFilters;

  /// Deuxième rangée : déroulants, segments.
  final List<Widget> filters;

  /// Première rangée, entre la bascule de vue et l'action principale.
  final List<Widget> actions;

  final Widget? primaryAction;

  /// Largeur imposée (l'admin groupe la calcule sur son `LayoutBuilder`).
  /// Nulle = la carte prend la largeur disponible.
  final double? width;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: searchCtrl,
              onChanged: onSearchChange,
              decoration: InputDecoration(
                hintText: searchHint,
                hintStyle: TextStyle(color: kTextMuted, fontSize: 13),
                prefixIcon:
                    Icon(Icons.search_rounded, color: kTextMuted, size: 20),
                suffixIcon: searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close_rounded,
                            size: 18, color: kTextMuted),
                        onPressed: () {
                          searchCtrl.clear();
                          onSearchChange('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: kSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          AnnuaireViewToggle(isTable: isTableView, onToggle: onToggleView),
          for (final a in actions) ...[const SizedBox(width: 8), a],
          const SizedBox(width: 8),
          AnnuaireIconAction(
            icon: Icons.refresh_rounded,
            tooltip: 'Réinitialiser les filtres',
            onTap: onReset,
            color: kTextMuted,
          ),
          if (primaryAction != null) ...[
            const SizedBox(width: 12),
            primaryAction!,
          ],
        ]),
        if (filters.isNotEmpty) ...[
          const SizedBox(height: 10),
          // ⚠️ `Wrap`, pas `Row`. Le nombre de filtres varie d'un annuaire à
          // l'autre (trois déroulants et un segment côté Personnel), et le
          // « Réinitialiser » n'apparaît qu'une fois un filtre posé : la rangée
          // débordait alors de quelques dizaines de pixels — rayures jaunes en
          // plein milieu de l'écran, au moment précis où l'agent vient de
          // filtrer. Un retour à la ligne coûte dix pixels de hauteur et ne
          // peut jamais déborder.
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Wrap(spacing: 8, runSpacing: 8, children: filters),
            ),
            if (hasActiveFilters) ...[
              const SizedBox(width: 8),
              AnnuaireResetChip(onTap: onReset),
            ],
          ]),
        ],
      ]),
    );

    return width == null ? card : SizedBox(width: width, child: card);
  }
}

/// Bouton « Réinitialiser » de la rangée filtres.
class AnnuaireResetChip extends StatelessWidget {
  const AnnuaireResetChip({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: kRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kRed.withValues(alpha: 0.25)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.filter_alt_off_rounded, size: 13, color: kRed),
              const SizedBox(width: 4),
              Text('Réinitialiser',
                  style: TextStyle(
                      color: kRed, fontSize: 11.5, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      );
}

/// « N résultats sur M » — dit toujours le total quand la liste est filtrée,
/// pour qu'un filtre trop serré ne se confonde pas avec un annuaire vide.
class AnnuaireResultHeader extends StatelessWidget {
  const AnnuaireResultHeader(
      {super.key, required this.total, required this.filtered, this.unit = 'résultat'});
  final int total, filtered;
  final String unit;

  @override
  Widget build(BuildContext context) => Row(children: [
        Text('$filtered $unit${filtered > 1 ? 's' : ''}',
            style: TextStyle(
                color: kTextPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
        if (filtered < total) ...[
          const SizedBox(width: 8),
          Text('sur $total', style: TextStyle(color: kTextMuted, fontSize: 13)),
        ],
      ]);
}
