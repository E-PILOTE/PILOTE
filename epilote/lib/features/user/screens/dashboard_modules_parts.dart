part of 'user_dashboard_screen.dart';

// ─── États modules (synchro / erreur / aucun module) ──────────────────────────
// L'« Accès rapide » (grille de modules) vit désormais dans le lanceur du top
// header (cf. app_header.dart · _ModuleLauncher). Ici ne restent que les états.
class _SyncingModulesCard extends StatelessWidget {
  const _SyncingModulesCard();
  @override
  Widget build(BuildContext context) => AdminCard(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(
              width: 20,
              height: 20,
              child:
                  CircularProgressIndicator(strokeWidth: 2.4, color: kNavy)),
          const SizedBox(width: 14),
          Flexible(
            child: Text('Synchronisation de vos modules…',
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: kTextMuted)),
          ),
        ]),
      );
}

class _ModulesErrorCard extends StatelessWidget {
  const _ModulesErrorCard();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(top: 8),
        child: AdminEmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Erreur de synchronisation',
          message:
              "Vos modules n'ont pas pu être chargés. Vérifiez votre connexion ; "
              'la synchronisation reprendra automatiquement.',
        ),
      );
}

class _NoModulesCard extends StatelessWidget {
  const _NoModulesCard();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(top: 32),
        child: AdminEmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Aucun module ne vous est encore attribué',
          message:
              "Contactez l'administrateur de votre groupe pour qu'il vous "
              "attribue un profil d'accès et les modules nécessaires.",
        ),
      );
}
