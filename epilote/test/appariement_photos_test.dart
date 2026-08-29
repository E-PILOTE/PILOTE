import 'package:epilote/features/cartes/providers/cartes_provider.dart';
import 'package:epilote/features/cartes/services/appariement_photos.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  APPARIER DES PHOTOS À DES ÉLÈVES
//
//  ── CE QUE CE TEST DÉFEND ──────────────────────────────────────────────────
//  Une photo posée sur le mauvais élève est PIRE que pas de photo : la carte
//  devient un faux qui circule — un visage, un autre nom — et rien ne le
//  signale avant le portail. C'est le seul défaut de tout le module qui ne se
//  rattrape pas, parce qu'on ne le CHERCHE pas : la carte a l'air normale.
//
//  Toute la logique tient donc en une phrase : **exact, ou rien**. Ces tests
//  vérifient surtout les cas où la tentation d'aider serait forte — l'homonyme,
//  le presque-pareil, les deux prises du même enfant — et où céder fabrique
//  précisément ce faux.
// ════════════════════════════════════════════════════════════════════════════

CarteEleveRow _eleve(
  String id,
  String nom,
  String prenom, {
  String? matricule,
  String? ine,
  String? photoUrl,
}) =>
    CarteEleveRow(
      studentId: id,
      firstName: prenom,
      lastName: nom,
      matricule: matricule ?? 'MAT-$id',
      className: '6ème A',
      status: 'active',
      ine: ine,
      photoUrl: photoUrl,
    );

FichierPhoto _f(String nom, {int? taille}) =>
    FichierPhoto(chemin: '/photos/$nom', nom: nom, taille: taille);

/// Raccourci : la raison pour laquelle un fichier a été écarté.
RaisonEcart? _raison(ResultatAppariement r, String nomFichier) {
  for (final e in r.ecartes) {
    if (e.fichier.nom == nomFichier) return e.raison;
  }
  return null;
}

