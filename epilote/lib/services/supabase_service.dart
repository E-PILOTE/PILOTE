import 'package:supabase_flutter/supabase_flutter.dart';

/// Service centralisé Supabase — accès singleton
class SupabaseService {
  SupabaseService._();

  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;
  static SupabaseStorageClient get storage => client.storage;

  static User? get currentUser => auth.currentUser;
  static String? get currentUserId => currentUser?.id;

  static bool get isAuthenticated => currentUser != null;

  /// Exécute une requête avec gestion d'erreur uniformisée
  static Future<T> safeQuery<T>(Future<T> Function() query) async {
    try {
      return await query();
    } on PostgrestException catch (e) {
      throw AppException(
        message: _translatePostgrestError(e),
        code: e.code,
      );
    } on AuthException catch (e) {
      throw AppException(message: e.message, code: 'auth_error');
    } catch (e) {
      throw AppException(message: e.toString());
    }
  }

  static String _translatePostgrestError(PostgrestException e) {
    switch (e.code) {
      case '23505':
        return 'Cette entrée existe déjà';
      case '23503':
        return 'Référence invalide — entrée liée introuvable';
      case '42501':
        return 'Accès non autorisé';
      case 'PGRST116':
        return 'Aucune donnée trouvée';
      default:
        return e.message;
    }
  }
}

/// Exception métier E-PILOTE
class AppException implements Exception {

  const AppException({required this.message, this.code});
  final String message;
  final String? code;

  @override
  String toString() => 'AppException($code): $message';
}
