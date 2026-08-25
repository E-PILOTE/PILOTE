import 'dart:async';
import 'dart:io';

import 'package:epilote/services/powersync/upload_outbox.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ════════════════════════════════════════════════════════════════════════════
//  File d'attente d'envoi de fichiers — règles de décision.
//
//  L'enjeu : distinguer « le réseau manque » (réessayable → on met en file) de
//  « le serveur REFUSE » (RLS, quota, MIME → se reproduirait à l'identique).
//  Mettre un refus en file créerait une file qui ne se viderait JAMAIS, et
//  promettrait à l'utilisateur un envoi qui n'aura jamais lieu.
// ════════════════════════════════════════════════════════════════════════════

void main() {
  group('isTransportFailure — met en file UNIQUEMENT ce qui est réessayable', () {
    test('coupure réseau (SocketException) → réessayable', () {
      expect(isTransportFailure(const SocketException('Network unreachable')),
          isTrue);
    });

    test('délai dépassé (TimeoutException) → réessayable', () {
      expect(isTransportFailure(TimeoutException('trop long')), isTrue);
    });

    test('DNS injoignable (Failed host lookup) → réessayable', () {
      expect(
          isTransportFailure(
              const SocketException('Failed host lookup: supabase.co')),
          isTrue);
    });

    test('connexion coupée en cours de route → réessayable', () {
      expect(isTransportFailure(Exception('Connection closed while receiving')),
          isTrue);
    });

    test('REFUS serveur (StorageException RLS) → PAS de mise en file', () {
      expect(
        isTransportFailure(
            const StorageException('new row violates row-level security policy',
                statusCode: '403')),
        isFalse,
        reason: 'un refus RLS se reproduirait identique → file infinie',
      );
    });

    test('REFUS serveur (fichier trop gros) → PAS de mise en file', () {
      expect(
        isTransportFailure(const StorageException('Payload too large',
            statusCode: '413')),
        isFalse,
      );
    });

    test('bug de programmation → PAS de mise en file', () {
      expect(isTransportFailure(ArgumentError('mime nul')), isFalse);
    });
  });

  group('buildStoragePath — calculé HORS RÉSEAU', () {
    test('range sous le dossier du groupe (RLS Storage)', () {
      final p = buildStoragePath(groupId: 'grp-1', fileName: 'photo.jpg');
      expect(p, startsWith('grp-1/'));
      expect(p, endsWith('_photo.jpg'));
    });

    test('sans groupe → dossier plateforme', () {
      expect(buildStoragePath(groupId: '', fileName: 'a.png'),
          startsWith('platform/'));
    });

    test('assainit le nom de fichier (accents, espaces, séparateurs)', () {
      final p = buildStoragePath(
          groupId: 'g', fileName: 'Bulletin Élève 3è/2026.pdf');
      final name = p.split('/').last;
      expect(name, isNot(contains(' ')));
      expect(RegExp(r'^[\w\.\-]+$').hasMatch(name), isTrue,
          reason: 'un nom non assaini casserait le chemin Storage');
    });

    test('deux appels ne collisionnent jamais (UUID)', () {
      final a = buildStoragePath(groupId: 'g', fileName: 'x.jpg');
      final b = buildStoragePath(groupId: 'g', fileName: 'x.jpg');
      expect(a, isNot(equals(b)));
    });
  });
}
