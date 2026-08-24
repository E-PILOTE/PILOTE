import 'package:flutter_test/flutter_test.dart';

import 'package:epilote/features/finance/providers/decompte_du_provider.dart';
import 'package:epilote/features/finance/providers/obligation_provider.dart';
import 'package:epilote/features/finance/services/bareme_applicable.dart';
import 'package:epilote/features/finance/services/obligation.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE DÉCOMPTE NE DOIT JAMAIS S'ÉCARTER DU DÛ
//
//  `duScolarite` calcule le total ; `DecompteDu` le décompose pour l'expliquer
//  à une famille. Ce sont deux chemins vers le même nombre — donc deux
//  occasions de diverger. Le jour où ils divergent, la caisse annonce un
//  montant et le tableau de bord en compte un autre : c'est le défaut qui a
//  produit le bug des mentions, transposé à l'argent.
//
//  Ces tests verrouillent l'égalité sur les cas où les trois mécanismes
//  récents (présence, frais annexes, exonération) se combinent.
// ════════════════════════════════════════════════════════════════════════════

LigneBareme _b(String id, String type, int montant, {String nom = ''}) => (
      id: id,
      feeType: type,
      nom: nom,
      montant: montant,
      schoolId: null,
      levelId: null,
    );

/// Passe par la composition DE PRODUCTION (`composerDecompte`), et non par une
/// reconstruction locale.
///
/// ⚠️ Ce fichier en contenait une copie : il vérifiait donc sa propre idée du
/// décompte, pendant que l'ordre des lignes, le libellé de repli et le calcul
/// du reliquat vivaient dans le provider sans être vus par personne. Un test
/// qui réimplémente ce qu'il contrôle ne contrôle rien.
///
/// [verses] associe un id de barème au net encaissé dessus. Un id ABSENT du
/// catalogue y est légitime : c'est ainsi que naît un reliquat.
DecompteDu _decompte(
  List<LigneBareme> baremes, {
  required int mois,
  int? exoneration,
  Map<String, int> verses = const {},
  bool boursier = false,
}) =>
    composerDecompte(
      baremes: baremes,
      levelId: null,
      verseParBareme: verses,
      mois: mois,
      exoneration: exoneration,
      boursierDeclare: boursier,
    );

