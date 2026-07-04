import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/ports.dart';

/// Coffre du [TrustState] sur `flutter_secure_storage`. Un seul enregistrement
/// JSON → l'écriture d'un blob unique est atomique au niveau du magasin.
///
/// ⚠️ Sur desktop Linux/Windows le magasin est FAIBLE (libsecret) : l'intégrité
/// ne repose PAS sur lui mais sur la signature Ed25519 (cf. ADR-0003). Le coffre
/// n'est que de la défense en profondeur, et sert surtout à SURVIVRE au
/// `disconnectAndClear()` de PowerSync (hors SQLite synchronisé).
class SecureLicenseStore implements LicenseStore {
  SecureLicenseStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'license_trust_state_v1';
  final FlutterSecureStorage _storage;

  @override
  Future<TrustState?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    final m = json.decode(raw) as Map<String, dynamic>;
    return TrustState(
      token: m['token'] as String,
      version: m['version'] as int,
      timeHighWater: DateTime.parse(m['time_high_water'] as String).toUtc(),
      lastSyncAt: DateTime.parse(m['last_sync_at'] as String).toUtc(),
    );
  }

  @override
  Future<void> write(TrustState s) async {
    final raw = json.encode({
      'token': s.token,
      'version': s.version,
      'time_high_water': s.timeHighWater.toUtc().toIso8601String(),
      'last_sync_at': s.lastSyncAt.toUtc().toIso8601String(),
    });
    await _storage.write(key: _key, value: raw);
  }

  @override
  Future<void> clear() => _storage.delete(key: _key);
}
