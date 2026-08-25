import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:epilote/features/auth/providers/auth_provider.dart';

void main() {
  group('classifyAuthFailure', () {
    test('5xx serveur (le bug "Database error querying schema") => server', () {
      // GoTrue enveloppe une 500 en AuthRetryableFetchException avec statusCode.
      final e = AuthRetryableFetchException(
        message: 'Database error querying schema',
        statusCode: '500',
      );
      expect(classifyAuthFailure(e), AuthFailureKind.server);
    });

    test('503 => server', () {
      final e = AuthRetryableFetchException(message: 'oops', statusCode: '503');
      expect(classifyAuthFailure(e), AuthFailureKind.server);
    });

    test('AuthRetryableFetchException sans statusCode (transport) => network',
        () {
      // Cas `error is! Response` dans gotrue : échec transport, statusCode null.
      final e = AuthRetryableFetchException(message: 'SocketException');
      expect(classifyAuthFailure(e), AuthFailureKind.network);
    });

    test('SocketException brute => network', () {
      final e = Exception('SocketException: Failed host lookup: supabase.co');
      expect(classifyAuthFailure(e), AuthFailureKind.network);
    });

    test('ClientException brute => network', () {
      final e = Exception('ClientException: Connection closed');
      expect(classifyAuthFailure(e), AuthFailureKind.network);
    });

    test('Identifiants invalides (400) => other (message d\'origine conservé)',
        () {
      final e = AuthApiException('Invalid login credentials', statusCode: '400');
      expect(classifyAuthFailure(e), AuthFailureKind.other);
    });
  });
}
