import 'package:epilote/features/finance/services/poste_tag.dart';
import 'package:epilote/features/finance/services/receipt_number.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE NUMÉRO DE REÇU (spec §6.1)
//
//  L'ancien numéro valait `REC-` + les 6 derniers chiffres de l'horloge en
//  millisecondes : il recommençait toutes les 16 min 40 s, sous une contrainte
//  d'unicité NATIONALE. La collision produisait un 23505, que le connecteur
//  PowerSync traite comme définitif — la transaction était abandonnée et le
//  paiement perdu, alors que le parent était reparti avec son papier.
//
//  L'unicité doit tenir SANS RÉSEAU. Elle repose donc sur deux choses que le
//  poste possède seul : son étiquette d'appareil, et une séquence qu'il relit
//  dans sa propre base. Le code de l'école n'est là que pour la lisibilité.
// ════════════════════════════════════════════════════════════════════════════

void main() {
  group('format du numéro', () {
    test('assemble école, année, poste et séquence', () {
      expect(
        formatReceiptNumber(
            schoolCode: 'METPLTAOWANDO',
            year: 2026,
            posteTag: 'a3f19c',
            sequence: 147),
        'REC-PLTAOWANDO-26-A3F19C-000147',
      );
    });

    test('ne dépasse jamais les 50 caractères de la colonne', () {
      final n = formatReceiptNumber(
        schoolCode: 'X' * 50,
        year: 2026,
        posteTag: 'ffffff',
        sequence: 999999,
      );
      expect(n.length, lessThanOrEqualTo(kReceiptMaxLength));
    });

    test('une école sans code reste numérotable', () {
      expect(
        formatReceiptNumber(
            schoolCode: null, year: 2026, posteTag: 'a3f19c', sequence: 1),
        'REC-ECOLE-26-A3F19C-000001',
      );
    });

    test('deux postes de la même école ne collisionnent pas', () {
      final a = formatReceiptNumber(
          schoolCode: 'KIN01', year: 2026, posteTag: 'aaaaaa', sequence: 12);
      final b = formatReceiptNumber(
          schoolCode: 'KIN01', year: 2026, posteTag: 'bbbbbb', sequence: 12);
      expect(a, isNot(b));
    });

    test('deux encaissements de la même milliseconde ne collisionnent pas', () {
      // Le défaut historique : le numéro ne dépendait QUE de l'horloge.
      final a = formatReceiptNumber(
          schoolCode: 'KIN01', year: 2026, posteTag: 'aaaaaa', sequence: 1);
      final b = formatReceiptNumber(
          schoolCode: 'KIN01', year: 2026, posteTag: 'aaaaaa', sequence: 2);
      expect(a, isNot(b));
    });
  });

  group('séquence suivante', () {
    const prefixe = 'REC-KIN01-26-A3F19C-';

    test('part à 1 sur un poste neuf', () {
      expect(prochaineSequence(const [], prefixe: prefixe), 1);
    });

    test('reprend après le plus grand numéro DÉJÀ en base', () {
      // Après une purge, les paiements redescendent par la synchro : relire la
      // base est ce qui empêche la séquence de repartir à 1 et de percuter des
      // reçus déjà émis par ce même poste.
      expect(
        prochaineSequence(
          const [
            'REC-KIN01-26-A3F19C-000003',
            'REC-KIN01-26-A3F19C-000011',
            'REC-KIN01-26-A3F19C-000007',
          ],
          prefixe: prefixe,
        ),
        12,
      );
    });

    test('ignore les reçus des AUTRES postes', () {
      expect(
        prochaineSequence(
          const [
            'REC-KIN01-26-BBBBBB-000900',
            'REC-KIN01-26-A3F19C-000004',
          ],
          prefixe: prefixe,
        ),
        5,
      );
    });

    test('ignore les valeurs nulles et les anciens formats', () {
      expect(
        prochaineSequence(
          const [null, 'REC-482913', '', 'REC-KIN01-26-A3F19C-000002'],
          prefixe: prefixe,
        ),
        3,
      );
    });
  });

  group('extraction de séquence', () {
    test('lit la séquence d\'un reçu du bon préfixe', () {
      expect(
        sequenceDansRecu('REC-KIN01-26-A3F19C-000042',
            prefixe: 'REC-KIN01-26-A3F19C-'),
        42,
      );
    });

    test('refuse un reçu d\'un autre préfixe', () {
      expect(
        sequenceDansRecu('REC-KIN01-26-BBBBBB-000042',
            prefixe: 'REC-KIN01-26-A3F19C-'),
        isNull,
      );
    });

    test('refuse l\'ancien format horodaté', () {
      expect(sequenceDansRecu('REC-482913', prefixe: 'REC-KIN01-26-A3F19C-'),
          isNull);
    });
  });

  group('étiquette du poste', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      resetPosteTagCache();
    });

    test('fait 6 caractères hexadécimaux', () async {
      final t = await posteTag();
      expect(t, matches(RegExp(r'^[0-9a-f]{6}$')));
    });

    test('ne change pas d\'un appel à l\'autre', () async {
      // Si l'étiquette bougeait, la séquence repartirait à 1 sur un préfixe
      // neuf à chaque redémarrage — sans collision, mais avec une numérotation
      // illisible pour un contrôleur.
      expect(await posteTag(), await posteTag());
    });

    test('survit à un redémarrage de l\'application', () async {
      final premier = await posteTag();
      resetPosteTagCache();
      expect(await posteTag(), premier);
    });
  });
}
