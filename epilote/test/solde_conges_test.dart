import 'dart:io';

import 'package:epilote/data/models/academic_year_model.dart';
import 'package:epilote/features/staff/providers/leave_provider.dart';
import 'package:epilote/features/staff/providers/solde_conges_provider.dart';
import 'package:epilote/features/structure/providers/academic_year_context.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  APPROUVER UN CONGÉ SANS SAVOIR CE QUI A DÉJÀ ÉTÉ ACCORDÉ
//
//  ── LE DÉFAUT ─────────────────────────────────────────────────────────────
//  Le module enregistrait des demandes et n'en tirait aucun décompte. Un agent
//  déposait soixante jours ; le directeur approuvait sans savoir qu'il en avait
//  déjà pris quarante. Aucune erreur, aucun message : une décision prise à
//  l'aveugle, avec l'apparence d'une décision.
//
//  ── ⚠️ ET CE QUE CE FICHIER REFUSE DE FAIRE ───────────────────────────────
//  Il ne fixe PAS le droit annuel. Ce nombre vient du Code du travail pour le
//  privé et du statut de la fonction publique pour le public — deux textes,
//  deux chiffres, et la plateforme sert les deux.
//
//  L'inventer produirait le défaut que ce dépôt a déjà payé une fois : le
//  barème de mentions avait glissé de deux points, personne ne l'a vu, et 8/20
//  ressortait « Passable ». Un droit de congé faux ne se verrait pas
//  davantage — et il ferait REFUSER des congés.
//
//  Le mécanisme est donc complet et le nombre reste `null`, visiblement. Les
//  tests ci-dessous vérifient les deux moitiés : que l'inconnu se propage sans
//  jamais devenir zéro, et que l'arithmétique est juste le jour où le chiffre
//  arrivera.
// ════════════════════════════════════════════════════════════════════════════

LeaveRequest _demande({
  String staff = 'a1',
  String type = 'annuel',
  String statut = 'approved',
  int jours = 5,
  String debut = '2025-11-10',
}) =>
    LeaveRequest(
      id: 'l$staff$type$statut$debut$jours',
      staffId: staff,
      staffName: 'MAKOSSO Jean',
      leaveType: type,
      startDate: debut,
      endDate: debut,
      daysCount: jours,
      status: statut,
    );

final _annee = AcademicYearModel(
  id: 'y1',
  groupId: 'g1',
  schoolId: 's1',
  label: '2025-2026',
  startDate: DateTime(2025, 10, 1),
  endDate: DateTime(2026, 7, 31),
  isCurrent: true,
  isLocked: false,
  createdAt: DateTime(2025, 9, 1),
  updatedAt: DateTime(2025, 9, 1),
);

/// [sansAnnee] force le cas « aucune année active ». Un paramètre `null`
/// n'aurait pas suffi : `null` est aussi la valeur par défaut, et le test se
/// serait exécuté AVEC l'année sans que rien ne le signale — un test vert
/// qui ne teste pas ce qu'il annonce.
Future<Map<String, ConsommationConges>> _calcul(
  List<LeaveRequest> demandes, {
  bool sansAnnee = false,
}) async {
  final c = ProviderContainer(overrides: [
    leaveRequestsProvider.overrideWith((ref) => Stream.value(demandes)),
    activeYearProvider.overrideWithValue(sansAnnee ? null : _annee),
  ]);
  addTearDown(c.dispose);
  await c.read(leaveRequestsProvider.future);
  return c.read(consommationCongesProvider);
}

