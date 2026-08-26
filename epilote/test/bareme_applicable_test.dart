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

LigneBareme l(String id, String type, int m,
        {String? school, String? level, String nom = '', int? jourEcheance}) =>
    (
      id: id,
      feeType: type,
      jourEcheance: jourEcheance,
      // Par défaut l'intitulé est vide : il ne pèse que sur les frais annexes
      // (cf. groupe « les frais annexes »), et le laisser vide ailleurs prouve
      // qu'il n'intervient PAS dans la résolution des autres types.
      nom: nom,
      montant: m,
      schoolId: school,
      levelId: level,
    );

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

  // ══════════════════════════════════════════════════════════════════════════
  //  ÉGALITÉ DE PORTÉE — le cas que la migration 0099 interdit en base, et que
  //  le poste doit malgré tout trancher SEUL.
  //
  //  Un appareil hors ligne peut porter, le temps d'une synchro, l'ancien et
  //  le nouveau barème. Avant le correctif, `>` strict laissait gagner le
  //  premier arrivé — et la requête amont n'a pas d'`ORDER BY`. Deux postes de
  //  la même école pouvaient réclamer deux sommes différentes au même élève.
  // ══════════════════════════════════════════════════════════════════════════
  group('deux barèmes de portée identique', () {
    test('le moins cher l\'emporte — jamais la famille qui paie l\'hésitation',
        () {
      final r = baremesApplicables([
        l('cher', 'inscription', 25000),
        l('juste', 'inscription', 15000),
      ], levelId: '6e');
      expect(r.single.id, 'juste');
      expect(r.single.montant, 15000);
    });

    test('et l\'ordre d\'arrivée n\'y change rien', () {
      final r = baremesApplicables([
        l('juste', 'inscription', 15000),
        l('cher', 'inscription', 25000),
      ], levelId: '6e');
      expect(r.single.id, 'juste');
    });

    test('à montant égal, l\'id départage — deux postes tombent d\'accord', () {
      final ordre1 = baremesApplicables([
        l('bbb', 'inscription', 15000),
        l('aaa', 'inscription', 15000),
      ], levelId: '6e');
      final ordre2 = baremesApplicables([
        l('aaa', 'inscription', 15000),
        l('bbb', 'inscription', 15000),
      ], levelId: '6e');
      expect(ordre1.single.id, 'aaa');
      expect(ordre2.single.id, 'aaa');
    });

    test('l\'égalité se départage aussi en portée école', () {
      final r = baremesApplicables([
        l('ec_cher', 'mensualite', 20000, school: 'ec1'),
        l('ec_juste', 'mensualite', 12000, school: 'ec1'),
        l('reseau', 'mensualite', 8000),
      ], levelId: '6e');
      // L'école prime sur le réseau (spécificité), puis le moins cher des deux
      // lignes d'école — le tarif réseau à 8 000 ne doit PAS remonter.
      expect(r.single.id, 'ec_juste');
    });

    test('un doublon ne fait jamais payer deux fois', () {
      final r = baremesApplicables([
        l('a', 'inscription', 15000),
        l('b', 'inscription', 15000),
        l('c', 'inscription', 15000),
      ], levelId: '6e');
      expect(r.length, 1);
      expect(r.single.montant, 15000);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  //  LES FRAIS ANNEXES (migration 0108)
  //
  //  `autre` est la seule catégorie ouverte de l'enum `fee_type` : cantine,
  //  transport, tenue, fournitures y tombent toutes. Les mettre en concurrence
  //  par leur type — ce que faisait la version précédente — n'en gardait qu'une
  //  seule : l'école enregistrait deux frais et n'en réclamait qu'un, sans que
  //  rien ne le signale.
  // ══════════════════════════════════════════════════════════════════════════
  group('les frais annexes', () {
    test('la cantine et le bus sont dus TOUS LES DEUX', () {
      final r = baremesApplicables([
        l('cant', 'autre', 10000, nom: 'Cantine'),
        l('bus', 'autre', 15000, nom: 'Transport'),
      ], levelId: '6e');
      expect(r.length, 2);
      expect(r.map((e) => e.montant).fold(0, (a, b) => a + b), 25000);
    });

    test('mais deux « Cantine » restent un doublon', () {
      final r = baremesApplicables([
        l('a', 'autre', 10000, nom: 'Cantine'),
        l('b', 'autre', 12000, nom: 'Cantine'),
      ], levelId: '6e');
      expect(r.length, 1);
      expect(r.single.montant, 10000, reason: 'le moins cher, comme ailleurs');
    });

    test('la casse et les espaces ne créent pas un second frais', () {
      // L'index `uniq_fee_structure_annexe_active` normalise de la même façon.
      // S'ils divergeaient, la base accepterait ce que le client dédoublerait.
      final r = baremesApplicables([
        l('a', 'autre', 10000, nom: 'Cantine'),
        l('b', 'autre', 12000, nom: '  cantine '),
      ], levelId: '6e');
      expect(r.length, 1);
    });

    test('le tarif d\'école prime toujours, par intitulé', () {
      final r = baremesApplicables([
        l('res_cant', 'autre', 10000, nom: 'Cantine'),
        l('ec_cant', 'autre', 14000, nom: 'Cantine', school: 'ec1'),
        l('res_bus', 'autre', 15000, nom: 'Transport'),
      ], levelId: '6e');
      expect(r.length, 2);
      expect(r.firstWhere((e) => e.nom == 'Cantine').id, 'ec_cant');
      expect(r.firstWhere((e) => e.nom == 'Transport').id, 'res_bus');
    });

    test('l\'intitulé ne départage QUE les frais annexes', () {
      // Deux inscriptions aux noms différents restent deux versions du même
      // tarif : les cumuler ferait payer l'inscription deux fois.
      final r = baremesApplicables([
        l('a', 'inscription', 15000, nom: 'Inscription 2025-2026'),
        l('b', 'inscription', 20000, nom: 'Droit d\'inscription'),
      ], levelId: '6e');
      expect(r.length, 1);
    });
  });
}
