import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE PÉRIMÈTRE SE POSE SUR CHAQUE PAGE, ET LA LECTURE S'ATTEND.
//
//  ── CE QUE CE TEST GARDE ───────────────────────────────────────────────────
//  Deux défauts distincts, trouvés le même jour dans le domaine Scolarité, qui
//  ont en commun de ne lever AUCUNE erreur : une requête sans restriction rend
//  simplement plus de lignes, et un provider lu trop tôt rend simplement
//  « rien ». Ni l'analyseur ni un test d'écran ne les voient.
//
//  1. LE PÉRIMÈTRE (verrou 4). `data_scope = own_classes` est réglable module
//     par module, et le profil « Enseignant » livré en base le pose sur
//     `eleves`, `inscriptions`, `documents`, `annuaire` ET `transferts`. Il
//     n'était appliqué que sur `eleves`. Un enseignant restreint à ses deux
//     classes lisait tout le guichet des inscriptions, le registre documentaire
//     de l'école entière, et le registre des transferts — donc les motifs de
//     sortie, qui portent la déperdition scolaire.
//
//     Ce n'est pas un contournement de verrou : le verrou n'avait jamais été
//     posé. C'est le troisième épisode de la même histoire (registre des
//     élèves, puis graphe d'effectif), d'où un test plutôt qu'une relecture.
//
//  2. LA LECTURE QUI N'A PAS EU LIEU. `ref.read(unProvider(id)).valueOrNull`
//     sur un provider `autoDispose.family` que rien n'écoute rend `null` :
//     `Stream`/`Future` n'ont pas encore émis. Le code retombe alors sur sa
//     branche « on ne sait pas », qui est toujours la branche permissive.
//
//     Concrètement : la boîte « Dossier incomplet » ne s'ouvrait jamais depuis
//     le bouton de la ligne — c'est-à-dire là où l'on valide vraiment —, la
//     mention « N dossier(s) incomplet(s) » de la validation groupée ne pouvait
//     pas s'afficher, la réserve sur les frais impayés non plus, et le reçu
//     remis à la famille sortait toujours sans sa ligne « reste dû ».
//
//     La forme sûre est `await ref.read(unProvider(id).future)`.
//
//  ── POURQUOI SUR LE TEXTE SOURCE ───────────────────────────────────────────
//  Les deux défauts demandent une base PowerSync vivante et un profil d'accès
//  synchronisé pour se reproduire. Aucun test unitaire ordinaire ne les
//  attrape ; la seule défense qui tienne à l'échelle du dépôt est d'exiger la
//  FORME. Même parti pris que `offline_booleen_test.dart`.
// ════════════════════════════════════════════════════════════════════════════

const _kProviders = 'lib/features/students/providers';

/// Les pages nominatives du domaine et le module dont elles portent les droits.
///
/// La clé est le fichier, la valeur le slug attendu dans l'appel. Passer le
/// mauvais slug, c'est appliquer les droits d'une autre page — le test le voit.
const _pagesAPerimetre = <String, String>{
  '$_kProviders/students_provider.dart': 'eleves',
  '$_kProviders/students_registry_provider.dart': 'eleves',
  '$_kProviders/inscriptions_data_provider.dart': 'inscriptions',
  '$_kProviders/inscriptions_rythme_provider.dart': 'inscriptions',
  '$_kProviders/documents_provider.dart': 'documents',
  '$_kProviders/transfers_provider.dart': 'transferts',
};

/// `ref.read(unProvider(argument)).valueOrNull` — la lecture qui n'attend pas.
///
/// ⚠️ On ne vise QUE la forme `.family` (avec parenthèses d'argument). Un
/// provider d'application — `authNotifierProvider`, `currentSchoolProvider`,
/// `classesProvider` — est déjà écouté par le shell quand l'écran s'ouvre : le
/// lire sans attendre est légitime, et il y a vingt-quatre lectures de ce genre
/// dans le seul domaine Scolarité. Interdire les deux formes rendrait le test
/// impossible à satisfaire, donc impossible à garder.
///
/// `await ref.read(p(id).future)` ne correspond pas : le `.future` s'intercale
/// avant la parenthèse fermante de `read`.
final _lectureNonAttendue = RegExp(
  r'ref\.read\(\s*[A-Za-z_][A-Za-z0-9_]*Provider\s*\([^()]*\)\s*\)\s*\.valueOrNull',
);

