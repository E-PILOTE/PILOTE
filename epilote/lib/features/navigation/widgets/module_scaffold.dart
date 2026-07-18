import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_shell.dart';
import '../../../licensing/domain/entitlement.dart';
import '../providers/permissions_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Kit de page module — applique le verrou 3 (profil) côté écran :
//  • ModuleScaffold : refuse l'accès si le membre n'a pas `can_read`.
//  • PermissionGate : masque un bouton/section selon une action (create, …).
//  • runModuleWrite  : exécute une mutation locale en remontant les erreurs.
// ════════════════════════════════════════════════════════════════════════════

Color get _kNavy => kNavy;
Color get _kGreen => kGreen;
const _kRed    = Color(0xFFEF4444);
Color get _kMuted => kTextMuted;

/// Enveloppe un écran de module : titre + AppShell + garde `can_read`.
/// Tant que les permissions chargent → spinner ; non accordé → page « Accès
/// non autorisé » (ou « aucun profil assigné » si le membre n'a aucun droit).
class ModuleScaffold extends ConsumerWidget {
  const ModuleScaffold({
    super.key,
    required this.slug,
    required this.title,
    required this.child,
    this.actions,
    this.onBack,
  });

  final String slug;
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permsAsync = ref.watch(myPermissionsProvider);
    return AppShell(
      title: title,
      actions: actions,
      onBack: onBack,
      child: permsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Denied(
          icon: Icons.error_outline_rounded,
          title: 'Erreur de permissions',
          message: '$e',
        ),
        data: (perms) {
          final p = perms[slug];
          if (p == null || !p.canRead) {
            return _Denied(
              icon: perms.isEmpty ? Icons.badge_outlined : Icons.lock_outline_rounded,
              title: perms.isEmpty ? 'Aucun profil d\'accès assigné' : 'Accès non autorisé',
              message: perms.isEmpty
                  ? 'Contactez l\'administrateur de votre groupe pour qu\'il vous attribue un profil d\'accès.'
                  : 'Votre profil d\'accès ne vous autorise pas à consulter ce module.',
            );
          }
          return child;
        },
      ),
    );
  }
}

class _Denied extends StatelessWidget {
  const _Denied({required this.icon, required this.title, required this.message});
  final IconData icon;
  final String title, message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: _kMuted),
              const SizedBox(height: 16),
              Text(title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700, color: _kNavy)),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(message,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: _kMuted, height: 1.5)),
              ),
            ],
          ),
        ),
      );
}

/// Affiche [child] seulement si le membre possède l'[action] sur le module
/// [slug] (verrou 3 boutons). Sinon affiche [replacement] (rien par défaut).
/// Actions : read, create, update, delete, export, import, validate, approve,
/// manage, write.
class PermissionGate extends ConsumerWidget {
  const PermissionGate({
    super.key,
    required this.slug,
    required this.action,
    required this.child,
    this.replacement = const SizedBox.shrink(),
  });

  final String slug;
  final String action;
  final Widget child;
  final Widget replacement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ok = ref.watch(canProvider((slug: slug, action: action)));
    return ok ? child : replacement;
  }
}

/// Exécute une mutation locale ([op]) en capturant les erreurs immédiates
/// (contraintes locales, exceptions) et en les remontant à l'utilisateur.
///
/// ⚠️ Les rejets à la SYNCHRONISATION (quota 23514, unique 23505, RLS 42501)
/// sont silencieux côté connecteur — la parade est la pré-validation AVANT
/// l'écriture dans chaque module (vérifier quota/unicité localement).
Future<bool> runModuleWrite(
  BuildContext context,
  Future<void> Function() op, {
  String? success,
}) async {
  // Verrou LICENCE UNIFORME (staff) : en lecture seule (licence expirée au-delà
  // de la grâce, ou fenêtre de confiance dépassée), on refuse l'écriture LOCALE
  // avant exécution. Fail-soft (aucune licence ⇒ jamais bloquant). Ne touche
  // JAMAIS la synchro (C4) : les données déjà créées continuent de remonter.
  if (LicenseEnforcement.writeBlockedNow) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        backgroundColor: _kRed,
        content: Text('Abonnement expiré — application en lecture seule. '
            'Modification impossible pour le moment.'),
      ));
    }
    return false;
  }
  try {
    await op();
    if (context.mounted && success != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success), backgroundColor: _kGreen));
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: _kRed));
    }
    return false;
  }
}
