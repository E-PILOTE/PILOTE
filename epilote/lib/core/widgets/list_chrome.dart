import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import 'admin_ui.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CHROME DES LISTES SUPER_ADMIN — KPI · filtres · bascule tableau/cartes.
//
//  ── POURQUOI CE FICHIER EXISTE ─────────────────────────────────────────────
//  `administrators_screen.dart` (3124 lignes) porte ce chrome en interne : KPI
//  animés, barre de filtres, bascule de vue, en-tête de résultats. C'est la
//  référence visuelle du projet — mais elle est enfermée dans un écran, en
//  `_privé`, donc chaque nouvel écran le RECOPIE. Trois copies plus tard, la
//  cohérence se perd et le fichier de 3124 lignes se duplique.
//
//  Ce fichier extrait le chrome, une fois. Les écrans neufs s'en servent ;
//  les écrans hérités migreront quand on les touchera (règle du projet : les
//  fichiers > 500 lignes se refondent au fil des modifications).
//
//  ── DÉTAILS QUI COMPTENT ───────────────────────────────────────────────────
//  • Le bouton « + » vit DANS la barre de filtres, jamais dans l'AppShell :
//    c'est là qu'il est dans Administrateurs, et c'est là que l'œil le cherche.
//  • Les couleurs sont des JETONS RUNTIME (thèmes Clair · Sombre · Melack) :
//    aucun `const` sur un widget qui en porte une.
// ════════════════════════════════════════════════════════════════════════════

/// Deux teintes que la palette globale n'a pas — reprises d'administrators.
const kListPurple = Color(0xFF7C3AED);
const kListOrange = Color(0xFFFF6B35);

// ── KPI ─────────────────────────────────────────────────────────────────────

class KpiData {
  const KpiData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.sub,
    this.trend,
    this.trendUp = true,
    this.progressValue,
  });

  final String label;
  final String value;
  final String? sub;
  final String? trend;
  final bool trendUp;

  /// 0..1 — la barre sous la carte. `null` = pas de barre.
  final double? progressValue;
  final IconData icon;
  final Color color;
}

class KpiGrid extends StatelessWidget {
  const KpiGrid({super.key, required this.items});
  final List<KpiData> items;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, c) {
        final cols = c.maxWidth > 1180 ? 3 : (c.maxWidth > 720 ? 2 : 1);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            // Convention du projet : jamais childAspectRatio pour un KPI —
            // il produit des cartes qui se déforment au redimensionnement.
            mainAxisExtent: 118,
          ),
          itemCount: items.length,
          itemBuilder: (_, i) => KpiCard(d: items[i], idx: i),
        );
      });
}

class KpiCard extends StatefulWidget {
  const KpiCard({super.key, required this.d, required this.idx});
  final KpiData d;

  /// Décale l'entrée en fondu — les cartes arrivent en cascade.
  final int idx;

  @override
  State<KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<KpiCard> with SingleTickerProviderStateMixin {
  bool _hov = false;
  late final AnimationController _entry;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    _fade = CurvedAnimation(parent: _entry, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entry, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: 60 * widget.idx), () {
      if (mounted) _entry.forward();
    });
  }

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hov = true),
          onExit: (_) => setState(() => _hov = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: _hov ? 0.08 : 0.04),
                  blurRadius: _hov ? 12 : 4,
                  offset: Offset(0, _hov ? 4 : 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        d.color,
                        d.color.withValues(alpha: _hov ? 0.9 : 0.4),
                      ]),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(d.value,
                                        style: TextStyle(
                                          color: d.color,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.5,
                                        )),
                                    const SizedBox(height: 2),
                                    Text(d.label,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: kTextMuted,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                        )),
                                    if (d.sub != null)
                                      Text(d.sub!,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color:
                                                d.color.withValues(alpha: 0.70),
                                            fontSize: 10,
                                          )),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: kSurface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: kBorder),
                                ),
                                child: Icon(d.icon, color: d.color, size: 18),
                              ),
                            ],
                          ),
                          const Spacer(),
                          if (d.progressValue != null)
                            Row(children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: d.progressValue!.clamp(0.0, 1.0),
                                    backgroundColor:
                                        d.color.withValues(alpha: 0.08),
                                    valueColor: AlwaysStoppedAnimation(
                                        d.color.withValues(
                                            alpha: _hov ? 1.0 : 0.75)),
                                    minHeight: 4,
                                  ),
                                ),
                              ),
                              if (d.trend != null) ...[
                                const SizedBox(width: 8),
                                Text(d.trend!,
                                    style: TextStyle(
                                      color: d.trendUp ? d.color : kListOrange,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    )),
                              ],
                            ]),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Barre de filtres ────────────────────────────────────────────────────────

class ListFilterBar extends StatelessWidget {
  const ListFilterBar({
    super.key,
    required this.searchCtrl,
    required this.searchHint,
    required this.isTableView,
    required this.onSearchChange,
    required this.onToggleView,
    required this.onReset,
    required this.onAdd,
    required this.addLabel,
    required this.addIcon,
    this.filters = const [],
  });