void main() {
  group('Seul le congé ANNUEL s’impute sur le droit', () {
    test('un congé maladie ne compte pas comme congé annuel', () async {
      final k = (await _calcul([
        _demande(type: 'annuel', jours: 10),
        _demande(type: 'maladie', jours: 20),
      ]))['a1']!;
      expect(k.approuves, 10,
          reason: 'Mélanger les deux ferait apparaître comme gros '
              'consommateur l’agent qui a été malade.');
      expect(k.horsDecompte, 20,
          reason: 'Compté à part : il informe le décideur sans s’imputer.');
    });

    test('maternité, formation, mission et sans solde restent hors décompte',
        () async {
      final k = (await _calcul([
        for (final t in ['maternite', 'formation', 'mission', 'sans_solde'])
          _demande(type: t, jours: 3),
      ]))['a1']!;
      expect(k.approuves, 0);
      expect(k.horsDecompte, 12);
    });

    test('la liste des types décomptés tient en un seul endroit', () {
      expect(kCongesDecomptes, {'annuel'});
    });
  });

  group('🩸 Une demande refusée n’a pas été prise', () {
    test('refusé et annulé ne consomment rien', () async {
      final k = await _calcul([
        _demande(statut: 'rejected', jours: 30),
        _demande(statut: 'cancelled', jours: 30),
      ]);
      expect(k['a1']?.approuves ?? 0, 0,
          reason: 'Décompter un congé refusé priverait l’agent de jours qu’on '
              'lui a précisément refusé de prendre.');
      expect(k['a1']?.enAttente ?? 0, 0);
    });

    test('l’instruction en cours se compte À PART de l’accordé', () async {
      final k = (await _calcul([
        _demande(statut: 'approved', jours: 12),
        _demande(statut: 'pending', jours: 8, debut: '2026-01-05'),
      ]))['a1']!;
      expect(k.approuves, 12);
      expect(k.enAttente, 8);
      expect(k.engage, 20,
          reason: 'C’est `engage` qui répond à « où en sera-t-il si '
              'j’approuve ».');
    });
  });

  group('La fenêtre est l’année scolaire', () {
    test('un congé de l’année précédente ne pèse plus', () async {
      final k = await _calcul([
        _demande(jours: 25, debut: '2025-03-12'), // année scolaire d'avant
        _demande(jours: 4, debut: '2025-11-10'),
      ]);
      expect(k['a1']!.approuves, 4);
    });

    test('les bornes de l’année sont INCLUSES', () async {
      final k = await _calcul([
        _demande(jours: 1, debut: '2025-10-01'),
        _demande(jours: 1, debut: '2026-07-31'),
      ]);
      expect(k['a1']!.approuves, 2,
          reason: 'Une comparaison stricte ferait disparaître le congé du '
              'premier et du dernier jour de l’année.');
    });

    test('sans année active, on totalise TOUT plutôt que RIEN', () async {
      // Un total large est visiblement large. Un zéro se lit « n’a rien pris »
      // — et c’est le seul des deux qui trompe.
      final k = await _calcul([
        _demande(jours: 25, debut: '2019-03-12'),
        _demande(jours: 4, debut: '2025-11-10'),
      ], sansAnnee: true);
      expect(k['a1']!.approuves, 29);
    });
  });

  group('🩸 Le droit inconnu ne devient JAMAIS zéro', () {
    test('sans droit, le reliquat est `null` et rien n’est en dépassement',
        () async {
      final k = (await _calcul([_demande(jours: 90)]))['a1']!;
      expect(k.droitConnu, isFalse);
      expect(k.restant, isNull,
          reason: 'Un reliquat à 0 sur un droit inconnu ferait refuser un '
              'congé dû.');
      expect(k.restantSiToutAccorde, isNull);
      expect(k.depasse, isFalse,
          reason: 'Annoncer un dépassement qu’on ne peut pas établir est '
              'exactement aussi faux que de n’en annoncer aucun.');
      expect(k.depasseraitSiAccorde, isFalse);
    });

    test('le jour où le droit sera fixé, l’arithmétique est déjà juste', () {
      const k = ConsommationConges(
        staffId: 'a1',
        approuves: 22,
        enAttente: 6,
        horsDecompte: 4,
        droitAnnuel: 26,
      );
      expect(k.droitConnu, isTrue);
      expect(k.restant, 4);
      expect(k.restantSiToutAccorde, -2);
      expect(k.depasse, isFalse);
      expect(k.depasseraitSiAccorde, isTrue,
          reason: 'C’est l’alerte utile : pas « il a dépassé », mais '
              '« il dépassera si vous signez ».');
    });

    test('un dépassement avéré se distingue d’un dépassement à venir', () {
      const k = ConsommationConges(
        staffId: 'a1',
        approuves: 30,
        enAttente: 0,
        horsDecompte: 0,
        droitAnnuel: 26,
      );
      expect(k.depasse, isTrue);
      expect(k.restant, -4);
    });
  });

  group('L’écran et le provider tiennent leur doctrine', () {
    String lire(String c) => File(c).readAsStringSync().replaceAll('\r\n', '\n');

    // ⚠️ Le rendu d'une demande a été sorti de `conges_screen.dart` vers
    // `conges_carte.dart` le 2026-09-10 (le fichier passait 500 lignes). Une
    // sonde de source doit suivre sa cible dans le MÊME commit, sinon elle
    // devient verte pour la mauvaise raison — ou rouge sans défaut.
    test('le décompte ne s’affiche que sur une demande à instruire', () {
      final src = lire('lib/features/staff/screens/conges_carte.dart');
      expect(src.contains('if (canReview && r.isPending) _decompte()'), isTrue,
          reason: 'Sur une demande déjà tranchée, il ne fait que du bruit.');
    });

    test('l’écran DIT que le droit n’est pas établi', () {
      // Une case vide sans explication se lit comme un défaut de l'outil.
      final src = lire('lib/features/staff/screens/conges_carte.dart');
      expect(src.contains('Droit annuel non établi'), isTrue);
    });

    test('le calcul ne coûte aucune requête de plus', () {
      final src =
          lire('lib/features/staff/providers/solde_conges_provider.dart');
      expect(src.contains('ref.watch(leaveRequestsProvider)'), isTrue);
      expect(src.contains('db.watch') || src.contains('db.getAll'), isFalse,
          reason: 'Le décompte se dérive des demandes déjà chargées. Une '
              'requête de plus par carte serait une requête par ligne de '
              'liste.');
    });

    test('la raison du droit manquant est écrite, pas seulement le manque', () {
      final src =
          lire('lib/features/staff/providers/solde_conges_provider.dart');
      expect(src.contains('MEPSA'), isTrue);
      expect(src.contains('METP'), isTrue,
          reason: 'Sans la raison, quelqu’un inscrira « 30 » pour faire '
              'propre — et tout le pays instruira sur ce nombre.');
    });
  });
}
