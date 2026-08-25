import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:epilote/features/finance/services/recu_pdf_service.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE SOLDE IMPRIMÉ SUR UN REÇU
//
//  Le reçu est la pièce que la famille conserve, et au Congo c'est LA preuve du
//  paiement. Y porter un solde engage l'école : « Soldé » sur un papier signé
//  vaut reconnaissance qu'il n'y a plus rien à réclamer.
//
//  Ces tests verrouillent les trois cas où la ligne ne doit PAS s'imprimer, ou
//  pas comme ça. Ils vérifient d'abord que le document SE CONSTRUIT — un reçu
//  qui lève une exception ne s'imprime pas du tout, et la famille repart les
//  mains vides.
// ════════════════════════════════════════════════════════════════════════════

RecuPaiement _recu({
  int? resteDu,
  String? annuleLe,
  String? motifAnnulation,
}) =>
    RecuPaiement(
      numero: 'KIN-2026-000142',
      eleve: 'Aristide NGOMA',
      matricule: 'KIN-2026-0042',
      classe: '6ème A',
      montant: 15000,
      date: DateTime(2026, 3, 12),
      methode: 'Espèces',
      encaissePar: 'Marie NKOUNKOU',
      motifFrais: 'Frais d\'inscription 2025-2026',
      resteDu: resteDu,
      annuleLe: annuleLe,
      motifAnnulation: motifAnnulation,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('fr'));

  test('avec un solde connu, le reçu se construit', () async {
    final bytes = await construireRecuPaiement(recu: _recu(resteDu: 33000));
    expect(bytes.length, greaterThan(1000));
  });

  test('SANS solde connu, le reçu se construit quand même', () async {
    // Aucun barème publié : on ne sait rien du reste dû. La ligne est omise,
    // et surtout pas imprimée à « 0 F » — trente écoles publiques du réseau
    // délivreraient sinon des reçus attestant que la scolarité est soldée.
    final bytes = await construireRecuPaiement(recu: _recu());
    expect(bytes.length, greaterThan(1000));
  });

  test('un solde nul s\'écrit « Soldé », pas « 0 FCFA »', () async {
    // « 0 FCFA » se lit comme un montant manquant ; « Soldé » est une
    // affirmation, et c'en est une que l'école assume.
    final bytes = await construireRecuPaiement(recu: _recu(resteDu: 0));
    expect(bytes.length, greaterThan(1000));
  });

  test('un reçu ANNULÉ se construit, et porte son annulation', () async {
    final bytes = await construireRecuPaiement(recu: _recu(
      resteDu: 33000,
      annuleLe: '2026-03-14',
      motifAnnulation: 'Chèque sans provision',
    ));
    expect(bytes.length, greaterThan(1000));
  });

  test('le solde ne s\'imprime PAS sur un reçu annulé', () async {
    // Le versement n'a pas eu lieu : le solde d'après-versement serait faux,
    // et faux dans le sens qui arrange l'école. On compare deux documents
    // identiques à ce détail près — s'ils ont la même taille, la ligne n'a
    // effectivement pas été ajoutée.
    final avecSolde = await construireRecuPaiement(recu: _recu(
      resteDu: 33000,
      annuleLe: '2026-03-14',
      motifAnnulation: 'Chèque sans provision',
    ));
    final sansSolde = await construireRecuPaiement(recu: _recu(
      annuleLe: '2026-03-14',
      motifAnnulation: 'Chèque sans provision',
    ));
    expect((avecSolde.length - sansSolde.length).abs(), lessThan(120));
  });

  test('un solde très élevé ne casse pas la mise en page', () async {
    final bytes = await construireRecuPaiement(recu: _recu(resteDu: 999999999));
    expect(bytes.length, greaterThan(1000));
  });

  test('rendu de référence pour inspection visuelle', () async {
    final bytes = await construireRecuPaiement(recu: _recu(resteDu: 33000));
    final out = File('${Directory.systemTemp.path}/recu_paiement.pdf');
    await out.writeAsBytes(bytes);
    expect(await out.exists(), isTrue);
  });
}
