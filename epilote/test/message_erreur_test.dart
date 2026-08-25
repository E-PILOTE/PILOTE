import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:epilote/core/utils/message_erreur.dart';

// Ce qui compte ici n'est pas la formulation exacte — elle bougera — mais que
// l'agent ne voie JAMAIS le nom d'une exception, un code Postgres nu, ou le
// mot « null ». Les tests portent donc sur ces garanties-là.
void main() {
  const bruitTechnique = [
    'PostgrestException',
    'AuthException',
    'StorageException',
    'SocketException',
    'Exception',
    'null',
    'PGRST',
  ];

  void neDoitPasFuir(String message) {
    for (final mot in bruitTechnique) {
      expect(message.contains(mot), isFalse,
          reason: 'le message montre « $mot » à l’agent : "$message"');
    }
    expect(message.trim(), isNotEmpty);
  }

  group('aucune fuite technique vers l’agent', () {
    final cas = <String, Object>{
      'jeton expiré': const PostgrestException(
          message: 'JWT expired', code: 'PGRST303', details: 'Unauthorized'),
      'refus RLS': const PostgrestException(
          message: 'permission denied for view v_x', code: '42501'),
      'doublon': const PostgrestException(
          message: 'duplicate key value', code: '23505'),
      'clé étrangère': const PostgrestException(
          message: 'violates foreign key', code: '23503'),
      'champ obligatoire': const PostgrestException(
          message: 'null value in column', code: '23502'),
      'format invalide': const PostgrestException(
          message: 'invalid input syntax', code: '22P02'),
      'introuvable': const PostgrestException(
          message: 'no rows', code: 'PGRST116'),
      'réseau': const SocketException('Failed host lookup'),
      'délai dépassé': TimeoutException('trop long'),
      'format': const FormatException('mauvais json'),
    };

    cas.forEach((nom, erreur) {
      test(nom, () => neDoitPasFuir(messageErreur(erreur)));
    });

    test('erreur inconnue reste lisible', () {
      final m = messageErreur(StateError('boom'));
      expect(m, isNotEmpty);
      expect(m.contains('boom'), isFalse,
          reason: 'le détail interne ne doit pas remonter');
    });

    test('null ne produit pas le mot « null »', () {
      neDoitPasFuir(messageErreur(null));
    });
  });

  group('contenu utile', () {
    test('une session expirée dit de se reconnecter', () {
      final m = messageErreur(const PostgrestException(
          message: 'JWT expired', code: 'PGRST303'));
      expect(m.toLowerCase(), contains('reconnect'));
      // Rassurer explicitement : l'agent doit savoir qu'il n'a rien perdu.
      expect(m.toLowerCase(), contains('perdu'));
    });

    test('un refus RLS parle de DROITS, pas de session', () {
      final m = messageErreur(const PostgrestException(
          message: 'permission denied', code: '42501'));
      expect(m.toLowerCase(), contains('droits'));
      expect(m.toLowerCase(), isNot(contains('expir')));
    });

    test('le contexte préfixe le message', () {
      final m =
          messageErreur(const SocketException('x'), contexte: 'Impression');
      expect(m, startsWith('Impression — '));
    });

    test('sans contexte, aucun préfixe parasite', () {
      expect(messageErreur(const SocketException('x')), isNot(contains('—')));
    });
  });
}
