import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/routes.dart';
import '../../../core/widgets/app_shell.dart';
import '../providers/admin_access_provider.dart'
    show PermRow, accessProfilePermsProvider, adminAccessServiceProvider;
import '../providers/admin_module_provider.dart';
import '../providers/admin_nav_provider.dart';
import '../../../core/widgets/admin_ui.dart';

// ─── Design tokens locaux ─────────────────────────────────────────────────────
const Color _kPurple = Color(0xFF7C3AED);

// ─── Niveaux d'accès (presets identiques à l'éditeur matrice) ────────────────
const String _levelNone    = 'Aucun accès';
const String _levelRead    = 'Lecture seule';
const String _levelContrib = 'Contribution';
const String _levelManage  = 'Gestion complète';
const List<String> _allLevels = [_levelNone, _levelRead, _levelContrib, _levelManage];

Color _levelColor(String l) => switch (l) {
      _levelManage  => kGreen,
      _levelContrib => kNavy,
      _levelRead    => kAccent,
      _             => kTextMuted,
    };

IconData _levelIcon(String l) => switch (l) {
      _levelManage  => Icons.shield_outlined,
      _levelContrib => Icons.edit_outlined,
      _levelRead    => Icons.visibility_outlined,
      _             => Icons.lock_outline_rounded,
    };

String _levelOf(PermRow? p) {
  if (p == null || p.isEmpty) return _levelNone;
  if (p.canManage || (p.canDelete && p.canUpdate && p.canCreate)) return _levelManage;
  if (p.canCreate || p.canUpdate || p.canValidate || p.canApprove) return _levelContrib;
  if (p.canRead) return _levelRead;
  return _levelNone;
}

PermRow _presetFor(String level, String scope) => switch (level) {
      _levelRead    => PermRow(canRead: true, dataScope: scope),
      _levelContrib => PermRow(canRead: true, canCreate: true, canUpdate: true, dataScope: scope),
      _levelManage  => PermRow(
          canRead: true, canCreate: true, canUpdate: true, canDelete: true,
          canExport: true, canImport: true, canValidate: true, canApprove: true,
          canManage: true, dataScope: scope),
      _             => PermRow(dataScope: scope),
    };

bool _sameActions(PermRow a, PermRow b) =>
    a.canRead == b.canRead && a.canCreate == b.canCreate &&
    a.canUpdate == b.canUpdate && a.canDelete == b.canDelete &&
    a.canExport == b.canExport && a.canImport == b.canImport &&
    a.canValidate == b.canValidate && a.canApprove == b.canApprove &&
    a.canManage == b.canManage;

bool _isCustom(PermRow? p) =>
    p != null && !p.isEmpty && !_sameActions(p, _presetFor(_levelOf(p), p.dataScope));

// ═══════════════════════════════════════════════════════════════════════════════
// ÉCRAN MODULE (pleine page — ouvert via "open_in_full" du panneau)
// ═══════════════════════════════════════════════════════════════════════════════

class AdminModuleScreen extends ConsumerWidget {
  const AdminModuleScreen({super.key, required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminModuleProvider(slug));
    return AppShell(
      title: async.valueOrNull?.name ?? 'Module',
      actions: [
        // Bouton retour vers le catalogue
        TextButton.icon(
          onPressed: () => context.go(Routes.adminModules),
          icon: const Icon(Icons.arrow_back_rounded, size: 16),
          label: const Text('Catalogue'),
          style: TextButton.styleFrom(
            foregroundColor: kNavy,
            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 8),
      ],
      child: RefreshIndicator(
        color: kNavy,
        onRefresh: () => ref.refresh(adminModuleProvider(slug).future),
        child: async.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => const Center(child: CircularProgressIndicator(color: kNavy)),
          error: (e, _) => Center(
            child: Text('Erreur : $e',
                style: const TextStyle(color: kTextMuted)),
          ),
          data: (m) => m == null ? const _NotFound() : _Body(module: m),
        ),
      ),
    );
  }
}

// ─── Corps principal ──────────────────────────────────────────────────────────

