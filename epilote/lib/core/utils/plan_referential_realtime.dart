import 'package:realtime_client/realtime_client.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE RÉFÉRENTIEL DE FACTURATION DOIT CIRCULER
//
//  ── CE QUI S'EST PASSÉ ─────────────────────────────────────────────────────
//  Le prix du plan `institutionnel` est passé de 900 000 à 2 500 000 FCFA.
//  L'écriture a réussi ; le revenu récurrent du tableau de bord, la fiche
//  d'abonnement de l'admin de groupe et les cartes de groupes ont continué
//  d'afficher l'ancien montant jusqu'au redémarrage de l'application.
//
//  Deux raisons, dont celle-ci : chaque provider qui affiche un prix ou une
//  limite n'écoutait que `school_groups`. Or changer un PRIX ne touche pas
//  `school_groups` — la ligne du groupe est identique, seul le plan qu'elle
//  référence a bougé. Aucun évènement, donc aucun rafraîchissement, et comme
//  ces providers sont `keepAlive` la valeur périmée survit à la session.
//
//  (L'autre raison vivait en base : `subscription_plans` n'appartenait pas à
//  la publication `supabase_realtime` — migration 0076.)
//
//  ── LA RÈGLE ───────────────────────────────────────────────────────────────
//  Tout provider qui lit `price_xaf`, `max_schools`, `max_students`,
//  `max_staff` ou `module_count` doit appeler `watchPlanReferential` sur son
//  canal. `test/plan_referential_test.dart` le vérifie fichier par fichier :
//  un nouvel écran qui affiche un tarif sans écouter le référentiel fait
//  échouer la suite.
// ════════════════════════════════════════════════════════════════════════════

/// Tables qui portent le référentiel de facturation : le tarif et les limites
/// (`subscription_plans`), et la composition en modules (`plan_modules`, qui
/// pilote `module_count`).
const kPlanReferentialTables = <String>['subscription_plans', 'plan_modules'];

extension PlanReferentialRealtime on RealtimeChannel {
  /// Rebranche ce canal sur les changements du référentiel de facturation.
  ///
  /// S'utilise aussi bien en chaîne (`client.channel(..).onPostgresChanges(..)
  /// .watchPlanReferential(cb).subscribe()`) qu'en instruction isolée.
  ///
  /// Volontairement SANS filtre : un plan est un objet de plateforme partagé
  /// par tous les groupes. Filtrer sur `group_id` n'aurait aucun sens ici, et
  /// le volume est dérisoire — quatre lignes qui bougent quelques fois par an.
  RealtimeChannel watchPlanReferential(void Function() onChange) {
    var channel = this;
    for (final table in kPlanReferentialTables) {
      channel = channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) => onChange(),
      );
    }
    return channel;
  }
}
