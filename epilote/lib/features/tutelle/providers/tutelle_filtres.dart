import 'tutelle_reseau_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LES FILTRES DU RÉSEAU — logique pure, testable sans Flutter
//
//  Séparée de l'écran exprès : ce sont ces fonctions qui décident quels
//  effectifs un ministère lit. Une erreur ici ne se voit pas — elle produit un
//  nombre plausible. Elles sont donc écrites pour être testées seules.
// ════════════════════════════════════════════════════════════════════════════

/// L'agrément est à TROIS états, jamais deux.
///
/// ⚠️ « non déclaré » n'est PAS « non agréé ». La plateforme n'instruit aucun
/// agrément : elle enregistre une mention. Une école sans numéro peut être
/// parfaitement en règle et n'avoir simplement rien saisi. Nommer ce filtre
/// « non agréées » serait une accusation portée par un logiciel.
enum FiltreAgrement { tous, declare, nonDeclare }

class FiltreReseau {
  const FiltreReseau({
    this.recherche = '',
    this.secteur, // null = tous ; 'public' | 'prive'
    this.departement, // null = tous
    this.typeEtablissement, // null = tous ; libellé court
    this.agrement = FiltreAgrement.tous,
    this.groupId, // null = tout le réseau
    this.actifSeulement = false,
  });

  final String recherche;
  final String? secteur, departement, typeEtablissement, groupId;
  final FiltreAgrement agrement;
  final bool actifSeulement;

  bool get estVierge =>
      recherche.trim().isEmpty &&
      secteur == null &&
      departement == null &&
      typeEtablissement == null &&
      groupId == null &&
      agrement == FiltreAgrement.tous &&
      !actifSeulement;

  FiltreReseau copyWith({
    String? recherche,
    Object? secteur = _garde,
    Object? departement = _garde,
    Object? typeEtablissement = _garde,
    Object? groupId = _garde,
    FiltreAgrement? agrement,
    bool? actifSeulement,
  }) =>
      FiltreReseau(
        recherche: recherche ?? this.recherche,
        // ⚠️ Sentinelle et non `??` : ici `null` est une VALEUR (« tous »), pas
        // une absence. Avec `??`, remettre un filtre à « tous » aurait été
        // impossible — il serait resté collé sur sa dernière valeur.
        secteur: secteur == _garde ? this.secteur : secteur as String?,
        departement:
            departement == _garde ? this.departement : departement as String?,
        typeEtablissement: typeEtablissement == _garde
            ? this.typeEtablissement
            : typeEtablissement as String?,
        groupId: groupId == _garde ? this.groupId : groupId as String?,
        agrement: agrement ?? this.agrement,
        actifSeulement: actifSeulement ?? this.actifSeulement,
      );

  static const _garde = Object();
}

/// Les écoles retenues par [f].
List<TutelleEcole> filtrerEcoles(List<TutelleEcole> ecoles, FiltreReseau f) {
  final q = f.recherche.trim().toLowerCase();
  return [
    for (final e in ecoles)
      if (_retient(e, f, q)) e,
  ];
}

bool _retient(TutelleEcole e, FiltreReseau f, String q) {
  if (f.groupId != null && e.groupId != f.groupId) return false;
  if (f.secteur != null && e.secteur != f.secteur) return false;
  if (f.departement != null && e.departement != f.departement) return false;
  if (f.typeEtablissement != null &&
      e.typeEtablissementCourt != f.typeEtablissement) {
    return false;
  }
  if (f.actifSeulement && !e.actif) return false;
  switch (f.agrement) {
    case FiltreAgrement.declare:
      if (!e.aDeclareUnAgrement) return false;
    case FiltreAgrement.nonDeclare:
      if (e.aDeclareUnAgrement) return false;
    case FiltreAgrement.tous:
      break;
  }
  if (q.isEmpty) return true;
  // La recherche porte sur ce qu'un agent de la tutelle a sous les yeux : le
  // nom, le code administratif, la ville, et le groupe propriétaire.
  return e.nom.toLowerCase().contains(q) ||
      (e.code ?? '').toLowerCase().contains(q) ||
      (e.ville ?? '').toLowerCase().contains(q) ||
      e.groupeNom.toLowerCase().contains(q);
}

