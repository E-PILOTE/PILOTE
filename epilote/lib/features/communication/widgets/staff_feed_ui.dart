import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';

// Helpers texte/dates/rôles et grille média : extraits (règle ≤ 500 lignes)
// et ré-exportés ici — les imports existants restent valides.
export 'comm_text.dart';
export 'feed_media.dart';

// ─── Exécute une action avec retour visuel (spinner → succès / erreur) ────────
/// Bandeau « … en cours » avec indicateur de progression, puis bandeau vert de
/// succès ou ROUGE avec le message d'erreur réel (plus aucune action
/// silencieuse). Renvoie true si l'action a réussi.
Future<bool> runFeedAction(
  BuildContext context, {
  required Future<void> Function() action,
  String running = 'Action en cours…',
  String success = 'Effectué.',
}) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(SnackBar(
    duration: const Duration(minutes: 1),
    behavior: SnackBarBehavior.floating,
    backgroundColor: kNavy,
    content: Row(children: [
      const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
      const SizedBox(width: 14),
      Expanded(child: Text(running)),
    ]),
  ));
  try {
    await action();
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: kGreen,
      duration: const Duration(seconds: 2),
      content: Row(children: [
        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(success)),
      ]),
    ));
    return true;
  } catch (e) {
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: kRed,
      duration: const Duration(seconds: 6),
      content: Row(children: [
        const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text('Échec : $e')),
      ]),
    ));
    return false;
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Composants PARTAGÉS des fils staff (Annonces / Événements) — alignés sur le
// langage admin_groupe (_FilterBar de admin_schools_screen) : barre de filtres
// blanche radius 8, dropdowns actifs navy, chip reset rouge, compteur de
// résultats, modal de lecture riche (AdminDialogHeader gradient).
// ═════════════════════════════════════════════════════════════════════════════

// ─── Avatar de fil (pastille dégradée + icône ou initiales) ─────────────────
class FeedAvatar extends StatelessWidget {
  const FeedAvatar({
    super.key,
    required this.color,
    this.icon,
    this.initials,
    this.avatarUrl,
    this.size = 44,
  });
  final Color color;
  final IconData? icon;
  final String? initials;
  /// Photo de profil ; repli sur l'icône/initiales si absente ou en erreur.
  final String? avatarUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, Colors.black, 0.28)!],
        ),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.28),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      alignment: Alignment.center,
      child: icon != null
          ? Icon(icon, color: Colors.white, size: size * 0.46)
          : Text(initials ?? '?',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.34,
                  fontWeight: FontWeight.w700)),
    );

    final url = avatarUrl?.trim();
    if (url == null || url.isEmpty || !url.startsWith('http')) return fallback;
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, _) => fallback,
        errorWidget: (_, _, _) => fallback,
      ),
    );
  }
}

// ─── Zone de composition (type réseau social) ───────────────────────────────
/// Pastille « Partagez… » qui ouvre le formulaire de publication. Affichée
/// uniquement à ceux qui ont le droit de publier (gouvernance conservée).
class FeedComposer extends StatelessWidget {
  FeedComposer({
    super.key,
    required this.hint,
    required this.onTap,
    Color? avatarColor,
    this.avatarIcon = Icons.campaign_rounded,
    this.actionIcon = Icons.add_rounded,
  }) : avatarColor = avatarColor ?? kNavy;
  final String hint;
  final VoidCallback onTap;
  final Color avatarColor;
  final IconData avatarIcon;
  final IconData actionIcon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Row(children: [
          FeedAvatar(color: avatarColor, icon: avatarIcon, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: kSurface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: kBorder),
                  ),
                  child: Text(hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13.5, color: kTextMuted)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: avatarColor,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(actionIcon, color: Colors.white, size: 20),
              ),
            ),
          ),
        ]),
      );
}

// ─── Audience (annonces & événements) ───────────────────────────────────────
const kAudienceLabels = {
  'all': 'Tout le monde',
  'staff': 'Personnel',
  'teachers': 'Enseignants',
  'parents': 'Parents',
  'students': 'Élèves',
};

Color audienceColor(String a) => switch (a) {
      'all' => kNavy,
      'staff' => const Color(0xFF7C3AED),
      'teachers' => const Color(0xFF0EA5E9),
      'parents' => kAccent,
      'students' => kGreen,
      _ => kTextMuted,
    };

// ─── Conteneur de barre de filtres (style _FilterBar admin) ─────────────────
class StaffFilterCard extends StatelessWidget {
  const StaffFilterCard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kBorder),
        ),
        child: child,
      );
}

// ─── Champ recherche (fond kSurface, croix d'effacement) ────────────────────
class StaffSearchField extends StatelessWidget {
  const StaffSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
  });
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: kTextMuted, fontSize: 13),
          prefixIcon:
              Icon(Icons.search_rounded, color: kTextMuted, size: 20),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded,
                      size: 18, color: kTextMuted),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  })
              : null,
          filled: true,
          fillColor: kSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      );
}

