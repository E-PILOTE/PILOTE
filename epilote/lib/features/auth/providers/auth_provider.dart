import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_constants.dart';
import '../../../data/models/profile_model.dart';

// ─── Client Supabase ───────────────────────────────────────────────────────
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// ─── Session en cours ──────────────────────────────────────────────────────
final authSessionProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange;
});

// ─── Utilisateur connecté ──────────────────────────────────────────────────
final currentUserProvider = Provider<User?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.currentUser;
});

// ─── Profil utilisateur ────────────────────────────────────────────────────
final currentProfileProvider = FutureProvider<ProfileModel?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final client = ref.watch(supabaseClientProvider);
  try {
    final data = await client
        .from(SupabaseConstants.profilesTable)
        .select()
        .eq('id', user.id)
        .single();

    return ProfileModel.fromMap(data);
  } catch (e) {
    return null;
  }
});

// ─── AuthNotifier ─────────────────────────────────────────────────────────
class AuthNotifier extends StateNotifier<AsyncValue<ProfileModel?>> {
  AuthNotifier(this._client) : super(const AsyncValue.loading()) {
    _init();
  }

  final SupabaseClient _client;

  Future<void> _init() async {
    // Le splash s'affiche TOUJOURS au moins 3.2 secondes,
    // même si l'utilisateur est déjà connecté.
    final minSplash = Future.delayed(const Duration(milliseconds: 3200));

    final user = _client.auth.currentUser;

    // Charger le profil en parallèle SANS mettre à jour state tout de suite
    ProfileModel? loadedProfile;
    Object? loadError;
    StackTrace? loadSt;

    if (user != null) {
      try {
        final data = await _client
            .from(SupabaseConstants.profilesTable)
            .select()
            .eq('id', user.id)
            .single();
        loadedProfile = ProfileModel.fromMap(data);
      } catch (e, st) {
        loadError = e;
        loadSt = st;
      }
    }

    // Attendre TOUJOURS la durée minimale du splash
    await minSplash;

    // Mettre à jour state une seule fois → déclenche la navigation
    if (loadError != null) {
      state = AsyncValue.error(loadError, loadSt!);
    } else {
      state = AsyncValue.data(loadedProfile); // null si pas connecté
    }
  }

  Future<void> _loadProfile(String userId, {bool setLoading = true}) async {
    try {
      if (setLoading) state = const AsyncValue.loading();
      final data = await _client
          .from(SupabaseConstants.profilesTable)
          .select()
          .eq('id', userId)
          .single();
      state = AsyncValue.data(ProfileModel.fromMap(data));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signIn(String email, String password) async {
    try {
      // On ne passe PAS par loading → évite le redirect vers splash.
      // Le LoginScreen gère son propre spinner local.
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user != null) {
        await _loadProfile(response.user!.id, setLoading: false);
      }
    } on AuthException catch (e, st) {
      state = AsyncValue.error(e, st);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Recharge le profil courant sans spinner (met à jour l'en-tête après édition).
  Future<void> reload() async {
    final user = _client.auth.currentUser;
    if (user != null) await _loadProfile(user.id, setLoading: false);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
    state = const AsyncValue.data(null);
  }

  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<ProfileModel?>>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AuthNotifier(client);
});
