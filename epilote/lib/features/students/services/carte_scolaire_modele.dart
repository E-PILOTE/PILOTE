// ═════════════════════════════════════════════════════════════════════════════
//  LA CARTE SCOLAIRE — ce qu'elle EST : format, contenu, règle de délivrance.
//
//  Séparé du dessin (`carte_scolaire_dessin.dart`) et de l'assemblage
//  (`carte_scolaire_pdf_service.dart`) parce que c'est la seule partie que les
//  tests interrogent directement, et la seule qui n'a besoin de RIEN : ni
//  polices, ni logo, ni octets de photo. Une permutation et deux dimensions se
//  vérifient sans rien dessiner.
// ═════════════════════════════════════════════════════════════════════════════

import 'dart:typed_data';

import 'package:pdf/pdf.dart';


/// Dimensions ISO/CEI 7810 ID-1, en points PDF.
const double kCarteLargeur = 85.6 * PdfPageFormat.mm;
const double kCarteHauteur = 54.0 * PdfPageFormat.mm;

/// Disposition de la planche A4.
const int kCartesParRangee = 2;
const int kRangeesParPlanche = 5;
const int kCartesParPlanche = kCartesParRangee * kRangeesParPlanche; // 10

/// Marges et gouttières de la planche. Publiques parce que c'est ce que le
/// garde de format vérifie : cinq rangées de 54 mm laissent 27 mm pour tout le
/// reste sur une A4, et la contrainte se serre par le haut.
const double kMargePlancheH = 14 * PdfPageFormat.mm;
const double kMargePlancheV = 8 * PdfPageFormat.mm;
const double kGouttiereColonne = 6 * PdfPageFormat.mm;
const double kGouttiereRangee = 2 * PdfPageFormat.mm;

/// Statuts d'inscription pour lesquels une carte scolaire est vraie.
///
/// Le même verrou que `peutDelivrerScolarite`, et pour la même raison : la
/// carte affirme une qualité présente. La délivrer à qui est parti fabrique un
/// titre valide au nom d'une école qui ne le reconnaît plus.
bool peutDelivrerCarte(String? enrollmentStatus) => enrollmentStatus == 'active';

/// L'élève tel qu'il apparaît sur sa carte.
class CarteEleve {
  const CarteEleve({
    required this.firstName,
    required this.lastName,
    required this.className,
    required this.matricule,
    this.ine,
    this.gender,
    this.dateOfBirth,
    this.placeOfBirth,
    this.bloodGroup,
    this.isBoarder = false,
    this.photo,
  });

  final String firstName, lastName, className, matricule;
  final String? ine, gender, placeOfBirth, bloodGroup;
  final DateTime? dateOfBirth;
  final bool isBoarder;

  /// Octets de la photo, déjà décodés. `null` = aucune photo disponible sur ce
  /// poste ; la carte s'imprime alors avec un cadre vide et le dit.
  final Uint8List? photo;

  String get fullName => '${lastName.toUpperCase()} $firstName'.trim();
  String get ne => gender == 'F' ? 'Née' : 'Né';

  /// Ce que porte le QR : l'identifiant national s'il existe, le matricule
  /// sinon. Jamais rien d'autre — un QR n'est pas un dossier scolaire, et cette
  /// carte va vivre dans la poche d'un enfant.
  String get codeQr => (ine != null && ine!.isNotEmpty) ? ine! : matricule;
}

/// Découpe un lot en rangées de [kCartesParRangee], et INVERSE l'ordre des
/// colonnes au verso.
///
/// ── POURQUOI CETTE FONCTION EST À PART, ET PUBLIQUE ──────────────────────────
/// C'est le seul endroit du module où une erreur ne se voit pas à l'écran. Une
/// planche verso dans le même ordre que le recto donne des cartes dont le dos
/// appartient au voisin — et on ne s'en aperçoit qu'après avoir découpé.
/// Un aperçu PDF ne le révèle pas non plus : les deux pages semblent correctes
/// séparément. Seule la feuille retournée le montre. Elle est donc isolée pour
/// être testée pour ce qu'elle est : une permutation.
///
/// La feuille se retourne sur son bord LONG : la colonne de gauche au recto
/// revient à droite au verso. Les cases manquantes de la dernière rangée sont
/// `null` — et au verso elles passent à gauche, ce qui est exactement ce qu'il
/// faut : elles sont en face du vide du recto.
List<List<CarteEleve?>> rangeesPlanche(
  List<CarteEleve> lot, {
  required bool verso,
}) {
  final rangees = <List<CarteEleve?>>[];
  for (var i = 0; i < lot.length; i += kCartesParRangee) {
    final r = <CarteEleve?>[
      for (var k = 0; k < kCartesParRangee; k++)
        i + k < lot.length ? lot[i + k] : null,
    ];
    rangees.add(verso ? r.reversed.toList() : r);
  }
  return rangees;
}