// ─── Dropdown de filtre (état actif navy) ───────────────────────────────────
class StaffFilterDropdown extends StatelessWidget {
  const StaffFilterDropdown({
    super.key,
    required this.icon,
    required this.items,
    required this.value,
    required this.onChanged,
    required this.active,
  });
  final IconData icon;
  final Map<String, String> items;
  final String value;
  final ValueChanged<String> onChanged;
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
        height: 38,
        constraints: const BoxConstraints(minWidth: 140),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: active ? kNavy.withValues(alpha: 0.06) : kSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: active ? kNavy.withValues(alpha: 0.35) : kBorder),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            icon: Icon(Icons.expand_more_rounded,
                size: 14, color: active ? kNavy : kTextMuted),
            style: TextStyle(
              color: active ? kNavy : kTextPrimary,
              fontSize: 12.5,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
            items: items.entries
                .map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(icon, size: 13, color: kTextMuted),
                        const SizedBox(width: 6),
                        Text(e.value),
                      ]),
                    ))
                .toList(),
            onChanged: (v) => onChanged(v ?? value),
          ),
        ),
      );
}

// ─── Toggle « chip » (ex. Épinglées) ────────────────────────────────────────
class StaffToggleChip extends StatelessWidget {
  StaffToggleChip({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    Color? color,
  }) : color = color ?? kAccent;
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: active ? color.withValues(alpha: 0.12) : kSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: active ? color.withValues(alpha: 0.45) : kBorder),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 14,
                  color: active
                      ? Color.lerp(color, Colors.black, 0.25)
                      : kTextMuted),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active
                        ? Color.lerp(color, Colors.black, 0.35)
                        : kTextPrimary,
                  )),
            ]),
          ),
        ),
      );
}

// ─── Chip « Réinitialiser » (rouge, visible si filtres actifs) ──────────────
class StaffResetChip extends StatelessWidget {
  const StaffResetChip({super.key, required this.onTap});
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
                      color: kRed,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      );
}

// ─── Compteur de résultats ──────────────────────────────────────────────────
class StaffResultCount extends StatelessWidget {
  const StaffResultCount({
    super.key,
    required this.filtered,
    required this.total,
    required this.singular,
  });
  final int filtered, total;
  final String singular; // « annonce » / « événement »

  @override
  Widget build(BuildContext context) => Row(children: [
        Text('$filtered $singular${filtered > 1 ? 's' : ''}',
            style: TextStyle(
                color: kTextPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700)),
        if (filtered < total) ...[
          const SizedBox(width: 8),
          Text('sur $total',
              style: TextStyle(color: kTextMuted, fontSize: 13)),
        ],
      ]);
}

// ─── État « aucun résultat de filtre » (≠ état vide global) ─────────────────
class StaffNoResults extends StatelessWidget {
  const StaffNoResults({super.key, required this.onReset});
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: kNavy.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.search_off_rounded,
                  size: 34, color: kNavy.withValues(alpha: 0.55)),
            ),
            const SizedBox(height: 16),
            Text('Aucun résultat',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary)),
            const SizedBox(height: 6),
            Text(
              'Aucun élément ne correspond à votre recherche ou à vos filtres.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: kTextMuted, height: 1.5),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
              label: const Text('Réinitialiser les filtres'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kNavy,
                side: BorderSide(color: kBorder),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                textStyle:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        ),
      );
}

// ─── Coquille de modal de lecture (AdminDialogHeader + corps scrollable) ────
class StaffDetailDialog extends StatelessWidget {
  const StaffDetailDialog({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.subtitle,
    this.width = 620,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget body;
  final double width;

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
        child: Container(
          width: width,
          constraints: const BoxConstraints(maxHeight: 680),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 40,
                  offset: const Offset(0, 10)),
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AdminDialogHeader(icon: icon, title: title, subtitle: subtitle),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                child: body,
              ),
            ),
          ]),
        ),
      );
}


// ─── Distribution en colonnes (grille à hauteurs variables, ordre préservé) ──
/// Répartit [items] sur [columns] colonnes (ligne par ligne : 0→col0, 1→col1…)
/// et rend une Row d'Expanded — les cartes gardent leur hauteur naturelle.
class StaffColumnGrid extends StatelessWidget {
  const StaffColumnGrid({
    super.key,
    required this.columns,
    required this.children,
    this.spacing = 12,
  });
  final int columns;
  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (columns <= 1) {
      return Column(
        children: [
          for (final c in children)
            Padding(padding: EdgeInsets.only(bottom: spacing), child: c),
        ],
      );
    }
    final cols = List.generate(columns, (_) => <Widget>[]);
    for (var i = 0; i < children.length; i++) {
      cols[i % columns].add(Padding(
        padding: EdgeInsets.only(bottom: spacing),
        child: children[i],
      ));
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var c = 0; c < columns; c++) ...[
          if (c > 0) SizedBox(width: spacing),
          Expanded(child: Column(children: cols[c])),
        ],
      ],
    );
  }
}
