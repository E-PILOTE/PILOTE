import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:epilote/licensing/domain/license.dart';
import 'package:epilote/licensing/infrastructure/ed25519_verifier.dart';
import 'package:flutter_test/flutter_test.dart';

/// Round-trip crypto RÉEL (sans serveur) : on génère une paire Ed25519, on
/// signe un JWS exactement comme le fera l'Edge Function `license-issuer`, et on
/// vérifie via l'adaptateur de prod [Ed25519Verifier]. Prouve la chaîne
/// signature → décodage → License.fromClaims de bout en bout.

String _b64u(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

Future<String> _signJws(
  SimpleKeyPair keyPair,
  Map<String, dynamic> header,
  Map<String, dynamic> payload,
) async {
  final algo = Ed25519();
  final h = _b64u(utf8.encode(json.encode(header)));
  final p = _b64u(utf8.encode(json.encode(payload)));
  final signingInput = ascii.encode('$h.$p');
  final sig = await algo.sign(signingInput, keyPair: keyPair);
  return '$h.$p.${_b64u(sig.bytes)}';
}

void main() {
  test('JWS Ed25519 signé → vérifié → décodé → License', () async {
    final algo = Ed25519();
    final keyPair = await algo.newKeyPair();
    final pub = await keyPair.extractPublicKey();

    final payload = {
      'group_id': 'grp-123',
      'plan': 'pro',
      'modules': ['notes', 'bulletins'],
      'quotas': {'schools': 5, 'students': 2000},
      'valid_to': '2026-12-31T00:00:00Z',
      'offline_window': 2592000,
      'version': 42,
      'issued_at': '2026-07-04T00:00:00Z',
    };
    final token = await _signJws(
      keyPair, {'alg': 'EdDSA', 'kid': 'k1'}, payload);

    final verifier = Ed25519Verifier({'k1': pub.bytes});
    final claims = await verifier.verifyAndDecode(token);

    expect(claims, isNotNull);
    final license = License.fromClaims(claims!);
    expect(license, isNotNull);
    expect(license!.groupId, 'grp-123');
    expect(license.version, 42);
    expect(license.modules, containsAll(['notes', 'bulletins']));
    expect(license.offlineWindow, const Duration(days: 30));
  });

  test('payload altéré → signature invalide → null', () async {
    final algo = Ed25519();
    final keyPair = await algo.newKeyPair();
    final pub = await keyPair.extractPublicKey();
    final token = await _signJws(
      keyPair, {'alg': 'EdDSA', 'kid': 'k1'}, {'group_id': 'g', 'version': 1});

    final parts = token.split('.');
    // On remplace le payload par un autre (droits gonflés) en gardant la signature.
    final forged = '${parts[0]}.${_b64u(utf8.encode('{"group_id":"g","version":999}'))}.${parts[2]}';

    final verifier = Ed25519Verifier({'k1': pub.bytes});
    expect(await verifier.verifyAndDecode(forged), isNull);
  });

  test('kid non épinglé → null', () async {
    final algo = Ed25519();
    final keyPair = await algo.newKeyPair();
    final pub = await keyPair.extractPublicKey();
    final token = await _signJws(
      keyPair, {'alg': 'EdDSA', 'kid': 'inconnu'}, {'group_id': 'g', 'version': 1});

    final verifier = Ed25519Verifier({'k1': pub.bytes}); // ne connaît pas 'inconnu'
    expect(await verifier.verifyAndDecode(token), isNull);
  });
}
