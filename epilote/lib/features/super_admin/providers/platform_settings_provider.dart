import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/auth_provider.dart';

/// Lit la ligne unique (id=1) de `platform_settings` et retourne son JSONB `data`.
/// super_admin uniquement (RLS `platform_settings_select`).
final platformSettingsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);
  final row = await client
      .from('platform_settings')
      .select('data')
      .eq('id', 1)
      .maybeSingle();
  if (row == null) return <String, dynamic>{};
  final data = row['data'];
  return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
});

/// Enregistre (upsert) les paramètres dans la ligne unique id=1.
Future<void> savePlatformSettings(
  dynamic client,
  Map<String, dynamic> data, {
  String? updatedBy,
}) async {
  await client.from('platform_settings').upsert({
    'id': 1,
    'data': data,
    'updated_at': DateTime.now().toIso8601String(),
    'updated_by': ?updatedBy,
  });
}
