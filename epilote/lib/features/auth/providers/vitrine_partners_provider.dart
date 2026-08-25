import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/booleen_offline.dart';
import '../../../services/powersync/powersync_service.dart';
import 'auth_provider.dart';
import 'vitrine_messages_provider.dart' show isMessageLive;

/// Un partenaire est-il « vivant » maintenant ? Actif + dans sa fenêtre de dates.
/// Même logique que les messages de service → délègue à [isMessageLive].
bool isPartnerLive(DateTime now, DateTime? starts, DateTime? ends, bool active) =>
    isMessageLive(now, starts, ends, active);

/// Faut-il afficher la bande partenaires ? Uniquement si le groupe a opté in ET
/// qu'il existe au moins un partenaire vivant. Fonction pure, testable.
bool showPartnerStrip(bool groupOptedIn, bool hasLivePartners) =>
    groupOptedIn && hasLivePartners;

/// Un partenaire prêt pour l'affichage sur la vitrine.
class PartnerVitrineItem {
  const PartnerVitrineItem({required this.name, this.logoUrl});
  final String name;
  final String? logoUrl;
}

DateTime? _parse(String? s) => s == null ? null : DateTime.tryParse(s);

/// Partenaires à afficher (offline, `db.watch`), filtrés actifs + fenêtre,
/// triés par `sort_order`, plafonnés à 3.
final vitrinePartnersProvider =
    StreamProvider.autoDispose<List<PartnerVitrineItem>>((ref) {
  return db
      .watch(
        'SELECT name, logo_url, is_active, sort_order, starts_at, ends_at '
        'FROM platform_partners ORDER BY sort_order',
      )
      .map((rows) {
    final now = DateTime.now();
    final live = <PartnerVitrineItem>[];
    for (final r in rows) {
      // `?? 0` faisait disparaître de l'écran de connexion un partenaire dont
      // la colonne n'était pas renseignée. `is_active` est par défaut VRAI.
      final active = actifOffline(r['is_active']);
      final name = (r['name'] as String? ?? '').trim();
      if (name.isEmpty) continue;
      if (isPartnerLive(now, _parse(r['starts_at'] as String?),
          _parse(r['ends_at'] as String?), active)) {
        live.add(PartnerVitrineItem(
            name: name, logoUrl: r['logo_url'] as String?));
      }
    }
    return live.take(3).toList();
  });
});

/// Le groupe de l'appareil autorise-t-il l'affichage des partenaires ? (offline)
final groupPartnerOptInProvider = StreamProvider.autoDispose<bool>((ref) {
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null || groupId.isEmpty) return Stream.value(false);
  return db
      .watch(
        'SELECT partner_display_enabled FROM school_groups WHERE id = ? LIMIT 1',
        parameters: [groupId],
      )
      .map((rows) =>
          rows.isNotEmpty && (rows.first['partner_display_enabled'] as int? ?? 0) == 1);
});