class _Body extends ConsumerWidget {
  const _Body({required this.module});
  final ModuleOverview module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adoptionAsync = ref.watch(adminModuleAdoptionProvider);
    final profiles = [...module.profiles]
      ..sort((a, b) {
        final ra = _allLevels.indexOf(_levelOf(a.perm));
        final rb = _allLevels.indexOf(_levelOf(b.perm));
        if (ra != rb) return rb.compareTo(ra);
        return a.name.compareTo(b.name);
      });

    // Adoption : écoles utilisant ce module
    final adoptionEntry = adoptionAsync.valueOrNull?.ranking
        .where((e) => e.moduleId == module.id)
        .firstOrNull;
    final schoolNames = adoptionAsync.valueOrNull?.schoolNames ?? {};
    final totalSchools = adoptionAsync.valueOrNull?.totalSchools ?? 0;

    // ── Colonne gauche : identité + KPIs + adoption ──────────────────────
    final leftCol = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminCard(
          accent: module.accessible ? kGreen : kTextMuted,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 64, height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: kNavy.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kBorder),
                ),
                child: (module.icon != null && module.icon!.isNotEmpty)
                    ? Text(module.icon!, style: const TextStyle(fontSize: 30))
                    : const Icon(Icons.widgets_rounded, color: kNavy, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(module.name,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kTextPrimary)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    if (module.categoryName != null)
                      AdminBadge(module.categoryName!, color: kNavy, icon: Icons.folder_outlined),
                    AdminBadge(
                      module.accessible ? 'Inclus dans le plan' : 'Hors plan',
                      color: module.accessible ? kGreen : kAccent,
                      icon: module.accessible
                          ? Icons.check_circle_outline_rounded
                          : Icons.lock_outline_rounded,
                    ),
                    AdminBadge(
                      '${module.authorizedProfiles}/${module.totalProfiles} profils',
                      color: module.authorizedProfiles > 0 ? kGreen : kTextMuted,
                      icon: Icons.verified_user_outlined,
                    ),
                  ]),
                ]),
              ),
            ]),
            if (module.description != null && module.description!.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Divider(color: kBorder),
              const SizedBox(height: 12),
              Text(module.description!,
                  style: const TextStyle(fontSize: 13.5, color: kTextMuted, height: 1.6)),
            ],
          ]),
        ),
        const SizedBox(height: 16),
        if (!module.accessible) ...[const _PlanWarning(), const SizedBox(height: 16)],
        _ModuleKpiRow(module: module, adoptionEntry: adoptionEntry, totalSchools: totalSchools),
        if (adoptionEntry != null && adoptionEntry.schoolCount > 0) ...[
          const SizedBox(height: 16),
          _SchoolAdoptionCard(
              entry: adoptionEntry, schoolNames: schoolNames, totalSchools: totalSchools),
        ],
      ],
    );

    // ── Colonne droite : actions rapides + habilitations + réglage fin ───
    final rightCol = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (module.accessible) ...[
          _BulkActionsCard(slug: module.slug, moduleId: module.id, profiles: profiles),
          const SizedBox(height: 16),
        ],
        AdminCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: AdminSectionTitle(
                  'Qui peut utiliser ce module',
                  icon: Icons.verified_user_outlined,
                  subtitle: module.accessible
                      ? 'Définissez le niveau d\'accès par profil. Les changements s\'appliquent immédiatement.'
                      : 'Activez ce module via votre abonnement pour gérer les accès.',
                ),
              ),
              const SizedBox(width: 12),
              AdminBadge(
                '${module.authorizedProfiles}/${module.totalProfiles}',
                color: module.authorizedProfiles > 0 ? kGreen : kTextMuted,
              ),
            ]),
            const SizedBox(height: 12),
            if (profiles.isEmpty)
              const AdminEmptyState(
                icon: Icons.verified_user_outlined,
                title: "Aucun profil d'accès",
                message: "Créez des profils d'accès pour habiliter votre personnel à ce module.",
              )
            else
              for (int i = 0; i < profiles.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: kBorder),
                _ProfileAccessRow(
                  slug: module.slug,
                  moduleId: module.id,
                  profile: profiles[i],
                  enabled: module.accessible,
                ),
              ],
          ]),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kNavy.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorder),
          ),
          child: Row(children: [
            const Icon(Icons.tune_rounded, color: kTextMuted, size: 18),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                "Réglage fin (9 actions, périmètre des données) profil par profil — disponible dans Profils d'accès.",
                style: TextStyle(fontSize: 12.5, color: kTextMuted, height: 1.4),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => context.go(Routes.adminProfils),
              child: const Text('Profils d\'accès',
                  style: TextStyle(color: kNavy, fontWeight: FontWeight.w700, fontSize: 12.5)),
            ),
          ]),
        ),
      ],
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
      children: [
        LayoutBuilder(builder: (_, cx) {
          if (cx.maxWidth >= 860) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 55, child: leftCol),
                const SizedBox(width: 16),
                Expanded(flex: 45, child: rightCol),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [leftCol, const SizedBox(height: 16), rightCol],
          );
        }),
      ],
    );
  }
}

