import '../../../core/utils/ine.dart';
import '../providers/students_registry_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CE QUE LA PAGE ÉLÈVES MONTRE, ET DANS QUEL ORDRE
//
//  ── POURQUOI HORS DE L'ÉCRAN ───────────────────────────────────────────────
//  Le tri et les filtres décidaient à eux seuls de ce qu'un agent voit d'une
//  école de huit cents élèves, et ils vivaient dans une méthode privée d'un
//  `State` : invérifiables autrement qu'en rejouant l'écran à la main.
//
//  ── LES DEUX MANQUES QU'ILS COMBLENT ───────────────────────────────────────
//  1. LES PARTICULARITÉS N'ÉTAIENT PAS FILTRABLES. La page affiche pourtant
//     « Internes : 42 » et « Boursiers / aidés : 17 » en gros, tout en haut —
//     et aucun moyen d'obtenir les 42 noms. Or c'est une liste qu'une école
//     produit vraiment : le dortoir, la cantine, le dossier de bourse. Le
//     chiffre était là, la liste inaccessible.
//  2. LA RECHERCHE IGNORAIT L'IDENTIFIANT NATIONAL. C'est pourtant le numéro
//     qui arrive d'ailleurs — sur un certificat de radiation, dans un appel du
//     ministère — et la seule chose qu'on ait parfois d'un enfant. Le chercher
//     ici ne donnait rien, alors que la fiche l'affiche.
//     Il se cherche sous n'importe quelle forme : « 26-00000123-4 » comme
//     « 26000001234 », puisque c'est ainsi qu'il se dicte et se recopie.
// ════════════════════════════════════════════════════════════════════════════

/// Les statuts particuliers sur lesquels la liste peut se restreindre.
///
/// Les clés sont celles des cartes KPI de l'en-tête : cliquer sur « Internes »
/// doit donner exactement la liste que ce chiffre compte.
const Map<String, String> kParticularitesEleve = {
  'interne': 'Internes',
  'affecte': 'Affectés MEPSA/METP',
  'boursier': 'Boursiers',
  'aide_sociale': 'Aide sociale',
  'boursier_ou_aide': 'Boursiers / aidés',
};

/// L'élève porte-t-il la particularité [code] ? `null` = pas de restriction.
bool porteParticularite(StudentRow s, String? code) => switch (code) {
      null || '' => true,
      'interne' => s.isBoarder,
      'affecte' => s.isAffecte,
      'boursier' => s.hasScholarship,
      'aide_sociale' => s.hasSocialAid,
      'boursier_ou_aide' => s.hasScholarship || s.hasSocialAid,
      // Un code inconnu ne doit RIEN masquer : mieux vaut une liste complète
      // qu'une liste vide qu'on prendrait pour « aucun élève concerné ».
      _ => true,
    };

/// L'élève répond-il à la recherche libre [requete] ?
///
/// Nom, prénom, matricule, classe — et l'identifiant national, comparé chiffres
/// à chiffres pour que la forme affichée et la forme dictée se valent.
bool correspondRecherche(StudentRow s, String requete) {
  final q = requete.trim().toLowerCase();
  if (q.isEmpty) return true;
  if (s.fullName.toLowerCase().contains(q)) return true;
  if (s.matricule.toLowerCase().contains(q)) return true;
  if ((s.className ?? '').toLowerCase().contains(q)) return true;

  final ine = normalizeIne(s.ine);
  if (ine == null) return false;
  final chiffres = normalizeIne(q);
  // Une requête sans aucun chiffre ne peut pas viser un INE : la comparer
  // ferait correspondre n'importe quel élève dès que `chiffres` est nul.
  return chiffres != null && ine.contains(chiffres);
}

/// La liste telle que la page l'affiche : filtrée puis triée sur « NOM Prénom ».
///
/// Le tri se fait sur [StudentRow.lastFirst] et non sur le nom complet : c'est
/// l'ordre d'un registre d'école, celui dans lequel on cherche un élève.
List<StudentRow> filtrerEleves(
  List<StudentRow> tous, {
  String recherche = '',
  String? sexe,
  String? particularite,
  String? cycle,
  String? niveau,
  String? classeId,
  bool triAscendant = true,
}) {
  final out = tous.where((s) {
    if (sexe != null && s.gender != sexe) return false;
    if (!porteParticularite(s, particularite)) return false;
    if (cycle != null && (s.cycleCode ?? '') != cycle) return false;
    if (niveau != null && (s.levelCode ?? '') != niveau) return false;
    if (classeId != null && s.classId != classeId) return false;
    return correspondRecherche(s, recherche);
  }).toList()
    ..sort((a, b) {
      final c = a.lastFirst.toLowerCase().compareTo(b.lastFirst.toLowerCase());
      return triAscendant ? c : -c;
    });
  return out;
}
