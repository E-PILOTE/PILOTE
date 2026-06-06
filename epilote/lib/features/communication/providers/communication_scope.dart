import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../features/auth/providers/auth_provider.dart';

/// Périmètre d'une fonctionnalité de communication (tissu natif partagé).
/// Déduit du rôle : super_admin = plateforme entière, admin_groupe = son groupe,
/// personnel école = son école (offline). Voir `communicationContextProvider`.
enum CommScope { platform, group, school }

class CommContext {
  const CommContext(this.scope, {this.groupId, this.schoolId});

  final CommScope scope;
  final String?   groupId;
  final String?   schoolId;

  bool get isPlatform => scope == CommScope.platform;
  bool get isGroup    => scope == CommScope.group;
  bool get isSchool   => scope == CommScope.school;
}

/// Contexte de communication de l'utilisateur connecté.
/// Sert à scoper les providers/écrans partagés (annonces, messagerie,
/// notifications, événements) sans dupliquer le code par espace.
final communicationContextProvider = Provider.autoDispose<CommContext>((ref) {
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  switch (profile?.role) {
    case AppConstants.roleSuperAdmin:
      return const CommContext(CommScope.platform);
    case AppConstants.roleAdminGroupe:
      return CommContext(CommScope.group, groupId: profile?.groupId);
    default:
      return CommContext(CommScope.school, schoolId: profile?.schoolId);
  }
});
