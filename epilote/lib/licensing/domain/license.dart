/// Faits signés décodés d'une licence. Objet valeur IMMUABLE, Dart pur.
///
/// Ne connaît RIEN de la crypto, du stockage, du réseau ou de Flutter : il ne
/// fait que porter les champs décodés du payload JWS (cf. ADR-0002). La
/// vérification de signature a lieu AVANT, dans un [SignatureVerifier].
class License {
  const License({
    required this.groupId,
    required this.plan,
    required this.modules,
    required this.quotas,
    required this.validFrom,
    required this.validTo,
    required this.offlineWindow,
    required this.version,
    required this.issuedAt,
  });

  /// Décode une licence depuis les *claims* d'un JWS déjà vérifié.
  /// Tolérant : un champ absent prend une valeur neutre plutôt que de jeter,
  /// pour rester fail-soft (une licence partiellement lisible vaut mieux que
  /// pas de licence). Renvoie `null` si le champ pivot `group_id` manque.
  static License? fromClaims(Map<String, dynamic> c) {
    final groupId = c['group_id'] as String?;
    if (groupId == null || groupId.isEmpty) return null;

    DateTime? parseTs(Object? v) {
      if (v is String) return DateTime.tryParse(v)?.toUtc();
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v * 1000, isUtc: true);
      return null;
    }

    final modules = <String>{
      for (final m in (c['modules'] as List? ?? const [])) '$m',
    };
    final quotas = <String, int>{
      for (final e in (c['quotas'] as Map? ?? const {}).entries)
        '${e.key}': (e.value is int) ? e.value as int : int.tryParse('${e.value}') ?? 0,
    };
    final windowSecs = (c['offline_window'] is int)
        ? c['offline_window'] as int
        : int.tryParse('${c['offline_window']}') ?? 0;

    return License(
      groupId: groupId,
      plan: (c['plan'] as String?) ?? '',
      modules: modules,
      quotas: quotas,
      validFrom: parseTs(c['valid_from']),
      validTo: parseTs(c['valid_to']),
      offlineWindow: Duration(seconds: windowSecs),
      version: (c['version'] is int) ? c['version'] as int : int.tryParse('${c['version']}') ?? 0,
      issuedAt: parseTs(c['issued_at']),
    );
  }

  /// Tenant facturé (groupe scolaire). Vérifié == identité à l'application.
  final String groupId;
  final String plan;
  final Set<String> modules;
  final Map<String, int> quotas;
  final DateTime? validFrom;

  /// Horloge 1 (expiration métier). `null` = pas d'échéance (perpétuel).
  final DateTime? validTo;

  /// Horloge 2 (fenêtre de confiance) : durée max hors ligne sans revalidation.
  final Duration offlineWindow;

  /// Compteur monotone : SEULE ancre anti-rollback (cf. ADR-0004, C3).
  final int version;

  /// Informationnel / audit UNIQUEMENT. Ne sert JAMAIS à rejeter (C3).
  final DateTime? issuedAt;

  bool grantsModule(String slug) => modules.contains(slug);
}