/// Les fichiers Dart d'un répertoire du dépôt, récursivement.
List<File> _dartsSous(String chemin) {
  final dir = Directory(chemin);
  if (!dir.existsSync()) {
    fail('Répertoire introuvable : $chemin — le test tourne-t-il depuis '
        '`epilote/` ?');
  }
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

void main() {
  group('Verrou 4 — chaque page nominative pose son périmètre', () {
    _pagesAPerimetre.forEach((chemin, slug) {
      test('${chemin.split('/').last} restreint sur « $slug »', () {
        final f = File(chemin);
        expect(f.existsSync(), isTrue,
            reason: '$chemin a disparu : si la page a été déplacée, déplacer '
                'aussi son entrée dans _pagesAPerimetre.');
        final src = f.readAsStringSync().replaceAll('\r\n', '\n');
        expect(
          src.contains("classScopeClause(ref, '$slug'") ||
              // `students_registry_provider` sert TROIS modules (eleves,
              // documents, annuaire) : son slug est un paramètre, et c'est
              // l'appelant qui déclare sous quels droits il lit.
              src.contains('classScopeClause(ref, slug'),
          isTrue,
          reason:
              '$chemin interroge des données nominatives sans passer par '
              '`classScopeClause(ref, \'$slug\', …)`. Un membre dont le profil '
              'dit `own_classes` y lirait l\'école entière, sans qu\'aucune '
              'erreur ne soit levée.',
        );
      });
    });

    test("l'annuaire hérite du périmètre par le registre", () {
      // L'annuaire des familles ne requête pas les élèves lui-même : il joint
      // les tuteurs au registre. Le slug compte quand même — `annuaire` est
      // une entrée distincte du profil d'accès, et lire sous `eleves` y
      // appliquerait les droits d'une autre page.
      final src =
          File('$_kProviders/annuaire_provider.dart').readAsStringSync().replaceAll('\r\n', '\n');
      expect(src.contains("studentsRegistryProvider('annuaire')"), isTrue,
          reason: 'Le répertoire des familles — noms, téléphones et adresses '
              'des parents — doit passer par le registre scopé, sous son '
              'propre slug.');
    });

    test('les KPI comptent le même ensemble que la liste', () {
      // « Familles » et « Avec contact » se dérivaient des familles affichées,
      // « Tuteurs » et « Urgence » de l'école entière : la même rangée
      // affichait « 12 familles » et « 847 tuteurs ».
      final src =
          File('$_kProviders/annuaire_provider.dart').readAsStringSync().replaceAll('\r\n', '\n');
      final stats = src.substring(src.indexOf('annuaireStatsProvider'));
      expect(stats.contains('schoolTutorsProvider'), isFalse,
          reason: 'Les compteurs de l\'annuaire doivent se lire sur les '
              'familles effectivement affichées, pas sur tous les tuteurs de '
              'l\'école.');
    });
  });

  group('Aucune décision ne se prend sur une lecture qui n\'a pas eu lieu', () {
    test('pas de `ref.read(unProvider(id)).valueOrNull` dans la Scolarité', () {
      final fautes = <String>[];
      for (final f in _dartsSous('lib/features/students')) {
        final lignes = f.readAsLinesSync();
        for (var i = 0; i < lignes.length; i++) {
          if (_lectureNonAttendue.hasMatch(lignes[i])) {
            fautes.add('${f.path}:${i + 1}  ${lignes[i].trim()}');
          }
        }
      }
      expect(
        fautes,
        isEmpty,
        reason: 'Ces lectures rendent `null` quand rien n\'écoute le provider '
            '— et le code retombe alors sur sa branche permissive : '
            'l\'avertissement ne s\'affiche pas, la ligne du reçu reste vide. '
            'Écrire `await ref.read(unProvider(id).future)`.\n\n'
            '${fautes.join('\n')}',
      );
    });
  });
}
