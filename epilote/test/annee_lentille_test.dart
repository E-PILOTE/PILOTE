import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:epilote/data/models/academic_year_model.dart';
import 'package:epilote/features/auth/providers/active_agent_provider.dart';
import 'package:epilote/features/structure/providers/academic_year_context.dart';
import 'package:epilote/features/structure/providers/academic_year_provider.dart';
import 'package:epilote/features/structure/providers/school_holidays_provider.dart';

/// ══════════════════════════════════════════════════════════════════════════
///  LA LENTILLE D'ANNÉE — le mécanisme qui scope TOUT l'espace école.
///
///  132 lectures dans 78 fichiers dépendent de `activeYearIdProvider` : classes,
///  inscriptions, notes, bulletins, présences, caisse. C'est le point le plus
///  central du produit, et il n'avait aucun test.
///
///  Ce qu'on fixe ici, ce sont les décisions qui ne se voient pas quand elles
///  se trompent :
///   • une année sélectionnée qui disparaît doit faire RETOMBER sur l'année
///     courante, jamais laisser l'app sans année (sinon les écrans se vident) ;
///   • `null` ne doit JAMAIS être écrivable — sans année résolue, une écriture
///     partirait sans `academic_year_id` et polluerait la base nationale ;
///   • sur un poste partagé, la lentille appartient à l'agent au clavier, pas
///     à la machine.
/// ══════════════════════════════════════════════════════════════════════════

AcademicYearModel _year(
  String id, {
  bool current = false,
  bool locked = false,
  int startYear = 2025,
}) =>
    AcademicYearModel(
      id: id,
      groupId: 'g1',
      schoolId: null,
      label: '$startYear-${startYear + 1}',
      startDate: DateTime(startYear, 9, 1),
      endDate: DateTime(startYear + 1, 7, 15),
      isCurrent: current,
      isLocked: locked,
      createdAt: DateTime(startYear),
      updatedAt: DateTime(startYear),
    );

/// Agent au clavier, pilotable depuis le test (évite Supabase et le PIN).
final _fakeAgent = StateProvider<String?>((ref) => 'agent-1');

ProviderContainer _container({
  required List<AcademicYearModel> years,
  AcademicYearModel? current,
}) =>
    ProviderContainer(overrides: [
      academicYearsProvider.overrideWith((ref) => Stream.value(years)),
      currentAcademicYearProvider.overrideWith((ref) => Stream.value(current)),
      activeAgentIdProvider.overrideWith((ref) => ref.watch(_fakeAgent)),
    ]);

/// Laisse les `StreamProvider` surchargés livrer leur première valeur.
Future<void> _settle(ProviderContainer c) async {
  await c.read(academicYearsProvider.future);
  await c.read(currentAcademicYearProvider.future);
}

