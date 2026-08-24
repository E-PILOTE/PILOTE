import 'package:flutter_test/flutter_test.dart';

import 'package:epilote/features/finance/providers/obligation_provider.dart';
import 'package:epilote/features/finance/providers/paiements_provider.dart';
import 'package:epilote/features/finance/services/bareme_applicable.dart';
import 'package:epilote/features/finance/services/obligation.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE TAUX DE RECOUVREMENT — LE CHIFFRE QUE L'ÉCOLE MONTRE
//
//  « 148 élèves à jour sur 190 » s'affiche sur la page Paiements, se remonte au
//  groupe, et finit dans les rapports du réseau. Il se fabriquait entièrement
//  dans une boucle sur un `db.getAll`, donc sans qu'aucun test ne puisse dire
//  s'il était juste — au moment précis où trois mécanismes neufs (présence,
//  frais annexes, exonération) venaient d'en changer le calcul.
//
//  `recouvrementEleve` porte cette décision pour UN élève. Ce que ces tests
//  verrouillent, ce sont les deux règles qui ne se devinent pas : le double
//  calcul du dû (avant et après remise), et le fait qu'un exonéré compte parmi
//  les élèves en règle.
// ════════════════════════════════════════════════════════════════════════════

LigneBareme _b(String id, String type, int montant, {String? levelId}) => (
      id: id,
      feeType: type,
      nom: id,
      montant: montant,
      schoolId: null,
      levelId: levelId,
    );

/// Inscription 15 000 · scolarité 12 000/mois · cantine 10 000.
final _tarifs = [
  _b('i', 'inscription', 15000),
  _b('m', 'mensualite', 12000),
  _b('c', 'autre', 10000),
];

RecouvrementEleve _eleve({
  List<LigneBareme>? tarifs,
  int mois = 1,
  int verse = 0,
  int? exoneration,
}) =>
    recouvrementEleve(
      tarifs ?? _tarifs,
      levelId: null,
      mois: mois,
      verse: verse,
      exoneration: exoneration,
    );

