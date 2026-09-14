import 'source_bibliotheque.dart';

// Le tableau de bord du groupe est un dossier depuis le 2026-09-05 :
// 2 975 lignes coupees en une coquille et douze `part`. Deux sondes le
// lisaient comme un fichier unique. La regle : `source_bibliotheque.dart`.

const coquilleTableauDeBord =
    'lib/features/admin_groupe/screens/admin_dashboard_screen.dart';
const dossierTableauDeBord =
    'lib/features/admin_groupe/screens/tableau_de_bord';

/// Tout le code du tableau de bord : la coquille ET ses pieces.
String sourceTableauDeBord() => sourceBibliotheque(
      coquille: coquilleTableauDeBord,
      dossier: dossierTableauDeBord,
      minimumPieces: 10,
    );

/// Une piece precise, pour les sondes de proximite.
String sourcePieceTableauDeBord(String nom) =>
    lireSource('$dossierTableauDeBord/$nom');

/// Les tailles de fichiers, pour garder la regle des 500 lignes opposable.
Map<String, int> taillesTableauDeBord() => taillesBibliotheque(
      coquille: coquilleTableauDeBord,
      dossier: dossierTableauDeBord,
    );
