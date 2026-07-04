import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../domain/ports.dart';

/// Vérificateur Ed25519 de JWS compacts (`header.payload.signature`, base64url
/// non paddé). Implémente [SignatureVerifier].
///
/// - Clés publiques ÉPINGLÉES, indexées par `kid` (rotation multi-clés).
/// - `alg` doit valoir `EdDSA`.
/// - Ne connaît QUE la crypto : aucune règle métier ici (SRP).
///
/// L'intégrité du système repose sur CETTE vérification, pas sur le coffre
/// (faible sur desktop) — cf. ADR-0003.
class Ed25519Verifier implements SignatureVerifier {
  Ed25519Verifier(this._pinnedKeys) : _algorithm = Ed25519();

  /// kid → octets bruts de la clé publique Ed25519 (32 o).
  final Map<String, List<int>> _pinnedKeys;
  final Ed25519 _algorithm;

  @override
  Future<Map<String, dynamic>?> verifyAndDecode(String token) async {
    final parts = token.split('.');
    if (parts.length != 3) return null;

    final header = _decodeJson(parts[0]);
    if (header == null) return null;
    if (header['alg'] != 'EdDSA') return null;

    final kid = header['kid'] as String?;
    final keyBytes = kid == null ? null : _pinnedKeys[kid];
    if (keyBytes == null) return null; // kid inconnu / non épinglé

    final signingInput = ascii.encode('${parts[0]}.${parts[1]}');
    final sigBytes = _b64uDecode(parts[2]);
    if (sigBytes == null) return null;

    final publicKey = SimplePublicKey(keyBytes, type: KeyPairType.ed25519);
    final ok = await _algorithm.verify(
      signingInput,
      signature: Signature(sigBytes, publicKey: publicKey),
    );
    if (!ok) return null;

    return _decodeJson(parts[1]);
  }

  Map<String, dynamic>? _decodeJson(String segment) {
    final bytes = _b64uDecode(segment);
    if (bytes == null) return null;
    try {
      final decoded = json.decode(utf8.decode(bytes));
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// base64url tolérant au padding manquant (convention JWS).
  static List<int>? _b64uDecode(String s) {
    try {
      final pad = (4 - s.length % 4) % 4;
      return base64Url.decode(s + '=' * pad);
    } catch (_) {
      return null;
    }
  }
}
