import 'package:flutter/foundation.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CE QU'UN ÉCRAN N'A PAS PU LIRE
//
//  ── LE TRAVERS QUE CECI CORRIGE ───────────────────────────────────────────
//  128 lectures de cette application sont enveloppées dans un `catch (_) {}`.
//  Sur un écran de mesures, la conséquence est toujours la même : la requête
//  échoue — réseau coupé, RLS resserrée, colonne renommée — la variable reste
//  à ZÉRO, et la page affiche ce zéro comme un fait. « 0 élève », « 0 FCFA de
//  revenus », « 0 école en règle ».
//
//  Dans un produit d'État, ce zéro ne reste pas à l'écran : il part en rapport,
//  en réunion, en décision. Et il est d'autant plus crédible qu'il est rond.
//
//  ── LA RÈGLE ──────────────────────────────────────────────────────────────
//  Zéro n'est pas « je ne sais pas ». Une lecture qui échoue :
//    1. porte un NOM de mesure ;
//    2. laisse une TRACE (`debugPrint`) — sans quoi on ne saura jamais pourquoi ;
//    3. REMONTE à l'écran, qui affiche « — » et nomme ce qui manque.
//
//  ⚠️ Toutes les lectures ne méritent pas ce traitement : une pastille
//  facultative peut disparaître en silence. Ce qui l'exige, c'est tout ce qui
//  s'affiche comme un NOMBRE ou comme un FAIT.
// ════════════════════════════════════════════════════════════════════════════

/// Les mesures qu'une lecture d'écran n'a pas pu obtenir.
///
/// Se remplit pendant la collecte, se rend avec les données. Vide dans le cas
/// normal — le coût d'y penser est nul tant que tout va bien.
class MesuresManquantes {
  MesuresManquantes();

  final Set<String> _cles = <String>{};

  /// Les clés manquantes, en lecture seule.
  Set<String> get cles => Set.unmodifiable(_cles);

  bool get estVide => _cles.isEmpty;
  bool get nEstPasVide => _cles.isNotEmpty;

  /// Cette mesure précise a-t-elle échoué ?
  bool contient(String cle) => _cles.contains(cle);

  /// Enregistre un échec de lecture.
  ///
  /// [cle] nomme la MESURE, pas la requête : c'est ce que l'écran affichera.
  /// La trace est indispensable — un « — » sans journal se diagnostique en
  /// interrogeant l'utilisateur, ce qui n'arrive jamais.
  void note(String cle, Object erreur, {String? ecran}) {
    _cles.add(cle);
    debugPrint('ℹ️ ${ecran ?? 'Écran'} : mesure « $cle » illisible ($erreur).');
  }
}

/// Les modèles de données exposent un `Set<String>` figé, jamais cet objet :
/// une fois la lecture finie, la liste ne doit plus bouger. Utiliser [cles].
