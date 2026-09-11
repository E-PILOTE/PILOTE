import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../admin_ui.dart' show kNavyDark, kAccent;
import '../../constants/routes.dart';
import '../../../data/models/profile_model.dart';
import '../../../features/navigation/module_routes.dart';
import '../../../licensing/presentation/license_providers.dart';
import 'nav_models.dart';
import 'nav_tile.dart';
import 'shell_providers.dart';
import 'sidebar_footer.dart';
import 'sidebar_header.dart';

/// Sidebar complète : en-tête + sections défilantes + sections épinglées (bas)
/// + footer. Reçoit des [NavSection] déjà construites et notifie la navigation
/// via [onNavigate]. Les sections titrées non épinglées sont repliables.
class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.sections,
    required this.expanded,
    required this.currentLocation,
    required this.messageBadge,
    required this.profile,
    required this.onNavigate,
  });

  final List<NavSection> sections;
  final bool expanded;
  final String currentLocation;
  final int messageBadge;
  final ProfileModel? profile;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {

    final active = activeNavRoute(currentLocation, navRoutes(sections));
    final top = [for (final s in sections) if (s.pinnedTop) s];
    final scrolling = [
      for (final s in sections)
        if (!s.pinned && !s.pinnedTop) s
    ];
    final pinned = [for (final s in sections) if (s.pinned) s];

    Widget sectionView(NavSection s) => _NavSectionView(
          section: s,
          expanded: expanded,
          activeRoute: active,
          messageBadge: messageBadge,
          onNavigate: onNavigate,
        );

    return Container(
      color: kNavyDark,
      child: Column(
        children: [
          SidebarHeader(expanded: expanded),
          if (top.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [for (final s in top) sectionView(s)],
              ),
            ),
          // ── LA ZONE DÉFILANTE ────────────────────────────────────────
          //
          //  ⚠️ PAS DE BARRE DE DÉFILEMENT — décision du fondateur, 2026-09-03.
          //
          //  Une `Scrollbar(thumbVisibility: true)` a été essayée puis retirée
          //  après l'avoir vue à l'écran : elle balafre une barre latérale qui
          //  est un aplat sombre, et elle s'y voit d'autant plus qu'elle ne
          //  sert qu'aux profils les plus chargés.
          //
          //  Ce qu'elle visait reste vrai : sur un petit écran, les dernières
          //  catégories passent sous la ligne de flottaison et le bloc épinglé
          //  juste en dessous fait croire à une liste terminée. Le FILET qui
          //  sépare les deux zones (voir plus bas) porte désormais seul ce
          //  rôle — et trois lignes mortes ont été récupérées entre-temps
          //  (migration 0176), ce qui abaisse d'autant la pression.
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 6),
              children: [for (final s in scrolling) sectionView(s)],
            ),
          ),
          // ── LE BLOC ÉPINGLÉ ──────────────────────────────────────────────
          //
          //  ⚠️ LE FILET DIT « SOUS CETTE LIGNE, RIEN NE DÉFILE ».
          //
          //  COMMUNICATION et SYSTÈME portent le même titre, la même graisse
          //  et la même casse que GESTION — mais celles du haut défilent, pas
          //  celles-ci. Rien à l'écran ne distinguait les deux comportements :
          //  deux sections d'apparence identique réagissaient différemment, ce
          //  qui se lit comme un défaut plutôt que comme une intention. Le
          //  filet est la plus petite marque qui les sépare.
          //
          //  Il ne dit RIEN du repli : les deux blocs d'ici se replient
          //  comme les catégories du haut, et leur chevron l'annonce. Être
          //  épinglé, c'est rester à portée — pas être figé.
          if (pinned.isNotEmpty) ...[
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: Colors.white.withValues(alpha: 0.10),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [for (final s in pinned) sectionView(s)],
            ),
          ],
          SidebarFooter(expanded: expanded, profile: profile),
        ],
      ),
    );
  }
}

/// Rendu d'une section : en-tête (repliable si titrée + non épinglée) + entrées.
class _NavSectionView extends ConsumerWidget {
  const _NavSectionView({
    required this.section,
    required this.expanded,
    required this.activeRoute,
    required this.messageBadge,
    required this.onNavigate,
  });

  final NavSection section;
  final bool expanded;
  final String? activeRoute;
  final int messageBadge;
  final ValueChanged<String> onNavigate;

  bool get _containsActive =>
      activeRoute != null && section.entries.any((e) => e.route == activeRoute);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasTitle = section.title.isNotEmpty;
    // Repliable si titrée, en mode étendu (en mode icônes il n'y a pas
    // d'en-tête à cliquer), et si la section le veut bien — par défaut, toute
    // section titrée non épinglée.
    //
    // ⚠️ « Épinglé » n'implique plus « figé » : COMMUNICATION reste en bas,
    // hors défilement, et se replie quand même. Les deux propriétés étaient
    // confondues dans un seul test ; c'est `NavSection.collapsible` qui les
    // sépare désormais.
    final collapsible = sectionEstRepliable(section, expanded: expanded);

