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

// ════════════════════════════════════════════════════════════════════════════
//  LA DISPOSITION PAR GROUPE — pourquoi le PRIVÉ vient en premier
//
//  Un ministère possède ses écoles publiques : il les connaît, elles sont déjà
//  sous « Mes écoles ». Ce qu'il ne connaît PAS, ce sont les établissements
//  privés qu'il agrée sans les administrer — 7 des 25 écoles du MEPSA au
//  2026-09-02, aucune sous son toit. C'est l'angle mort que cette page existe
//  pour couvrir, et un angle mort ne se range pas en second.
//
//  ⚠️ LE SECTEUR EST CELUI DU GROUPE, pas de l'école. `group_type` descend sur
//  `schools.school_type` par le déclencheur `trg_cascade_group_type` : un
//  groupe n'est donc jamais mixte. Sectionner sur l'école produirait le même
//  découpage aujourd'hui et un découpage FAUX le jour où le déclencheur change.
// ════════════════════════════════════════════════════════════════════════════

/// Les écoles d'une sélection, rangées par groupe propriétaire.
Map<String, List<TutelleEcole>> ecolesParGroupe(List<TutelleEcole> ecoles) {
  final out = <String, List<TutelleEcole>>{};
  for (final e in ecoles) {
    out.putIfAbsent(e.groupId, () => []).add(e);
  }
  return out;
}

/// Un pan du réseau : les groupes d'un secteur et le bilan de leurs écoles.
class SectionReseau {
  const SectionReseau({
    required this.prive,
    required this.groupes,
    required this.bilan,
  });

  final bool prive;
  final List<TutelleGroupe> groupes;

  /// ⚠️ Bilan des écoles RETENUES par les filtres, pas du secteur entier.
  final BilanReseau bilan;

  String get titre => prive ? 'Réseau privé sous tutelle' : 'Réseau public';

  /// Ce que la section recouvre, en une ligne. Dit au lecteur POURQUOI les deux
  /// pans sont séparés — sinon la coupure passe pour un tri cosmétique.
  String get explication => prive
      ? 'Établissements agréés par le ministère et administrés par des '
          'personnes morales privées. Le ministère les supervise ; il ne les '
          'gère pas.'
      : 'Établissements du secteur public, tous groupes confondus — y compris '
          'ceux qui ne relèvent pas de votre propre groupe.';
}

/// Découpe le réseau en deux pans — le PRIVÉ D'ABORD (voir l'en-tête).
///
/// Un groupe dont aucune école ne passe les filtres disparaît : afficher une
/// carte à zéro école au-dessus d'une liste filtrée ferait croire à un groupe
/// vide alors qu'il est seulement hors sélection.
List<SectionReseau> sectionsDuReseau(
  List<TutelleGroupe> groupes,
  List<TutelleEcole> ecolesFiltrees,
) {
  final parGroupe = ecolesParGroupe(ecolesFiltrees);
  final out = <SectionReseau>[];
  for (final prive in [true, false]) {
    final retenus = [
      for (final g in groupes)
        if (g.estPublic != prive && parGroupe.containsKey(g.id)) g,
    ];
    if (retenus.isEmpty) continue;
    out.add(SectionReseau(
      prive: prive,
      groupes: retenus,
      bilan: BilanReseau.de([
        for (final g in retenus) ...parGroupe[g.id]!,
      ]),
    ));
  }
  return out;
}

// ─── Répartition territoriale (écran ET document) ───────────────────────────

/// Une ligne de répartition : un libellé, et le bilan des écoles qu'il couvre.
class LigneReseau {
  const LigneReseau(this.libelle, this.bilan);
  final String libelle;
  final BilanReseau bilan;
}

/// Le réseau par département, du plus peuplé au moins peuplé.
///
/// ⚠️ Les écoles sans département forment une ligne NOMMÉE (« Non renseigné »)
/// au lieu d'être écartées : un état ministériel dont les lignes ne totalisent
/// pas l'effectif annoncé en tête est un état qu'on ne peut pas signer.
List<LigneReseau> repartitionParDepartement(List<TutelleEcole> ecoles) {
  final parDept = <String, List<TutelleEcole>>{};
  for (final e in ecoles) {
    final d = (e.departement ?? '').trim();
    parDept.putIfAbsent(d.isEmpty ? 'Non renseigné' : d, () => []).add(e);
  }
  final lignes = [
    for (final entry in parDept.entries)
      LigneReseau(entry.key, BilanReseau.de(entry.value)),
  ];
  lignes.sort((a, b) {
    final parEleves = b.bilan.nbEleves.compareTo(a.bilan.nbEleves);
    return parEleves != 0 ? parEleves : a.libelle.compareTo(b.libelle);
  });
  return lignes;
}

/// Le réseau par secteur — deux lignes, dans l'ordre de la page.
List<LigneReseau> repartitionParSecteur(List<TutelleEcole> ecoles) {
  final prives = [for (final e in ecoles) if (!e.estPublic) e];
  final publics = [for (final e in ecoles) if (e.estPublic) e];
  return [
    if (prives.isNotEmpty) LigneReseau('Privé', BilanReseau.de(prives)),
    if (publics.isNotEmpty) LigneReseau('Public', BilanReseau.de(publics)),
  ];
}

// ─── Ce qu'un document doit dire de sa propre sélection ──────────────────────

/// Décrit les filtres actifs en une phrase, ou `null` si la vue est complète.
///
/// ⚠️ CE N'EST PAS UN ORNEMENT. Un PDF exporté depuis une liste filtrée porte
/// des totaux PARTIELS. Sans cette phrase imprimée sous le titre, « 7 écoles,
/// 1 204 élèves » se lit comme l'état du réseau entier — et c'est ce chiffre-là
/// qui remonte dans une note au ministre.
String? descriptionDesFiltres(FiltreReseau f, {String? nomGroupe}) {
  final parts = <String>[
    if (f.secteur == 'prive') 'secteur privé',
    if (f.secteur == 'public') 'secteur public',
    if (f.departement != null) 'département de ${f.departement}',
    if (f.typeEtablissement != null) 'type ${f.typeEtablissement}',
    if (f.agrement == FiltreAgrement.declare) 'agrément déclaré',
    if (f.agrement == FiltreAgrement.nonDeclare) 'agrément non déclaré',
    if (f.actifSeulement) 'établissements actifs',
    if (nomGroupe != null) 'groupe « $nomGroupe »',
    if (f.recherche.trim().isNotEmpty) 'recherche « ${f.recherche.trim()} »',
  ];
  if (parts.isEmpty) return null;
  return 'Sélection : ${parts.join(' · ')}';
}
