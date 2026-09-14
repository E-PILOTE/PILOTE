import 'source_bibliotheque.dart';

// Les parametres du groupe sont un dossier depuis le 2026-09-05 : 2 468 lignes
// coupees en une coquille et dix `part`. Cinq fichiers de tests lisaient le
// fichier unique. La regle : `source_bibliotheque.dart`.

const coquilleReglages =
    'lib/features/admin_groupe/screens/admin_settings_screen.dart';
const dossierReglages = 'lib/features/admin_groupe/screens/reglages';

/// Tout le code des parametres du groupe : la coquille ET ses pieces.
String sourceEcranReglages() => sourceBibliotheque(
      coquille: coquilleReglages,
      dossier: dossierReglages,
      minimumPieces: 8,
    );

/// Une piece precise, pour les sondes de proximite.
String sourcePieceReglages(String nom) => lireSource('$dossierReglages/$nom');

/// Les tailles de fichiers, pour garder la regle des 500 lignes opposable.
Map<String, int> taillesEcranReglages() => taillesBibliotheque(
      coquille: coquilleReglages,
      dossier: dossierReglages,
    );