    // Hard-lock d'abonnement (ADR-0009) : les entrées de MODULE deviennent des
    // clics morts (grisées + cadenas). Fail-soft : non-enforcé / grâce / lecture
    // seule / plan public → false. Les entrées hors catalogue (Dashboard, Profil,
    // Paramètres, natives) ne sont jamais verrouillées (moduleSlugForLocation == null).
    final hardLocked = ref
            .watch(entitlementProvider)
            .valueOrNull
            ?.isHardLockedAt(DateTime.now().toUtc()) ??
        false;

    // La section de la page courante est toujours dépliée (on ne cache jamais
    // où l'on se trouve). Idem en mode icônes : pas de repli.
    final collapsed = collapsible &&
        !_containsActive &&
        ref.watch(collapsedNavSectionsProvider).contains(section.title);

    final entries = [
      for (final e in section.entries)
        if (e.isInfo)
          _InfoRow(entry: e, expanded: expanded)
        else
          NavTile(
            entry: e,
            isActive: e.route == activeRoute,
            expanded: expanded,
            badge: _badgeFor(e.route),
            locked: hardLocked && moduleSlugForLocation(e.route) != null,
            onTap: () => onNavigate(e.route),
          ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasTitle)
          _SectionHeader(
            label: section.title,
            expanded: expanded,
            collapsible: collapsible,
            collapsed: collapsed,
            onToggle: collapsible
                ? () => ref
                    .read(collapsedNavSectionsProvider.notifier)
                    .basculer(section.title)
                : null,
          ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: collapsed
              ? const SizedBox(width: double.infinity)
              : Column(mainAxisSize: MainAxisSize.min, children: entries),
        ),
      ],
    );
  }

  int _badgeFor(String route) {
    final isMsg =
        route == Routes.adminMessagerie || route == Routes.messagerie;
    return isMsg ? messageBadge : 0;
  }
}

// ─── En-tête de section (avec chevron de repli si applicable) ───────────────
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.label,
    required this.expanded,
    required this.collapsible,
    required this.collapsed,
    required this.onToggle,
  });

  final String label;
  final bool expanded;
  final bool collapsible;
  final bool collapsed;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final white = Colors.white;
    if (!expanded) {
      // Mode réduit : fine ligne de séparation entre groupes.
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        child: Divider(height: 1, color: white.withValues(alpha: 0.08)),
      );
    }

    // ⚠️ Le titre est borné À LA MAIN, pas par un `Flexible`.
    // Dans un `Row`, un enfant souple et un `Expanded` se partagent l'espace
    // libre à parts égales : le titre n'aurait plus que la moitié de la largeur
    // et « FORMATION PROFESSIONNELLE » serait tronqué même au repos. Sans
    // contrainte du tout — l'état précédent — c'est l'inverse : la barre déborde
    // et Flutter jette une exception à chaque image pendant l'animation de
    // repli. On réserve donc une largeur minimale au filet et on laisse le
    // titre prendre le reste, en l'abrégeant s'il le faut.
    const kRuleMin = 16.0;
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 5),
      child: LayoutBuilder(builder: (context, c) {
        final reserved = (collapsible ? 20.0 : 0.0) + 8 + kRuleMin;
        final maxLabel =
            (c.maxWidth - reserved).clamp(0.0, double.infinity);
        return Row(
          children: [
            if (collapsible) ...[
              AnimatedRotation(
                turns: collapsed ? -0.25 : 0, // ▸ replié / ▾ déplié
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: white.withValues(alpha: 0.40),
                ),
              ),
              const SizedBox(width: 4),
            ],
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxLabel),
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: white.withValues(alpha: 0.38),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Divider(height: 1, color: white.withValues(alpha: 0.10)),
            ),
          ],
        );
      }),
    );

    if (!collapsible) return header;
    return _HoverableHeader(onTap: onToggle!, child: header);
  }
}

/// En-tête cliquable avec retour de survol (curseur + léger fond).
class _HoverableHeader extends StatefulWidget {
  const _HoverableHeader({required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_HoverableHeader> createState() => _HoverableHeaderState();
}

class _HoverableHeaderState extends State<_HoverableHeader> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: ColoredBox(
          color: _hovered
              ? Colors.white.withValues(alpha: 0.03)
              : Colors.transparent,
          child: widget.child,
        ),
      ),
    );
  }
}

// ─── Ligne d'information non cliquable (synchro / aucun module) ─────────────
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.entry, required this.expanded});
  final NavEntry entry;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final white = Colors.white;
    if (!expanded) {
      return entry.loading
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: kAccent,
                  ),
                ),
              ),
            )
          : const SizedBox(height: 8);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 14, 6),
      child: Row(
        children: [
          if (entry.loading)
            SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(strokeWidth: 2, color: kAccent),
            )
          else
            Icon(
              Icons.info_outline_rounded,
              size: 14,
              color: white.withValues(alpha: 0.4),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entry.label,
              style: TextStyle(
                color: white.withValues(alpha: 0.5),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
