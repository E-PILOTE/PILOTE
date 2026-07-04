import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/ports.dart';

/// Récupère un token de licence frais via l'Edge Function `license-issuer`,
/// hors-bande, en réutilisant la session Supabase authentifiée (aucune
/// mécanique d'auth nouvelle — cf. ADR-0002). Ne touche PAS PowerSync.
///
/// Renvoie `null` (jamais d'exception) si indisponible : hors ligne, fonction
/// non déployée, ou réponse inattendue → le [LicenseService] gère en fail-soft.
class SupabaseLicenseGateway implements LicenseGateway {
  SupabaseLicenseGateway(this._client);
  final SupabaseClient _client;

  static const _functionName = 'license-issuer';

  @override
  Future<String?> fetchLicenseToken() async {
    try {
      final res = await _client.functions.invoke(_functionName);
      final data = res.data;
      if (data is String && data.isNotEmpty) return data;
      if (data is Map && data['token'] is String) return data['token'] as String;
      return null;
    } catch (_) {
      return null;
    }
  }
}
