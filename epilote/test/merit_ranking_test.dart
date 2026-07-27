import 'package:flutter_test/flutter_test.dart';
import 'package:epilote/features/admin_groupe/providers/admin_merit_provider.dart';

/// Palmarès national — le classement qui sert à attribuer une bourse.
///
/// Ce qui est gardé ici n'est pas de l'affichage : c'est de l'équité. Deux
/// élèves à la même moyenne doivent obtenir le même rang, et un « top 10 » ne
/// doit jamais couper un groupe d'ex æquo en deux — écarter l'un des deux
/// serait indéfendable devant la famille concernée.
void main() {
  var seq = 0;
  MeritEntry e(
    double average, {
    String? filiere,
    String? dept,
    String? gender,
    String? exam,
    String? school,
  }) {
    seq++;
    return MeritEntry(
      studentId: 's$seq',
      fullName: 'Élève $seq',
      schoolId: school ?? 'ecole-$seq',
      schoolName: school ?? 'École $seq',
      average: average,
      gender: gender,
      department: dept,
      filiere: filiere,
      examShortName: exam,
    );
  }

  List<MeritEntry> sorted(List<MeritEntry> l) =>
      [...l]..sort((a, b) => b.average.compareTo(a.average));

  group('rankMerit — attribution des rangs', () {
    test('classe par moyenne décroissante, rangs 1..n', () {
      final rows = rankMerit(sorted([e(12), e(18), e(15)]), const MeritFilter());

      expect(rows.map((r) => r.rank), [1, 2, 3]);
      expect(rows.first.entry.average, 18);
      expect(rows.last.entry.average, 12);
      expect(rows.every((r) => !r.exAequo), isTrue);
    });

    test('deux moyennes égales partagent le rang, et le suivant saute', () {
      final rows =
          rankMerit(sorted([e(18), e(17.7), e(17.7), e(16)]), const MeritFilter());

      expect(rows.map((r) => r.rank), [1, 2, 2, 4]);
      expect(rows[1].exAequo, isTrue);
      expect(rows[2].exAequo, isTrue);
      expect(rows[0].exAequo, isFalse);
      expect(rows[3].exAequo, isFalse);
    });

    test('un rang unique n\'est jamais marqué ex æquo', () {
      final rows = rankMerit(sorted([e(14), e(13)]), const MeritFilter());
      expect(rows.every((r) => !r.exAequo), isTrue);
    });
  });

  group('rankMerit — taille du palmarès', () {
    test('tronque à topN quand il n\'y a pas d\'ex æquo à la frontière', () {
      final rows = rankMerit(
        sorted([e(18), e(17), e(16), e(15), e(14)]),
        const MeritFilter(topN: 3),
      );
      expect(rows.length, 3);
      expect(rows.last.entry.average, 16);
    });

    test('ne coupe JAMAIS un groupe d\'ex æquo à la frontière du topN', () {
      // 3ᵉ et 4ᵉ à égalité : le top 3 doit en contenir 4.
      final rows = rankMerit(
        sorted([e(18), e(17), e(16), e(16), e(12)]),
        const MeritFilter(topN: 3),
      );

      expect(rows.length, 4);
      expect(rows.map((r) => r.rank), [1, 2, 3, 3]);
      expect(rows.last.entry.average, 16);
      // Le 5ᵉ, lui, reste dehors : on n'élargit que l'égalité.
      expect(rows.any((r) => r.entry.average == 12), isFalse);
    });

    test('une liste plus courte que topN sort entière', () {
      final rows = rankMerit(sorted([e(15), e(14)]), const MeritFilter(topN: 10));
      expect(rows.length, 2);
    });

    test('liste vide → palmarès vide, sans erreur', () {
      expect(rankMerit(const [], const MeritFilter()), isEmpty);
    });
  });

  group('rankMerit — périmètre', () {
    final pool = sorted([
      e(18, filiere: 'Électrotechnique', dept: 'Pool', gender: 'F', exam: 'BET'),
      e(17, filiere: 'Comptabilité', dept: 'Pool', gender: 'M', exam: 'BET'),
      e(16, filiere: 'Électrotechnique', dept: 'Niari', gender: 'M', exam: 'BEP'),
    ]);

    test('filtre par filière, et renumérote depuis 1', () {
      final rows =
          rankMerit(pool, const MeritFilter(filiere: 'Électrotechnique'));
      expect(rows.length, 2);
      expect(rows.map((r) => r.rank), [1, 2]);
      expect(rows.first.entry.average, 18);
    });

    test('filtre par département', () {
      final rows = rankMerit(pool, const MeritFilter(department: 'Niari'));
      expect(rows.length, 1);
      expect(rows.single.entry.average, 16);
    });

    test('filtre par sexe', () {
      expect(rankMerit(pool, const MeritFilter(gender: 'F')).length, 1);
      expect(rankMerit(pool, const MeritFilter(gender: 'M')).length, 2);
    });

    test('filtre par examen', () {
      expect(rankMerit(pool, const MeritFilter(exam: 'BET')).length, 2);
    });

    test('critères cumulés', () {
      final rows = rankMerit(
        pool,
        const MeritFilter(filiere: 'Électrotechnique', gender: 'M'),
      );
      expect(rows.single.entry.average, 16);
    });
  });

  group('mention et parité', () {
    test('la mention vient de la source unique, pas de la base', () {
      expect(e(18).mention, 'Excellent');
      expect(e(17.9).mention, 'Très Bien');
      expect(e(14).mention, 'Bien');
      expect(e(10).mention, 'Passable');
      expect(e(9.9).mention, 'Insuffisant');
    });

    test('part de filles calculée sur la sélection affichée', () {
      final rows = rankMerit(
        sorted([e(18, gender: 'F'), e(17, gender: 'M'), e(16, gender: 'F')]),
        const MeritFilter(),
      );
      expect(femaleShare(rows), closeTo(66.67, 0.01));
    });

    test('part de filles NULLE sur une sélection vide — jamais 0 %', () {
      // 0 % dirait « aucune fille » ; il n'y a simplement personne à compter.
      expect(femaleShare(const []), isNull);
    });
  });

  group('MeritFilter', () {
    test('isDefault ignore la taille du palmarès', () {
      expect(const MeritFilter(topN: 50).isDefault, isTrue);
      expect(const MeritFilter(filiere: 'X').isDefault, isFalse);
    });

    test('copyWith peut remettre un critère à null', () {
      const f = MeritFilter(filiere: 'X', department: 'Pool');
      final cleared = f.copyWith(filiere: null);
      expect(cleared.filiere, isNull);
      expect(cleared.department, 'Pool', reason: 'les autres sont conservés');
    });

    test('le périmètre est libellé pour le document officiel', () {
      const f = MeritFilter(exam: 'BET', filiere: 'Froid', gender: 'F');
      expect(f.scopeLabel, contains('BET'));
      expect(f.scopeLabel, contains('filière Froid'));
      expect(f.scopeLabel, contains('filles'));
    });
  });

  // ── Un palmarès porte sur UN examen ───────────────────────────────────────
  //  Classer ensemble le CEPE (fin de primaire) et le Baccalauréat n'a pas de
  //  sens : ce ne sont ni les mêmes épreuves, ni les mêmes niveaux. C'est le
  //  même principe qui exclut déjà les bulletins du classement. Tant qu'un seul
  //  examen a des résultats le mélange ne se voit pas — d'où ces garde-fous.
  group('Choix de l\'examen classé', () {
    MeritData data(List<MeritEntry> entries) => MeritData(
          entries: entries,
          unranked: 0,
          exams: const [],
          filieres: const [],
          departments: const [],
          yearLabel: null,
          admittedTotal: entries.length,
        );

    test('sans lauréat, aucun examen n\'est retenu', () {
      expect(resolveExam(data(const []), null), isNull);
    });

    test('l\'examen le plus représenté est retenu par défaut', () {
      final d = data([
        e(12, exam: 'CEPE'),
        e(11, exam: 'BET'),
        e(10, exam: 'BET'),
      ]);
      expect(resolveExam(d, null), 'BET');
    });

    test('un choix explicite est respecté s\'il a des lauréats', () {
      final d = data([e(12, exam: 'BET'), e(11, exam: 'CEPE')]);
      expect(resolveExam(d, 'CEPE'), 'CEPE');
    });

    test('un examen devenu vide est remplacé, pas conservé', () {
      final d = data([e(12, exam: 'BET')]);
      expect(resolveExam(d, 'BAC'), 'BET',
          reason: 'garder « BAC » afficherait une page vide sans explication');
    });

    test('à égalité, le choix par défaut est stable', () {
      final d = data([e(12, exam: 'CEPE'), e(11, exam: 'BET')]);
      expect(resolveExam(d, null), 'BET');
      expect(resolveExam(d, null), 'BET', reason: 'jamais aléatoire');
    });

    test('des lauréats sans examen nommé ne fabriquent pas de périmètre', () {
      expect(resolveExam(data([e(12), e(11)]), null), isNull);
    });

    test('le classement ne retient QUE l\'examen demandé', () {
      final rows = rankMerit(
        [e(19, exam: 'CEPE'), e(15, exam: 'BET'), e(14, exam: 'BET')],
        const MeritFilter(exam: 'BET'),
      );
      expect(rows.length, 2);
      expect(rows.first.entry.average, 15,
          reason: 'le 19 du CEPE ne prend pas la tête du palmarès du BET');
    });
  });
}
