import 'package:epilote/features/admin_groupe/providers/passage_merit_provider.dart';
import 'package:epilote/features/admin_groupe/services/passage_merit_pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Meilleurs élèves des CLASSES DE PASSAGE.
///
/// C'est la seule liste de mérite que la plateforme produit à partir de ses
/// propres calculs : pour les classes d'examen, elle transmet la liste des
/// candidats à la DEC et n'en calcule pas les résultats.
///
/// Ce qui est gardé ici est de l'équité, pas de l'affichage : deux élèves à la
/// même moyenne doivent obtenir le même rang, et un « top 10 » ne doit jamais
/// couper un groupe d'ex æquo — écarter l'un des deux serait indéfendable
/// devant la famille concernée.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('fr'));

  var seq = 0;
  PassageEntry e(double average, {String? gender, String? school}) {
    seq++;
    return PassageEntry(
      studentId: 'e$seq',
      fullName: 'Élève $seq',
      schoolName: school ?? 'École $seq',
      className: '5ème A',
      average: average,
      subjectCount: 10,
      gender: gender,
      levelCode: '5e',
      classAverage: 12,
    );
  }

  group('Rangs et ex æquo', () {
    test('deux moyennes égales partagent le rang, la suite saute', () {
      final r = rankPassage([e(16), e(15), e(15), e(14)], 10);
      expect(r.map((x) => x.rank), [1, 2, 2, 4]);
    });

    test('les ex æquo sont signalés comme tels', () {
      final r = rankPassage([e(16), e(15), e(15)], 10);
      expect(r[0].exAequo, isFalse);
      expect(r[1].exAequo, isTrue);
      expect(r[2].exAequo, isTrue);
    });

    test('le topN ne coupe JAMAIS un groupe d\'égalité', () {
      // Trois élèves à 15 occupent le rang 2 : un « top 3 » doit les garder
      // tous les trois plutôt que d'en écarter un arbitrairement.
      final r = rankPassage([e(16), e(15), e(15), e(15), e(10)], 3);
      expect(r.length, 4);
      expect(r.last.entry.average, 15);
      expect(r.any((x) => x.entry.average == 10), isFalse);
    });

    test('un classement vide ne produit aucun rang', () {
      expect(rankPassage(const [], 10), isEmpty);
    });

    test('le topN borne bien quand il n\'y a pas d\'égalité', () {
      final r = rankPassage([e(18), e(17), e(16), e(15)], 2);
      expect(r.length, 2);
    });
  });

  group('Parité', () {
    test('part de filles nulle sur classement vide — jamais 0 %', () {
      expect(passageFemaleShare(const []), isNull,
          reason: '0 % dirait « aucune fille » là où il n\'y a personne');
    });

    test('part de filles calculée sur les élèves classés', () {
      final r = rankPassage([e(16, gender: 'F'), e(15, gender: 'M')], 10);
      expect(passageFemaleShare(r), 50);
    });
  });

  group('Périmètre du classement', () {
    test('l\'année entière est un CHOIX, pas une absence de filtre', () {
      const f = PassageFilter();
      expect(f.trimesterId, isNull);
      expect(f.copyWith(trimesterId: 't1').trimesterId, 't1');
      expect(f.copyWith(trimesterId: 't1').copyWith(trimesterId: null).trimesterId,
          isNull);
    });

    test('changer de période ne perd pas le niveau retenu', () {
      const f = PassageFilter(levelCode: '5e', topN: 20);
      final c = f.copyWith(trimesterId: 't2');
      expect(c.levelCode, '5e');
      expect(c.topN, 20);
    });

    test('deux périmètres identiques sont égaux — pas de requête inutile', () {
      expect(const PassageFilter(trimesterId: 't1', levelCode: '5e'),
          const PassageFilter(trimesterId: 't1', levelCode: '5e'));
    });
  });

  group('Mention', () {
    test('la mention vient de la source unique, pas d\'un barème local', () {
      // Barème officiel (migration 0059) : Très Bien ≥ 16, Passable ≥ 10.
      expect(e(17).mention, 'Très Bien');
      expect(e(10).mention, 'Passable');
      expect(e(9.99).mention, 'Insuffisant');
    });

    test('l\'écart à la classe situe l\'élève dans SON groupe', () {
      expect(e(16).delta, 4, reason: 'classe à 12');
    });
  });

  group('Document officiel', () {
    test('un classement vide produit quand même un document', () async {
      final bytes = await PassageMeritPdfService.buildPdf(
        groupName: 'METP',
        rows: const [],
        periodLabel: '1er trimestre',
        evaluatedTotal: 0,
      );
      expect(bytes.length, greaterThan(0));
    });

    test('200 élèves aux libellés à rallonge se génèrent sans exception',
        () async {
      final rows = rankPassage([
        for (var i = 0; i < 200; i++)
          PassageEntry(
            studentId: 'x$i',
            fullName: 'Marie-Bénédicte Nkounkou Massamba Loemba $i',
            schoolName: 'Complexe Scolaire Départemental Étoile du Nord $i',
            className: 'Terminale Technique Industrielle A',
            average: 18 - i / 100,
            subjectCount: 12,
            classAverage: 13.25,
            levelCode: 'Tle',
          ),
      ], 200);
      final bytes = await PassageMeritPdfService.buildPdf(
        groupName: 'Ministère de l\'Enseignement Technique et Professionnel',
        rows: rows,
        periodLabel: '3e trimestre',
        evaluatedTotal: 216,
        levelCode: 'Tle',
      );
      expect(bytes.length, greaterThan(0),
          reason: 'un cadre trop haut bloquerait tout le document');
    });
  });

  group('Périmètre du palmarès — il doit toujours être énonçable', () {
    test('sans restriction, le périmètre se réduit à la période', () {
      expect(const PassageFilter().scopeLabel('année entière'),
          'année entière');
    });

    test('territoire, filière et niveau s\'ajoutent dans un ordre stable', () {
      // L'ordre est fixe pour que le même périmètre produise toujours la même
      // phrase : deux PDF du même classement ne doivent pas se lire
      // différemment.
      const f = PassageFilter(
        department: 'Niari',
        filiere: 'Électrotechnique',
        levelCode: '2nde',
      );
      expect(f.scopeLabel('2e trimestre'),
          '2e trimestre · département Niari · Électrotechnique · niveau 2nde');
    });

    test('un rang filtré ne se présente jamais comme national', () {
      const f = PassageFilter(department: 'Pool');
      final label = f.scopeLabel('année entière');
      expect(label, contains('Pool'),
          reason: 'un 1er du Pool présenté sans son département serait '
              'lu comme un 1er national');
    });

    test('deux filtres identiques sont le même périmètre', () {
      // L'égalité pilote le rechargement du provider : sans elle, changer un
      // filtre puis revenir relancerait une requête pour rien.
      expect(const PassageFilter(department: 'Niari', filiere: 'Série C'),
          const PassageFilter(department: 'Niari', filiere: 'Série C'));
      expect(const PassageFilter(department: 'Niari'),
          isNot(const PassageFilter(department: 'Pool')));
    });
  });
}