// ─── KPIs rapides ─────────────────────────────────────────────────────────────

class _ModuleKpiRow extends StatelessWidget {
  const _ModuleKpiRow({
    required this.module,
    required this.adoptionEntry,
    required this.totalSchools,
  });
  final ModuleOverview module;
  final ModuleAdoptionEntry? adoptionEntry;
  final int totalSchools;

  @override
  Widget build(BuildContext context) {
    final schoolCount = adoptionEntry?.schoolCount ?? 0;
    final memberCount = module.profiles
        .where((p) => p.authorized)
        .fold<int>(0, (s, p) => s + p.memberCount);
    final schoolPct   = totalSchools > 0
        ? (schoolCount / totalSchools * 100).round()
        : 0;
    final profilePct  = module.totalProfiles > 0
        ? (module.authorizedProfiles / module.totalProfiles * 100).round()
        : 0;

    return LayoutBuilder(builder: (_, cx) {
      final cols = cx.maxWidth >= 700 ? 4 : 2;
      const gap  = 12.0;
      final w    = (cx.maxWidth - gap * (cols - 1)) / cols;
      final tiles = [
        _KpiTile(
          icon: Icons.school_outlined,
          value: '$schoolCount / $totalSchools',
          label: 'Écoles utilisatrices',
          sub: '$schoolPct% du parc',
          color: schoolCount > 0 ? kGreen : kTextMuted,
        ),
        _KpiTile(
          icon: Icons.people_rounded,
          value: '$memberCount',
          label: 'Membres autorisés',
          sub: 'dans tous les profils habilités',
          color: kNavy,
        ),
        _KpiTile(
          icon: Icons.shield_rounded,
          value: '${module.authorizedProfiles} / ${module.totalProfiles}',
          label: 'Profils habilités',
          sub: '$profilePct% de couverture',
          color: module.authorizedProfiles > 0 ? kGreen : kTextMuted,
        ),
        _KpiTile(
          icon: module.accessible
              ? Icons.check_circle_outline_rounded
              : Icons.lock_outline_rounded,
          value: module.accessible ? 'Actif' : 'Inactif',
          label: 'Statut plan',
          sub: module.accessible ? 'Inclus dans le plan' : 'Hors plan actuel',
          color: module.accessible ? kGreen : kAccent,
        ),
      ];
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final t in tiles) SizedBox(width: w, child: t),
        ],
      );
    });
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.sub,
    required this.color,
  });
  final IconData icon;
  final String   value;
  final String   label;
  final String   sub;
  final Color    color;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kTextPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
          ),
        ]),
      ),
    );
  }
}

// ─── Adoption par école ───────────────────────────────────────────────────────

class _SchoolAdoptionCard extends StatelessWidget {
  const _SchoolAdoptionCard({
    required this.entry,
    required this.schoolNames,
    required this.totalSchools,
  });
  final ModuleAdoptionEntry   entry;
  final Map<String, String>   schoolNames;
  final int totalSchools;

  @override
  Widget build(BuildContext context) {
    final schools = entry.schoolIds
        .map((id) => schoolNames[id] ?? id)
        .toList()
      ..sort();

    return AdminCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AdminSectionTitle(
          'Écoles utilisant ce module',
          icon: Icons.location_city_rounded,
          subtitle: '${entry.schoolCount} école${entry.schoolCount > 1 ? "s" : ""}'
              ' sur $totalSchools ont ce module configuré.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final name in schools)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: kGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: kGreen.withValues(alpha: 0.25)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.school_outlined, size: 13, color: kGreen),
                  const SizedBox(width: 6),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: kTextPrimary,
                    ),
                  ),
                ]),
              ),
          ],
        ),
      ]),
    );
  }
}

