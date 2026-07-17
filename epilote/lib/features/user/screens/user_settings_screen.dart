import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/active_agent_provider.dart';
import '../../../core/widgets/logout_guard.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/routes.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/staff_ui.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/auth/screens/widgets/device_mode_setting.dart';
import '../../../features/navigation/providers/module_navigation_provider.dart';
import '../../../features/structure/providers/academic_year_provider.dart';
import '../providers/user_profile_provider.dart';
import '../widgets/staff_account_widgets.dart';
import '../widgets/user_settings_cards.dart';

/// Page « Paramètres » du personnel scolaire — préférences du compte,
/// sécurité, établissement, apparence et synchronisation.
/// Données 100 % offline-first (ligne `profiles` locale PowerSync).
class UserSettingsScreen extends ConsumerWidget {
  const UserSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AppShell(title: 'Paramètres', child: _Body());
  }
}

class _Body extends ConsumerWidget {
  const _Body();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authNotifierProvider);
    if (authAsync.isLoading) {
      return const FormSkeleton(sections: 4, maxWidth: double.infinity);
    }

    // Ligne locale (PowerSync) prioritaire — last_login & co toujours à jour.
    final profile =
        ref.watch(myProfileRowProvider).valueOrNull ?? authAsync.valueOrNull;
    final email = ref.watch(currentUserProvider)?.email ?? '—';
    final schoolName =
        ref.watch(currentSchoolProvider).valueOrNull?['name'] as String?;
    final syncUi = ref.watch(syncIndicatorProvider);
    final (syncLabel, _, syncIcon) = syncUiChip(syncUi);
    final wide = MediaQuery.sizeOf(context).width >= 1100;

    final left = <Widget>[
      // ── Compte ───────────────────────────────────────────────────────────
      StaffSection(
        title: 'Compte',
        icon: Icons.person_rounded,
        child: AdminCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            SettingsTile(
              icon: Icons.account_circle_outlined,
              color: kNavy,
              title: 'Mon profil',
              subtitle: 'Voir et modifier mes informations',
              trailing:
                  Icon(Icons.chevron_right_rounded, color: kTextMuted),
              onTap: () => context.go(Routes.userProfil),
            ),
            Divider(height: 1, color: kBorder),
            SettingsTile(
              icon: Icons.email_outlined,
              color: kGreen,
              title: 'Adresse e-mail',
              subtitle: email,
            ),
          ]),
        ),
      ),
      const SizedBox(height: 22),

      // ── Sécurité ─────────────────────────────────────────────────────────
      StaffSection(
        title: 'Sécurité',
        icon: Icons.lock_outline_rounded,
        child: Column(
          children: [
            StaffSecurityCard(lastLogin: profile?.lastLogin),
            const SizedBox(height: 12),
            const DeviceModeTile(),
            // Verrouillage auto : pertinent uniquement sur un poste PARTAGÉ.
            if (ref.watch(deviceModeProvider).mode == DeviceMode.shared) ...[
              const SizedBox(height: 12),
              const AutoLockTile(),
            ],
          ],
        ),
      ),
      const SizedBox(height: 22),

      // ── Établissement ────────────────────────────────────────────────────
      const StaffSection(
        title: 'Établissement',
        icon: Icons.business_rounded,
        child: StaffSchoolCard(),
      ),
    ];

    final right = <Widget>[
      // ── Synchronisation ──────────────────────────────────────────────────
      const StaffSection(
        title: 'Synchronisation',
        icon: Icons.sync_rounded,
        child: StaffSyncCard(),
      ),
      const SizedBox(height: 22),

      // ── Apparence ────────────────────────────────────────────────────────
      const StaffSection(
        title: 'Apparence',
        icon: Icons.palette_outlined,
        child: StaffAppearanceCard(),
      ),
      const SizedBox(height: 22),

      // ── Notifications ────────────────────────────────────────────────────
      StaffSection(
        title: 'Notifications',
        icon: Icons.notifications_outlined,
        child: AdminCard(
          padding: EdgeInsets.zero,
          child: SettingsTile(
            icon: Icons.notifications_active_outlined,
            color: kAccent,
            title: 'Centre de notifications',
            subtitle: 'Annonces, messages et alertes de votre école',
            trailing:
                Icon(Icons.chevron_right_rounded, color: kTextMuted),
            onTap: () => Scaffold.of(context).openEndDrawer(),
          ),
        ),
      ),
      const SizedBox(height: 22),

      // ── À propos ─────────────────────────────────────────────────────────
      StaffSection(
        title: 'À propos',
        icon: Icons.info_outline,
        child: AdminCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            SettingsTile(
              icon: Icons.flag_rounded,
              color: kNavy,
              title: 'E-PILOTE CONGO',
              subtitle: 'Version 3.0.2',
            ),
            Divider(height: 1, color: kBorder),
            SettingsTile(
              icon: Icons.school_rounded,
              color: kGreen,
              title: 'Gestion scolaire offline-first',
              subtitle: 'MEPSA · METP — République du Congo',
            ),
          ]),
        ),
      ),
    ];

    // Pleine largeur — même gabarit que les pages admin_groupe.
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        StaffPageHeader(
          icon: Icons.settings_rounded,
          title: 'Paramètres',
          subtitle: 'Préférences du compte, sécurité et synchronisation',
          badges: [
            if (profile != null)
              HeaderChip(
                  label: staffRoleLabel(profile.role),
                  icon: Icons.shield_rounded),
            if (schoolName != null)
              HeaderChip(label: schoolName, icon: Icons.business_rounded),
            HeaderChip(label: syncLabel, icon: syncIcon),
          ],
        ),
        const SizedBox(height: 24),
        if (wide)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: left)),
            const SizedBox(width: 22),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: right)),
          ])
        else ...[
          ...left,
          const SizedBox(height: 22),
          ...right,
        ],
        const SizedBox(height: 24),

        // ── Déconnecter le poste ────────────────────────────────────────────
        // Réservé à la direction sur un poste partagé : l'action prive TOUTE
        // l'école de son mode hors-ligne (cf. `canUnenrollDevice`).
        if (canUnenrollDevice(
          role: ref.watch(authNotifierProvider).valueOrNull?.role,
          mode: ref.watch(deviceModeProvider).mode,
        )) ...[
          OutlinedButton.icon(
            onPressed: () => _confirmSignOut(context, ref),
            icon: const Icon(Icons.link_off_rounded, size: 18),
            label: const Text('Déconnecter ce poste…'),
            style: OutlinedButton.styleFrom(
              foregroundColor: kRed,
              side: BorderSide(color: kRed.withValues(alpha: 0.3)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    // `guardedSignOut` porte déjà l'avertissement complet (offline + travail en
    // attente) — un second dialogue générique par-dessus ne ferait que du bruit.
    await guardedSignOut(context, ref, sharedDevice: true);
  }
}
