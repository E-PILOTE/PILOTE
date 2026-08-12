/// Dimensions partagées par les composants de l'AppShell.
///
/// Les **couleurs** sont volontairement réutilisées depuis `admin_ui.dart`
/// (`kNavy`, `kGreen`, `kAccent`, `kSurface`, …) pour éviter la divergence de
/// tokens : les valeurs hex y sont identiques à celles historiquement dupliquées
/// dans la sidebar.
library;

const double kSidebarExpandedWidth = 268;
const double kSidebarCollapsedWidth = 64;
const double kSidebarMaxWidth = 340;
const double kShellHeaderHeight = 68;

/// En-dessous de cette largeur, la sidebar passe en mode « réduit » (icônes).
const double kSidebarCollapseThreshold = 120;

/// Largeur de FENÊTRE sous laquelle la barre latérale se replie d'office.
///
/// Une barre déployée coûte 268 px. Sur une fenêtre de 420 px logiques — ce
/// qu'on obtient en réduisant l'application, ou sur un poste à 175 %
/// d'agrandissement — il ne restait que 150 px à tout le reste : l'en-tête
/// débordait, la page n'avait plus de colonne. Le repli est une CONTRAINTE
/// d'affichage, jamais un choix enregistré : la largeur voulue par l'agent est
/// conservée et revient dès que la fenêtre s'élargit.
const double kShellNarrowWidth = 760;
