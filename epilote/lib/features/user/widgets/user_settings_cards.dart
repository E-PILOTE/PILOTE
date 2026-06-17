import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/password_change_dialog.dart';
import '../../../features/navigation/providers/module_navigation_provider.dart';
import '../../../features/structure/providers/academic_year_context.dart';
import '../../../features/structure/providers/academic_year_provider.dart';
import '../../../services/powersync/powersync_service.dart';
import 'staff_account_widgets.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Cartes de la page « Paramètres » du personnel scolaire.
//  Données 100 % offline-first (PowerSync) — aucun appel Supabase direct.
// ════════════════════════════════════════════════════════════════════════════

/// Nombre d'écritures locales en attente d'envoi au serveur (file PowerSync).
/// Réévalué à chaque changement de statut de synchro.
final uploadQueueCountProvider = FutureProvider.autoDispose<int>((ref) async {
  ref.watch(syncStatusProvider); // recalcul quand la synchro évolue
  try {
    final stats = await db.getUploadQueueStats();
    return stats.count;
  } catch (_) {
    return 0;
  }
});

// ─── Tuile de réglage ─────────────────────────────────────────────────────────
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: kTextPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 12, color: kTextMuted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

// ─── Carte Sécurité (dernière connexion + mot de passe) ───────────────────────
class StaffSecurityCard extends StatelessWidget {
  const StaffSecurityCard({super.key, required this.lastLogin});
  final DateTime? lastLogin;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminDetailCard([
            AdminDetailRow(Icons.history_rounded, 'Dernière connexion',
                staffFmtDateTime(lastLogin), last: true),
          ]),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const PasswordChangeDialog(),
            ),
            icon: const Icon(Icons.lock_reset_rounded, size: 17),
            label: const Text('Changer le mot de passe'),
            style: OutlinedButton.styleFrom(
              foregroundColor: kNavy,
              side: const BorderSide(color: kBorder),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Le changement de mot de passe nécessite une connexion internet.',
            style: TextStyle(fontSize: 11.5, color: kTextMuted),
          ),
        ],
      ),
    );
  }
}

// ─── Carte Établissement ───────────────────────────────────────────────────────
class StaffSchoolCard extends ConsumerWidget {
  const StaffSchoolCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final school = ref.watch(currentSchoolProvider).valueOrNull;
    final year = ref.watch(activeYearProvider);
    final status = ref.watch(activeYearStatusProvider);
    final schoolName = school?['name'] as String?;

    if (schoolName == null && year == null) {
      return const AdminCard(
        child: AdminEmptyState(
          icon: Icons.cloud_sync_outlined,
          title: 'En attente de synchronisation',
          message:
              'Les informations de votre établissement apparaîtront ici dès '
              'la première synchronisation.',
        ),
      );
    }

    final (statusLabel, statusColor) = _yearStatusChip(status);

    return AdminCard(
      child: AdminDetailCard([
        AdminDetailRow(Icons.business_rounded, 'École', schoolName ?? '—'),
        AdminDetailRow(
            Icons.event_note_rounded, 'Année active', year?.label ?? '—'),
        AdminDetailRow(
          Icons.flag_circle_rounded,
          'Statut',
          statusLabel,
          valueColor: statusColor,
          last: true,
        ),
      ]),
    );
  }
}

// ─── Statut année → libellé + couleur ──────────────────────────────────────────
(String, Color) _yearStatusChip(YearStatus s) => switch (s) {
      YearStatus.current => ('Année courante', kGreen),
      YearStatus.upcoming => ('À venir', kNavy),
      YearStatus.archived => ('Archivée', kAccent),
      YearStatus.locked => ('Verrouillée', kTextMuted),
      YearStatus.none => ('Non définie', kTextMuted),
    };

// ─── Carte Apparence ───────────────────────────────────────────────────────────
class StaffAppearanceCard extends ConsumerWidget {
  const StaffAppearanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    return AdminCard(
      padding: EdgeInsets.zero,
      child: SettingsTile(
        icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
        color: kAccent,
        title: 'Thème sombre',
        subtitle: isDark ? 'Activé' : 'Désactivé',
        trailing: Switch(
          value: isDark,
          activeThumbColor: kGreen,
          onChanged: (v) => ref.read(themeModeProvider.notifier).state =
              v ? ThemeMode.dark : ThemeMode.light,
        ),
        onTap: () => ref.read(themeModeProvider.notifier).state =
            isDark ? ThemeMode.light : ThemeMode.dark,
      ),
    );
  }
}

// ─── Carte Synchronisation ─────────────────────────────────────────────────────
class StaffSyncCard extends ConsumerWidget {
  const StaffSyncCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncUi = ref.watch(syncIndicatorProvider);
    final lastSynced = ref.watch(lastSyncedAtProvider);
    final pending = ref.watch(uploadQueueCountProvider).valueOrNull ?? 0;
    final connected = syncUi == SyncUiState.synced;

    final (stateLabel, stateColor, stateIcon) = syncUiChip(syncUi);

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: stateColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(stateIcon, color: stateColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(stateLabel,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: stateColor)),
            ),
          ]),
          const SizedBox(height: 14),
          AdminDetailCard([
            AdminDetailRow(Icons.history_rounded, 'Dernière synchronisation',
                staffFmtDateTime(lastSynced)),
            AdminDetailRow(
              Icons.cloud_upload_outlined,
              'Modifications en attente',
              pending == 0 ? 'Aucune' : '$pending à envoyer',
              valueColor: pending == 0 ? kGreen : kAccent,
              last: true,
            ),
          ]),
          const SizedBox(height: 12),
          Text(
            connected
                ? 'Vos données sont à jour avec le serveur. Les modifications '
                    'sont envoyées automatiquement.'
                : 'Vous travaillez hors ligne. Vos modifications seront '
                    'envoyées dès le retour de la connexion.',
            style: const TextStyle(fontSize: 12, color: kTextMuted, height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// État de synchro → (libellé, couleur, icône) — partagé carte + en-tête.
(String, Color, IconData) syncUiChip(SyncUiState s) => switch (s) {
      SyncUiState.syncing =>
        ('Synchronisation en cours…', kNavy, Icons.sync_rounded),
      SyncUiState.synced =>
        ('Données à jour', kGreen, Icons.cloud_done_rounded),
      SyncUiState.offline => ('Hors ligne', kAccent, Icons.cloud_off_rounded),
    };