/// Les totaux d'une sélection d'écoles.
///
/// ⚠️ Recalculés sur les écoles FILTRÉES, jamais lus sur les totaux du réseau.
/// Afficher un total national au-dessus d'une liste filtrée est la façon la
/// plus simple de faire dire à un écran le contraire de ce qu'il montre.
class BilanReseau {
  const BilanReseau({
    required this.nbEcoles,
    required this.nbGroupes,
    required this.nbEleves,
    required this.nbFilles,
    required this.nbPersonnel,
    required this.nbClasses,
    required this.nbPublic,
    required this.nbPrive,
    required this.nbAgrementDeclare,
    required this.nbCapaciteConnue,
    required this.capaciteTotale,
    required this.elevesCapaciteConnue,
  });

  factory BilanReseau.de(List<TutelleEcole> ecoles) {
    var eleves = 0, filles = 0, personnel = 0, classes = 0;
    var pub = 0, prv = 0, agr = 0, capN = 0, capTot = 0, elevesCap = 0;
    final groupes = <String>{};
    for (final e in ecoles) {
      groupes.add(e.groupId);
      eleves += e.nbEleves;
      filles += e.nbFilles;
      personnel += e.nbPersonnel;
      classes += e.nbClasses;
      if (e.estPublic) {
        pub++;
      } else {
        prv++;
      }
      if (e.aDeclareUnAgrement) agr++;
      if (e.capacite != null && e.capacite! > 0) {
        capN++;
        capTot += e.capacite!;
        // On accumule AUSSI les élèves de ces écoles-là : c'est le seul
        // numérateur qui va avec ce dénominateur.
        elevesCap += e.nbEleves;
      }
    }
    return BilanReseau(
      nbEcoles: ecoles.length,
      nbGroupes: groupes.length,
      nbEleves: eleves,
      nbFilles: filles,
      nbPersonnel: personnel,
      nbClasses: classes,
      nbPublic: pub,
      nbPrive: prv,
      nbAgrementDeclare: agr,
      nbCapaciteConnue: capN,
      capaciteTotale: capTot,
      elevesCapaciteConnue: elevesCap,
    );
  }

  final int nbEcoles,
      nbGroupes,
      nbEleves,
      nbFilles,
      nbPersonnel,
      nbClasses,
      nbPublic,
      nbPrive,
      nbAgrementDeclare,
      nbCapaciteConnue,
      capaciteTotale,
      elevesCapaciteConnue;

  int get nbGarcons => nbEleves - nbFilles;

  /// Part de filles, en pourcentage. `null` s'il n'y a aucun élève : 0 %
  /// s'afficherait comme « aucune fille », ce qui est faux.
  double? get partFilles => nbEleves == 0 ? null : nbFilles * 100 / nbEleves;

  /// Taux d'occupation, en pourcentage.
  ///
  /// ⚠️ Numérateur ET dénominateur portent sur les MÊMES écoles — celles dont
  /// la capacité est renseignée. Diviser l'effectif COMPLET par une capacité
  /// PARTIELLE produit un taux au-dessus de 100 % qui ne veut rien dire, et
  /// qui a l'air d'une école surchargée.
  double? get tauxOccupation =>
      capaciteTotale == 0 ? null : elevesCapaciteConnue * 100 / capaciteTotale;

  /// Vrai si toutes les écoles de la sélection déclarent leur capacité.
  bool get capaciteComplete => nbCapaciteConnue == nbEcoles;
}

/// Les départements présents dans une sélection, triés — pour alimenter un
/// menu déroulant sans jamais proposer un choix qui ne rendrait rien.
List<String> departementsDe(List<TutelleEcole> ecoles) =>
    (ecoles.map((e) => e.departement ?? '').where((d) => d.isNotEmpty).toSet()
          .toList()
      ..sort());

/// Les types d'établissement présents, triés. Même principe.
List<String> typesEtablissementDe(List<TutelleEcole> ecoles) =>
    (ecoles
        .map((e) => e.typeEtablissementCourt ?? '')
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList()
      ..sort());
