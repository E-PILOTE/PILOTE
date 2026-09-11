import 'package:flutter/material.dart';

/// Modèle déclaratif de la navigation latérale (sidebar).
///
/// Une [NavSection] est un groupe titré d'[NavEntry]. Le drapeau [pinned]
/// remplace l'ancien test fragile `sectionLabel.contains('SYSTÈME')` : une
/// section épinglée est rendue en bas (zone footer), le reste défile.
/// [pinnedTop] ancre au contraire la section en HAUT, hors-scroll (ex. le
/// « Tableau de bord » : toujours visible quel que soit le nombre de modules).
///
/// Une [NavEntry] est soit un item navigable (`NavEntry.item`), soit une ligne
/// d'information non cliquable (`NavEntry.info`, ex. « Synchronisation… »).
class NavSection {
  const NavSection({
    required this.title,
    required this.entries,
    this.pinned = false,
    this.pinnedTop = false,
  });

  /// Libellé de section. Vide = aucun en-tête (ex. le « Tableau de bord » seul).
  final String title;

  final List<NavEntry> entries;

  /// Épinglée en bas de la sidebar (juste au-dessus du footer).
  final bool pinned;

  /// Épinglée en haut de la sidebar (sous l'en-tête, hors zone défilante).
  final bool pinnedTop;
}

/// Une section se replie-t-elle par son en-tête ?
///
/// ⚠️ RÈGLE EXTRAITE ICI POUR ÊTRE TESTÉE. Elle vivait en une ligne au milieu
/// du `build()` de la barre — donc vérifiable seulement en rendant tout le
/// shell (licence, synchro, profil), ce qu'aucun test ne fait. Une règle qu'on
/// ne peut pas éprouver se casse en silence.
///
/// ⚠️ ÊTRE ÉPINGLÉ N'EST PAS ÊTRE FIGÉ. La règle a longtemps été
/// `titrée && !épinglée` : une seule ligne pour deux questions sans rapport —
/// *où* la section est rendue (en bas, hors défilement) et *si* on peut en
/// masquer les entrées. COMMUNICATION et SYSTÈME restent en bas, à portée, et
/// se replient comme les autres : un agent qui n'écrit pas de la journée
/// préfère rendre ces lignes à ses modules.
///
/// - Pas de titre → rien à cliquer. C'est le cas du bloc de tête (« Tableau de
///   bord » seul) : lui donner un chevron reviendrait à proposer de masquer la
///   seule entrée toujours visible de la barre.
/// - [expanded] faux (barre en mode icônes) → pas d'en-tête à l'écran, donc
///   rien à replier.
bool sectionEstRepliable(NavSection s, {required bool expanded}) =>
    s.title.isNotEmpty && expanded;

class NavEntry {
  /// Item navigable.
  const NavEntry.item({
    required IconData this.icon,
    required this.label,
    required this.route,
  })  : isInfo = false,
        loading = false;

  /// Ligne d'information non cliquable (ex. « Aucun module attribué »).
  const NavEntry.info(this.label, {this.loading = false})
      : icon = null,
        route = '',
        isInfo = true;

  final IconData? icon;
  final String label;
  final String route;
  final bool isInfo;
  final bool loading;
}

/// Toutes les routes navigables d'une liste de sections (pour le calcul de
/// l'item actif).
List<String> navRoutes(List<NavSection> sections) => [
      for (final s in sections)
        for (final e in s.entries)
          if (!e.isInfo && e.route.isNotEmpty) e.route,
    ];

/// Route active = **préfixe le plus long** qui correspond à l'emplacement
/// courant. Corrige les faux positifs de l'ancien `startsWith` brut
/// (ex. `/user/eleves` ne s'allume plus sous `/user/eleves-transferts`).
String? activeNavRoute(String location, List<String> routes) {
  String? best;
  for (final r in routes) {
    if (r.isEmpty || r == '/') continue;
    if (location == r || location.startsWith('$r/')) {
      if (best == null || r.length > best.length) best = r;
    }
  }
  return best;
}