// ─── Actions rapides bulk ─────────────────────────────────────────────────────

class _BulkActionsCard extends ConsumerStatefulWidget {
  const _BulkActionsCard({
    required this.slug,
    required this.moduleId,
    required this.profiles,
  });
  final String slug;
  final String moduleId;
  final List<ModuleProfileAccess> profiles;

  @override
  ConsumerState<_BulkActionsCard> createState() => _BulkActionsCardState();
}

class _BulkActionsCardState extends ConsumerState<_BulkActionsCard> {
  bool _applying = false;

  Future<void> _applyToAll(String level) async {
    if (_applying) return;
    setState(() => _applying = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final svc = ref.read(adminAccessServiceProvider);
      for (final p in widget.profiles) {
        final map = {...await ref.read(accessProfilePermsProvider(p.id).future)};
        final scope = map[widget.moduleId]?.dataScope ?? 'own_school';
        if (level == _levelNone) {
          map.remove(widget.moduleId);
        } else {
          map[widget.moduleId] = _presetFor(level, scope);
        }
        final perms = [
          for (final e in map.entries)
            if (!e.value.isEmpty) e.value.toJson(e.key),
        ];
        await svc.savePermissions(p.id, perms);
      }
      ref.invalidate(adminModuleProvider(widget.slug));
      messenger.showSnackBar(SnackBar(
        content: Text(level == _levelNone
            ? 'Accès retiré pour tous les profils'
            : '${widget.profiles.length} profils passés en $level'),
        backgroundColor: kNavy,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Erreur : $e'),
        backgroundColor: kRed,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const AdminSectionTitle(
          'Actions rapides',
          icon: Icons.bolt_rounded,
          subtitle: 'Appliquer un niveau à tous les profils en un clic',
        ),
        const SizedBox(height: 14),
        if (_applying)
          const Center(child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: CircularProgressIndicator(color: kNavy, strokeWidth: 2),
          ))
        else
          Wrap(spacing: 8, runSpacing: 8, children: [
            _BulkBtn(label: 'Lecture — tous',       level: _levelRead,    onTap: _applyToAll),
            _BulkBtn(label: 'Contribution — tous',  level: _levelContrib, onTap: _applyToAll),
            _BulkBtn(label: 'Gestion — tous',       level: _levelManage,  onTap: _applyToAll),
            _BulkBtn(label: 'Révoquer tous',        level: _levelNone,    onTap: _applyToAll, danger: true),
          ]),
      ]),
    );
  }
}

class _BulkBtn extends StatelessWidget {
  const _BulkBtn({
    required this.label,
    required this.level,
    required this.onTap,
    this.danger = false,
  });
  final String label;
  final String level;
  final Future<void> Function(String) onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? kRed : _levelColor(level);
    return OutlinedButton.icon(
      onPressed: () => onTap(level),
      icon: Icon(_levelIcon(level), size: 14, color: color),
      label: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withValues(alpha: 0.40)),
        backgroundColor: color.withValues(alpha: 0.06),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// ─── Ligne de profil d'accès ──────────────────────────────────────────────────

class _ProfileAccessRow extends ConsumerStatefulWidget {
  const _ProfileAccessRow({
    required this.slug,
    required this.moduleId,
    required this.profile,
    required this.enabled,
  });
  final String slug;
  final String moduleId;
  final ModuleProfileAccess profile;
  final bool enabled;

  @override
  ConsumerState<_ProfileAccessRow> createState() => _ProfileAccessRowState();
}

class _ProfileAccessRowState extends ConsumerState<_ProfileAccessRow> {
  bool _saving = false;

