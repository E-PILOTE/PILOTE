part of '../admin_subscription_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CE QUE L'ÉCRAN D'ABONNEMENT N'A PAS PU LIRE
//
//  ── POURQUOI CET ÉCRAN-LÀ EST LE PLUS SENSIBLE DES TROIS ───────────────────
//  Le tableau de bord affiche des effectifs, les rapports des statistiques.
//  Celui-ci affiche un MONTANT, une ÉCHÉANCE et des QUOTAS — c'est-à-dire la
//  relation commerciale elle-même. Un zéro faux n'y est pas une imprécision :
//  il change ce que le client croit devoir, et ce qu'il croit pouvoir faire.
//
//  Les huit lectures étaient muettes (`catch (_) {}`). La plus dangereuse
//  laissait `subscription` à `null`, ce que l'écran traduisait par « Aucun
//  abonnement — ce groupe n'a pas encore de plan actif ». À un ministère sous
//  licence, cette phrase est fausse ET alarmante.
//
//  ── DEUX ÉTATS À NE JAMAIS CONFONDRE ──────────────────────────────────────
//  « Aucun abonnement » est un FAIT vérifié : la lecture a réussi, elle n'a
//  rien trouvé. « Abonnement illisible » est une ABSENCE DE FAIT. Le premier
//  demande d'appeler la plateforme, le second de réessayer. Les afficher
//  pareil envoie la moitié des gens au mauvais endroit.
// ════════════════════════════════════════════════════════════════════════════

/// Le bandeau, posé AVANT les chiffres — après, il ne sert plus à rien : la
/// lecture est déjà faite.
class _MesuresManquantesAbonnement extends ConsumerWidget {
  const _MesuresManquantesAbonnement({required this.data});
  final AdminSubscriptionData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noms = (data.mesuresManquantes
            .map(MesuresAbonnement.libelle)
            .toList()
          ..sort())
        .join(', ');

    // ⚠️ Le quota est nommé à part. Une jauge trop basse fait croire à de la
    // marge — c'est la seule des huit mesures dont l'erreur pousse à AGIR
    // (inscrire, recruter) plutôt qu'à mal s'informer.
    final quotaTouche = data.manque(MesuresAbonnement.ecoles) ||
        data.manque(MesuresAbonnement.eleves) ||
        data.manque(MesuresAbonnement.personnel);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: kAccent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kAccent.withValues(alpha: 0.35)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.cloud_off_rounded, size: 18, color: kAccent),
        const SizedBox(width: 11),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Certaines informations manquent',
                style: TextStyle(
                    color: kAccent, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(
              'Non lues : $noms. Les cases correspondantes ne sont pas à zéro, '
              'elles sont inconnues.'
              '${quotaTouche ? " Ne vous fiez pas aux jauges de consommation "
                  "tant que cette page n'a pas été relue." : ''}',
              style: TextStyle(
                  color: kTextPrimary.withValues(alpha: 0.85),
                  fontSize: 11.5,
                  height: 1.35),
            ),
          ]),
        ),
        const SizedBox(width: 12),
        TextButton.icon(
          onPressed: () => ref.invalidate(adminSubscriptionProvider),
          icon: const Icon(Icons.refresh_rounded, size: 15),
          label: const Text('Réessayer', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(foregroundColor: kAccent),
        ),
      ]),
    );
  }
}

/// L'écran plein quand l'abonnement lui-même n'a pas pu être lu.
///
/// Volontairement PROCHE de `AdminEmptyState` par la forme et LOIN par le
/// texte : même page, même place, mais la phrase ne prétend rien savoir.
class _AbonnementIllisible extends ConsumerWidget {
  const _AbonnementIllisible();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.cloud_off_rounded, size: 46, color: kAccent),
            const SizedBox(height: 14),
            Text('Abonnement non lu',
                style: TextStyle(
                    color: kTextPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              "Votre plan n'a pas pu être récupéré. Cela ne veut PAS dire que "
              "ce groupe est sans abonnement : la page n'a simplement rien pu "
              'lire. Vérifiez votre connexion et réessayez.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: kTextMuted.withValues(alpha: 0.95),
                  fontSize: 13,
                  height: 1.45),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => ref.invalidate(adminSubscriptionProvider),
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Réessayer'),
              style: FilledButton.styleFrom(backgroundColor: kNavy),
            ),
          ]),
        ),
      );
}
