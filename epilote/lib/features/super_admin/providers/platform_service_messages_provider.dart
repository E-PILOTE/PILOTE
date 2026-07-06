import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/auth_provider.dart';

/// Message de service diffusé sur la vitrine des postes (table
/// `platform_service_messages`). CRUD online (super_admin), lecture staff via
/// PowerSync (cf. `serviceMessagesProvider`).
class ServiceMessageModel {
  const ServiceMessageModel({
    required this.id,
    required this.body,
    required this.isActive,
    required this.startsAt,
    required this.endsAt,
    required this.createdAt,
  });

  factory ServiceMessageModel.fromRow(Map m) => ServiceMessageModel(
        id: m['id'] as String,
        body: m['body'] as String? ?? '',
        isActive: m['is_active'] as bool? ?? false,
        startsAt: _p(m['starts_at']),
        endsAt: _p(m['ends_at']),
        createdAt: _p(m['created_at']),
      );

  final String id;
  final String body;
  final bool isActive;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime? createdAt;

  static DateTime? _p(dynamic v) =>
      v is String ? DateTime.tryParse(v) : null;
}

final serviceMessagesAdminProvider =
    FutureProvider.autoDispose<List<ServiceMessageModel>>((ref) async {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);
  final rows = await client
      .from('platform_service_messages')
      .select('id, body, is_active, starts_at, ends_at, created_at')
      .order('created_at', ascending: false);
  return (rows as List)
      .map((r) => ServiceMessageModel.fromRow(r as Map))
      .toList();
});

class ServiceMessagesAdminService {
  ServiceMessagesAdminService(this._ref);
  final Ref _ref;

  dynamic get _client => _ref.read(supabaseClientProvider);

  Future<void> create({
    required String body,
    required bool isActive,
    DateTime? startsAt,
    DateTime? endsAt,
    String? createdBy,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _client.from('platform_service_messages').insert({
      'body': body.trim(),
      'is_active': isActive,
      'starts_at': startsAt?.toIso8601String(),
      'ends_at': endsAt?.toIso8601String(),
      'created_by': ?createdBy,
      'created_at': now,
      'updated_at': now,
    });
    _ref.invalidate(serviceMessagesAdminProvider);
  }

  Future<void> update({
    required String id,
    required String body,
    required bool isActive,
    DateTime? startsAt,
    DateTime? endsAt,
  }) async {
    await _client.from('platform_service_messages').update({
      'body': body.trim(),
      'is_active': isActive,
      'starts_at': startsAt?.toIso8601String(),
      'ends_at': endsAt?.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
    _ref.invalidate(serviceMessagesAdminProvider);
  }

  Future<void> toggleActive(String id, bool value) async {
    await _client.from('platform_service_messages').update({
      'is_active': value,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
    _ref.invalidate(serviceMessagesAdminProvider);
  }

  Future<void> delete(String id) async {
    await _client.from('platform_service_messages').delete().eq('id', id);
    _ref.invalidate(serviceMessagesAdminProvider);
  }
}

final serviceMessagesAdminServiceProvider =
    Provider<ServiceMessagesAdminService>(
        (ref) => ServiceMessagesAdminService(ref));