void main() {
  final catalogue = [
    _b('i', 'inscription', 15000, nom: 'Inscription 2025-2026'),
    _b('m', 'mensualite', 12000, nom: 'Scolarité'),
    _b('a', 'cotisation_ape', 2000, nom: 'Cotisation APE'),
    _b('c', 'autre', 10000, nom: 'Cantine'),
    _b('t', 'autre', 8000, nom: 'Transport'),
    _b('bac', 'frais_examens', 30000, nom: 'Baccalauréat'),
  ];

  group('le net du décompte égale le dû calculé', () {
    for (final mois in [1, 4, 10]) {
      for (final exo in <int?>[null, 25, 50, 100]) {
        test('$mois mois, exonération ${exo ?? "aucune"}', () {
          final d = _decompte(catalogue, mois: mois, exoneration: exo);
          final du =
              duScolarite(catalogue, levelId: null, mois: mois, exoneration: exo);
          expect(d.net, du);
        });
      }
    }
  });

  group('ce que la famille lit', () {
    test('les frais d\'examen ne figurent PAS au décompte de scolarité', () {
      final d = _decompte(catalogue, mois: 1);
      expect(d.lignes.where((l) => l.feeType == 'frais_examens'), isEmpty);
      expect(d.lignes.length, 5);
    });

    test('la mensualité est déjà multipliée par les mois dus', () {
      final d = _decompte(catalogue, mois: 4);
      final m = d.lignes.firstWhere((l) => l.feeType == 'mensualite');
      expect(m.montant, 48000);
    });

    test('la remise ne porte QUE sur la scolarité', () {
      // 50 % sur inscription (15 000) + mensualité (12 000) + APE (2 000).
      // La cantine et le transport n'y entrent pas.
      final d = _decompte(catalogue, mois: 1, exoneration: 50);
      expect(d.remise, 7500 + 6000 + 1000);
      expect(d.brut - d.remise, d.net);
    });

    test('une exonération totale laisse les services dus', () {
      final d = _decompte(catalogue, mois: 1, exoneration: 100);
      expect(d.net, 18000, reason: 'cantine 10 000 + transport 8 000');
      expect(d.estExonere, isTrue);
    });

    test('le reste se déduit du versé, sans jamais passer sous zéro', () {
      final d = _decompte(catalogue, mois: 1, verses: {'': 999999});
      expect(d.reste, 0);
    });

    test('un décompte vide ne prétend rien', () {
      // Aucun barème publié : `brut` est nul, et `vide` le DIT. Afficher
      // « 0 F dû » se lirait « scolarité gratuite ».
      const d = DecompteDu();
      expect(d.vide, isTrue);
      expect(d.brut, 0);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  //  LE RESTE, LIGNE PAR LIGNE
  //
  //  Le guichet pré-remplit le montant à encaisser depuis ces valeurs. Une
  //  erreur ici, c'est une somme fausse réclamée à une famille au comptoir.
  // ══════════════════════════════════════════════════════════════════════════
  group('le reste par ligne', () {
    test('un acompte ne solde que SA ligne', () {
      final d = _decompte(catalogue, mois: 1, verses: {'i': 5000});
      final insc = d.lignes.firstWhere((l) => l.id == 'i');
      final ape = d.lignes.firstWhere((l) => l.id == 'a');

      expect(d.resteDe(insc), 10000, reason: '15 000 − 5 000');
      expect(d.resteDe(ape), 2000, reason: 'l\'APE n\'a rien reçu');
    });

    test('un trop-versé sur une ligne ne vient PAS éponger les autres', () {
      // Une compensation silencieuse entre deux frais rendrait la caisse
      // impossible à justifier : l'excédent se rembourse, il ne se déplace pas.
      final d = _decompte(catalogue, mois: 1, verses: {'c': 50000});
      final cantine = d.lignes.firstWhere((l) => l.id == 'c');
      final insc = d.lignes.firstWhere((l) => l.id == 'i');

      expect(d.resteDe(cantine), 0);
      expect(d.resteDe(insc), 15000, reason: 'toujours dû en entier');
    });

    test('l\'exonération réduit le reste de la ligne exonérable', () {
      final d = _decompte(catalogue, mois: 1, exoneration: 50, verses: {'i': 2000});
      final insc = d.lignes.firstWhere((l) => l.id == 'i');
      final cantine = d.lignes.firstWhere((l) => l.id == 'c');

      expect(d.duDe(insc), 7500, reason: '15 000 remis de moitié');
      expect(d.resteDe(insc), 5500, reason: '7 500 − 2 000');
      expect(d.duDe(cantine), 10000, reason: 'la cantine n\'est pas exonérée');
    });

    test('les lignes soldées sortent de ce que le guichet propose', () {
      final d = _decompte(catalogue, mois: 1, verses: {'i': 15000, 'a': 2000});
      expect(d.lignesOuvertes.map((l) => l.id), ['m', 'c', 't']);
    });

    test('tout soldé : plus aucune ligne ouverte', () {
      final d = _decompte(catalogue, mois: 1, verses: {
        'i': 15000, 'a': 2000, 'm': 12000, 'c': 10000, 't': 8000,
      });
      expect(d.lignesOuvertes, isEmpty);
      expect(d.reste, 0);
      expect(d.etat, EtatObligation.aJour);
    });

    test('le versé total = somme des lignes + le libre', () {
      final d = _decompte(catalogue, mois: 1,
          verses: {'i': 5000, 'c': 3000, '': 1500});
      expect(d.verse, 9500);
    });

    test('un versement dont le barème a disparu reste dans la caisse', () {
      // ⚠️ Le cas qui perdrait de l'argent : un tarif retiré, un changement de
      // niveau, et le versement n'a plus de ligne où s'accrocher. Compté en
      // « libre », il continue de solder l'élève ; ignoré, il le rendrait
      // débiteur d'une somme qu'il a réellement payée.
      final d = _decompte(catalogue, mois: 1, verses: {'tarif-retire': 27000});
      expect(d.verseLibre, 27000, reason: 'le reliquat le recueille');
      expect(d.verse, 27000);
      expect(d.reste, d.net - 27000);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  //  CE QUE `composerDecompte` DÉCIDE, ET QUE PERSONNE NE VÉRIFIAIT
  //
  //  Ces trois règles vivaient derrière un `db.getAll`, donc hors de portée des
  //  tests : le décompte y était reconstruit à la main plus haut dans CE
  //  fichier, avec un ordre et des libellés qui n'étaient pas ceux du produit.
  // ══════════════════════════════════════════════════════════════════════════
  group('le reliquat se DÉDUIT, il ne se déclare pas', () {
    test('rien d\'orphelin, rien de libre', () {
      final d = _decompte(catalogue, mois: 1, verses: {'i': 15000, 'c': 4000});
      expect(d.verseLibre, 0);
      expect(d.verse, 19000);
    });

    test('l\'affecté et le libre cohabitent sans se recouvrir', () {
      final d = _decompte(catalogue,
          mois: 1, verses: {'i': 15000, 'inconnu': 3000, '': 500});
      expect(d.verseLibre, 3500, reason: '3 000 orphelins + 500 sans barème');
      expect(d.verse, 18500, reason: 'la caisse au franc près');
    });

    test('un versement sur un barème d\'un AUTRE niveau reste de l\'argent', () {
      // Le guichet a encaissé sur le tarif de 6e, l'élève est passé en 5e.
      // La ligne ne s'affiche plus ; la somme, elle, a bien été versée.
      final autreNiveau = (
        id: '6e',
        feeType: 'mensualite',
        nom: 'Scolarité 6e',
        montant: 9000,
        schoolId: null,
        levelId: 'niveau-6e',
      );
      final d = composerDecompte(
        baremes: [...catalogue, autreNiveau],
        levelId: null,
        verseParBareme: const {'6e': 9000},
        mois: 1,
      );
      expect(d.lignes.any((l) => l.id == '6e'), isFalse);
      expect(d.verseLibre, 9000);
    });

    test('l\'argent des EXAMENS ne devient jamais un reliquat', () {
      // ⚠️ Ce n'est pas l'argent de l'école : il ne solde aucune scolarité. La
      // requête l'écarte déjà — la règle doit tenir même si ce `WHERE` bouge,
      // sinon un candidat au bac ressortirait comme ayant payé sa mensualité.
      final d = _decompte(catalogue, mois: 1, verses: {'bac': 30000});
      expect(d.verseLibre, 0);
      expect(d.verse, 0);
    });
  });

  group('l\'ordre et les intitulés du papier', () {
    test('une facture se lit : une fois, l\'APE, ce qui court, les services',
        () {
      final d = _decompte(catalogue, mois: 1);
      expect(d.lignes.map((l) => l.feeType).toList(),
          ['inscription', 'cotisation_ape', 'mensualite', 'autre', 'autre']);
    });

    test('l\'ordre de saisie des barèmes ne change pas celui de la facture', () {
      final d = _decompte(catalogue.reversed.toList(), mois: 1);
      expect(d.lignes.first.feeType, 'inscription');
      expect(d.lignes.last.feeType, 'autre');
    });

    test('les frais annexes gardent leur ordre relatif', () {
      final d = _decompte(catalogue, mois: 1);
      final annexes =
          d.lignes.where((l) => l.feeType == 'autre').map((l) => l.libelle);
      expect(annexes, ['Cantine', 'Transport']);
    });

    test('un barème sans intitulé ne laisse pas une ligne vide sur le papier',
        () {
      // La base l'interdit depuis la migration 0108, les lignes créées avant
      // restent possibles. « ______ : 15 000 F » sur une facture familiale est
      // indéfendable.
      final d = _decompte([_b('i', 'inscription', 15000)], mois: 1);
      expect(d.lignes.single.libelle, 'Frais d\'inscription');
    });

    test('un intitulé n\'est pas rendu avec ses espaces de saisie', () {
      final d = _decompte([_b('c', 'autre', 10000, nom: '  Cantine  ')],
          mois: 1);
      expect(d.lignes.single.libelle, 'Cantine');
    });
  });

  group('ce que le décompte rapporte du dossier', () {
    test('boursier déclaré sans taux : l\'écart remonte', () {
      final d = _decompte(catalogue, mois: 1, boursier: true);
      expect(d.boursierSansTaux, isTrue);
      expect(d.estExonere, isFalse, reason: 'on ne devine JAMAIS un taux');
    });

    test('boursier avec taux : plus d\'écart à signaler', () {
      final d = _decompte(catalogue, mois: 1, exoneration: 60, boursier: true);
      expect(d.boursierSansTaux, isFalse);
      expect(d.estExonere, isTrue);
    });

    test('sans aucun barème, le décompte reste vide et ne dit rien', () {
      final d = _decompte(const [], mois: 3, verses: {'': 5000});
      expect(d.vide, isTrue);
      expect(d.verseLibre, 5000, reason: 'l\'argent encaissé ne s\'efface pas');
    });
  });
}
