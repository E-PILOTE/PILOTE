import 'package:flutter_test/flutter_test.dart';

import 'package:epilote/features/admin_groupe/providers/admin_regional_provider.dart';

AdminSchoolPin _pin(
  String id, {
  String? dept,
  bool gps = false,
  int students = 0,
  bool active = true,
}) =>
    AdminSchoolPin(
      id: id,
      name: 'EP $id',
      type: 'public',
      isActive: active,
      students: students,
      department: dept,
      latitude: gps ? -4.26 : null,
      longitude: gps ? 15.27 : null,
    );

void main() {
  test('deptKeyOf : département vide/absent → « Non précisé »', () {
    expect(deptKeyOf(_pin('1', dept: 'Brazzaville')), 'Brazzaville');
    expect(deptKeyOf(_pin('2')), 'Non précisé');
    expect(deptKeyOf(_pin('3', dept: '')), 'Non précisé');
  });

  test('buildDeptEntries agrège écoles/élèves/actives par département', () {
    final entries = buildDeptEntries([
      _pin('1', dept: 'Brazzaville', students: 10),
      _pin('2', dept: 'Brazzaville', students: 5, active: false),
      _pin('3', dept: 'Niari', students: 7),
    ]);
    expect(entries.length, 2);
    // trié par nombre d'écoles décroissant
    final bzv = entries.first;
    expect(bzv.dept, 'Brazzaville');
    expect(bzv.schoolCount, 2);
    expect(bzv.studentCount, 15);
    expect(bzv.activeCount, 1);
  });

  test('countCoveredDepts exclut « Non précisé »', () {
    final entries = buildDeptEntries([
      _pin('1', dept: 'Brazzaville'),
      _pin('2', dept: 'Niari'),
      _pin('3'), // sans département
    ]);
    expect(entries.length, 3);
    expect(countCoveredDepts(entries), 2);
  });

  // ── Régression : le bug qui vidait la répartition départementale ───────────
  test('géolocaliser TOUTES les écoles ne vide pas allDepts ni coveredDepts',
      () {
    final pins = [
      _pin('1', dept: 'Brazzaville', gps: true, students: 4),
      _pin('2', dept: 'Brazzaville', gps: true, students: 4),
    ];
    // `depts` (bulles carte) = écoles SANS GPS → vide, c'est attendu.
    final depts = buildDeptEntries(pins.where((p) => !p.hasGps));
    expect(depts, isEmpty);

    // `allDepts` (KPI/PDF/analytique) doit toujours contenir Brazzaville.
    final allDepts = buildDeptEntries(pins);
    expect(allDepts.length, 1);
    expect(allDepts.single.dept, 'Brazzaville');
    expect(allDepts.single.schoolCount, 2);
    expect(allDepts.single.studentCount, 8);
    expect(countCoveredDepts(allDepts), 1);
  });
}
