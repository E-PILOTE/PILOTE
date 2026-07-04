import 'package:epilote/licensing/domain/ports.dart';

/// Fakes mémoire pour tester le domaine + l'application SANS crypto/coffre/réseau.
/// Chaque fake couvre un des 4 ports.

class FakeClock implements Clock {
  FakeClock(this._now);
  DateTime _now;
  set now(DateTime v) => _now = v.toUtc();
  @override
  DateTime wallNow() => _now.toUtc();
  @override
  Duration sessionElapsed() => Duration.zero;
}

class FakeStore implements LicenseStore {
  FakeStore([this._state]);
  TrustState? _state;
  bool failWrite = false;
  int writes = 0;

  @override
  Future<TrustState?> read() async => _state;

  @override
  Future<void> write(TrustState s) async {
    if (failWrite) throw StateError('write failed');
    writes++;
    _state = s;
  }

  @override
  Future<void> clear() async => _state = null;

  TrustState? get current => _state;
}

class FakeGateway implements LicenseGateway {
  FakeGateway([this.token]);
  String? token;
  bool throwOnFetch = false;

  @override
  Future<String?> fetchLicenseToken() async {
    if (throwOnFetch) throw StateError('offline');
    return token;
  }
}

/// Vérificateur factice : délègue le décodage à une fonction (claims ou null).
class FakeVerifier implements SignatureVerifier {
  FakeVerifier(this.decoder);
  final Map<String, dynamic>? Function(String token) decoder;

  @override
  Future<Map<String, dynamic>?> verifyAndDecode(String token) async =>
      decoder(token);
}
