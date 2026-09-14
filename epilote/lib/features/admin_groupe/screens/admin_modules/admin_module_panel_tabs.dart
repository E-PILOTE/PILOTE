part of '../admin_modules_screen.dart';

// Onglets Presentation et Acces du panneau.

extension _PanelTabs on _ModulePanelState {
  Widget _buildPresentationTab(BuildContext context, ModuleOverview module) {
    final totalMembers = module.profiles
        .where((p) => p.authorized)
        .fold<int>(0, (s, p) => s + p.memberCount);
    final adoption = ref.watch(adminModuleAdoptionProvider).valueOrNull;
    final adoptEntry = adoption?.ranking
        .where((e) => e.moduleId == module.id)
        .firstOrNull;
    final totalSchools = adoption?.totalSchools ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Avertissement hors-plan
        if (!module.accessible)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: kAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kAccent.withValues(alpha: 0.28)),
            ),
            child: Row(children: [
              Icon(Icons.warning_amber_rounded, color: kAccent, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Ce module n'est pas inclus dans votre plan d'abonnement.",
                  style: TextStyle(fontSize: 13, color: kTextPrimary),
                ),
              ),
            ]),
          ),

        // Identité
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 64, height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: kNavy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: (module.icon != null && module.icon!.isNotEmpty)
                ? Text(module.icon!, style: const TextStyle(fontSize: 32))
                : Icon(Icons.widgets_outlined, size: 32, color: kNavy),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(module.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800, color: kTextPrimary)),
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [
                if (module.categoryName != null)
                  AdminBadge(module.categoryName!, color: kNavy),
                AdminBadge(
                  module.accessible ? 'Inclus dans le plan' : 'Hors plan',
                  color: module.accessible ? kGreen : kAccent,
                  icon: module.accessible
                      ? Icons.check_circle_outline_rounded
                      : Icons.info_outline_rounded,
                ),
              ]),
            ]),
          ),
        ]),

        if (module.description != null && module.description!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(module.description!,
              style: TextStyle(fontSize: 13.5, color: kTextMuted, height: 1.5)),
        ],

        const SizedBox(height: 20),

        // Stats en boîtes
        Row(children: [
          Expanded(
            child: _StatBox(
              icon: Icons.people_rounded,
              value: '$totalMembers',
              label: 'Membres autorisés',
              color: kNavy,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatBox(
              icon: Icons.shield_rounded,
              value: '${module.authorizedProfiles}/${module.totalProfiles}',
              label: 'Profils habilités',
              color: module.authorizedProfiles > 0 ? kGreen : kTextMuted,
            ),
          ),
        ]),

        // Adoption par école
        if (adoptEntry != null && adoption != null &&
            adoption.schoolNames.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: Text('Adoption par école',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: kTextMuted,
                      letterSpacing: 0.3)),
            ),
            Text(
              '${adoptEntry.schoolCount}/$totalSchools école${totalSchools > 1 ? "s" : ""}',
              style: TextStyle(fontSize: 12, color: kTextMuted),
            ),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: totalSchools > 0
                  ? (adoptEntry.schoolCount / totalSchools).clamp(0.0, 1.0)
                  : 0.0,
              minHeight: 6,
              backgroundColor: kBorder,
              color: adoptEntry.schoolCount == totalSchools
                  ? kGreen
                  : adoptEntry.schoolCount > 0
                      ? kNavy
                      : kTextMuted,
            ),
          ),
          const SizedBox(height: 14),
          for (final s in adoption.schoolNames.entries) ...[
            _SchoolAdoptRow(
              name: s.value,
              uses: adoptEntry.schoolIds.contains(s.key),
            ),
            const SizedBox(height: 8),
          ],
        ],

        const SizedBox(height: 20),
      ]),
    );
  }

  // ── Onglet 2 : Accès profils ────────────────────────────────────────────────

  Widget _buildAccessTab(BuildContext context, ModuleOverview module) {
    final filter = _filterCtrl.text.toLowerCase();
    final profiles = (filter.isEmpty
            ? module.profiles
            : module.profiles
                .where((p) => p.name.toLowerCase().contains(filter))
                .toList())
      ..sort((a, b) {
        final ra = _allLevels.indexOf(_levelOf(a.perm));
        final rb = _allLevels.indexOf(_levelOf(b.perm));
        if (ra != rb) return rb.compareTo(ra);
        return a.name.compareTo(b.name);
      });

    return Column(
      children: [
        // Actions rapides — fixées en haut
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: kSurface,
            border: Border(bottom: BorderSide(color: kBorder)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ACTIONS RAPIDES',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: kTextMuted,
                    letterSpacing: 0.8)),
            const SizedBox(height: 10),
            if (_bulkLoading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(child: CircularProgressIndicator(color: kNavy, strokeWidth: 2)),
              )
            else
              Wrap(spacing: 8, runSpacing: 8, children: [
                _ActionChip(
                  label: 'Lecture — tous',
                  icon: Icons.visibility_outlined,
                  color: kAccent,
                  enabled: module.accessible,
                  onTap: () => _bulkSet(module, _levelRead),
                ),
                _ActionChip(
                  label: 'Contribution — tous',
                  icon: Icons.edit_outlined,
                  color: kNavy,
                  enabled: module.accessible,
                  onTap: () => _bulkSet(module, _levelContrib),
                ),
                _ActionChip(
                  label: 'Gestion — tous',
                  icon: Icons.admin_panel_settings_outlined,
                  color: kGreen,
                  enabled: module.accessible,
                  onTap: () => _bulkSet(module, _levelManage),
                ),
                _ActionChip(
                  label: 'Révoquer tous',
                  icon: Icons.lock_outline_rounded,
                  color: kRed,
                  enabled: module.accessible && module.authorizedProfiles > 0,
                  onTap: () => _confirmRevoke(context, module),
                ),
              ]),
          ]),
        ),

        // Liste profils — scrollable
        Expanded(
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Expanded(
                      child: AdminSectionTitle(
                        'Qui peut utiliser ce module',
                        icon: Icons.lock_person_outlined,
                        subtitle: 'Changements appliqués immédiatement',
                      ),
                    ),
                    const SizedBox(width: 8),
                    AdminBadge(
                      '${module.authorizedProfiles}/${module.totalProfiles}',
                      color: module.authorizedProfiles > 0 ? kGreen : kTextMuted,
                    ),
                  ]),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _filterCtrl,
                    onChanged: (_) => rafraichir(() {}),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un profil…',
                      hintStyle: TextStyle(fontSize: 13, color: kTextMuted),
                      prefixIcon: Icon(Icons.search_rounded, size: 18, color: kTextMuted),
                      suffixIcon: _filterCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear_rounded, size: 16, color: kTextMuted),
                              onPressed: () => rafraichir(() => _filterCtrl.clear()),
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      filled: true,
                      fillColor: kSurface,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(9),
                          borderSide: BorderSide(color: kBorder)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(9),
                          borderSide: BorderSide(color: kBorder)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(9),
                          borderSide: BorderSide(color: kNavy, width: 1.5)),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ]),
              ),

              if (profiles.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      _filterCtrl.text.isEmpty
                          ? 'Aucun profil dans ce groupe'
                          : 'Aucun profil correspondant',
                      style: TextStyle(color: kTextMuted, fontSize: 13),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: profiles.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, indent: 48),
                  itemBuilder: (_, i) => _PanelProfileRow(
                    slug: widget.slug,
                    moduleId: module.id,
                    profile: profiles[i],
                    enabled: module.accessible,
                  ),
                ),

              // Pied de page
              const SizedBox(height: 8),
              const Divider(height: 1, thickness: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Icon(Icons.tune_rounded, size: 14, color: kTextMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Réglage fin (9 actions, périmètre) profil par profil : ouvrez Profils d'accès.",
                      style: TextStyle(fontSize: 12, color: kTextMuted, height: 1.4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => context.go(Routes.adminProfils),
                    child: Text("Profils d'accès",
                        style: TextStyle(color: kNavy, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ],
    );
  }
}
