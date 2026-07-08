import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_constants.dart';
import '../../../data/models/profile_model.dart';
import '../../../services/powersync/powersync_service.dart' show db;

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

    // `currentUser` est restauré depuis la session locale persistée — AUCUN
    // appel réseau. C'est la clé de l'offline-first : on sait qui est connecté
    // sans internet.
    final user = _client.auth.currentUser;

    ProfileModel? loadedProfile;
    if (user != null) {
      // ── OFFLINE-FIRST : profil depuis PowerSync local d'ABORD ────────────
      // Le personnel scolaire a sa fiche `profiles` dans le SQLite local
      // (bucket `directory`). Une réouverture à froid sans réseau déverrouille
      // ainsi l'app sans jamais toucher Supabase.
      loadedProfile = await _loadLocalProfile(user.id);
      // ── Repli RÉSEAU : seulement si le local est vide ────────────────────
      // = super_admin / admin_groupe (jamais en PowerSync) OU tout premier
      // login avant la 1ʳᵉ synchro. Ne JAMAIS produire d'état d'erreur : hors
      // ligne sans profil local → on reste simplement déconnecté (→ login),
      // on n'éjecte pas un membre dont les données sont pourtant en local.
      loadedProfile ??= await _fetchRemoteProfile(user.id);
    }

    // Attendre TOUJOURS la durée minimale du splash
    await minSplash;
    state = AsyncValue.data(loadedProfile); // null si pas connecté
  }

  /// Lit le profil dans le SQLite local PowerSync. Hors-ligne par nature,
  /// instantané, ne throw jamais. `null` si absent (pas encore synchronisé
  /// ou rôle online-only super_admin/admin_groupe).
  Future<ProfileModel?> _loadLocalProfile(String userId) async {
    try {
      final row = await db.getOptional(
        'SELECT * FROM profiles WHERE id = ? LIMIT 1',
        [userId],
      );
      if (row == null) return null;
      return ProfileModel.fromMap(Map<String, dynamic>.from(row));
    } catch (_) {
      return null;
    }
  }

  /// Récupère le profil depuis Supabase (réseau requis). `null` si hors-ligne
  /// ou introuvable — ne throw jamais (l'offline ne doit pas éjecter).
  Future<ProfileModel?> _fetchRemoteProfile(String userId) async {
    try {
      final data = await _client
          .from(SupabaseConstants.profilesTable)
          .select()
          .eq('id', userId)
          .maybeSingle();
      return data == null ? null : ProfileModel.fromMap(data);
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadProfile(String userId, {bool setLoading = true}) async {
    if (setLoading) state = const AsyncValue.loading();
    // En ligne d'abord (données fraîches), repli local si le réseau manque.
    final remote = await _fetchRemoteProfile(userId);
    final profile = remote ?? await _loadLocalProfile(userId);
    if (profile != null) {
      state = AsyncValue.data(profile);
    } else {
      state = AsyncValue.error(
        const AuthException('Profil introuvable'),
        StackTrace.current,
      );
    }
  }

  /// Message affiché quand l'authentification échoue faute de réseau.
  /// La session déjà ouverte sur l'appareil, elle, reste utilisable hors-ligne
  /// (restaurée par `_init()` sans appel réseau).
  static const _offlineLoginMsg =
      'Pas de connexion internet. La toute première connexion sur cet '
      'appareil nécessite internet ; ensuite votre session reste active '
      'hors-ligne tant que vous ne vous déconnectez pas.';

  /// Message affiché quand le serveur d'authentification renvoie une 5xx.
  /// Ce N'EST PAS la connexion de l'utilisateur qui est en cause : réessayer
  /// suffit souvent ; sinon le compte a un souci côté serveur (à signaler).
  static const _serverErrorMsg =
      "Le serveur d'authentification a rencontré une erreur. Réessayez dans "
      'un instant ; si le problème persiste, contactez le support '
      "(ce n'est pas votre connexion internet).";

  /// Traduit l'exception d'authentification en objet d'erreur affichable.
  /// Sépare une vraie coupure réseau d'une 5xx serveur : les deux remontent
  /// en `AuthRetryableFetchException`, mais ne disent pas la même chose à
  /// l'utilisateur (cf. bug login « Database error querying schema » où une
  /// 500 serveur s'affichait à tort comme « Pas de connexion internet »).
  static Object _mapAuthError(Object e) {
    switch (classifyAuthFailure(e)) {
      case AuthFailureKind.network:
        return const AuthException(_offlineLoginMsg);
      case AuthFailureKind.server:
        return const AuthException(_serverErrorMsg);
      case AuthFailureKind.other:
        return e; // ex. « Invalid login credentials » — message d'origine
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
      state = AsyncValue.error(_mapAuthError(e), st);
    } catch (e, st) {
      state = AsyncValue.error(_mapAuthError(e), st);
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

// ─── Classification des échecs d'authentification ───────────────────────────

/// Nature d'un échec d'authentification, pour choisir le message utilisateur.
enum AuthFailureKind {
  /// Coupure réseau / hôte injoignable : la 1ʳᵉ connexion exige internet.
  network,

  /// Le serveur d'auth a répondu 5xx : ce n'est PAS la connexion de l'usager.
  server,

  /// Autre (ex. identifiants invalides 4xx) : afficher le message d'origine.
  other,
}

/// Classe une exception d'authentification.
///
/// gotrue lève `AuthRetryableFetchException` dans DEUX cas distincts
/// (`gotrue/src/fetch.dart`) : échec transport (`statusCode` null) OU réponse
/// HTTP ≥ 500 (`statusCode` = "500"…). On les sépare pour ne pas afficher
/// « Pas de connexion internet » sur une erreur serveur — bug historique où
/// des comptes créés par RPC renvoyaient 500 « Database error querying schema »
/// (colonnes token NULL dans `auth.users`).
AuthFailureKind classifyAuthFailure(Object e) {
  if (e is AuthRetryableFetchException) {
    final code = int.tryParse(e.statusCode ?? '');
    return (code != null && code >= 500)
        ? AuthFailureKind.server
        : AuthFailureKind.network;
  }
  final s = e.toString();
  final isTransport = s.contains('SocketException') ||
      s.contains('ClientException') ||
      s.contains('Failed host lookup') ||
      s.contains('Connection refused') ||
      s.contains('Network is unreachable') ||
      s.contains('Connection timed out');
  return isTransport ? AuthFailureKind.network : AuthFailureKind.other;
}
