import 'package:flutter_test/flutter_test.dart';
import 'package:epilote/features/admin_groupe/providers/admin_students_provider.dart';

/// Recherche d'élèves au niveau du réseau (ministère).
///
/// Deux pièges gardés ici :
///  • une virgule ou une parenthèse tapée dans la barre de recherche ne doit
///    JAMAIS atteindre le filtre PostgREST — elle y changerait la requête ;
///  • une recherche trop courte ne doit pas partir : sur un réseau national,
///    « a » ramènerait une part énorme de la base pour rien.
void main() {
  group('StudentQuery — déclenchement', () {
    test('ne part pas sans critère', () {
      expect(const StudentQuery().isRunnable, isFalse);
    });

    test('ne part pas sur un seul caractère', () {
      expect(const StudentQuery(search: 'a').isRunnable, isFalse);
    });

    test('part dès 2 caractères', () {
      expect(const StudentQuery(search: 'ok').isRunnable, isTrue);
    });

    test('part sur un établissement seul, sans terme', () {
      expect(const StudentQuery(schoolId: 'ecole-1').isRunnable, isTrue);
    });

    test('part sur un sexe seul', () {
      expect(const StudentQuery(gender: 'F').isRunnable, isTrue);
    });

    test('part sur un département seul — le réflexe d\'un ministère', () {
      expect(const StudentQuery(department: 'Niari').isRunnable, isTrue);
    });

    test('part sur une filière seule — la lentille du METP', () {
      expect(const StudentQuery(filiere: 'Électrotechnique').isRunnable, isTrue);
    });

    test('les espaces ne comptent pas comme des caractères', () {
      expect(const StudentQuery(search: '  a  ').isRunnable, isFalse);
      expect(const StudentQuery(search: '  ok  ').isRunnable, isTrue);
    });
  });

  group('StudentQuery — assainissement du terme', () {
    test('retire les caractères qui casseraient le filtre PostgREST', () {
      const q = StudentQuery(search: 'Okemba, (Josué) 100%');
      expect(q.safeSearch, isNot(contains(',')));
      expect(q.safeSearch, isNot(contains('(')));
      expect(q.safeSearch, isNot(contains(')')));
      expect(q.safeSearch, isNot(contains('%')));
    });

    test('conserve les lettres accentuées et les traits d\'union', () {
      const q = StudentQuery(search: 'Mvoula-Ngoï');
      expect(q.safeSearch, 'Mvoula-Ngoï');
    });

    test('un terme fait uniquement de séparateurs ne déclenche rien', () {
      expect(const StudentQuery(search: ',,,()').isRunnable, isFalse);
    });

    test('rogne les espaces de bord', () {
      expect(const StudentQuery(search: '  Ekani  ').safeSearch, 'Ekani');
    });
  });

  group('StudentQuery — copyWith et égalité', () {
    test('remet un critère à null sans toucher aux autres', () {
      const q = StudentQuery(search: 'ok', schoolId: 'e1', gender: 'F');
      final c = q.copyWith(schoolId: null);
      expect(c.schoolId, isNull);
      expect(c.gender, 'F');
      expect(c.search, 'ok');
    });

    test('deux requêtes identiques sont égales — pas de refetch inutile', () {
      expect(const StudentQuery(search: 'ok', schoolId: 'e1'),
          const StudentQuery(search: 'ok', schoolId: 'e1'));
      expect(const StudentQuery(search: 'ok').hashCode,
          const StudentQuery(search: 'ok').hashCode);
    });

    test('activeOnly est vrai par défaut', () {
      expect(const StudentQuery().activeOnly, isTrue);
    });

    test('département et filière se remettent à null indépendamment', () {
      const q = StudentQuery(department: 'Niari', filiere: 'Série C');
      expect(q.copyWith(department: null).filiere, 'Série C');
      expect(q.copyWith(filiere: null).department, 'Niari');
    });

    test('deux requêtes ne diffèrant que par la filière ne sont pas égales', () {
      expect(const StudentQuery(filiere: 'A'),
          isNot(const StudentQuery(filiere: 'B')));
    });
  });

  group('StudentQuery — périmètre affiché et exporté', () {
    test('aucun filtre = aucun critère à annoncer', () {
      expect(const StudentQuery().activeFilters, isEmpty);
    });

    test('chaque critère actif est libellé pour le PDF', () {
      const q = StudentQuery(
        search: 'Ekani',
        department: 'Niari',
        filiere: 'Électrotechnique',
        gender: 'F',
        activeOnly: false,
      );
      final labels = q.activeFilters.map((e) => e.$1).toList();
      expect(labels,
          containsAll(['Recherche', 'Département', 'Filière', 'Sexe', 'Statut']));
      expect(q.activeFilters.firstWhere((e) => e.$1 == 'Sexe').$2, 'Filles');
    });

    test('le statut par défaut ne pollue pas le périmètre', () {
      expect(const StudentQuery(department: 'Niari').activeFilters.length, 1);
    });
  });

  group('Tri de la liste', () {
    GroupStudent s(String name,
            {String school = 'École', String? klass, int? age}) =>
        GroupStudent(
          id: name,
          fullName: name,
          schoolName: school,
          isActive: true,
          className: klass,
          dateOfBirth:
              age == null ? null : DateTime(DateTime.now().year - age, 1, 1),
        );

    test('le tri par défaut est alphabétique croissant', () {
      final r = sortStudents(
          [s('Ngoma'), s('Ekani')], const StudentSortState());
      expect(r.first.fullName, 'Ekani');
    });

    test('recliquer la même colonne inverse le sens', () {
      const st = StudentSortState();
      final flipped = st.toggled(StudentSort.name);
      expect(flipped.ascending, isFalse);
      expect(flipped.key, StudentSort.name);
    });

    test('changer de colonne repart en croissant', () {
      const st = StudentSortState(key: StudentSort.name, ascending: false);
      expect(st.toggled(StudentSort.school).ascending, isTrue);
    });

    test('une valeur absente reste en fin de liste dans les DEUX sens', () {
      final rows = [s('A', klass: null), s('B', klass: '3ème A')];
      for (final asc in [true, false]) {
        final r = sortStudents(
            rows, StudentSortState(key: StudentSort.className, ascending: asc));
        expect(r.last.className, isNull,
            reason: 'un « — » en tête passerait pour une donnée');
      }
    });

    test('un âge manquant ne se trie pas comme un âge de zéro', () {
      final r = sortStudents([s('A'), s('B', age: 14)],
          const StudentSortState(key: StudentSort.age));
      expect(r.first.age, 14);
    });

    test('à égalité, l\'ordre reste stable — départage par nom', () {
      final rows = [s('Ngoma', school: 'X'), s('Ekani', school: 'X')];
      final r =
          sortStudents(rows, const StudentSortState(key: StudentSort.school));
      expect(r.map((e) => e.fullName), ['Ekani', 'Ngoma']);
    });

    test('le tri ne modifie pas la liste d\'origine', () {
      final rows = [s('Ngoma'), s('Ekani')];
      sortStudents(rows, const StudentSortState());
      expect(rows.first.fullName, 'Ngoma');
    });
  });

  group('GroupStudent', () {
    GroupStudent s({DateTime? dob, String? className}) => GroupStudent(
          id: '1',
          fullName: 'Test Élève',
          schoolName: 'École',
          isActive: true,
          dateOfBirth: dob,
          className: className,
        );

    test('âge révolu, pas différence d\'années', () {
      final now = DateTime.now();
      // Anniversaire pas encore passé cette année → un an de moins.
      final tomorrow = now.add(const Duration(days: 1));
      final dob = DateTime(now.year - 15, tomorrow.month, tomorrow.day);
      final age = s(dob: dob).age;
      expect(age, anyOf(14, 15), reason: 'jamais 16 : l\'anniversaire n\'est pas passé');
    });

    test('âge nul si la date manque — jamais 0 an', () {
      expect(s().age, isNull);
    });

    test('âge nul si la date est aberrante', () {
      expect(s(dob: DateTime(1700)).age, isNull);
      expect(s(dob: DateTime(3000)).age, isNull);
    });

    test('sans classe pour l\'année courante = signalé', () {
      expect(s().isUnplaced, isTrue);
      expect(s(className: '3ème A').isUnplaced, isFalse);
    });
  });
}
