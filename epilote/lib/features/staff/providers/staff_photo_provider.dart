import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../services/powersync/powersync_service.dart';

const _uuid = Uuid();

// ════════════════════════════════════════════════════════════════════════════
//  LA PHOTO D'UN AGENT SE DEMANDE, ELLE NE S'ÉCRIT PAS.
//
//  ── POURQUOI UNE DEMANDE ───────────────────────────────────────────────────
//  `profiles_update` n'autorise que super_admin, admin_groupe du groupe, ou
//  l'agent lui-même. Un DIRECTEUR qui corrige la fiche d'un autre agent n'entre
//  dans aucune des trois : un UPDATE d'`avatar_url` poussé par PowerSync
//  reviendrait en `42501`, code fatal pour le connecteur, et emporterait le LOT
//  ENTIER — les notes et les paiements écrits dans la même fenêtre.
//
//  L'école dépose donc une DEMANDE dans `staff_photo_requests` (migration
//  0113), table qui lui appartient et qui se synchronise comme le reste. Le
//  serveur l'applique par trigger, avec l'autorité exacte de
//  `corriger_fiche_agent` : aucun droit n'est relâché, seul le MOMENT change.
//
//  ── CE QUE L'ÉCRAN DOIT EN LIRE ────────────────────────────────────────────
//  Hors ligne, `profiles.avatar_url` local ne bouge pas — c'est le serveur qui
//  l'écrit. L'agent qui vient de prendre la photo ne la verrait donc pas, et
//  conclurait que son geste a échoué. D'où [demandePhotoAgentProvider] : tant
//  qu'une demande n'est pas appliquée, c'est ELLE qui fait foi à l'écran.
// ════════════════════════════════════════════════════════════════════════════

/// Ce que l'écran sait d'une demande de photo pas encore aboutie.
class DemandePhotoAgent {
  const DemandePhotoAgent({this.urlEnAttente, this.refus, this.effacer = false});

  /// Adresse visée, tant que le serveur n'a pas appliqué. `null` si rien
  /// n'attend, ou si la demande était un retrait.
  final String? urlEnAttente;

  /// Motif renvoyé par le serveur quand il a REFUSÉ d'appliquer.
  ///
  /// Le trigger ne lève jamais — une exception ferait abandonner le lot
  /// PowerSync entier. Le refus redescend donc ici, et c'est le seul endroit
  /// où l'agent peut apprendre que sa demande n'a pas abouti.
  final String? refus;

  /// La demande en attente est un RETRAIT de photo.
  final bool effacer;

  bool get enAttente => urlEnAttente != null || (effacer && refus == null);
}

/// Les demandes de photo NON ABOUTIES, par agent.
///
/// ── POURQUOI UNE CARTE, ET PAS UNE FAMILLE DE REQUÊTES ─────────────────────
/// La liste du personnel affiche deux cents pastilles ; interroger la table par
/// pastille ferait deux cents requêtes, et autant à chaque reconstruction.
/// Les demandes en attente se comptent au plus sur les doigts d'une main — on
/// les lit donc toutes, une fois.
///
/// Une demande APPLIQUÉE n'a plus rien à dire : `profiles.avatar_url` porte
/// alors la vérité, et c'est lui que l'écran doit lire. Elle est donc écartée.
final demandesPhotoAgentProvider =
    StreamProvider.autoDispose<Map<String, DemandePhotoAgent>>((ref) {
  return db
      .watch(
        '''
        SELECT profile_id, avatar_url, effacer, refus, created_at
        FROM   staff_photo_requests
        WHERE  applied_at IS NULL OR applied_at = ''
        ORDER  BY created_at DESC
        ''',
      )
      .map((rows) {
        final out = <String, DemandePhotoAgent>{};
        for (final r in rows) {
          final id = r['profile_id'] as String?;
          if (id == null || out.containsKey(id)) continue; // la plus récente
          final refus = (r['refus'] as String?)?.trim();
          final effacer = r['effacer'] == 1 || r['effacer'] == true;
          final rejetee = refus != null && refus.isNotEmpty;
          out[id] = DemandePhotoAgent(
            urlEnAttente:
                (!rejetee && !effacer) ? r['avatar_url'] as String? : null,
            refus: rejetee ? refus : null,
            effacer: effacer,
          );
        }
        return out;
      });
});

/// La demande non aboutie d'UN agent — dérivée de la carte, sans requête.
final demandePhotoAgentProvider =
    Provider.autoDispose.family<DemandePhotoAgent, String>((ref, profileId) {
  final toutes = ref.watch(demandesPhotoAgentProvider).valueOrNull;
  return toutes?[profileId] ?? const DemandePhotoAgent();
});

/// L'adresse à AFFICHER pour un agent : la demande en attente si elle existe,
/// la fiche sinon.
///
/// Hors ligne, `profiles.avatar_url` ne bouge pas — c'est le serveur qui
/// l'écrit. Sans ce détour, le chef qui vient de choisir une photo verrait
/// encore l'ancienne, et recommencerait.
String? photoAffichee(WidgetRef ref, String profileId, String? avatarUrl) {
  final d = ref.watch(demandePhotoAgentProvider(profileId));
  if (d.effacer && d.refus == null) return null;
  return d.urlEnAttente ?? avatarUrl;
}

/// Dépose la demande. Offline-first : une simple écriture locale, que
/// PowerSync remontera.
///
/// ⚠️ [requestedBy] n'est qu'une trace. L'AUTORITÉ se lit côté serveur dans
/// `auth.uid()` au moment où la demande arrive — un client ne se déclare pas
/// lui-même habilité.
Future<void> deposerDemandePhotoAgent({
  required String groupId,
  required String schoolId,
  required String profileId,
  required String? avatarUrl,
  required String requestedBy,
  bool effacer = false,
}) async {
  final now = DateTime.now().toIso8601String();
  await db.execute(
    '''
    INSERT INTO staff_photo_requests
      (id, group_id, school_id, profile_id, avatar_url, effacer,
       requested_by, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''',
    [
      _uuid.v4(), groupId, schoolId, profileId,
      effacer ? null : avatarUrl, effacer ? 1 : 0,
      requestedBy, now, now,
    ],
  );
}
