import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../../../features/auth/providers/auth_provider.dart';

/// Catégories de partenaires — enum applicatif volontairement FERMÉ (curation
/// institutionnelle/éducative ; pas de régie publicitaire tierce).
const kPartnerCategories = <String, String>{
  'institutionnel': 'Institutionnel',
  'educatif': 'Éducatif',
  'ong': 'ONG',
  'editeur': 'Éditeur scolaire',
};

String partnerCategoryLabel(String slug) =>
    kPartnerCategories[slug] ?? 'Institutionnel';

/// Partenaire affiché sur la vitrine des postes (table `platform_partners`).
/// CRUD online (super_admin) ; lecture staff via PowerSync.
class PartnerModel {
  const PartnerModel({
    required this.id,
    required this.name,
    required this.logoUrl,
    required this.websiteUrl,
    required this.category,
    required this.isActive,
    required this.sortOrder,
    required this.startsAt,
    required this.endsAt,
  });

  factory PartnerModel.fromRow(Map m) => PartnerModel(
        id: m['id'] as String,
        name: m['name'] as String? ?? '',
        logoUrl: m['logo_url'] as String?,
        websiteUrl: m['website_url'] as String?,
        category: m['category'] as String? ?? 'institutionnel',
        isActive: m['is_active'] as bool? ?? false,
        sortOrder: (m['sort_order'] as num?)?.toInt() ?? 0,
        startsAt: _p(m['starts_at']),
        endsAt: _p(m['ends_at']),
      );

  final String id;
  final String name;
  final String? logoUrl;
  final String? websiteUrl;
  final String category;
  final bool isActive;
  final int sortOrder;
  final DateTime? startsAt;
  final DateTime? endsAt;

  static DateTime? _p(dynamic v) => v is String ? DateTime.tryParse(v) : null;
}

final partnersAdminProvider =
    FutureProvider.autoDispose<List<PartnerModel>>((ref) async {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);
  final rows = await client
      .from('platform_partners')
      .select(
          'id, name, logo_url, website_url, category, is_active, sort_order, starts_at, ends_at')
      .order('sort_order', ascending: true);
  return (rows as List).map((r) => PartnerModel.fromRow(r as Map)).toList();
});

class PartnersAdminService {
  PartnersAdminService(this._ref);
  final Ref _ref;

  dynamic get _client => _ref.read(supabaseClientProvider);

  String? _nz(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();

  Future<void> create({
    required String name,
    String? logoUrl,
    String? websiteUrl,
    required String category,
    required bool isActive,
    required int sortOrder,
    DateTime? startsAt,
    DateTime? endsAt,
    String? createdBy,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _client.from('platform_partners').insert({
      'name': name.trim(),
      'logo_url': _nz(logoUrl),
      'website_url': _nz(websiteUrl),
      'category': category,
      'is_active': isActive,
      'sort_order': sortOrder,
      'starts_at': startsAt?.toIso8601String(),
      'ends_at': endsAt?.toIso8601String(),
      'created_by': ?createdBy,
      'created_at': now,
      'updated_at': now,
    });
    _ref.invalidate(partnersAdminProvider);
  }

  Future<void> update({
    required String id,
    required String name,
    String? logoUrl,
    String? websiteUrl,
    required String category,
    required bool isActive,
    required int sortOrder,
    DateTime? startsAt,
    DateTime? endsAt,
  }) async {
    await _client.from('platform_partners').update({
      'name': name.trim(),
      'logo_url': _nz(logoUrl),
      'website_url': _nz(websiteUrl),
      'category': category,
      'is_active': isActive,
      'sort_order': sortOrder,
      'starts_at': startsAt?.toIso8601String(),
      'ends_at': endsAt?.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
    _ref.invalidate(partnersAdminProvider);
  }

  Future<void> toggleActive(String id, bool value) async {
    await _client.from('platform_partners').update({
      'is_active': value,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
    _ref.invalidate(partnersAdminProvider);
  }

  Future<void> delete(String id) async {
    await _client.from('platform_partners').delete().eq('id', id);
    _ref.invalidate(partnersAdminProvider);
  }

  /// Upload d'un logo → bucket public `partner-logos`, renvoie l'URL publique.
  Future<String> uploadLogo(Uint8List bytes, String ext) async {
    final e = ext.toLowerCase();
    final path = 'partners/partner_${DateTime.now().millisecondsSinceEpoch}.$e';
    await _client.storage.from('partner-logos').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: 'image/$e', upsert: true),
        );
    return _client.storage.from('partner-logos').getPublicUrl(path);
  }
}

final partnersAdminServiceProvider =
    Provider<PartnersAdminService>((ref) => PartnersAdminService(ref));
