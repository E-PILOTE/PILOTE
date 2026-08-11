import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:epilote/core/auth/session_morte.dart';

// La détection doit être ÉTROITE. Trop large, elle déconnecterait un agent en
// plein travail pour un simple refus RLS ou une coupure réseau — exactement ce
// qu'il ne faut pas sur un poste d'établissement, où personne sur place ne
// connaît le mot de passe du compte.
void main() {
  group('estSessionMorte — ce qui DOIT déclencher la reprise', () {
    test('PGRST303 : jeton expiré', () {
      expect(
        estSessionMorte(const PostgrestException(
          message: 'JWT expired', code: 'PGRST303', details: 'Unauthorized')),
        isTrue,
      );
    });

    test('PGRST301 : jeton invalide', () {
      expect(
        estSessionMorte(
            const PostgrestException(message: 'JWSError', code: 'PGRST301')),
        isTrue,
      );
    });

    test('message explicite, même sans code reconnu', () {
      expect(
        estSessionMorte(const PostgrestException(message: 'JWT expired')),
        isTrue,
      );
    });

    test('jeton de rafraîchissement introuvable → plus aucune reprise possible',
        () {
      expect(
        estSessionMorte(AuthApiException('Refresh Token Not Found',
            statusCode: '400', code: 'refresh_token_not_found')),
        isTrue,
      );
    });

    test('jeton de rafraîchissement déjà consommé (deux instances)', () {
      expect(
        estSessionMorte(AuthApiException('Already Used',
            code: 'refresh_token_already_used')),
        isTrue,
      );
    });
  });

  group('estSessionMorte — ce qui ne DOIT PAS déconnecter', () {
    test('refus RLS : la session est valide, c\'est le DROIT qui manque', () {
      expect(
        estSessionMorte(const PostgrestException(
          message: 'permission denied for view v_x', code: '42501')),
        isFalse,
      );
    });

    test('violation de contrainte', () {
      expect(
        estSessionMorte(const PostgrestException(
          message: 'duplicate key value', code: '23505')),
        isFalse,
      );
    });

    test('mot de passe erroné à la connexion — pas une session morte', () {
      expect(
        estSessionMorte(AuthApiException('Invalid login credentials',
            statusCode: '400', code: 'invalid_credentials')),
        isFalse,
      );
    });

    test('panne réseau', () {
      expect(estSessionMorte(Exception('SocketException: failed host lookup')),
          isFalse);
    });

    test('erreur quelconque', () {
      expect(estSessionMorte(StateError('boom')), isFalse);
    });
  });
}
