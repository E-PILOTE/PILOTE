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
