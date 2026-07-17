import 'package:flutter/material.dart';

import 'admin_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/powersync/upload_outbox.dart';

const _kInfoBlue = Color(0xFF1D4ED8);
Color get _kInfoBg => kNavy.withValues(alpha: 0.10);
const _kInfoBorder = Color(0xFFBFDBFE);

/// Bandeau discret (personnel uniquement) : des fichiers attendent le réseau.
///
/// À la différence de [SyncFailureBanner], ce n'est PAS une alerte — rien n'est
/// perdu. C'est une promesse tenue : le message est déjà parti, la pièce jointe
/// suivra. Le bandeau disparaît de lui-même dès la file vidée (db.watch).
class PendingUploadsBanner extends ConsumerWidget {
  const PendingUploadsBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(pendingUploadsProvider).valueOrNull ?? 0;
    if (n == 0) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: _kInfoBg,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: _kInfoBg,
        border: const Border(bottom: BorderSide(color: _kInfoBorder)),
      ),
      child: Row(children: [
        const Icon(Icons.cloud_upload_outlined, size: 16, color: _kInfoBlue),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            n == 1
                ? '1 pièce jointe en attente de réseau — elle partira toute seule.'
                : '$n pièces jointes en attente de réseau — elles partiront toutes seules.',
            style: const TextStyle(
                fontSize: 12, color: _kInfoBlue, fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }
}