  Future<void> _setLevel(String level) async {
    if (_saving) return;
    final p       = widget.profile;
    final current = _levelOf(p.perm);
    if (level == current && !_isCustom(p.perm)) return;

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final svc  = ref.read(adminAccessServiceProvider);
      final map  = {...await ref.read(accessProfilePermsProvider(p.id).future)};
      final scope = map[widget.moduleId]?.dataScope ?? 'own_school';
      if (level == _levelNone) {
        map.remove(widget.moduleId);
      } else {
        map[widget.moduleId] = _presetFor(level, scope);
      }
      final perms = [
        for (final e in map.entries)
          if (!e.value.isEmpty) e.value.toJson(e.key),
      ];
      await svc.savePermissions(p.id, perms);
      ref.invalidate(adminModuleProvider(widget.slug));
      messenger.showSnackBar(SnackBar(
        content: Text(level == _levelNone
            ? '${p.name} : accès retiré'
            : '${p.name} : ${level.toLowerCase()}'),
        backgroundColor: kNavy,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Échec de la mise à jour : $e'),
        backgroundColor: kRed,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p      = widget.profile;
    final level  = _levelOf(p.perm);
    final color  = _levelColor(level);
    final custom = _isCustom(p.perm);
    final on     = level != _levelNone;
    final sub    = <String>[
      if (p.roleType != null && p.roleType!.isNotEmpty) p.roleType!,
      '${p.memberCount} membre${p.memberCount > 1 ? "s" : ""}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // Icône niveau
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: (on ? color : kTextMuted).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_levelIcon(level), color: on ? color : kTextMuted, size: 18),
        ),
        const SizedBox(width: 12),
        // Nom + sous-titre
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              p.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: kTextPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Row(children: [
              Flexible(
                child: Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: kTextMuted),
                ),
              ),
              if (custom) ...[
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Permissions personnalisées — changer le niveau ici les remplacera.',
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: _kPurple.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Text(
                      'réglage fin',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: _kPurple,
                      ),
                    ),
                  ),
                ),
              ],
            ]),
          ]),
        ),
        const SizedBox(width: 10),
        // Sélecteur de niveau
        _LevelSelector(
          level: level,
          color: color,
          enabled: widget.enabled,
          saving: _saving,
          onSelect: _setLevel,
        ),
      ]),
    );
  }
}

class _LevelSelector extends StatelessWidget {
  const _LevelSelector({
    required this.level,
    required this.color,
    required this.enabled,
    required this.saving,
    required this.onSelect,
  });
  final String level;
  final Color  color;
  final bool   enabled;
  final bool   saving;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      constraints: const BoxConstraints(maxWidth: 160),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: enabled ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (saving)
          const SizedBox(
            width: 14, height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: kNavy),
          )
        else
          Icon(_levelIcon(level), size: 14, color: enabled ? color : kTextMuted),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            level,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: enabled ? kTextPrimary : kTextMuted,
            ),
          ),
        ),
        if (enabled) ...[
          const SizedBox(width: 4),
          const Icon(Icons.expand_more_rounded, size: 15, color: kTextMuted),
        ],
      ]),
    );

    if (!enabled) return Opacity(opacity: 0.7, child: chip);

    return PopupMenuButton<String>(
      tooltip: "Modifier le niveau d'accès",
      onSelected: onSelect,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      itemBuilder: (_) => [
        for (final l in _allLevels)
          PopupMenuItem<String>(
            value: l,
            child: Row(children: [
              Icon(_levelIcon(l), size: 16, color: _levelColor(l)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(l,
                    style: const TextStyle(fontSize: 13, color: kTextPrimary)),
              ),
              if (l == level)
                const Icon(Icons.check_rounded, size: 16, color: kGreen),
            ]),
          ),
      ],
      child: chip,
    );
  }
}

// ─── Avertissement hors-plan ──────────────────────────────────────────────────

class _PlanWarning extends StatelessWidget {
  const _PlanWarning();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kAccent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kAccent.withValues(alpha: 0.40)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.lock_outline_rounded, color: kAccent, size: 22),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            "Ce module n'est pas inclus dans votre plan actuel. "
            "Mettez à niveau votre abonnement pour débloquer l'accès.",
            style: TextStyle(fontSize: 13, color: kTextPrimary, height: 1.4),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: () => context.go(Routes.adminAbonnement),
          style: OutlinedButton.styleFrom(
            foregroundColor: kNavy,
            side: const BorderSide(color: kBorder),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Voir les plans'),
        ),
      ]),
    );
  }
}

// ─── Module introuvable ───────────────────────────────────────────────────────

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) {
    return const AdminEmptyState(
      icon: Icons.search_off_rounded,
      title: 'Module introuvable',
      message: "Ce module n'existe pas ou n'est pas disponible pour votre groupe.",
    );
  }
}
