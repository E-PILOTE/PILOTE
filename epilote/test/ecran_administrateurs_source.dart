import 'source_bibliotheque.dart';

// L'ecran des administrateurs de plateforme est un dossier depuis le
// 2026-09-05 : 3 134 lignes coupees en une coquille et treize `part`.
// La regle et ses raisons : `source_bibliotheque.dart`.

const coquilleAdministrateurs =
    'lib/features/super_admin/screens/administrators_screen.dart';
const dossierAdministrateurs = 'lib/features/super_admin/screens/admins';

/// Tout le code de l'ecran : la coquille ET ses pieces.
String sourceEcranAdministrateurs() => sourceBibliotheque(
      coquille: coquilleAdministrateurs,
      dossier: dossierAdministrateurs,
      minimumPieces: 11,
    );

/// Une piece precise, pour les sondes de proximite.
String sourcePieceAdministrateurs(String nom) =>
    lireSource('$dossierAdministrateurs/$nom');

/// Les tailles de fichiers, pour garder la regle des 500 lignes opposable.
Map<String, int> taillesEcranAdministrateurs() => taillesBibliotheque(
      coquille: coquilleAdministrateurs,
      dossier: dossierAdministrateurs,
    );
