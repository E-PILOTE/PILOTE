import 'package:epilote/features/finance/services/obligation.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CE QUE L'ÉLÈVE DOIT (spec §6.5, §5.7)
//
//  « Élèves à jour » comptait tout élève ayant versé AU MOINS UN FRANC. Un
//  élève qui verse 1 000 sur 90 000 était compté à jour, parce qu'aucun
//  montant dû n'existait nulle part.
//
//  Le dû se déduit des barèmes applicables. Trois cas seulement pour les
//  8 130 élèves du public — inscription, cotisation APE, frais d'examen — qui
//  se règlent en une fois. La mensualité, qui n'existe que dans le privé
//  (974 élèves), s'échelonne sur les mois écoulés : aucune table d'échéances.
// ════════════════════════════════════════════════════════════════════════════

void main() {
  group('dû d\'un barème', () {
    test('un frais unique est dû en entier dès le premier jour', () {
      for (final t in [
        'inscription',
        'cotisation_ape',
        'frais_examens',
        'autre'
      ]) {
        expect(duPourBareme(feeType: t, montant: 5000, moisEcoules: 1), 5000,
            reason: '$t se règle en une fois');
      }
    });

    test('une mensualité s\'accumule mois après mois', () {
      expect(duPourBareme(feeType: 'mensualite', montant: 25000, moisEcoules: 1),
          25000);
      expect(duPourBareme(feeType: 'mensualite', montant: 25000, moisEcoules: 4),
          100000);
    });

    test('une mensualité avant le début de l\'année ne doit rien', () {
      expect(duPourBareme(feeType: 'mensualite', montant: 25000, moisEcoules: 0),
          0);
    });
  });

  group('mois écoulés', () {
    final debut = DateTime(2025, 10, 1);
    final fin = DateTime(2026, 7, 31);

    test('le premier mois compte dès la rentrée', () {
      expect(
          moisEcoules(debut: debut, fin: fin, maintenant: DateTime(2025, 10, 2)),
          1);
    });

    test('quatre mois début janvier', () {
      expect(
          moisEcoules(debut: debut, fin: fin, maintenant: DateTime(2026, 1, 5)),
          4);
    });

    test('avant la rentrée, rien n\'est dû', () {
      expect(
          moisEcoules(debut: debut, fin: fin, maintenant: DateTime(2025, 8, 30)),
          0);
    });

    test('après la fin, le compteur se fige sur l\'année entière', () {
      // Sans plafond, un dossier consulté en 2030 réclamerait 60 mensualités.
      expect(
          moisEcoules(debut: debut, fin: fin, maintenant: DateTime(2030, 1, 1)),
          10);
    });
  });

  group('état d\'un élève', () {
    test('sans barème, on ne peut RIEN dire — surtout pas « à jour »', () {
      // 30 écoles publiques n'ont aucun barème : les déclarer à jour serait
      // aussi faux que de les déclarer débitrices.
      expect(etatObligation(du: 0, verse: 0), EtatObligation.sansBareme);
      expect(etatObligation(du: 0, verse: 5000), EtatObligation.sansBareme);
    });

    test('rien versé sur un dû : impayé', () {
      expect(etatObligation(du: 5000, verse: 0), EtatObligation.impaye);
    });

    test('une avance n\'est PAS être à jour', () {
      // Le défaut historique : 2 000 sur 5 000 comptait comme réglé.
      expect(etatObligation(du: 5000, verse: 2000), EtatObligation.partiel);
    });

    test('le compte exact est à jour', () {
      expect(etatObligation(du: 5000, verse: 5000), EtatObligation.aJour);
    });

    test('un trop-versé reste à jour — le dépassement se traite ailleurs', () {
      expect(etatObligation(du: 5000, verse: 7000), EtatObligation.aJour);
    });
  });

  group('libellés', () {
    test('chaque état a un libellé lisible', () {
      for (final e in EtatObligation.values) {
        expect(libelleEtat(e), isNotEmpty);
      }
    });
  });
}