void main() {
  group('activeYearProvider — quelle année pilote l\'application', () {
    test('sans sélection, suit l\'année courante de l\'établissement', () async {
      final courante = _year('y2026', current: true, startYear: 2026);
      final c = _container(
        years: [courante, _year('y2025', startYear: 2025)],
        current: courante,
      );
      addTearDown(c.dispose);
      await _settle(c);

      expect(c.read(activeYearIdProvider), 'y2026');
    });

    test('une sélection explicite prime sur l\'année courante', () async {
      final courante = _year('y2026', current: true, startYear: 2026);
      final passee = _year('y2025', startYear: 2025);
      final c = _container(years: [courante, passee], current: courante);
      addTearDown(c.dispose);
      await _settle(c);

      c.read(selectedYearIdProvider.notifier).select('y2025');

      expect(c.read(activeYearIdProvider), 'y2025');
    });

    test(
        'une année sélectionnée qui n\'est plus visible fait retomber sur la '
        'courante — jamais sur rien', () async {
      // Cas réel : le groupe retire une année, ou les sync-rules cessent de la
      // descendre. Si on gardait l'id fantôme, tous les écrans de l'école se
      // videraient sans message.
      final courante = _year('y2026', current: true, startYear: 2026);
      final c = _container(years: [courante], current: courante);
      addTearDown(c.dispose);
      await _settle(c);

      c.read(selectedYearIdProvider.notifier).select('annee-disparue');

      expect(c.read(activeYearIdProvider), 'y2026');
    });

    test('aucune année résolue ⇒ null (aucune donnée ne doit fuiter)',
        () async {
      final c = _container(years: const [], current: null);
      addTearDown(c.dispose);
      await _settle(c);

      expect(c.read(activeYearIdProvider), isNull);
    });

    test('revenir à null rebascule sur le suivi automatique', () async {
      final courante = _year('y2026', current: true, startYear: 2026);
      final c = _container(
        years: [courante, _year('y2025', startYear: 2025)],
        current: courante,
      );
      addTearDown(c.dispose);
      await _settle(c);

      c.read(selectedYearIdProvider.notifier).select('y2025');
      expect(c.read(activeYearIdProvider), 'y2025');

      c.read(selectedYearIdProvider.notifier).select(null);
      expect(c.read(activeYearIdProvider), 'y2026');
    });
  });

  group('yearReadOnlyProvider — qui a le droit d\'écrire', () {
    test('l\'année courante non verrouillée est écrivable', () async {
      final courante = _year('y2026', current: true, startYear: 2026);
      final c = _container(years: [courante], current: courante);
      addTearDown(c.dispose);
      await _settle(c);

      expect(c.read(yearReadOnlyProvider), isFalse);
    });

    test('une année passée est en lecture seule', () async {
      final courante = _year('y2026', current: true, startYear: 2026);
      final passee = _year('y2025', startYear: 2025);
      final c = _container(years: [courante, passee], current: courante);
      addTearDown(c.dispose);
      await _settle(c);

      c.read(selectedYearIdProvider.notifier).select('y2025');

      expect(c.read(yearReadOnlyProvider), isTrue);
    });

    test('une année verrouillée reste en lecture seule même si « courante »',
        () async {
      // Ceinture ET bretelles : `is_locked` doit gagner quoi qu'il arrive.
      final gelee =
          _year('y2026', current: true, locked: true, startYear: 2026);
      final c = _container(years: [gelee], current: gelee);
      addTearDown(c.dispose);
      await _settle(c);

      expect(c.read(yearReadOnlyProvider), isTrue);
    });

    test('sans année résolue, TOUT est en lecture seule', () async {
      // Le défaut le plus dangereux serait l'inverse : une écriture sans
      // `academic_year_id` part en base et n'appartient à aucune année.
      final c = _container(years: const [], current: null);
      addTearDown(c.dispose);
      await _settle(c);

      expect(c.read(yearReadOnlyProvider), isTrue);
    });
  });

  group('la lentille appartient à l\'agent, pas au poste', () {
    test('changer d\'agent réinitialise la sélection d\'année', () async {
      // Poste partagé : le proviseur consulte 2025-2026, rend la main. Le
      // comptable ne doit pas hériter d\'une caisse en lecture seule.
      final courante = _year('y2026', current: true, startYear: 2026);
      final passee = _year('y2025', startYear: 2025);
      final c = _container(years: [courante, passee], current: courante);
      addTearDown(c.dispose);
      await _settle(c);

      c.read(selectedYearIdProvider.notifier).select('y2025');
      expect(c.read(activeYearIdProvider), 'y2025');

      c.read(_fakeAgent.notifier).state = 'agent-2'; // bascule d'agent

      expect(c.read(selectedYearIdProvider), isNull);
      expect(c.read(activeYearIdProvider), 'y2026');
    });

    test('la déconnexion (plus aucun agent) réinitialise aussi', () async {
      final courante = _year('y2026', current: true, startYear: 2026);
      final c = _container(
        years: [courante, _year('y2025', startYear: 2025)],
        current: courante,
      );
      addTearDown(c.dispose);
      await _settle(c);

      c.read(selectedYearIdProvider.notifier).select('y2025');
      c.read(_fakeAgent.notifier).state = null;

      expect(c.read(selectedYearIdProvider), isNull);
    });
  });

  group('yearStatusOf — le libellé porté par le sélecteur du header', () {
    test('aucune année', () => expect(yearStatusOf(null), YearStatus.none));

    test('verrouillée prime sur courante', () {
      expect(
        yearStatusOf(_year('y', current: true, locked: true)),
        YearStatus.locked,
      );
    });

    test('courante', () {
      expect(yearStatusOf(_year('y', current: true)), YearStatus.current);
    });

    test('à venir quand la rentrée n\'a pas eu lieu', () {
      final futur = DateTime.now().year + 3;
      expect(yearStatusOf(_year('y', startYear: futur)), YearStatus.upcoming);
    });

    test('archivée quand elle a commencé sans être courante', () {
      expect(yearStatusOf(_year('y', startYear: 2001)), YearStatus.archived);
    });
  });

  group('countSchoolDays — le chiffre que regarde un chef d\'établissement', () {
    SchoolHoliday h(String label, DateTime a, DateTime b, {String kind = 'vacances'}) =>
        SchoolHoliday(
            id: label, label: label, kind: kind, startDate: a, endDate: b);

    test('une semaine pleine vaut 5 jours de classe', () {
      // lundi 1er au dimanche 7 septembre 2026.
      expect(
        countSchoolDays(DateTime(2026, 9, 1), DateTime(2026, 9, 7), const []),
        5,
      );
    });

    test('les week-ends ne comptent jamais', () {
      // samedi 5 + dimanche 6 septembre 2026.
      expect(
        countSchoolDays(DateTime(2026, 9, 5), DateTime(2026, 9, 6), const []),
        0,
      );
    });

    test('un férié en semaine retire un jour', () {
      expect(
        countSchoolDays(DateTime(2026, 9, 1), DateTime(2026, 9, 7), [
          h('Fête', DateTime(2026, 9, 2), DateTime(2026, 9, 2), kind: 'ferie'),
        ]),
        4,
      );
    });

    test('un férié tombant un week-end ne retire rien', () {
      expect(
        countSchoolDays(DateTime(2026, 9, 1), DateTime(2026, 9, 7), [
          h('Fête', DateTime(2026, 9, 5), DateTime(2026, 9, 5), kind: 'ferie'),
        ]),
        5,
      );
    });

    test('une période de vacances retire ses jours ouvrables seulement', () {
      // Le 1er septembre 2026 est un MARDI. Du 1er au 14 : mar-ven (4), lun-ven
      // (5), lun 14 (1) = 10 jours ouvrables. Une semaine de vacances posée du
      // lundi 7 au dimanche 13 en couvre 5 → il en reste 5. Les deux week-ends
      // ne sont comptés ni d'un côté ni de l'autre.
      expect(
        countSchoolDays(DateTime(2026, 9, 1), DateTime(2026, 9, 14), [
          h('Congés', DateTime(2026, 9, 7), DateTime(2026, 9, 13)),
        ]),
        5,
      );
    });

    test('des périodes qui se chevauchent ne décomptent pas deux fois', () {
      // A couvre mar 1 → jeu 3, B mer 2 → ven 4 : l'union est mar→ven, soit 4
      // des 5 jours ouvrables de la fenêtre. Il reste le lundi 7.
      expect(
        countSchoolDays(DateTime(2026, 9, 1), DateTime(2026, 9, 7), [
          h('A', DateTime(2026, 9, 1), DateTime(2026, 9, 3)),
          h('B', DateTime(2026, 9, 2), DateTime(2026, 9, 4)),
        ]),
        1,
      );
    });

    test('un intervalle inversé ne boucle pas et vaut 0', () {
      expect(
        countSchoolDays(DateTime(2026, 9, 10), DateTime(2026, 9, 1), const []),
        0,
      );
    });
  });
}
