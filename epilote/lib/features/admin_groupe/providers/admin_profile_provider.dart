import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/auth/providers/auth_provider.dart';

// ─── Service compte courant (admin_groupe édite SON propre profil) ───────────
class AdminSelfService {
  AdminSelfService(this._ref);
  final Ref _ref;

  Future<void> updateOwnProfile({
    required String firstName,
    required String lastName,
    String? phone,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    final uid = client.auth.currentUser?.id;
    if (uid == null) throw Exception('Session invalide');
    await client.from('profiles').update({
      'first_name': firstName,
      'last_name': lastName,
      'phone': (phone != null && phone.isNotEmpty) ? phone : null,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', uid);
    // Rafraîchit l'en-tête (nom affiché)
    await _ref.read(authNotifierProvider.notifier).reload();
  }

  Future<void> changePassword(String newPassword) async {
    if (newPassword.length < 6) {
      throw Exception('Le mot de passe doit contenir au moins 6 caractères');
    }
    final client = _ref.read(supabaseClientProvider);
    await client.auth.updateUser(UserAttributes(password: newPassword));
  }
}

final adminSelfServiceProvider =
    Provider<AdminSelfService>((ref) => AdminSelfService(ref));