void main() {
  group('Ce qui s’apparie tout seul', () {
    test('par matricule, quels que soient les séparateurs', () {
      final e = _eleve('1', 'NGOMA', 'Jean', matricule: 'M-2024/0137');
      for (final nom in [
        'M-2024/0137.jpg',
        'M 2024 0137.JPG',
        'm20240137.png',
        'M_2024-0137.jpeg',
      ]) {
        final r = apparierPhotos(fichiers: [_f(nom)], eleves: [e]);
        expect(r.apparies, hasLength(1), reason: 'Échec sur « $nom ».');
        expect(r.apparies.first.cle, CleAppariement.matricule);
      }
    });

    test('par identifiant national', () {
      final e = _eleve('1', 'NGOMA', 'Jean', ine: '12345678901');
      final r = apparierPhotos(fichiers: [_f('12345678901.jpg')], eleves: [e]);
      expect(r.apparies, hasLength(1));
      expect(r.apparies.first.cle, CleAppariement.identifiantNational);
    });

    test('par nom, dans les deux ordres et sans se soucier des accents', () {
      final e = _eleve('1', 'MBEMBA', 'Rachël');
      for (final nom in [
        'MBEMBA Rachël.jpg',
        'Rachel Mbemba.jpg',
        'mbemba-rachel.png',
      ]) {
        final r = apparierPhotos(fichiers: [_f(nom)], eleves: [e]);
        expect(r.apparies, hasLength(1), reason: 'Échec sur « $nom ».');
      }
    });

    test('le matricule prime sur le nom quand les deux désignent le même', () {
      // Un élève dont le matricule EST son nom : deux entrées d'index, un seul
      // enfant. Ce n'est pas une ambiguïté.
      final e = _eleve('1', 'KOUMBA', 'Alice', matricule: 'KOUMBA Alice');
      final r =
          apparierPhotos(fichiers: [_f('KOUMBA Alice.jpg')], eleves: [e]);
      expect(r.apparies, hasLength(1));
      expect(r.apparies.first.cle, CleAppariement.matricule,
          reason: 'La clé la plus forte doit être annoncée.');
    });
  });

  group('Ce qu’on refuse d’apparier — le cœur du sujet', () {
    test('un nom d’appareil photo ne désigne personne', () {
      final r = apparierPhotos(
        fichiers: [_f('IMG_0042.JPG'), _f('DSC00871.jpg')],
        eleves: [_eleve('1', 'NGOMA', 'Jean')],
      );
      expect(r.apparies, isEmpty);
      expect(_raison(r, 'IMG_0042.JPG'), RaisonEcart.aucuneCorrespondance);
    });

    test('DEUX HOMONYMES : aucune des deux ne reçoit la photo', () {
      final r = apparierPhotos(
        fichiers: [_f('NGOMA Jean.jpg')],
        eleves: [
          _eleve('1', 'NGOMA', 'Jean'),
          _eleve('2', 'NGOMA', 'Jean'),
        ],
      );
      expect(r.apparies, isEmpty,
          reason: 'Choisir « le premier » mettrait un visage sur un enfant au '
              'hasard, et personne ne le vérifierait jamais.');
      expect(_raison(r, 'NGOMA Jean.jpg'), RaisonEcart.plusieursEleves);
    });

    test('DEUX FICHIERS pour le même élève : aucun n’est retenu', () {
      final e = _eleve('1', 'NGOMA', 'Jean');
      final r = apparierPhotos(
        fichiers: [_f('NGOMA Jean.jpg'), _f('ngoma jean.png')],
        eleves: [e],
      );
      expect(r.apparies, isEmpty,
          reason: "Deux prises, ou deux enfants dont un manque à l'appel : on "
              'ne peut pas trancher depuis un nom de fichier.');
      expect(r.ecartes, hasLength(2));
      expect(_raison(r, 'NGOMA Jean.jpg'), RaisonEcart.plusieursFichiers);
    });

    test('PRESQUE le bon nom ne vaut pas le bon nom', () {
      final r = apparierPhotos(
        fichiers: [_f('NGOMA Jeanne.jpg')],
        eleves: [_eleve('1', 'NGOMA', 'Jean')],
      );
      expect(r.apparies, isEmpty,
          reason: 'Jean et Jeanne sont deux enfants. Une distance d’édition '
              'les confondrait.');
      expect(_raison(r, 'NGOMA Jeanne.jpg'), RaisonEcart.aucuneCorrespondance);
    });

    test('un matricule tronqué ne vaut pas le matricule', () {
      final r = apparierPhotos(
        fichiers: [_f('M-2024.jpg')],
        eleves: [_eleve('1', 'NGOMA', 'Jean', matricule: 'M-2024/0137')],
      );
      expect(r.apparies, isEmpty,
          reason: 'Un préfixe désignerait tous les élèves de la promotion.');
    });

    test('ce qui n’est pas une image est écarté avant tout le reste', () {
      final r = apparierPhotos(
        fichiers: [_f('NGOMA Jean.pdf'), _f('liste.xlsx')],
        eleves: [_eleve('1', 'NGOMA', 'Jean')],
      );
      expect(r.apparies, isEmpty);
      expect(_raison(r, 'NGOMA Jean.pdf'), RaisonEcart.pasUneImage);
    });

    test('un fichier trop lourd est écarté, pas chargé', () {
      final r = apparierPhotos(
        fichiers: [_f('NGOMA Jean.jpg', taille: kPoidsMaxPhotoImport + 1)],
        eleves: [_eleve('1', 'NGOMA', 'Jean')],
      );
      expect(_raison(r, 'NGOMA Jean.jpg'), RaisonEcart.tropLourd);
    });
  });

  group('Les photos déjà là', () {
    test('ne sont pas remplacées par défaut', () {
      final e = _eleve('1', 'NGOMA', 'Jean', photoUrl: 'https://x/y.jpg');
      final r = apparierPhotos(fichiers: [_f('NGOMA Jean.jpg')], eleves: [e]);
      expect(r.apparies, isEmpty);
      expect(_raison(r, 'NGOMA Jean.jpg'), RaisonEcart.photoDejaPresente);
    });

    test('le sont si on le demande explicitement', () {
      final e = _eleve('1', 'NGOMA', 'Jean', photoUrl: 'https://x/y.jpg');
      final r = apparierPhotos(
        fichiers: [_f('NGOMA Jean.jpg')],
        eleves: [e],
        remplacerExistantes: true,
      );
      expect(r.apparies, hasLength(1));
    });

    test('un élève déjà pourvu ne figure pas dans ce qui reste à faire', () {
      final r = apparierPhotos(
        fichiers: const [],
        eleves: [
          _eleve('1', 'NGOMA', 'Jean', photoUrl: 'https://x/y.jpg'),
          _eleve('2', 'MBEMBA', 'Alice'),
        ],
      );
      expect(r.elevesRestants.map((e) => e.studentId), ['2']);
    });
  });

  group('Le compte final est juste', () {
    test('ce qui reste à faire exclut ce que cet import va poser', () {
      final r = apparierPhotos(
        fichiers: [_f('MAT-1.jpg'), _f('IMG_0001.jpg')],
        eleves: [
          _eleve('1', 'NGOMA', 'Jean'),
          _eleve('2', 'MBEMBA', 'Alice'),
          _eleve('3', 'KOUMBA', 'Paul'),
        ],
      );
      expect(r.apparies.map((p) => p.eleve.studentId), ['1']);
      expect(r.elevesRestants.map((e) => e.studentId), ['2', '3'],
          reason: 'Jean est servi par cet import ; les deux autres restent.');
    });

    test('aucun élève ne reçoit deux photos dans le même lot', () {
      final r = apparierPhotos(
        fichiers: [
          _f('MAT-1.jpg'),
          _f('NGOMA Jean.png'), // le même élève, désigné autrement
        ],
        eleves: [_eleve('1', 'NGOMA', 'Jean')],
      );
      final ids = r.apparies.map((p) => p.eleve.studentId).toList();
      expect(ids.toSet().length, ids.length);
      // Et ici, les deux fichiers visant le même enfant, aucun ne passe.
      expect(r.apparies, isEmpty);
    });

    test('un lot vide ne casse rien et rend la classe entière à faire', () {
      final r = apparierPhotos(
        fichiers: const [],
        eleves: [_eleve('1', 'NGOMA', 'Jean')],
      );
      expect(r.vide, isTrue);
      expect(r.ecartes, isEmpty);
      expect(r.elevesRestants, hasLength(1));
    });

    test('chaque fichier apparaît une fois et une seule dans le résultat', () {
      final fichiers = [
        _f('MAT-1.jpg'),
        _f('IMG_0001.jpg'),
        _f('NGOMA Jean.pdf'),
        _f('MAT-9.jpg'),
      ];
      final r = apparierPhotos(
        fichiers: fichiers,
        eleves: [_eleve('1', 'NGOMA', 'Jean')],
      );
      final vus = [
        ...r.apparies.map((p) => p.fichier.nom),
        ...r.ecartes.map((e) => e.fichier.nom),
      ];
      expect(vus.length, fichiers.length,
          reason: 'Un fichier perdu en route est un fichier dont personne ne '
              "saura qu'il n'a pas été traité.");
      expect(vus.toSet(), fichiers.map((f) => f.nom).toSet());
    });
  });
}
