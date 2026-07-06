import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/admin_ui.dart'
    show AdminCard, kNavy, kTextMuted, kTextPrimary;
import '../../../user/widgets/user_settings_cards.dart' show SettingsTile;
import '../../providers/active_agent_provider.dart';

/// Réglage « Type de poste » (Paramètres › Sécurité) : bascule entre poste
/// PARTAGÉ (verrou + code PIN par agent) et poste PERSONNEL (aucun verrou).
/// Persisté par appareil via [deviceModeProvider].
class DeviceModeTile extends ConsumerWidget {
  const DeviceModeTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(deviceModeProvider).mode;
    final (label, sub, icon) = switch (mode) {
      DeviceMode.shared => (
          'Poste partagé',
          'Verrou + code PIN par agent',
          Icons.groups_rounded
        ),
      DeviceMode.personal => (
          'Poste personnel',
          'Aucun verrou — votre compte directement',
          Icons.person_rounded
        ),
      null => ('Non défini', 'Choisir le type de poste', Icons.devices_rounded),
    };

    return AdminCard(
      padding: EdgeInsets.zero,
      child: SettingsTile(
        icon: icon,
        color: kNavy,
        title: 'Type de poste',
        subtitle: '$label · $sub',
        trailing: const Icon(Icons.chevron_right_rounded, color: kTextMuted),
        onTap: () => _pick(context, ref, mode),
      ),
    );
  }

  Future<void> _pick(
      BuildContext context, WidgetRef ref, DeviceMode? current) async {
    final chosen = await showDialog<DeviceMode>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Type de poste'),
        children: [
          _option(context, DeviceMode.shared, current, Icons.groups_rounded,
              'Poste partagé',
              'Plusieurs agents sur ce même ordinateur. Chacun ouvre sa '
              'session avec un code PIN.'),
          _option(context, DeviceMode.personal, current, Icons.person_rounded,
              'Poste personnel',
              'Un seul agent. Aucun verrou : vous travaillez directement '
              'avec votre compte.'),
        ],
      ),
    );
    if (chosen != null && chosen != current) {
      await ref.read(deviceModeProvider.notifier).set(chosen);
    }
  }

  Widget _option(BuildContext context, DeviceMode mode, DeviceMode? current,
          IconData icon, String title, String desc) =>
      SimpleDialogOption(
        onPressed: () => Navigator.pop(context, mode),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: kNavy, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: kTextPrimary)),
                        if (mode == current) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.check_circle_rounded,
                              color: kNavy, size: 16),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(desc,
                        style: const TextStyle(
                            fontSize: 12, color: kTextMuted, height: 1.35)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
