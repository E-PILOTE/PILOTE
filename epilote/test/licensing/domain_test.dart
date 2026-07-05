import 'package:epilote/licensing/domain/entitlement.dart';
import 'package:epilote/licensing/domain/license.dart';
import 'package:epilote/licensing/domain/license_phase.dart';
import 'package:epilote/licensing/domain/license_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 7, 4, 12);

  group('computeLicensePhase (double horloge)', () {
    test('actif : échéance future, synchro récente', () {
      final p = computeLicensePhase(
        validTo: now.add(const Duration(days: 60)),
        offlineWindow: const Duration(days: 30),
        lastSyncAt: now.subtract(const Duration(days: 2)),
        now: now,
      );
      expect(p, LicensePhase.active);
    });

    test('grâce : échu depuis 10 j (< 15)', () {
      final p = computeLicensePhase(
        validTo: now.subtract(const Duration(days: 10)),
        offlineWindow: const Duration(days: 30),
        lastSyncAt: now.subtract(const Duration(days: 1)),
        now: now,
      );
      expect(p, LicensePhase.grace);
    });

    test('lecture seule : échu au-delà de la grâce', () {
      final p = computeLicensePhase(
        validTo: now.subtract(const Duration(days: 40)),
        offlineWindow: const Duration(days: 30),
        lastSyncAt: now.subtract(const Duration(days: 1)),
        now: now,
      );
      expect(p, LicensePhase.readOnly);
    });

    test('lecture seule : fenêtre de confiance dépassée (angle mort révocation)', () {
      final p = computeLicensePhase(
        validTo: now.add(const Duration(days: 60)), // métier OK
        offlineWindow: const Duration(days: 30),
        lastSyncAt: now.subtract(const Duration(days: 45)), // trop longtemps hors ligne
        now: now,
      );
      expect(p, LicensePhase.readOnly);
    });

    test('entrées inconnues → actif (fail-soft)', () {
      final p = computeLicensePhase(
        validTo: null,
        offlineWindow: Duration.zero,
        lastSyncAt: null,
        now: now,
      );
      expect(p, LicensePhase.active);
    });

    test('hard-lock LE JOUR MÊME : éligible, échu à peine (1 j)', () {
      final p = computeLicensePhase(
        validTo: now.subtract(const Duration(days: 1)),
        offlineWindow: const Duration(days: 30),
        lastSyncAt: now.subtract(const Duration(hours: 2)),
        now: now,
        hardLockEligible: true,
      );
      expect(p, LicensePhase.hardLock); // aucune grâce quand le flag est présent
    });

    test('hard-lock : éligible et échu de longue date', () {
      final p = computeLicensePhase(
        validTo: now.subtract(const Duration(days: 40)),
        offlineWindow: const Duration(days: 30),
        lastSyncAt: now.subtract(const Duration(days: 1)),
        now: now,
        hardLockEligible: true,
      );
      expect(p, LicensePhase.hardLock);
    });

    test('flag hard_lock absent (fail-soft) → échelle douce : grâce puis lecture seule', () {
      final grace = computeLicensePhase(
        validTo: now.subtract(const Duration(days: 10)), // < 15 j
        offlineWindow: const Duration(days: 30),
        lastSyncAt: now.subtract(const Duration(days: 1)),
        now: now,
        hardLockEligible: false,
      );
      expect(grace, LicensePhase.grace);

      final ro = computeLicensePhase(
        validTo: now.subtract(const Duration(days: 40)), // > 15 j
        offlineWindow: const Duration(days: 30),
        lastSyncAt: now.subtract(const Duration(days: 1)),
        now: now,
        hardLockEligible: false, // émetteur n'a pas stampé le claim
      );
      expect(ro, LicensePhase.readOnly);
    });

    test('encore actif : échéance FUTURE, éligible → aucun blocage', () {
      final p = computeLicensePhase(
        validTo: now.add(const Duration(days: 5)),
        offlineWindow: const Duration(days: 30),
        lastSyncAt: now.subtract(const Duration(hours: 1)),
        now: now,
        hardLockEligible: true,
      );
      expect(p, LicensePhase.active);
    });

    test('fenêtre de confiance dépassée n\'escalade PAS au hard-lock (réseau ≠ impayé)', () {
      final p = computeLicensePhase(
        validTo: now.add(const Duration(days: 60)), // métier OK
        offlineWindow: const Duration(days: 30),
        lastSyncAt: now.subtract(const Duration(days: 45)),
        now: now,
        hardLockEligible: true, // même éligible, on ne bloque que sur impayé confirmé
      );
      expect(p, LicensePhase.readOnly);
    });
  });

  group('LicenseValidator (C3 : anti-rollback = version seule)', () {
    const v = LicenseValidator();
    License lic({required String group, required int version}) => License(
          groupId: group,
          plan: 'pro',
          modules: const {'a'},
          quotas: const {},
          validFrom: null,
          validTo: null,
          offlineWindow: Duration.zero,
          version: version,
          issuedAt: now.subtract(const Duration(days: 999)), // horloge "passée"
        );

    test('OK : identité + version ≥ repère (issued_at ancien N’EST PAS rejeté)', () {
      final r = v.validate(lic(group: 'g1', version: 5),
          expectedGroupId: 'g1', versionFloor: 5);
      expect(r.isOk, true);
    });

    test('rejet : identité différente', () {
      final r = v.validate(lic(group: 'g2', version: 9),
          expectedGroupId: 'g1', versionFloor: 0);
      expect(r.rejection, LicenseRejection.identityMismatch);
    });

    test('rejet : rollback (version < repère)', () {
      final r = v.validate(lic(group: 'g1', version: 3),
          expectedGroupId: 'g1', versionFloor: 5);
      expect(r.rejection, LicenseRejection.rollback);
    });
  });

  group('Entitlement (fail-soft)', () {
    test('none() : autorise tout, écriture permise', () {
      const e = Entitlement.none();
      expect(e.isEnforced, false);
      expect(e.grantsModule('n_importe_quoi'), true);
      expect(e.canWriteAt(now), true);
    });

    test('enforced : n’autorise que les modules du plan', () {
      final e = Entitlement(
        license: License(
          groupId: 'g1', plan: 'pro', modules: const {'notes'}, quotas: const {},
          validFrom: null, validTo: now.add(const Duration(days: 30)),
          offlineWindow: const Duration(days: 30), version: 1, issuedAt: now,
        ),
        lastSyncAt: now,
      );
      expect(e.grantsModule('notes'), true);
      expect(e.grantsModule('paie'), false);
      expect(e.canWriteAt(now), true);
    });

    test('phase lecture seule → canWrite false, mais module ENCORE ouvrable', () {
      final e = Entitlement(
        license: License(
          groupId: 'g1', plan: 'pro', modules: const {'notes'}, quotas: const {},
          validFrom: null, validTo: now.subtract(const Duration(days: 40)),
          offlineWindow: const Duration(days: 30), version: 1, issuedAt: now,
        ),
        lastSyncAt: now,
      );
      expect(e.canWriteAt(now), false);         // lecture seule
      expect(e.isHardLockedAt(now), false);     // public → pas de hard-lock
      expect(e.grantsModule('notes'), true);    // la route reste ouverte
    });

    test('plan privé expiré → hard-lock : canWrite false ET hard-lock actif', () {
      final e = Entitlement(
        license: License(
          groupId: 'g1', plan: 'pro', modules: const {'notes'}, quotas: const {},
          validFrom: null, validTo: now.subtract(const Duration(days: 40)),
          offlineWindow: const Duration(days: 30), version: 1, issuedAt: now,
          hardLockable: true,
        ),
        lastSyncAt: now,
      );
      expect(e.isHardLockedAt(now), true);
      expect(e.canWriteAt(now), false);
      expect(e.grantsModule('notes'), true); // appartenance au plan inchangée
    });

    test('non-enforcé (none) → jamais de hard-lock (fail-soft)', () {
      const e = Entitlement.none();
      expect(e.isHardLockedAt(now), false);
    });
  });

  group('LicenseEnforcement (miroir global, chokepoint écriture)', () {
    tearDown(() => LicenseEnforcement.current = const Entitlement.none());

    test('défaut none() → écriture jamais bloquée (fail-soft)', () {
      LicenseEnforcement.current = const Entitlement.none();
      expect(LicenseEnforcement.writeBlockedNow, false);
    });

    test('licence en lecture seule → écriture bloquée', () {
      LicenseEnforcement.current = Entitlement(
        license: License(
          groupId: 'g1', plan: 'pro', modules: const {'notes'}, quotas: const {},
          validFrom: null,
          validTo: DateTime.now().toUtc().subtract(const Duration(days: 40)),
          offlineWindow: const Duration(days: 30), version: 1,
          issuedAt: DateTime.now().toUtc(),
        ),
        lastSyncAt: DateTime.now().toUtc(),
      );
      expect(LicenseEnforcement.writeBlockedNow, true);
    });

    test('licence en grâce → écriture permise', () {
      LicenseEnforcement.current = Entitlement(
        license: License(
          groupId: 'g1', plan: 'pro', modules: const {'notes'}, quotas: const {},
          validFrom: null,
          validTo: DateTime.now().toUtc().subtract(const Duration(days: 5)),
          offlineWindow: const Duration(days: 30), version: 1,
          issuedAt: DateTime.now().toUtc(),
        ),
        lastSyncAt: DateTime.now().toUtc(),
      );
      expect(LicenseEnforcement.writeBlockedNow, false);
    });
  });
}
