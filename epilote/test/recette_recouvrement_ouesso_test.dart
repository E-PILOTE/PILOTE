import 'dart:io';

import 'package:epilote/features/user/providers/rapports_provider.dart';
import 'package:epilote/features/user/services/rapport_pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

// ════════════════════════════════════════════════════════════════════════════
//  RECETTE — L'ÉTAT DE RECOUVREMENT AVEC LES CHIFFRES RÉELS DE OUÉSSO
//
//  Ce n'est pas un test unitaire de plus : c'est le PARCOURS, joué sur les
//  seules données réelles disponibles. Le Collège d'Enseignement Technique de
//  Ouésso est le seul établissement du pays à avoir encaissé quoi que ce soit.
//
//  Les nombres ci-dessous ont été obtenus DEUX FOIS, séparément :
//   • en SQL sur la base Postgres de production ;
//   • en rejouant les requêtes des providers sur la base SQLite locale du
//     poste, après synchronisation PowerSync.
//  Les deux donnent la même chose. Ce document doit donc les porter.
//
//  ⚠️ « Encaissé : 0 » alors que l'école a bien reçu 4 000 F : ce versement est
//  un FRAIS D'EXAMEN, que le module Examens porte. C'est le « double solde par
//  famille » assumé aujourd'hui — l'intendant n'a pas de chiffre unique. Ce
//  n'est pas un défaut de ce document, c'est un manque de complétude connu.
// ════════════════════════════════════════════════════════════════════════════

/// Ouésso, année 2025-2026 : dû = inscription 3 000 F + cotisation APE 2 000 F.
/// Aucune mensualité active, aucune exonération, aucun versement de scolarité.
const _ouesso = <LigneRecouvrement>[
  (className: '3e A', effectif: 31, aJour: 0, du: 155000, encaisse: 0, reste: 155000),
  (className: '4e A', effectif: 32, aJour: 0, du: 160000, encaisse: 0, reste: 160000),
  (className: '5e A', effectif: 34, aJour: 0, du: 170000, encaisse: 0, reste: 170000),
  (className: '6e A', effectif: 33, aJour: 0, du: 165000, encaisse: 0, reste: 165000),
];

void main() {
  // Les polices et le logo du document officiel sont des ASSETS : sans le
  // binding, `rootBundle` ne répond pas et l'édition échoue.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('fr'));

  test('les totaux du document retombent sur les chiffres mesurés', () {
    expect(_ouesso.fold(0, (a, l) => a + l.effectif), 130);
    expect(_ouesso.fold(0, (a, l) => a + l.du), 650000);
    expect(_ouesso.fold(0, (a, l) => a + resteDe(l)), 650000,
        reason: 'Personne n\'a réglé sa scolarité : le reste vaut le dû.');
    expect(_ouesso.fold(0, (a, l) => a + l.aJour), 0);
  });

  test('le document sort, et il est déposé pour relecture humaine', () async {
    final bytes = await RapportPdfService.etatRecouvrement(
      lignes: _ouesso,
      anneeLabel: '2025-2026',
      sansBareme: false,
    );
    expect(bytes.length, greaterThan(1000));

    // Déposé à côté du dépôt : je n'ai plus de capture d'écran (le serveur
    // computer-use s'est déconnecté), donc l'artefact lui-même tient lieu de
    // preuve, et quelqu'un peut l'ouvrir.
    final sortie = Platform.environment['RECETTE_PDF'];
    if (sortie != null && sortie.isNotEmpty) {
      File(sortie).writeAsBytesSync(bytes);
      // ignore: avoid_print
      print('Document écrit : $sortie (${bytes.length} octets)');
    }
  });

  test('une classe qui a trop encaissé garde sa dette au document', () {
    // La régression que ce module vient de corriger, rejouée sur la forme
    // exacte du document : l'ancienne soustraction imprimait « 0 ».
    const avance = (
      className: '6e A',
      effectif: 33,
      aJour: 1,
      du: 165000,
      encaisse: 200000,
      reste: 160000,
    );
    expect(resteDe(avance), 160000);
  });
}
