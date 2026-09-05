import 'source_bibliotheque.dart';

// Le tableau de bord de la plateforme est un dossier depuis le 2026-09-05 :
// 2 689 lignes coupees en une coquille et onze `part`.
// La regle : `source_bibliotheque.dart`.

const coquilleDashboardFondateur =
    'lib/features/super_admin/screens/super_dashboard_screen.dart';
const dossierDashboardFondateur =
    'lib/features/super_admin/screens/super_dash';

/// Tout le code du tableau de bord fondateur : la coquille ET ses pieces.
String sourceDashboardFondateur() => sourceBibliotheque(
      coquille: coquilleDashboardFondateur,
      dossier: dossierDashboardFondateur,
      minimumPieces: 9,
    );

/// Les tailles de fichiers, pour garder la regle des 500 lignes opposable.
Map<String, int> taillesDashboardFondateur() => taillesBibliotheque(
      coquille: coquilleDashboardFondateur,
      dossier: dossierDashboardFondateur,
    );
