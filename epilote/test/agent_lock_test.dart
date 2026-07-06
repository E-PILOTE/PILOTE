import 'package:flutter_test/flutter_test.dart';
import 'package:epilote/features/auth/providers/active_agent_provider.dart';

void main() {
  group('agentLockApplies', () {
    test('staff scolaire → vrai', () {
      expect(agentLockApplies('enseignant'), isTrue);
      expect(agentLockApplies('secretaire'), isTrue);
      expect(agentLockApplies('directeur'), isTrue);
      expect(agentLockApplies('comptable'), isTrue);
    });
    test('super_admin / admin_groupe / parent / eleve → faux', () {
      expect(agentLockApplies('super_admin'), isFalse);
      expect(agentLockApplies('admin_groupe'), isFalse);
      expect(agentLockApplies('parent'), isFalse);
      expect(agentLockApplies('eleve'), isFalse);
    });
    test('null / vide → faux', () {
      expect(agentLockApplies(null), isFalse);
      expect(agentLockApplies(''), isFalse);
    });
  });

  group('computeNeedsAgentUnlock (mode d\'appareil)', () {
    test('poste PARTAGÉ, agents dispo, aucun agent choisi → verrou', () {
      expect(
        computeNeedsAgentUnlock(
          deviceRole: 'enseignant',
          hasAgents: true,
          selectedAgentId: null,
          deviceMode: DeviceMode.shared,
        ),
        isTrue,
      );
    });
    test('poste PERSONNEL → jamais de verrou (l\'utilisateur EST l\'agent)', () {
      expect(
        computeNeedsAgentUnlock(
          deviceRole: 'enseignant',
          hasAgents: true,
          selectedAgentId: null,
          deviceMode: DeviceMode.personal,
        ),
        isFalse,
      );
    });
    test('mode non choisi → pas de verrou (le sélecteur de mode s\'affiche)', () {
      expect(
        computeNeedsAgentUnlock(
          deviceRole: 'enseignant',
          hasAgents: true,
          selectedAgentId: null,
          deviceMode: null,
        ),
        isFalse,
      );
    });
    test('poste personnel + bascule forcée (Changer d\'utilisateur) → verrou', () {
      expect(
        computeNeedsAgentUnlock(
          deviceRole: 'enseignant',
          hasAgents: true,
          selectedAgentId: null,
          deviceMode: DeviceMode.personal,
          forcePicker: true,
        ),
        isTrue,
      );
    });
    test('agent déjà choisi → pas de verrou (même si forcePicker)', () {
      expect(
        computeNeedsAgentUnlock(
          deviceRole: 'enseignant',
          hasAgents: true,
          selectedAgentId: 'a1',
          deviceMode: DeviceMode.shared,
          forcePicker: true,
        ),
        isFalse,
      );
    });
    test('aucun agent synchronisé → pas de verrou (anti-blocage)', () {
      expect(
        computeNeedsAgentUnlock(
          deviceRole: 'enseignant',
          hasAgents: false,
          selectedAgentId: null,
          deviceMode: DeviceMode.shared,
        ),
        isFalse,
      );
    });
    test('super_admin → jamais de verrou', () {
      expect(
        computeNeedsAgentUnlock(
          deviceRole: 'super_admin',
          hasAgents: true,
          selectedAgentId: null,
          deviceMode: DeviceMode.shared,
        ),
        isFalse,
      );
    });
    test('rôle null (pas de session) → pas de verrou', () {
      expect(
        computeNeedsAgentUnlock(
          deviceRole: null,
          hasAgents: true,
          selectedAgentId: null,
          deviceMode: DeviceMode.shared,
        ),
        isFalse,
      );
    });
  });

  group('computeNeedsDeviceModeChoice', () {
    test('staff, mode non choisi, agents synchronisés → demander le mode', () {
      expect(
        computeNeedsDeviceModeChoice(
            deviceRole: 'secretaire', deviceMode: null, hasAgents: true),
        isTrue,
      );
    });
    test('mode déjà choisi → ne pas redemander', () {
      expect(
        computeNeedsDeviceModeChoice(
            deviceRole: 'secretaire',
            deviceMode: DeviceMode.personal,
            hasAgents: true),
        isFalse,
      );
    });
    test('aucun agent synchronisé → ne pas demander trop tôt', () {
      expect(
        computeNeedsDeviceModeChoice(
            deviceRole: 'secretaire', deviceMode: null, hasAgents: false),
        isFalse,
      );
    });
    test('non-staff (super_admin/parent) → jamais', () {
      expect(
        computeNeedsDeviceModeChoice(
            deviceRole: 'super_admin', deviceMode: null, hasAgents: true),
        isFalse,
      );
    });
  });

  group('pinCooldown (anti-force-brute progressif)', () {
    test('échecs 0 à 4 → aucune pause', () {
      for (var i = 0; i <= 4; i++) {
        expect(pinCooldown(i), Duration.zero, reason: 'échec $i');
      }
    });
    test('5ᵉ échec → 30 s', () {
      expect(pinCooldown(5), const Duration(seconds: 30));
    });
    test('6ᵉ échec → 60 s', () {
      expect(pinCooldown(6), const Duration(seconds: 60));
    });
    test('7ᵉ échec → 2 min', () {
      expect(pinCooldown(7), const Duration(minutes: 2));
    });
    test('8ᵉ échec et au-delà → 5 min (plafond)', () {
      expect(pinCooldown(8), const Duration(minutes: 5));
      expect(pinCooldown(12), const Duration(minutes: 5));
      expect(pinCooldown(100), const Duration(minutes: 5));
    });
  });
}
