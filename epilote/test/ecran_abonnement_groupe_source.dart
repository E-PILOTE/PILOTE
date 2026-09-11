import 'source_bibliotheque.dart';

// L'ecran d'abonnement du groupe est un dossier depuis le 2026-09-05 :
// 1 494 lignes coupees en une coquille et cinq `part`.
// La regle : `source_bibliotheque.dart`.

const coquilleAbonnementGroupe =
    'lib/features/admin_groupe/screens/admin_subscription_screen.dart';
const dossierAbonnementGroupe =
    'lib/features/admin_groupe/screens/abonnement';

/// Tout le code de l'ecran : la coquille ET ses pieces.
String sourceAbonnementGroupe() => sourceBibliotheque(
      coquille: coquilleAbonnementGroupe,
      dossier: dossierAbonnementGroupe,
      minimumPieces: 4,
    );

/// Les tailles de fichiers, pour garder la regle des 500 lignes opposable.
Map<String, int> taillesAbonnementGroupe() => taillesBibliotheque(
      coquille: coquilleAbonnementGroupe,
      dossier: dossierAbonnementGroupe,
    );
