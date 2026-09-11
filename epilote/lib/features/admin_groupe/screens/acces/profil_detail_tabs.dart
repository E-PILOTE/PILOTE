part of '../admin_access_screen.dart';

// Onglets de la fiche et resume des permissions.

class _ProfileInfoTab extends StatelessWidget {
  const _ProfileInfoTab({required this.profile});
  final AccessProfile profile;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const AdminModalSectionTitle('Profil'),
        const SizedBox(height: 8),
        AdminDetailCard([
          AdminDetailRow(Icons.label_outline, 'Nom', p.name),
          AdminDetailRow(Icons.notes_rounded, 'Description',
              p.description?.isNotEmpty == true ? p.description! : '—'),
          AdminDetailRow(
              p.isActive ? Icons.check_circle_outline : Icons.block_outlined,
              'Statut', p.isActive ? 'Actif' : 'Inactif',
              valueColor: p.isActive ? kGreen : kRed, last: true),
        ]),
        const SizedBox(height: 14),
        const AdminModalSectionTitle('Couverture'),
        const SizedBox(height: 8),
        AdminDetailCard([
          AdminDetailRow(Icons.people_outline_rounded, 'Membres rattachés',
              '${p.memberCount}'),
          AdminDetailRow(Icons.widgets_outlined, 'Modules autorisés',
              '${p.moduleCount}'),
          AdminDetailRow(Icons.tag_rounded, 'Identifiant', p.id, mono: true, last: true),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: AdminMetaChip(
              icon: Icons.people_rounded, label: '${p.memberCount} membres', color: kNavy)),
          const SizedBox(width: 8),
          Expanded(child: AdminMetaChip(
              icon: Icons.widgets_rounded, label: '${p.moduleCount} modules', color: kGreen)),
          const SizedBox(width: 8),
          Expanded(child: AdminMetaChip(
              icon: p.isActive ? Icons.verified_rounded : Icons.block_rounded,
              label: p.isActive ? 'Actif' : 'Inactif',
              color: p.isActive ? kGreen : kRed)),
        ]),
        if (p.memberCount == 0) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kOrange.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kOrange.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, size: 16, color: _kOrange),
              const SizedBox(width: 8),
              Expanded(child: Text(
                "Aucun membre n'utilise encore ce profil. "
                'Attribuez-le depuis la page Utilisateurs.',
                style: TextStyle(fontSize: 12, color: kTextMuted, height: 1.4),
              )),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _ProfilePermsTab extends ConsumerWidget {
  const _ProfilePermsTab({
    required this.profile,
    required this.categories,
    required this.onConfigure,
  });
  final AccessProfile profile;
  final List<ModuleCategory> categories;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permsAsync = ref.watch(accessProfilePermsProvider(profile.id));
    return permsAsync.when(
      loading: () => Center(child: CircularProgressIndicator(color: kNavy)),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.cloud_off_rounded, size: 40, color: kTextMuted),
            const SizedBox(height: 12),
            Text('Impossible de charger les permissions.\n${_friendlyError(e)}',
                textAlign: TextAlign.center,
                style: TextStyle(color: kTextMuted, fontSize: 13)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(accessProfilePermsProvider(profile.id)),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Réessayer'),
            ),
          ]),
        ),
      ),
      data: (perms) {
        final granted = perms.entries.where((e) => !e.value.isEmpty).toList();
        if (granted.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: AdminEmptyState(
              icon: Icons.lock_open_rounded,
              title: 'Aucune permission définie',
              message: "Ce profil n'a encore aucun accès. "
                  'Configurez ses permissions pour autoriser des modules.',
              actionLabel: 'Configurer les permissions',
              onAction: onConfigure,
            ),
          );
        }
        // moduleId → (catégorie, module)
        final moduleNames = <String, ({String cat, ModuleInfo mod})>{};
        for (final c in categories) {
          for (final m in c.modules) {
            moduleNames[m.id] = (cat: c.name, mod: m);
          }
        }
        // Regrouper par catégorie
        final byCat = <String, List<MapEntry<String, PermRow>>>{};
        for (final e in granted) {
          final cat = moduleNames[e.key]?.cat ?? 'Autres';
          byCat.putIfAbsent(cat, () => []).add(e);
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final entry in byCat.entries) ...[
              AdminModalSectionTitle(entry.key),
              const SizedBox(height: 8),
              ...entry.value.map((e) {
                final info = moduleNames[e.key];
                return _PermSummaryRow(
                  icon: info?.mod.icon ?? '📦',
                  name: info?.mod.name ?? 'Module',
                  row: e.value,
                );
              }),
              const SizedBox(height: 14),
            ],
          ]),
        );
      },
    );
  }
}

class _PermSummaryRow extends StatelessWidget {
  const _PermSummaryRow({required this.icon, required this.name, required this.row});
  final String icon;
  final String name;
  final PermRow row;

  @override
  Widget build(BuildContext context) {
    // Affiche uniquement les actions ACCORDÉES, avec mise en évidence orange
    // pour les actions sensibles (suppression, export, import, validation…).
    Widget flag(String label, bool on, bool sensitive) {
      final accent = sensitive ? _kOrange : _kPurple;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(sensitive ? Icons.warning_amber_rounded : Icons.check_rounded,
              size: 12, color: accent),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
              color: accent)),
        ]),
      );
    }

    // (label, accordé, sensible) — seules les actions actives sont rendues.
    final flags = <Widget>[
      if (row.canRead)     flag('Voir',       true, false),
      if (row.canCreate)   flag('Créer',      true, false),
      if (row.canUpdate)   flag('Modifier',   true, false),
      if (row.canDelete)   flag('Supprimer',  true, true),
      if (row.canExport)   flag('Exporter',   true, true),
      if (row.canImport)   flag('Importer',   true, true),
      if (row.canValidate) flag('Valider',    true, true),
      if (row.canApprove)  flag('Approuver',  true, true),
      if (row.canManage)   flag('Paramètres', true, true),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(child: Text(name,
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: kTextPrimary))),
          AdminBadge(
            row.dataScope == 'own_classes' ? 'Ses classes' : "Toute l'école",
            color: kNavy, icon: Icons.visibility_outlined,
          ),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: flags),
      ]),
    );
  }
}

// ─── Catalogue des 9 actions ─────────────────────────────────────────────────
