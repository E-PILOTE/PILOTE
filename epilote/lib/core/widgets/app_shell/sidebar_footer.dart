import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logout_guard.dart';

import '../admin_ui.dart' show kGreen, kAccent;
import '../../constants/app_constants.dart';
import '../../../data/models/profile_model.dart';
import '../../../features/auth/providers/active_agent_provider.dart';
import '../../../features/navigation/providers/module_navigation_provider.dart'
    show syncIndicatorProvider;
import '../../../services/powersync/powersync_service.dart' show SyncUiState;

/// Pied de la sidebar : statut de synchro (personnel offline) + déconnexion.
class SidebarFooter extends ConsumerWidget {
  const SidebarFooter({
    super.key,
    required this.expanded,
    required this.profile,
  });
  final bool expanded;
  final ProfileModel? profile;

  bool get _isStaff =>
      profile != null &&
      profile!.role != AppConstants.roleSuperAdmin &&
      profile!.role != AppConstants.roleAdminGroupe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Offline-first : « synchronisé » dès qu'une synchro a réussi, pas seulement
    // quand la connexion live est active.
    final isSynced =
        ref.watch(syncIndicatorProvider) == SyncUiState.synced;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 14),
      decoration: BoxDecoration(
        border:
            Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isStaff) _SyncStatus(expanded: expanded, isSynced: isSynced),
          // Poste scolaire partagé : l'action quotidienne est VERROUILLER, pas
          // déconnecter. Déconnecter l'appareil lui retire son droit de
          // travailler hors-ligne — c'est un acte d'administration, relégué au
          // menu compte et à l'écran-verrou, jamais à portée de clic ici.
          if (agentLockApplies(profile?.role))
            _LockButton(expanded: expanded, ref: ref)
          else
            _LogoutButton(expanded: expanded, ref: ref),
        ],
      ),
    );
  }
}

/// Verrouille le poste (retour à l'écran-verrou). Local, hors-ligne, sans risque.
class _LockButton extends StatelessWidget {
  const _LockButton({required this.expanded, required this.ref});
  final bool expanded;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: expanded ? '' : 'Verrouiller le poste',
      child: InkWell(
        onTap: () => lockDevice(ref),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding:
              EdgeInsets.symmetric(horizontal: expanded ? 12 : 8, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: Row(
            mainAxisAlignment:
                expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline_rounded,
                  size: 15, color: Colors.white.withValues(alpha: 0.85)),
              if (expanded) ...[
                const SizedBox(width: 9),
                Text(
                  'Verrouiller',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncStatus extends StatelessWidget {
  const _SyncStatus({required this.expanded, required this.isSynced});
  final bool expanded;
  final bool isSynced;

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: isSynced ? kGreen : kAccent,
        shape: BoxShape.circle,
      ),
    );

    if (!expanded) {
      return Padding(padding: const EdgeInsets.only(bottom: 8), child: dot);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          dot,
          const SizedBox(width: 8),
          Text(
            isSynced ? 'Synchronisé' : 'Hors ligne',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.expanded, required this.ref});
  final bool expanded;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    const danger = Color(0xFFFF6B6B);
    return Tooltip(
      message: expanded ? '' : 'Déconnexion',
      child: InkWell(
        // super_admin / admin_groupe : online par conception, rien à protéger.
        onTap: () => guardedSignOut(context, ref, sharedDevice: false),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: expanded ? 12 : 8, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.withValues(alpha: 0.22)),
          ),
          child: Row(
            mainAxisAlignment:
                expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              const Icon(Icons.logout_rounded, size: 15, color: danger),
              if (expanded) ...[
                const SizedBox(width: 9),
                const Text(
                  'Déconnexion',
                  style: TextStyle(
                    color: danger,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
