part of 'user_dashboard_screen.dart';

// ─── États modules (synchro / erreur / aucun module) ──────────────────────────
// ─── Accès rapide : lanceur COMPACT groupé par catégorie ───────────────────────
// Avec 28 modules, une grille de grosses tuiles écrase l'accueil. On condense en
// chips denses regroupés par catégorie, dans une seule carte → organisé, scannable,
// ~⅓ de la hauteur. Complément de la sidebar, jamais un mur.
class _QuickModulesGrid extends ConsumerWidget {
  const _QuickModulesGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grouped =
        ref.watch(modulesGroupedByCategoryProvider).valueOrNull ?? const {};
    final perms = ref.watch(myPermissionsProvider).valueOrNull ?? const {};

    final sections = <Widget>[];
    var ci = 0;
    for (final entry in grouped.entries) {
      final visible = entry.value
          .where((m) => perms[m.slug]?.canRead ?? false)
          .toList();
      if (visible.isEmpty) continue;
      final color = _kPalette[ci % _kPalette.length];
      sections.add(
        Padding(
          padding: EdgeInsets.only(top: ci == 0 ? 0 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(
                  entry.key.name.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: kTextMuted,
                  ),
                ),
              ]),
              const SizedBox(height: 11),
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: [
                  for (final m in visible) _ModuleChip(module: m, color: color),
                ],
              ),
            ],
          ),
        ),
      );
      ci++;
    }
    if (sections.isEmpty) return const SizedBox.shrink();

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: sections,
      ),
    );
  }
}

class _ModuleChip extends StatelessWidget {
  const _ModuleChip({required this.module, required this.color});
  final ModuleModel module;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => context.go(moduleRoute(module.slug)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(moduleIcon(module.slug), size: 15, color: color),
              ),
              const SizedBox(width: 9),
              Text(
                module.name,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: kTextPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncingModulesCard extends StatelessWidget {
  const _SyncingModulesCard();
  @override
  Widget build(BuildContext context) => const AdminCard(
        padding: EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(
              width: 20,
              height: 20,
              child:
                  CircularProgressIndicator(strokeWidth: 2.4, color: kNavy)),
          SizedBox(width: 14),
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
