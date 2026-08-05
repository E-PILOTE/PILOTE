import 'package:epilote/features/finance/services/bareme_applicable.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  UN SEUL BARÈME PAR TYPE DE FRAIS (spec §5.2, migration 0096)
//
//  Depuis que le barème appartient au groupe, un poste voit DEUX portées : le
//  tarif du réseau (`school_id IS NULL`) et celui posé pour son école. S'y
//  ajoute le ciblage par niveau. Un élève de 6e peut donc voir quatre lignes
//  pour le MÊME frais — les additionner lui ferait payer quatre fois.
// ════════════════════════════════════════════════════════════════════════════

LigneBareme l(String id, String type, int m, {String? school, String? level}) =>
    (id: id, feeType: type, montant: m, schoolId: school, levelId: level);

void main() {
  group('un seul barème par type de frais', () {
    test('sans rien de spécifique, le tarif du groupe s\'applique', () {
      final r = baremesApplicables([l('g', 'inscription', 5000)], levelId: '6e');
      expect(r.map((e) => e.id), ['g']);
      expect(r.single.montant, 5000);
    });

    test('le tarif posé pour l\'école prime sur celui du réseau', () {
      // ⚠️ Le cas qui compte : additionner les deux ferait un dû de 12 500.
      final r = baremesApplicables([
        l('g', 'inscription', 5000),
        l('e', 'inscription', 7500, school: 'ec1'),
      ], levelId: '6e');
      expect(r.single.id, 'e');
    });

    test('le tarif du niveau prime sur celui de toute l\'école', () {
      final r = baremesApplicables([
        l('tous', 'inscription', 5000),
        l('6e', 'inscription', 3000, level: '6e'),
      ], levelId: '6e');
      expect(r.single.id, '6e');
    });

    test('école + niveau bat école seule et niveau seul', () {
      final r = baremesApplicables([
        l('groupe', 'inscription', 5000),
        l('niveau', 'inscription', 4000, level: '6e'),
        l('ecole', 'inscription', 7000, school: 'ec1'),
        l('les2', 'inscription', 6000, school: 'ec1', level: '6e'),
      ], levelId: '6e');
      expect(r.single.id, 'les2');
    });

    test('l\'ordre d\'arrivée ne change pas le vainqueur', () {
      // La liste vient d'un ORDER BY SQL : elle ne doit pas décider du tarif.
      final r = baremesApplicables([
        l('les2', 'inscription', 6000, school: 'ec1', level: '6e'),
        l('groupe', 'inscription', 5000),
      ], levelId: '6e');
      expect(r.single.id, 'les2');
    });

    test('un barème d\'un AUTRE niveau ne s\'applique pas', () {
      final r = baremesApplicables([
        l('term', 'inscription', 9000, level: 'terminale'),
      ], levelId: '6e');
      expect(r, isEmpty);
    });

    test('des types différents coexistent, ils ne se remplacent pas', () {
      final r = baremesApplicables([
        l('i', 'inscription', 5000),
        l('m', 'mensualite', 12000),
        l('a', 'cotisation_ape', 2000),
      ], levelId: '6e');
      expect(r.length, 3);
    });

    test('un élève sans niveau connu ne prend que les tarifs tous niveaux', () {
      final r = baremesApplicables([
        l('tous', 'inscription', 5000),
        l('6e', 'inscription', 3000, level: '6e'),
      ], levelId: null);
      expect(r.single.id, 'tous');
    });

    test('aucun barème visible ne donne aucune obligation', () {
      expect(baremesApplicables(const [], levelId: '6e'), isEmpty);
    });
  });
}