void main() {
  group('sans exonération, rien ne change pour personne', () {
    test('qui n\'a rien versé est impayé', () {
      final r = _eleve();
      expect(r.du, 37000);
      expect(r.etat, EtatObligation.impaye);
      expect(r.aJour, isFalse);
    });

    test('qui a versé une partie est partiel', () {
      final r = _eleve(verse: 20000);
      expect(r.etat, EtatObligation.partiel);
      expect(r.aJour, isFalse);
    });

    test('qui a tout versé est à jour', () {
      expect(_eleve(verse: 37000).aJour, isTrue);
    });

    test('qui a trop versé reste à jour', () {
      // Un trop-perçu se rembourse ; il ne rétrograde pas l'élève.
      expect(_eleve(verse: 99000).aJour, isTrue);
    });
  });

  group('le dû suit la présence', () {
    test('quatre mois coûtent quatre mensualités', () {
      expect(_eleve(mois: 4).du, 15000 + 48000 + 10000);
    });

    test('l\'élève arrivé en cours d\'année peut être à jour pour moins', () {
      // ⚠️ Deux élèves de la même classe, deux dûs, deux fois « à jour ».
      expect(_eleve(mois: 1, verse: 37000).aJour, isTrue);
      expect(_eleve(mois: 4, verse: 37000).aJour, isFalse);
    });
  });

  group('l\'exonération, et le piège des deux zéros', () {
    test('une remise de moitié ne porte pas sur la cantine', () {
      // 7 500 (inscription) + 6 000 (scolarité) + 10 000 (cantine).
      expect(_eleve(exoneration: 50).du, 23500);
    });

    test('un exonéré total ne doit QUE les services', () {
      expect(_eleve(exoneration: 100).du, 10000, reason: 'la cantine reste due');
      expect(_eleve(exoneration: 100, verse: 10000).aJour, isTrue);
    });

    test('exonéré de tout ce qui existe : à jour sans avoir rien versé', () {
      // Le cas qui a motivé `EtatObligation.exonere` : le dû tombe à zéro par
      // la remise, et NON par l'absence de tarif.
      final r = _eleve(tarifs: [_b('i', 'inscription', 15000)], exoneration: 100);
      expect(r.du, 0);
      expect(r.etat, EtatObligation.exonere);
      expect(r.aJour, isTrue,
          reason: 'sinon accorder des bourses fait chuter le taux de l\'école');
    });

    test('AUCUN barème posé ne se confond pas avec une exonération', () {
      // ⚠️ Les deux rendent un dû nul et veulent dire le contraire. Ici l'école
      // n'a pas publié ses tarifs — une trentaine d'écoles publiques sont dans
      // ce cas ; annoncer « à jour » leur inventerait un recouvrement parfait.
      final r = _eleve(tarifs: const []);
      expect(r.du, 0);
      expect(r.etat, EtatObligation.sansBareme);
      expect(r.aJour, isFalse);
    });

    test('exonéré de 100 % sur des frais qui ne s\'exonèrent pas', () {
      // Seule la cantine est tarifée : la remise ne la touche pas, le dû reste
      // entier, et l'élève n'est donc pas « exonéré ».
      final r = _eleve(tarifs: [_b('c', 'autre', 10000)], exoneration: 100);
      expect(r.du, 10000);
      expect(r.etat, EtatObligation.impaye);
    });
  });

  group('les frais d\'examen ne pèsent sur personne', () {
    test('un barème d\'examen de portée réseau n\'entre pas dans le dû', () {
      // Le dégât mesuré le 13/08/2026 sur le METP : 1 775 élèves × 30 000 F de
      // dette fictive, dont des élèves de 6e pour un baccalauréat.
      final avecBac = [..._tarifs, _b('bac', 'frais_examens', 30000)];
      expect(_eleve(tarifs: avecBac).du, 37000);
      expect(_eleve(tarifs: avecBac, verse: 37000).aJour, isTrue);
    });

    test('un élève ne devant QUE des frais d\'examen n\'a pas de barème', () {
      final r = _eleve(tarifs: [_b('bac', 'frais_examens', 30000)]);
      expect(r.etat, EtatObligation.sansBareme,
          reason: 'Finance ne connaît pas les candidats, le module Examens si');
    });
  });

  group('un même frais posé à plusieurs portées ne se paie qu\'une fois', () {
    test('le barème de l\'école l\'emporte sur celui du réseau', () {
      final r = _eleve(tarifs: [
        _b('reseau', 'inscription', 15000),
        (
          id: 'ecole',
          feeType: 'inscription',
          nom: 'ecole',
          montant: 20000,
          schoolId: 'e1',
          levelId: null,
        ),
      ]);
      expect(r.du, 20000, reason: 'la ligne la plus proche de l\'élève');
    });

    test('deux frais annexes distincts se cumulent, eux', () {
      final r = _eleve(tarifs: [
        _b('cantine', 'autre', 10000),
        _b('transport', 'autre', 8000),
      ]);
      expect(r.du, 18000);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  //  LE TOTAL ET LE DÉTAIL DOIVENT DIRE LA MÊME CHOSE
  //
  //  `paymentsOverviewProvider` compte les élèves à jour d'une école ;
  //  `classPaymentsProvider` affiche la ligne de chacun. Les deux passent
  //  maintenant par `recouvrementEleve` — mais `StudentPayRow` redérive son
  //  état depuis ses propres champs, et c'est là que la divergence se
  //  réinstallerait : un élève « à jour » dans le total, « impayé » sur sa
  //  ligne. C'est le défaut qui avait produit le bug des mentions.
  // ══════════════════════════════════════════════════════════════════════════
  group('la ligne de l\'élève s\'accorde avec le total de l\'école', () {
    StudentPayRow ligne(RecouvrementEleve r, int verse) => StudentPayRow(
          studentId: 's',
          enrollmentId: 'e',
          studentName: 'NGOMA Aristide',
          matricule: null,
          paid: verse,
          count: 1,
          lastDate: null,
          du: r.du,
          duAvantExoneration: r.duBrut,
        );

    for (final cas in <({String nom, List<LigneBareme> tarifs, int verse, int? exo})>[
      (nom: 'impayé', tarifs: [], verse: 0, exo: null),
      (nom: 'partiel', tarifs: [], verse: 20000, exo: null),
      (nom: 'à jour', tarifs: [], verse: 37000, exo: null),
      (nom: 'remise partielle', tarifs: [], verse: 0, exo: 50),
      (nom: 'exonéré total', tarifs: [_b('i', 'inscription', 15000)], verse: 0, exo: 100),
      (nom: 'sans barème', tarifs: [_b('bac', 'frais_examens', 30000)], verse: 0, exo: null),
    ]) {
      test('${cas.nom} : même état des deux côtés', () {
        final tarifs = cas.tarifs.isEmpty ? _tarifs : cas.tarifs;
        final r = _eleve(tarifs: tarifs, verse: cas.verse, exoneration: cas.exo);
        final l = ligne(r, cas.verse);
        expect(l.etat, r.etat);
        expect(l.du, r.du);
        expect(l.reste, (r.du - cas.verse).clamp(0, r.du));
      });
    }

    test('le brut sert à dire qu\'un tarif EXISTE, pas ce qu\'il coûte', () {
      final exonere = _eleve(exoneration: 100);
      expect(exonere.du, 10000, reason: 'la cantine ne s\'exonère pas');
      expect(exonere.duBrut, 37000);
      expect(ligne(exonere, 0).baremeDefini, isTrue);

      final sansTarif = _eleve(tarifs: const []);
      expect(sansTarif.duBrut, 0);
      expect(ligne(sansTarif, 0).baremeDefini, isFalse);
    });
  });
}