  final TextEditingController searchCtrl;
  final String searchHint;
  final bool isTableView;
  final ValueChanged<String> onSearchChange;
  final VoidCallback onToggleView;
  final VoidCallback onReset;

  /// `null` masque le bouton — un rôle sans droit de créer ne doit pas le voir.
  final VoidCallback? onAdd;
  final String addLabel;
  final IconData addIcon;

  /// Seconde ligne : les listes déroulantes propres à l'écran.
  final List<Widget> filters;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: searchCtrl,
                  onChanged: onSearchChange,
                  style: TextStyle(fontSize: 13, color: kTextPrimary),
                  decoration: InputDecoration(
                    hintText: searchHint,
                    hintStyle: TextStyle(color: kTextMuted, fontSize: 13),
                    prefixIcon:
                        Icon(Icons.search_rounded, color: kTextMuted, size: 20),
                    suffixIcon: searchCtrl.text.isEmpty
                        ? null
                        : IconButton(
                            icon: Icon(Icons.close_rounded,
                                size: 18, color: kTextMuted),
                            onPressed: () {
                              searchCtrl.clear();
                              onSearchChange('');
                            },
                          ),
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
              _SquareBtn(
                icon: isTableView
                    ? Icons.grid_view_rounded
                    : Icons.table_rows_rounded,
                tooltip: isTableView ? 'Vue en cartes' : 'Vue en tableau',
                color: kNavy,
                onTap: onToggleView,
              ),
              const SizedBox(width: 8),
              _SquareBtn(
                icon: Icons.refresh_rounded,
                tooltip: 'Réinitialiser les filtres',
                color: kTextMuted,
                onTap: onReset,
              ),
              if (onAdd != null) ...[
                const SizedBox(width: 12),
                _AddBtn(label: addLabel, icon: addIcon, onTap: onAdd!),
              ],
            ]),
            if (filters.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(children: [
                for (final (i, f) in filters.indexed) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(child: f),
                ],
              ]),
            ],
          ],
        ),
      );
}

class _SquareBtn extends StatelessWidget {
  const _SquareBtn({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
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
              child: Icon(icon, size: 19, color: color),
            ),
          ),
        ),
      );
}

class _AddBtn extends StatelessWidget {
  const _AddBtn({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
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
                ),
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

class ListFilterDropdown extends StatelessWidget {
  const ListFilterDropdown({
    super.key,
    required this.icon,
    required this.label,
    required this.items,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final Map<String, String> items;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kBorder),
        ),
        child: Row(children: [
          Icon(icon, size: 15, color: kTextMuted),
          const SizedBox(width: 7),
          Text('$label :',
              style: TextStyle(
                  fontSize: 11.5,
                  color: kTextMuted,
                  fontWeight: FontWeight.w600)),
          // Sans cet écart, le libellé et la valeur se collent (« Statut :Actifs »)
          // et se lisent comme un seul mot.
          const SizedBox(width: 5),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                isDense: true,
                dropdownColor: kCardBg,
                style: TextStyle(fontSize: 12.5, color: kTextPrimary),
                icon: Icon(Icons.expand_more_rounded, size: 17, color: kTextMuted),
                items: [
                  for (final e in items.entries)
                    DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => v == null ? null : onChanged(v),
              ),
            ),
          ),
        ]),
      );
}

class ListResultHeader extends StatelessWidget {
  const ListResultHeader({
    super.key,
    required this.total,
    required this.filtered,
    this.noun = 'résultat',
  });

  final int total;
  final int filtered;
  final String noun;

  @override
  Widget build(BuildContext context) => Row(children: [
        Text('$filtered $noun${filtered > 1 ? 's' : ''}',
            style: TextStyle(
                color: kTextPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
        if (filtered < total) ...[
          const SizedBox(width: 8),
          Text('sur $total', style: TextStyle(color: kTextMuted, fontSize: 13)),
        ],
      ]);
}

// ── Squelette de chargement ───────────────────────────────────────────────────

/// Squelette animé pendant le chargement, calqué sur `administrators_screen`
/// (`_ShimmerSkeleton`) : grille de KPI → graphique → en-tête → lignes. Reprend
/// la même grammaire que le contenu réel pour éviter le saut de mise en page.
class ListShimmer extends StatelessWidget {
  const ListShimmer({super.key, this.kpiCount = 6, this.rowCount = 6});

  final int kpiCount;
  final int rowCount;

  Widget _box(double w, double h, {double r = 10}) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(r),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE8ECF0),
      highlightColor: const Color(0xFFF5F7FA),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                mainAxisExtent: 118,
              ),
              itemCount: kpiCount,
              itemBuilder: (_, _) => _box(double.infinity, double.infinity, r: 14),
            ),
            const SizedBox(height: 20),
            _box(double.infinity, 220, r: 14),
            const SizedBox(height: 20),
            _box(double.infinity, 52, r: 10),
            const SizedBox(height: 16),
            _box(180, 18, r: 8),
            const SizedBox(height: 12),
            _box(double.infinity, 46, r: 6),
            const SizedBox(height: 1),
            for (var i = 0; i < rowCount; i++) ...[
              const SizedBox(height: 1),
              _box(double.infinity, 56, r: 0),
            ],
          ],
        ),
      ),
    );
  }
}
