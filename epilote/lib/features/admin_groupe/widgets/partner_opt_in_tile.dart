import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart' show AdminCard, kNavy, kTextMuted, kTextPrimary, kGreen;
import '../../auth/providers/auth_provider.dart';

/// Opt-in du groupe pour l'affichage des partenaires sur ses postes (Phase 3b).
/// Écrit `school_groups.partner_display_enabled` (online, admin_groupe).
final groupPartnerDisplayProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null) return false;
  final g = await client
      .from('school_groups')
      .select('partner_display_enabled')
      .eq('id', groupId)
      .maybeSingle();
  return (g?['partner_display_enabled'] as bool?) ?? false;
});

Future<void> setGroupPartnerDisplay(WidgetRef ref, bool value) async {
  final client = ref.read(supabaseClientProvider);
  final groupId = ref.read(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null) return;
  await client.from('school_groups').update({
    'partner_display_enabled': value,
    'updated_at': DateTime.now().toIso8601String(),
  }).eq('id', groupId);
  ref.invalidate(groupPartnerDisplayProvider);
}

/// Interrupteur « Afficher les partenaires E-PILOTE sur les postes ».
class PartnerOptInTile extends ConsumerWidget {
  const PartnerOptInTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(groupPartnerDisplayProvider);
    final enabled = async.valueOrNull ?? false;
    return AdminCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: kNavy.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.handshake_rounded, color: kNavy, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Partenaires sur les postes',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: kTextPrimary)),
                const SizedBox(height: 2),
                Text(
                  'Autorise l’affichage d’encarts partenaires institutionnels, '
                  'discrets et étiquetés, sur la vitrine de vos postes. '
                  'Désactivable à tout moment.',
                  style: TextStyle(
                      fontSize: 12,
                      color: kTextMuted,
                      height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          async.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Switch(
                  value: enabled,
                  activeThumbColor: kGreen,
                  onChanged: (v) => setGroupPartnerDisplay(ref, v),
                ),
        ],
      ),
    );
  }
}
