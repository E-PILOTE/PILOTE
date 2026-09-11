import 'source_bibliotheque.dart';

// L'ecran des groupes scolaires est un dossier depuis le 2026-09-05 :
// 3 400 lignes coupees en une coquille et quatorze `part`. Six fichiers de
// tests lisaient le fichier unique ; ils lisent desormais la bibliotheque.
// La regle et ses raisons : `source_bibliotheque.dart`.

const coquilleGroupes =
    'lib/features/super_admin/screens/school_groups_screen.dart';
// ⚠️ UN SEUL dossier de `part` pour cette bibliotheque. Le decoupage du
// 2026-09-05 en avait cree un second (`groupes/`, en francais) a cote de
// celui qui existait deja (`groups/`) : les sondes lisaient l'un et le code
// vivait dans les deux.
const dossierGroupes = 'lib/features/super_admin/screens/groups';

/// Tout le code de l'ecran des groupes : la coquille ET ses pieces.
String sourceEcranGroupes() => sourceBibliotheque(
      coquille: coquilleGroupes,
      dossier: dossierGroupes,
      minimumPieces: 18,
    );

/// Une piece precise, pour les sondes de proximite.
String sourcePieceGroupes(String nom) => lireSource('$dossierGroupes/$nom');

/// Les tailles de fichiers, pour garder la regle des 500 lignes opposable.
Map<String, int> taillesEcranGroupes() => taillesBibliotheque(
      coquille: coquilleGroupes,
      dossier: dossierGroupes,
    );

/// Le formulaire de groupe : sa classe ET sa mise en page.
///
/// `group_form_modal.dart` faisait 557 lignes ; son `build` de 319 lignes est
/// parti dans `group_form_layout.dart`. Trois fichiers de tests lisaient « le
/// formulaire » et n'y trouvaient plus la moitie de ce qu'ils gardent.
///
/// L'ordre est stable — la classe, puis la mise en page — mais une sonde de
/// PROXIMITE (« cet appel suit bien cette affectation ») doit rester a
/// l'interieur d'une seule moitie : la concatenation ne dit rien de la distance
/// entre deux fichiers.
String sourceFormulaireGroupe() =>
    '${sourcePieceGroupes('group_form_modal.dart')}\n'
    '${sourcePieceGroupes('group_form_layout.dart')}';
