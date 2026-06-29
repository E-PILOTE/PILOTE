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

  group('computeNeedsAgentUnlock', () {
    test('staff, agents dispo, aucun agent choisi → verrou', () {
      expect(
        computeNeedsAgentUnlock(
            deviceRole: 'enseignant', hasAgents: true, selectedAgentId: null),
        isTrue,
      );
    });
    test('agent déjà choisi → pas de verrou', () {
      expect(
        computeNeedsAgentUnlock(
            deviceRole: 'enseignant', hasAgents: true, selectedAgentId: 'a1'),
        isFalse,
      );
    });
    test('aucun agent synchronisé → pas de verrou (anti-blocage)', () {
      expect(
        computeNeedsAgentUnlock(
            deviceRole: 'enseignant', hasAgents: false, selectedAgentId: null),
        isFalse,
      );
    });
    test('super_admin → jamais de verrou', () {
      expect(
        computeNeedsAgentUnlock(
            deviceRole: 'super_admin', hasAgents: true, selectedAgentId: null),
        isFalse,
      );
    });
    test('rôle null (pas de session) → pas de verrou', () {
      expect(
        computeNeedsAgentUnlock(
            deviceRole: null, hasAgents: true, selectedAgentId: null),
        isFalse,
      );
    });
  });
}
