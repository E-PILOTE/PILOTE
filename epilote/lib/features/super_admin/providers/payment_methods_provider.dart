import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/auth_provider.dart';

// ─── Modèles ──────────────────────────────────────────────────────────────────

class PaymentConfigModel {
  const PaymentConfigModel({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.provider,
    required this.displayName,
    required this.merchantId,
    required this.webhookUrl,
    required this.isActive,
    required this.isTestMode,
    required this.configuredAt,
    required this.notes,
  });

  final String  id;
  final String  groupId;
  final String  groupName;
  final String  provider;
  final String  displayName;
  final String  merchantId;
  final String  webhookUrl;
  final bool    isActive;
  final bool    isTestMode;
  final String  configuredAt;
  final String  notes;
}

class PaymentMethodsData {
  const PaymentMethodsData({
    required this.configs,
    required this.totalConfigs,
    required this.activeConfigs,
    required this.testConfigs,
    required this.configuredGroups,
    required this.byProvider,
  });

  final List<PaymentConfigModel> configs;
  final int                      totalConfigs;
  final int                      activeConfigs;
  final int                      testConfigs;
  final int                      configuredGroups;
  final Map<String, int>         byProvider;
}

// ─── Providers ────────────────────────────────────────────────────────────────

final paymentMethodsProvider = FutureProvider.autoDispose<PaymentMethodsData>((ref) async {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);

  final rows = await client
      .from('payment_configs')
      .select(
        'id, group_id, provider, display_name, merchant_id, webhook_url, '
        'is_active, is_test_mode, configured_at, notes, '
        'school_groups(name)',
      )
      .order('configured_at', ascending: false);

  final configs = (rows as List).map((r) {
    final m  = r as Map;
    final sg = m['school_groups'] as Map? ?? {};
    return PaymentConfigModel(
      id:           m['id'] as String,
      groupId:      m['group_id'] as String,
      groupName:    sg['name'] as String? ?? '—',
      provider:     m['provider'] as String? ?? '',
      displayName:  m['display_name'] as String? ?? '',
      merchantId:   m['merchant_id'] as String? ?? '',
      webhookUrl:   m['webhook_url'] as String? ?? '',
      isActive:     m['is_active'] as bool? ?? false,
      isTestMode:   m['is_test_mode'] as bool? ?? false,
      configuredAt: m['configured_at'] as String? ?? '',
      notes:        m['notes'] as String? ?? '',
    );
  }).toList();

  final Map<String, int> byProvider = {};
  for (final c in configs) {
    byProvider[c.provider] = (byProvider[c.provider] ?? 0) + 1;
  }

  final uniqueGroups = configs.map((c) => c.groupId).toSet().length;

  return PaymentMethodsData(
    configs:          configs,
    totalConfigs:     configs.length,
    activeConfigs:    configs.where((c) => c.isActive).length,
    testConfigs:      configs.where((c) => c.isTestMode).length,
    configuredGroups: uniqueGroups,
    byProvider:       byProvider,
  );
});

// Toggle active
Future<void> togglePaymentConfigActive({
  required dynamic client,
  required String id,
  required bool newValue,
}) async {
  await client
      .from('payment_configs')
      .update({'is_active': newValue, 'updated_at': DateTime.now().toIso8601String()})
      .eq('id', id);
}

// Toggle test mode
Future<void> togglePaymentConfigTestMode({
  required dynamic client,
  required String id,
  required bool newValue,
}) async {
  await client
      .from('payment_configs')
      .update({'is_test_mode': newValue, 'updated_at': DateTime.now().toIso8601String()})
      .eq('id', id);
}

// ─── Liste des groupes (pour le sélecteur du formulaire d'ajout) ───────────────

class PaymentGroupOption {
  const PaymentGroupOption({required this.id, required this.name});
  final String id;
  final String name;
}

final paymentConfigGroupsProvider =
    FutureProvider.autoDispose<List<PaymentGroupOption>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final rows = await client.from('school_groups').select('id, name').order('name');
  return (rows as List).map((r) {
    final m = r as Map;
    return PaymentGroupOption(id: m['id'] as String, name: m['name'] as String? ?? '—');
  }).toList();
});

// ─── Création / mise à jour d'une configuration ───────────────────────────────
// api_key / api_secret sont en écriture seule : jamais relus côté client, et
// uniquement transmis lorsqu'une nouvelle valeur est saisie.

String? _nullIfEmpty(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();

Future<void> createPaymentConfig({
  required dynamic client,
  required String groupId,
  required String provider,
  required String displayName,
  String? merchantId,
  String? webhookUrl,
  String? notes,
  String? apiKey,
  String? apiSecret,
  required bool isActive,
  required bool isTestMode,
  String? configuredBy,
}) async {
  final now = DateTime.now().toIso8601String();
  await client.from('payment_configs').insert({
    'group_id':      groupId,
    'provider':      provider,
    'display_name':  displayName.trim(),
    'merchant_id':   _nullIfEmpty(merchantId),
    'webhook_url':   _nullIfEmpty(webhookUrl),
    'notes':         _nullIfEmpty(notes),
    if (_nullIfEmpty(apiKey)    != null) 'api_key':    apiKey!.trim(),
    if (_nullIfEmpty(apiSecret) != null) 'api_secret': apiSecret!.trim(),
    'is_active':     isActive,
    'is_test_mode':  isTestMode,
    'configured_by': ?configuredBy,
    'configured_at': now,
    'updated_at':    now,
  });
}

Future<void> updatePaymentConfig({
  required dynamic client,
  required String id,
  required String displayName,
  String? merchantId,
  String? webhookUrl,
  String? notes,
  String? apiKey,
  String? apiSecret,
  required bool isActive,
  required bool isTestMode,
}) async {
  await client.from('payment_configs').update({
    'display_name': displayName.trim(),
    'merchant_id':  _nullIfEmpty(merchantId),
    'webhook_url':  _nullIfEmpty(webhookUrl),
    'notes':        _nullIfEmpty(notes),
    if (_nullIfEmpty(apiKey)    != null) 'api_key':    apiKey!.trim(),
    if (_nullIfEmpty(apiSecret) != null) 'api_secret': apiSecret!.trim(),
    'is_active':    isActive,
    'is_test_mode': isTestMode,
    'updated_at':   DateTime.now().toIso8601String(),
  }).eq('id', id);
}
