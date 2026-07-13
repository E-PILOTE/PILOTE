import 'package:epilote/features/auth/providers/active_agent_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Qui a le droit de DÉSENRÔLER un poste ?
//
//  Désenrôler = retirer à l'appareil sa session Supabase, donc son droit de
//  travailler hors-ligne. Plus AUCUN agent ne peut ouvrir de session tant
//  qu'internet n'est pas revenu → rayon de destruction = l'école entière.
//
//  Deux faits qui décident de la règle :
//    • désenrôler n'est JAMAIS urgent (un appareil volé se révoque côté
//      serveur, pas depuis l'appareil) → on peut le réserver sans rien bloquer ;
//    • sur un poste PERSONNEL, l'interdire serait absurde : c'est sa machine.
// ════════════════════════════════════════════════════════════════════════════

void main() {
  group('Poste PARTAGÉ — direction uniquement', () {
    test('directeur → autorisé', () {
      expect(
          canUnenrollDevice(role: 'directeur', mode: DeviceMode.shared), isTrue);
    });

    test('proviseur → autorisé', () {
      expect(
          canUnenrollDevice(role: 'proviseur', mode: DeviceMode.shared), isTrue);
    });

    test('enseignant → REFUSÉ (il bloquerait toute l\'école)', () {
      expect(canUnenrollDevice(role: 'enseignant', mode: DeviceMode.shared),
          isFalse);
    });

    test('secrétaire → REFUSÉ', () {
      expect(canUnenrollDevice(role: 'secretaire', mode: DeviceMode.shared),
          isFalse);
    });

    test('comptable, CPE, surveillant → REFUSÉS', () {
      for (final r in ['comptable', 'cpe', 'surveillant']) {
        expect(canUnenrollDevice(role: r, mode: DeviceMode.shared), isFalse,
            reason: '$r ne doit pas pouvoir priver l\'école de son hors-ligne');
      }
    });
  });

  group('Poste PERSONNEL — c\'est sa machine', () {
    test('enseignant → autorisé (aucun autre agent ne dépend de ce poste)', () {
      expect(canUnenrollDevice(role: 'enseignant', mode: DeviceMode.personal),
          isTrue);
    });

    test('directeur → autorisé', () {
      expect(canUnenrollDevice(role: 'directeur', mode: DeviceMode.personal),
          isTrue);
    });
  });

  group('Rôles online — la question ne se pose pas', () {
    test('super_admin et admin_groupe → toujours autorisés', () {
      for (final r in ['super_admin', 'admin_groupe']) {
        expect(canUnenrollDevice(role: r, mode: null), isTrue,
            reason: 'aucun mode hors-ligne à protéger chez eux');
      }
    });
  });

  group('Cas limites', () {
    test('rôle inconnu / vide → REFUSÉ (on ne détruit pas sur un doute)', () {
      expect(canUnenrollDevice(role: null, mode: DeviceMode.shared), isFalse);
      expect(canUnenrollDevice(role: '', mode: DeviceMode.shared), isFalse);
    });

    test('mode d\'appareil pas encore choisi → traité comme PARTAGÉ (prudent)',
        () {
      expect(canUnenrollDevice(role: 'enseignant', mode: null), isFalse);
      expect(canUnenrollDevice(role: 'directeur', mode: null), isTrue);
    });
  });
}
