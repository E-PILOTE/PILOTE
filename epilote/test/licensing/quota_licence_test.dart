import 'package:epilote/core/utils/erreur_metier.dart';
import 'package:epilote/features/students/providers/students_provider.dart';
import 'package:epilote/licensing/domain/entitlement.dart';
import 'package:epilote/licensing/domain/license.dart';
import 'package:flutter_test/flutter_test.dart';

/// Quota d'élèves porté par la licence signée (migration 0207).
///
/// Le serveur ne refuse plus un élève en trop : sur le chemin hors ligne, son
/// refus (23514) était fatal et JETAIT l'élève avec tout son lot. La barrière
/// est désormais dans l'app, avant l'écriture — ces tests la tiennent.

Entitlement _avec(Map<String, int> quotas) => Entitlement(
      license: License(
        groupId: 'g', plan: 'p', modules: const {'eleves'}, quotas: quotas,
        validFrom: null, validTo: null,
        offlineWindow: const Duration(days: 30), version: 1, issuedAt: null),
      lastSyncAt: DateTime.now().toUtc(),
    );

void main() {
  group('Entitlement.quota', () {
    test('sans licence : aucun quota', () {
      expect(const Entitlement.none().quota('students'), isNull);
    });

    test('licence émise avant 0207 (quotas vides) : aucun quota', () {
      expect(_avec(const {}).quota('students'), isNull);
    });

    test('-1 veut dire illimité, pas « zéro élève »', () {
      expect(_avec(const {'students': -1}).quota('students'), isNull);
    });

    test('une vraie limite passe telle quelle', () {
      expect(_avec(const {'students': 100}).quota('students'), 100);
    });

    test('la licence décode les quotas émis par license-issuer', () {
      final lic = License.fromClaims({
        'group_id': 'g',
        'quotas': {'students': 100, 'staff': '10'},
      })!;
      expect(lic.quotas, {'students': 100, 'staff': 10});
    });
  });

  group('exigerPlaceDansLeQuota', () {
    test('sans plafond, rien ne bloque', () {
      exigerPlaceDansLeQuota(max: null, inscrits: 5000);
    });

    test('sous le plafond, l\'inscription passe', () {
      exigerPlaceDansLeQuota(max: 100, inscrits: 99);
    });

    test('au plafond, refus lisible AVANT toute écriture', () {
      expect(
        () => exigerPlaceDansLeQuota(max: 100, inscrits: 100),
        throwsA(isA<ErreurMetier>().having(
            (e) => e.message, 'message', contains('100 élèves'))),
      );
    });

    test('déjà au-delà (élèves saisis avant la garde) : toujours refusé', () {
      expect(() => exigerPlaceDansLeQuota(max: 100, inscrits: 237),
          throwsA(isA<ErreurMetier>()));
    });
  });
}
