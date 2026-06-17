import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/routes.dart';
import '../../../core/widgets/app_shell.dart';
import '../providers/admin_settings_provider.dart';
import '../../../core/widgets/admin_ui.dart';

// ═════════════════════════════════════════════════════════════════════════════
// PARAMÈTRES — espace admin_groupe (online, scope group_id)
// 4 onglets persistés : Général · Facturation · Notifications · Sécurité
// ═════════════════════════════════════════════════════════════════════════════
class AdminSettingsScreen extends ConsumerStatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  ConsumerState<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends ConsumerState<AdminSettingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Paramètres',
      child: Column(
        children: [
          _SettingsTabBar(controller: _tabs),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: const [
                _GeneralTab(),
                _BillingTab(),
                _NotificationsTab(),
                _SecurityTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Barre d'onglets (style navy) ────────────────────────────────────────────
class _SettingsTabBar extends StatelessWidget {
  const _SettingsTabBar({required this.controller});
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: kCardBg,
        border: Border(bottom: BorderSide(color: kBorder)),
      ),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: kNavy,
        unselectedLabelColor: kTextMuted,
        indicatorColor: kNavy,
        indicatorWeight: 2.5,
        labelStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(icon: Icon(Icons.tune_rounded, size: 18), text: 'Général'),
          Tab(icon: Icon(Icons.payments_outlined, size: 18), text: 'Facturation'),
          Tab(icon: Icon(Icons.notifications_outlined, size: 18), text: 'Notifications'),
          Tab(icon: Icon(Icons.shield_outlined, size: 18), text: 'Sécurité'),
        ],
      ),
    );
  }
}

// ─── Conteneur scrollable pleine-largeur commun aux onglets ──────────────────
class _TabScaffold extends StatelessWidget {
  const _TabScaffold({required this.children, this.onRefresh});
  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, c) {
      final w = c.maxWidth.isFinite ? c.maxWidth : MediaQuery.of(ctx).size.width - 80;
      final scrollView = SingleChildScrollView(
        child: SizedBox(
          width: w,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      );
      if (onRefresh == null) return scrollView;
      return RefreshIndicator(onRefresh: onRefresh!, child: scrollView);
    });
  }
}

// ─── Bandeau « bouton Enregistrer » réutilisable ─────────────────────────────
class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.saving, required this.onSave, this.error});
  final bool saving;
  final VoidCallback onSave;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null) ...[
          AdminErrorBanner(message: error!),
          const SizedBox(height: 14),
        ],
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: saving ? null : onSave,
            icon: saving
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_rounded, size: 18),
            label: Text(saving ? 'Enregistrement…' : 'Enregistrer'),
            style: FilledButton.styleFrom(
              backgroundColor: kNavy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

void _toast(BuildContext context, String message, {bool ok = true}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    backgroundColor: ok ? kGreen : kRed,
    behavior: SnackBarBehavior.floating,
    content: Text(message),
  ));
}

// ─── Ligne de switch compacte ────────────────────────────────────────────────
class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      activeThumbColor: kNavy,
      value: value,
      onChanged: onChanged,
      secondary: Icon(icon, color: kNavy, size: 21),
      title: Text(title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTextPrimary)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: kTextMuted)),
    );
  }
}

// ─── Stepper numérique (min/max) ─────────────────────────────────────────────
class _NumberStepper extends StatelessWidget {
  const _NumberStepper({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.suffix,
    this.step = 1,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final int value;
  final int min;
  final int max;
  final int step;
  final String? suffix;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: kNavy, size: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTextPrimary)),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: kTextMuted)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: value > min ? () => onChanged(value - step) : null,
                  icon: const Icon(Icons.remove_rounded, size: 18, color: kNavy),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 56),
                  child: Text(
                    suffix == null ? '$value' : '$value $suffix',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: kTextPrimary),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: value < max ? () => onChanged(value + step) : null,
                  icon: const Icon(Icons.add_rounded, size: 18, color: kNavy),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Dropdown intégré au design ──────────────────────────────────────────────
class _SettingDropdown<T> extends StatelessWidget {
  const _SettingDropdown({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String label;
  final IconData icon;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        decoration: adminInputDecoration(label, icon: icon),
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ONGLET 1 — GÉNÉRAL  (infos groupe en lecture seule + préférences group_settings)
// ═════════════════════════════════════════════════════════════════════════════
class _GeneralTab extends ConsumerWidget {
  const _GeneralTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(adminGroupProfileProvider);
    final settings = ref.watch(adminGroupSettingsProvider);

    return _TabScaffold(
      onRefresh: () async {
        ref.invalidate(adminGroupProfileProvider);
        ref.invalidate(adminGroupSettingsProvider);
        await Future.wait([
          ref.read(adminGroupProfileProvider.future),
          ref.read(adminGroupSettingsProvider.future),
        ]);
      },
      children: [
        // ── Informations du groupe (lecture seule) ──────────────────────────
        profile.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => const _CardLoader(),
          error: (e, _) => AdminCard(child: AdminErrorBanner(message: 'Erreur : $e')),
          data: (g) => _GroupInfoCard(group: g),
        ),
        const SizedBox(height: 20),

        // ── Aperçu temps réel : écoles, utilisateurs, quotas du plan ────────
        const _GroupStatsCard(),
        const SizedBox(height: 20),

        // ── Préférences régionales (persistées dans group_settings.general) ──
        settings.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => const _CardLoader(),
          error: (e, _) => AdminCard(child: AdminErrorBanner(message: 'Erreur : $e')),
          data: (s) => _GeneralPrefsCard(initial: s.general),
        ),
        const SizedBox(height: 20),

        // ── Paramètres pédagogiques (persistés dans group_settings.general) ─
        settings.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => const _CardLoader(),
          error: (e, _) => AdminCard(child: AdminErrorBanner(message: 'Erreur : $e')),
          data: (s) => _PedagogyCard(initial: s.general),
        ),
        const SizedBox(height: 20),

        // ── Apparence (local, non persisté côté DB) ─────────────────────────
        const _AppearanceCard(),
        const SizedBox(height: 20),

        // ── Mon compte ──────────────────────────────────────────────────────
        const _AccountCard(),
        const SizedBox(height: 20),

        // ── Mes demandes au support ──────────────────────────────────────────
        const _SupportHistoryCard(),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _GroupInfoCard extends StatelessWidget {
  const _GroupInfoCard({required this.group});
  final GroupProfile? group;

  static String _typeLabel(String t) => switch (t) {
        'public'        => 'Public',
        'prive'         => 'Privé',
        'confessionnel' => 'Confessionnel',
        'ministere'     => 'Ministère',
        'reseau'        => 'Réseau',
        _               => t,
      };

  static String _fmtDate(DateTime? d) {
    if (d == null) return '—';
    const months = [
      'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
      'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final g = group;
    return AdminCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AdminSectionTitle('Informations du groupe',
            icon: Icons.business_rounded,
            trailing: g != null
                ? AdminBadge(g.isActive ? 'Actif' : 'Inactif',
                    color: g.isActive ? kGreen : kTextMuted)
                : null),
        const SizedBox(height: 14),
        if (g == null)
          const Text('Aucune information disponible.', style: TextStyle(color: kTextMuted))
        else ...[
          // ── En-tête : logo + nom + badges ──────────────────────────────────
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _GroupLogo(logoUrl: g.logoUrl, name: g.name),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(g.name,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800, color: kTextPrimary)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                AdminBadge(_typeLabel(g.groupType), color: kNavy, icon: Icons.category_outlined),
                AdminBadge(g.planName, color: kAccent, icon: Icons.workspace_premium_outlined),
                AdminBadge(statusLabel(g.subscriptionStatus),
                    color: statusColor(g.subscriptionStatus), icon: Icons.verified_outlined),
                if (g.slug != null && g.slug!.isNotEmpty)
                  AdminBadge('@${g.slug}', color: kTextMuted, icon: Icons.alternate_email_rounded),
              ]),
            ])),
          ]),
          const SizedBox(height: 16),
          // ── bandeau lecture seule ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: kNavy.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(children: [
              Icon(Icons.lock_outline_rounded, size: 16, color: kNavy),
              SizedBox(width: 8),
              Expanded(
                  child: Text(
                      "Ces informations sont gérées par l'administration de la plateforme. "
                      'Pour toute modification, envoyez une demande ci-dessous.',
                      style: TextStyle(fontSize: 12, color: kTextMuted))),
            ]),
          ),
          const SizedBox(height: 16),
          // ── Grille d'informations responsive (2 colonnes sur grand écran) ──
          _InfoGrid(rows: [
            if (g.department != null)
              _InfoRow(label: 'Département', value: g.department!, icon: Icons.map_outlined),
            if (g.foundedYear != null)
              _InfoRow(label: 'Année de création', value: '${g.foundedYear}', icon: Icons.event_outlined),
            if (g.adminEmail != null)
              _InfoRow(label: 'Email', value: g.adminEmail!, icon: Icons.email_outlined),
            if (g.phone != null)
              _InfoRow(label: 'Téléphone', value: g.phone!, icon: Icons.phone_outlined),
            _InfoRow(label: 'Plan', value: g.planName, icon: Icons.workspace_premium_outlined),
            _InfoRow(label: 'Statut abonnement', value: statusLabel(g.subscriptionStatus), icon: Icons.verified_outlined),
            if (g.subscriptionStart != null)
              _InfoRow(label: 'Début abonnement', value: _fmtDate(g.subscriptionStart), icon: Icons.play_circle_outline_rounded),
            if (g.subscriptionEnd != null)
              _InfoRow(label: 'Fin abonnement', value: _subEndLabel(g.subscriptionEnd!), icon: Icons.event_busy_outlined),
            if (g.address != null)
              _InfoRow(label: 'Adresse', value: g.address!, icon: Icons.location_on_outlined),
          ]),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () =>
                  showDialog(context: context, builder: (_) => const _RequestUpdateDialog()),
              icon: const Icon(Icons.edit_note_rounded, size: 18),
              label: const Text('Demander une modification'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kNavy,
                side: const BorderSide(color: kBorder),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ]),
    );
  }

  static String _subEndLabel(DateTime end) {
    final days = end.difference(DateTime.now()).inDays;
    final date = _fmtDate(end);
    if (days < 0) return '$date (expiré)';
    if (days == 0) return '$date (aujourd\'hui)';
    return '$date (dans $days j)';
  }
}

// ─── Logo du groupe (lecture seule, school_groups.logo_url) ──────────────────
class _GroupLogo extends StatelessWidget {
  const _GroupLogo({required this.logoUrl, required this.name});
  final String? logoUrl;
  final String name;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'G';
  }

  @override
  Widget build(BuildContext context) {
    final hasLogo = logoUrl != null && logoUrl!.startsWith('http');
    final fallback = Center(
      child: Text(_initials,
          style: const TextStyle(color: kNavy, fontSize: 24, fontWeight: FontWeight.w900)),
    );
    return Container(
      width: 72, height: 72,
      decoration: BoxDecoration(
        color: kNavy.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasLogo
          ? CachedNetworkImage(
              imageUrl: logoUrl!,
              fit: BoxFit.cover,
              placeholder: (_, _) => fallback,
              errorWidget: (_, _, _) => fallback,
            )
          : fallback,
    );
  }
}

// ─── Grille d'infos responsive (1 ou 2 colonnes selon largeur) ───────────────
class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.rows});
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, c) {
      if (c.maxWidth < 640) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
      }
      final pairs = <Widget>[];
      for (int i = 0; i < rows.length; i += 2) {
        pairs.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: rows[i]),
          const SizedBox(width: 28),
          Expanded(child: i + 1 < rows.length ? rows[i + 1] : const SizedBox()),
        ]));
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: pairs);
    });
  }
}

class _GeneralPrefsCard extends ConsumerStatefulWidget {
  const _GeneralPrefsCard({required this.initial});
  final GeneralSettings initial;

  @override
  ConsumerState<_GeneralPrefsCard> createState() => _GeneralPrefsCardState();
}

class _GeneralPrefsCardState extends ConsumerState<_GeneralPrefsCard> {
  late GeneralSettings _s = widget.initial;
  bool _saving = false;
  String? _error;

  static const _months = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
  ];
  static const _weekDays = [
    (1, 'Lundi'), (7, 'Dimanche'),
  ];

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      // Patch : ne réécrire que les champs régionaux pour ne pas écraser
      // la pédagogie / politique de frais (même blob group_settings.general).
      final current = await ref.read(adminGroupSettingsProvider.future);
      final merged = current.general.copyWith(
        defaultLanguage:        _s.defaultLanguage,
        timezone:               _s.timezone,
        dateFormat:             _s.dateFormat,
        academicYearStartMonth: _s.academicYearStartMonth,
        currencyDisplay:        _s.currencyDisplay,
        weekStartsOn:           _s.weekStartsOn,
      );
      await ref.read(adminSettingsServiceProvider).saveGeneral(merged);
      if (mounted) _toast(context, 'Préférences générales enregistrées.');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const AdminSectionTitle('Préférences régionales',
            icon: Icons.public_rounded,
            subtitle: 'Langue, fuseau, format de date et année scolaire'),
        const SizedBox(height: 8),
        _SettingDropdown<String>(
          label: 'Langue par défaut',
          icon: Icons.translate_rounded,
          value: _s.defaultLanguage,
          items: const [
            DropdownMenuItem(value: 'fr', child: Text('Français')),
            DropdownMenuItem(value: 'en', child: Text('English')),
          ],
          onChanged: (v) => v == null ? null : setState(() => _s = _s.copyWith(defaultLanguage: v)),
        ),
        _SettingDropdown<String>(
          label: 'Fuseau horaire',
          icon: Icons.schedule_rounded,
          value: _s.timezone,
          items: const [
            DropdownMenuItem(value: 'Africa/Brazzaville', child: Text('Brazzaville (GMT+1)')),
            DropdownMenuItem(value: 'Africa/Kinshasa', child: Text('Kinshasa (GMT+1)')),
            DropdownMenuItem(value: 'UTC', child: Text('UTC')),
          ],
          onChanged: (v) => v == null ? null : setState(() => _s = _s.copyWith(timezone: v)),
        ),
        _SettingDropdown<String>(
          label: 'Format de date',
          icon: Icons.calendar_month_rounded,
          value: _s.dateFormat,
          items: const [
            DropdownMenuItem(value: 'dd/MM/yyyy', child: Text('31/12/2026')),
            DropdownMenuItem(value: 'yyyy-MM-dd', child: Text('2026-12-31')),
            DropdownMenuItem(value: 'dd MMM yyyy', child: Text('31 déc. 2026')),
          ],
          onChanged: (v) => v == null ? null : setState(() => _s = _s.copyWith(dateFormat: v)),
        ),
        _SettingDropdown<int>(
          label: "Début de l'année scolaire",
          icon: Icons.school_outlined,
          value: _s.academicYearStartMonth,
          items: [
            for (var m = 1; m <= 12; m++)
              DropdownMenuItem(value: m, child: Text(_months[m - 1])),
          ],
          onChanged: (v) => v == null ? null : setState(() => _s = _s.copyWith(academicYearStartMonth: v)),
        ),
        _SettingDropdown<int>(
          label: 'Premier jour de la semaine',
          icon: Icons.view_week_outlined,
          value: _s.weekStartsOn,
          items: [
            for (final d in _weekDays) DropdownMenuItem(value: d.$1, child: Text(d.$2)),
          ],
          onChanged: (v) => v == null ? null : setState(() => _s = _s.copyWith(weekStartsOn: v)),
        ),
        _SettingDropdown<String>(
          label: 'Affichage de la devise',
          icon: Icons.payments_outlined,
          value: _s.currencyDisplay,
          items: const [
            DropdownMenuItem(value: 'XAF', child: Text('XAF')),
            DropdownMenuItem(value: 'FCFA', child: Text('FCFA')),
          ],
          onChanged: (v) => v == null ? null : setState(() => _s = _s.copyWith(currencyDisplay: v)),
        ),
        const SizedBox(height: 16),
        _SaveBar(saving: _saving, onSave: _save, error: _error),
      ]),
    );
  }
}

// ─── Aperçu temps réel : écoles, utilisateurs, quotas du plan ────────────────
class _GroupStatsCard extends ConsumerWidget {
  const _GroupStatsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminGroupStatsProvider);
    return AdminCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const AdminSectionTitle('Aperçu du groupe',
            icon: Icons.insights_outlined,
            subtitle: 'Écoles, utilisateurs et quotas du plan'),
        const SizedBox(height: 16),
        statsAsync.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(color: kNavy)),
          ),
          error: (_, _) => const AdminErrorBanner(message: 'Statistiques indisponibles.'),
          data: (s) => _body(s),
        ),
      ]),
    );
  }

  Widget _body(GroupStats s) {
    return LayoutBuilder(builder: (ctx, c) {
      final twoCol = c.maxWidth >= 700;
      final ecoles = AdminStatCard(
        label: 'Écoles actives',
        value: '${s.activeSchools}/${s.totalSchools}',
        icon: Icons.apartment_rounded,
        color: kNavy,
        subtitle: 'sur ${s.totalSchools} école(s)',
      );
      final users = AdminStatCard(
        label: 'Utilisateurs',
        value: '${s.totalUsers}',
        icon: Icons.groups_rounded,
        color: kGreen,
        subtitle: '${s.activeUsers} actif(s)',
      );
      final qEcoles = _QuotaBar(
        label: 'Quota écoles',
        used: s.activeSchools,
        max: s.planMaxSchools,
        pct: s.schoolQuotaPct,
      );
      final qUsers = _QuotaBar(
        label: 'Quota utilisateurs',
        used: s.totalUsers,
        max: s.planMaxUsers,
        pct: s.userQuotaPct,
      );
      if (twoCol) {
        return Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: ecoles),
            const SizedBox(width: 14),
            Expanded(child: users),
          ]),
          const SizedBox(height: 18),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: qEcoles),
            const SizedBox(width: 28),
            Expanded(child: qUsers),
          ]),
        ]);
      }
      return Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: ecoles),
          const SizedBox(width: 14),
          Expanded(child: users),
        ]),
        const SizedBox(height: 18),
        qEcoles,
        const SizedBox(height: 16),
        qUsers,
      ]);
    });
  }
}

class _QuotaBar extends StatelessWidget {
  const _QuotaBar({
    required this.label,
    required this.used,
    required this.max,
    required this.pct,
  });
  final String label;
  final int used;
  final int max;
  final double pct;

  @override
  Widget build(BuildContext context) {
    final hasQuota = max > 0;
    final nearLimit = pct >= 0.9;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w600, color: kTextPrimary)),
        ),
        Text(hasQuota ? '$used / $max' : '$used',
            style: const TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w800, color: kTextPrimary)),
        if (hasQuota) ...[
          const SizedBox(width: 8),
          AdminBadge('${(pct * 100).round()} %',
              color: nearLimit ? kRed : (pct >= 0.7 ? kAccent : kGreen)),
        ],
      ]),
      const SizedBox(height: 7),
      AdminProgressBar(value: used, max: hasQuota ? max : 1),
      if (nearLimit && hasQuota) ...[
        const SizedBox(height: 6),
        Text('Quota presque atteint — envisagez de relever votre plan.',
            style: TextStyle(fontSize: 11, color: kRed.withValues(alpha: 0.9))),
      ],
    ]);
  }
}

// ─── Paramètres pédagogiques (group_settings.general) ────────────────────────
class _PedagogyCard extends ConsumerStatefulWidget {
  const _PedagogyCard({required this.initial});
  final GeneralSettings initial;

  @override
  ConsumerState<_PedagogyCard> createState() => _PedagogyCardState();
}

class _PedagogyCardState extends ConsumerState<_PedagogyCard> {
  late GeneralSettings _s = widget.initial;
  bool _saving = false;
  String? _error;

  bool get _numericGrading =>
      _s.gradingSystem == 'numeric_20' || _s.gradingSystem == 'numeric_10';

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      final current = await ref.read(adminGroupSettingsProvider.future);
      final merged = current.general.copyWith(
        gradingSystem:                _s.gradingSystem,
        gradingMaxScore:              _s.gradingMaxScore,
        defaultCourseDurationMinutes: _s.defaultCourseDurationMinutes,
        trimesterCount:               _s.trimesterCount,
      );
      await ref.read(adminSettingsServiceProvider).saveGeneral(merged);
      if (mounted) _toast(context, 'Paramètres pédagogiques enregistrés.');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const AdminSectionTitle('Paramètres pédagogiques',
            icon: Icons.school_rounded,
            subtitle: "Notation, durée des cours et découpage de l'année"),
        const SizedBox(height: 8),
        _SettingDropdown<String>(
          label: 'Système de notation',
          icon: Icons.grade_outlined,
          value: _s.gradingSystem,
          items: const [
            DropdownMenuItem(value: 'numeric_20', child: Text('Numérique sur 20')),
            DropdownMenuItem(value: 'numeric_10', child: Text('Numérique sur 10')),
            DropdownMenuItem(value: 'letter', child: Text('Lettres (A–F)')),
            DropdownMenuItem(value: 'competence', child: Text('Par compétences')),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              final next = v == 'numeric_10'
                  ? 10
                  : v == 'numeric_20'
                      ? 20
                      : _s.gradingMaxScore;
              _s = _s.copyWith(gradingSystem: v, gradingMaxScore: next);
            });
          },
        ),
        if (_numericGrading)
          _NumberStepper(
            icon: Icons.straighten_rounded,
            title: 'Note maximale',
            subtitle: 'Barème de référence des évaluations',
            value: _s.gradingMaxScore,
            min: 10,
            max: 100,
            step: 5,
            suffix: 'pts',
            onChanged: (v) => setState(() => _s = _s.copyWith(gradingMaxScore: v)),
          ),
        _NumberStepper(
          icon: Icons.timelapse_rounded,
          title: "Durée d'un cours",
          subtitle: "Créneau standard à l'emploi du temps",
          value: _s.defaultCourseDurationMinutes,
          min: 30,
          max: 120,
          step: 5,
          suffix: 'min',
          onChanged: (v) => setState(() => _s = _s.copyWith(defaultCourseDurationMinutes: v)),
        ),
        _NumberStepper(
          icon: Icons.calendar_view_month_rounded,
          title: 'Périodes par année',
          subtitle: 'Trimestres ou semestres scolaires',
          value: _s.trimesterCount,
          min: 2,
          max: 3,
          suffix: 'périodes',
          onChanged: (v) => setState(() => _s = _s.copyWith(trimesterCount: v)),
        ),
        const SizedBox(height: 16),
        _SaveBar(saving: _saving, onSave: _save, error: _error),
      ]),
    );
  }
}

class _AppearanceCard extends ConsumerWidget {
  const _AppearanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return AdminCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const AdminSectionTitle('Apparence', icon: Icons.palette_outlined),
        const SizedBox(height: 8),
        _ToggleRow(
          icon: Icons.dark_mode_outlined,
          title: 'Mode sombre',
          subtitle: 'Basculer entre le thème clair et sombre',
          value: themeMode == ThemeMode.dark,
          onChanged: (v) => ref.read(themeModeProvider.notifier).state =
              v ? ThemeMode.dark : ThemeMode.light,
        ),
      ]),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard();

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const AdminSectionTitle('Mon compte', icon: Icons.manage_accounts_outlined),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.person_outline_rounded, color: kNavy),
          title: const Text('Mon profil', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: const Text('Nom, téléphone, mot de passe',
              style: TextStyle(fontSize: 12, color: kTextMuted)),
          trailing: const Icon(Icons.chevron_right_rounded, color: kTextMuted),
          onTap: () => context.go(Routes.adminProfil),
        ),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ONGLET 2 — FACTURATION  (payment_configs — CRUD réel)
// ═════════════════════════════════════════════════════════════════════════════
class _BillingTab extends ConsumerWidget {
  const _BillingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configs = ref.watch(adminPaymentConfigsProvider);
    final settings = ref.watch(adminGroupSettingsProvider);

    return _TabScaffold(
      onRefresh: () async {
        ref.invalidate(adminPaymentConfigsProvider);
        ref.invalidate(adminGroupSettingsProvider);
        await Future.wait([
          ref.read(adminPaymentConfigsProvider.future),
          ref.read(adminGroupSettingsProvider.future),
        ]);
      },
      children: [
        AdminCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AdminSectionTitle(
              'Moyens de paiement',
              icon: Icons.account_balance_wallet_outlined,
              subtitle: 'Configurez la collecte des frais scolaires',
              trailing: AdminActionButton(
                label: 'Ajouter',
                icon: Icons.add_rounded,
                onPressed: () => _openEditor(context),
              ),
            ),
            const SizedBox(height: 16),
            configs.when(
              skipLoadingOnReload: true,
              skipLoadingOnRefresh: true,
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(color: kNavy)),
              ),
              error: (e, _) => AdminErrorBanner(message: 'Erreur : $e'),
              data: (list) => list.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: AdminEmptyState(
                        icon: Icons.payments_outlined,
                        title: 'Aucun moyen de paiement',
                        message:
                            'Ajoutez MTN Money, Airtel Money, carte bancaire ou espèces pour encaisser les frais de scolarité.',
                      ),
                    )
                  : Column(
                      children: [
                        for (final c in list) _PaymentTile(config: c),
                      ],
                    ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kAccent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kAccent.withValues(alpha: 0.3)),
          ),
          child: const Row(children: [
            Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFB7791F)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Les clés secrètes sont masquées. Activez le mode test pour valider une intégration avant la mise en production.',
                style: TextStyle(fontSize: 12, color: Color(0xFF92651A)),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        // ── Politique de frais & remises (group_settings.general) ───────────
        settings.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => const _CardLoader(),
          error: (e, _) => AdminCard(child: AdminErrorBanner(message: 'Erreur : $e')),
          data: (s) => _FeePolicyCard(initial: s.general),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  void _openEditor(BuildContext context, {PaymentConfig? config}) {
    showDialog(
      context: context,
      builder: (_) => _PaymentEditorDialog(existing: config),
    );
  }
}

// ─── Politique de frais & remises (group_settings.general) ───────────────────
class _FeePolicyCard extends ConsumerStatefulWidget {
  const _FeePolicyCard({required this.initial});
  final GeneralSettings initial;

  @override
  ConsumerState<_FeePolicyCard> createState() => _FeePolicyCardState();
}

class _FeePolicyCardState extends ConsumerState<_FeePolicyCard> {
  late GeneralSettings _s = widget.initial;
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      final current = await ref.read(adminGroupSettingsProvider.future);
      final merged = current.general.copyWith(
        defaultInstallments:    _s.defaultInstallments,
        lateFeeRatePercent:     _s.lateFeeRatePercent,
        lateGraceDays:          _s.lateGraceDays,
        siblingDiscountPercent: _s.siblingDiscountPercent,
        scholarshipMaxPercent:  _s.scholarshipMaxPercent,
      );
      await ref.read(adminSettingsServiceProvider).saveGeneral(merged);
      if (mounted) _toast(context, 'Politique de frais enregistrée.');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const AdminSectionTitle('Politique de frais & remises',
            icon: Icons.policy_outlined,
            subtitle: 'Échéancier, pénalités de retard et remises par défaut'),
        const SizedBox(height: 4),
        _NumberStepper(
          icon: Icons.event_repeat_rounded,
          title: 'Échéances par défaut',
          subtitle: 'Tranches de paiement proposées aux familles',
          value: _s.defaultInstallments,
          min: 1,
          max: 12,
          suffix: 'tranches',
          onChanged: (v) => setState(() => _s = _s.copyWith(defaultInstallments: v)),
        ),
        _NumberStepper(
          icon: Icons.percent_rounded,
          title: 'Pénalité de retard',
          subtitle: 'Majoration appliquée aux frais impayés',
          value: _s.lateFeeRatePercent,
          min: 0,
          max: 50,
          suffix: '%',
          onChanged: (v) => setState(() => _s = _s.copyWith(lateFeeRatePercent: v)),
        ),
        _NumberStepper(
          icon: Icons.timer_outlined,
          title: 'Délai de grâce',
          subtitle: 'Jours avant application de la pénalité',
          value: _s.lateGraceDays,
          min: 0,
          max: 90,
          step: 5,
          suffix: 'jours',
          onChanged: (v) => setState(() => _s = _s.copyWith(lateGraceDays: v)),
        ),
        _NumberStepper(
          icon: Icons.family_restroom_rounded,
          title: 'Remise fratrie',
          subtitle: "Réduction pour élèves d'une même famille",
          value: _s.siblingDiscountPercent,
          min: 0,
          max: 100,
          step: 5,
          suffix: '%',
          onChanged: (v) => setState(() => _s = _s.copyWith(siblingDiscountPercent: v)),
        ),
        _NumberStepper(
          icon: Icons.volunteer_activism_outlined,
          title: 'Plafond de bourse',
          subtitle: 'Prise en charge maximale par bourse',
          value: _s.scholarshipMaxPercent,
          min: 0,
          max: 100,
          step: 5,
          suffix: '%',
          onChanged: (v) => setState(() => _s = _s.copyWith(scholarshipMaxPercent: v)),
        ),
        const SizedBox(height: 16),
        _SaveBar(saving: _saving, onSave: _save, error: _error),
      ]),
    );
  }
}

class _PaymentTile extends ConsumerStatefulWidget {
  const _PaymentTile({required this.config});
  final PaymentConfig config;

  @override
  ConsumerState<_PaymentTile> createState() => _PaymentTileState();
}

class _PaymentTileState extends ConsumerState<_PaymentTile> {
  bool _busy = false;

  IconData get _icon => switch (widget.config.provider) {
        PaymentProvider.mtnMoney => Icons.phone_android_rounded,
        PaymentProvider.airtelMoney => Icons.phone_android_rounded,
        PaymentProvider.visa => Icons.credit_card_rounded,
        PaymentProvider.especes => Icons.payments_rounded,
      };

  Future<void> _toggle(bool v) async {
    final c = widget.config;
    if (c.id == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(adminSettingsServiceProvider).setPaymentActive(c.id!, v);
    } catch (e) {
      if (mounted) _toast(context, 'Échec : $e', ok: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final c = widget.config;
    if (c.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Supprimer ce moyen de paiement ?'),
        content: Text('« ${c.displayName} » sera définitivement retiré.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler', style: TextStyle(color: kTextMuted)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: kRed),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(adminSettingsServiceProvider).deletePaymentConfig(c.id!);
      if (mounted) _toast(context, 'Moyen de paiement supprimé.');
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _toast(context, 'Échec : $e', ok: false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.config;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: kNavy.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_icon, color: kNavy, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(c.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextPrimary)),
              ),
              const SizedBox(width: 8),
              if (c.isTestMode) const AdminBadge('TEST', color: kAccent),
            ]),
            const SizedBox(height: 2),
            Text(c.provider.label, style: const TextStyle(fontSize: 12, color: kTextMuted)),
          ]),
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: kNavy)),
          )
        else ...[
          Switch(
            value: c.isActive,
            activeThumbColor: kGreen,
            onChanged: _toggle,
          ),
          AdminModalIconBtn(
            icon: Icons.edit_outlined,
            color: kNavy,
            tooltip: 'Modifier',
            onTap: () => showDialog(
              context: context,
              builder: (_) => _PaymentEditorDialog(existing: c),
            ),
          ),
          const SizedBox(width: 6),
          AdminModalIconBtn(
            icon: Icons.delete_outline_rounded,
            color: kRed,
            tooltip: 'Supprimer',
            onTap: _delete,
          ),
        ],
      ]),
    );
  }
}

// ─── Éditeur (ajout / modification) de moyen de paiement ─────────────────────
class _PaymentEditorDialog extends ConsumerStatefulWidget {
  const _PaymentEditorDialog({this.existing});
  final PaymentConfig? existing;

  @override
  ConsumerState<_PaymentEditorDialog> createState() => _PaymentEditorDialogState();
}

class _PaymentEditorDialogState extends ConsumerState<_PaymentEditorDialog> {
  late PaymentProvider _provider;
  late final TextEditingController _name;
  late final TextEditingController _apiKey;
  late final TextEditingController _apiSecret;
  late final TextEditingController _merchant;
  late final TextEditingController _webhook;
  late final TextEditingController _notes;
  late bool _active;
  late bool _testMode;
  bool _showSecret = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _provider = e?.provider ?? PaymentProvider.mtnMoney;
    _name = TextEditingController(text: e?.displayName ?? '');
    _apiKey = TextEditingController(text: e?.apiKey ?? '');
    _apiSecret = TextEditingController(text: e?.apiSecret ?? '');
    _merchant = TextEditingController(text: e?.merchantId ?? '');
    _webhook = TextEditingController(text: e?.webhookUrl ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _active = e?.isActive ?? false;
    _testMode = e?.isTestMode ?? true;
    if (_name.text.isEmpty) _name.text = _provider.label;
  }

  @override
  void dispose() {
    _name.dispose();
    _apiKey.dispose();
    _apiSecret.dispose();
    _merchant.dispose();
    _webhook.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = "Le nom d'affichage est obligatoire");
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await ref.read(adminSettingsServiceProvider).savePaymentConfig(PaymentConfig(
            id: widget.existing?.id,
            provider: _provider,
            displayName: _name.text.trim(),
            apiKey: _apiKey.text,
            apiSecret: _apiSecret.text,
            merchantId: _merchant.text,
            webhookUrl: _webhook.text,
            isActive: _active,
            isTestMode: _testMode,
            notes: _notes.text,
          ));
      if (mounted) {
        Navigator.of(context).pop();
        _toast(context, widget.existing == null
            ? 'Moyen de paiement ajouté.'
            : 'Moyen de paiement mis à jour.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final apiBased = _provider.isApiBased;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AdminDialogHeader(
            title: widget.existing == null ? 'Ajouter un moyen de paiement' : 'Modifier le moyen de paiement',
            icon: Icons.account_balance_wallet_outlined,
            subtitle: 'Collecte des frais de scolarité',
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<PaymentProvider>(
                  initialValue: _provider,
                  isExpanded: true,
                  decoration: adminInputDecoration('Fournisseur', icon: Icons.bolt_rounded),
                  items: [
                    for (final p in PaymentProvider.values)
                      DropdownMenuItem(value: p, child: Text(p.label)),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      final wasDefault = _name.text.trim() == _provider.label || _name.text.trim().isEmpty;
                      _provider = v;
                      if (wasDefault) _name.text = v.label;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _name,
                  decoration: adminInputDecoration("Nom d'affichage", icon: Icons.label_outline_rounded),
                ),
                if (apiBased) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _apiKey,
                    decoration: adminInputDecoration('Clé API', icon: Icons.vpn_key_outlined),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _apiSecret,
                    obscureText: !_showSecret,
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: adminInputDecoration('Clé secrète', icon: Icons.password_rounded).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(_showSecret ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            size: 19, color: kTextMuted),
                        onPressed: () => setState(() => _showSecret = !_showSecret),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _merchant,
                    decoration: adminInputDecoration('Identifiant marchand', icon: Icons.store_outlined),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _webhook,
                    keyboardType: TextInputType.url,
                    decoration: adminInputDecoration('URL de webhook', icon: Icons.link_rounded,
                        hint: 'https://…'),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _notes,
                  maxLines: 2,
                  decoration: adminInputDecoration('Notes (interne)', icon: Icons.notes_rounded),
                ),
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: kGreen,
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                  title: const Text('Actif', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Disponible pour encaisser les paiements',
                      style: TextStyle(fontSize: 11.5, color: kTextMuted)),
                ),
                if (apiBased)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: kAccent,
                    value: _testMode,
                    onChanged: (v) => setState(() => _testMode = v),
                    title: const Text('Mode test', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Sandbox — aucune transaction réelle',
                        style: TextStyle(fontSize: 11.5, color: kTextMuted)),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  AdminErrorBanner(message: _error!),
                ],
              ]),
            ),
          ),
          AdminDialogFooter(
            saving: _saving,
            submitLabel: widget.existing == null ? 'Ajouter' : 'Enregistrer',
            submitIcon: Icons.save_rounded,
            onCancel: () => Navigator.of(context).pop(),
            onSubmit: _submit,
          ),
        ]),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ONGLET 3 — NOTIFICATIONS  (group_settings.notifications)
// ═════════════════════════════════════════════════════════════════════════════
class _NotificationsTab extends ConsumerWidget {
  const _NotificationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(adminGroupSettingsProvider);
    return _TabScaffold(
      onRefresh: () async {
        ref.invalidate(adminGroupSettingsProvider);
        await ref.read(adminGroupSettingsProvider.future);
      },
      children: [
        settings.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => const _CardLoader(),
          error: (e, _) => AdminCard(child: AdminErrorBanner(message: 'Erreur : $e')),
          data: (s) => _NotificationsCard(initial: s.notifications),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _NotificationsCard extends ConsumerStatefulWidget {
  const _NotificationsCard({required this.initial});
  final NotificationSettings initial;

  @override
  ConsumerState<_NotificationsCard> createState() => _NotificationsCardState();
}

class _NotificationsCardState extends ConsumerState<_NotificationsCard> {
  late NotificationSettings _s = widget.initial;
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      await ref.read(adminSettingsServiceProvider).saveNotifications(_s);
      if (mounted) _toast(context, 'Préférences de notification enregistrées.');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AdminCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const AdminSectionTitle('Canaux de notification',
              icon: Icons.campaign_outlined,
              subtitle: 'Comment le groupe est notifié'),
          const SizedBox(height: 8),
          _ToggleRow(
            icon: Icons.email_outlined,
            title: 'Email',
            subtitle: 'Notifications par courriel',
            value: _s.emailEnabled,
            onChanged: (v) => setState(() => _s = _s.copyWith(emailEnabled: v)),
          ),
          _ToggleRow(
            icon: Icons.sms_outlined,
            title: 'SMS',
            subtitle: 'Notifications par message texte',
            value: _s.smsEnabled,
            onChanged: (v) => setState(() => _s = _s.copyWith(smsEnabled: v)),
          ),
          _ToggleRow(
            icon: Icons.notifications_active_outlined,
            title: 'Push',
            subtitle: "Notifications dans l'application mobile",
            value: _s.pushEnabled,
            onChanged: (v) => setState(() => _s = _s.copyWith(pushEnabled: v)),
          ),
        ]),
      ),
      const SizedBox(height: 20),
      AdminCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const AdminSectionTitle('Événements suivis',
              icon: Icons.event_note_outlined,
              subtitle: 'Déclencheurs envoyant une notification'),
          const SizedBox(height: 8),
          _ToggleRow(
            icon: Icons.how_to_reg_outlined,
            title: 'Nouvelle inscription',
            subtitle: 'À chaque élève inscrit',
            value: _s.notifyNewEnrollment,
            onChanged: (v) => setState(() => _s = _s.copyWith(notifyNewEnrollment: v)),
          ),
          _ToggleRow(
            icon: Icons.payments_outlined,
            title: 'Paiement reçu',
            subtitle: 'À chaque encaissement de frais',
            value: _s.notifyPaymentReceived,
            onChanged: (v) => setState(() => _s = _s.copyWith(notifyPaymentReceived: v)),
          ),
          _ToggleRow(
            icon: Icons.person_off_outlined,
            title: 'Absence',
            subtitle: "À chaque absence d'élève signalée",
            value: _s.notifyAbsence,
            onChanged: (v) => setState(() => _s = _s.copyWith(notifyAbsence: v)),
          ),
          _ToggleRow(
            icon: Icons.trending_down_rounded,
            title: 'Assiduité faible',
            subtitle: "Alerte quand l'assiduité chute",
            value: _s.notifyLowAttendance,
            onChanged: (v) => setState(() => _s = _s.copyWith(notifyLowAttendance: v)),
          ),
        ]),
      ),
      const SizedBox(height: 20),
      AdminCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const AdminSectionTitle('Résumé quotidien',
              icon: Icons.summarize_outlined),
          const SizedBox(height: 8),
          _ToggleRow(
            icon: Icons.schedule_send_outlined,
            title: 'Activer le résumé quotidien',
            subtitle: 'Un récapitulatif envoyé chaque jour',
            value: _s.dailyDigest,
            onChanged: (v) => setState(() => _s = _s.copyWith(dailyDigest: v)),
          ),
          if (_s.dailyDigest)
            _NumberStepper(
              icon: Icons.access_time_rounded,
              title: "Heure d'envoi",
              subtitle: 'Heure locale du résumé',
              value: _s.digestHour,
              min: 0,
              max: 23,
              suffix: 'h',
              onChanged: (v) => setState(() => _s = _s.copyWith(digestHour: v)),
            ),
        ]),
      ),
      const SizedBox(height: 20),
      // ── Seuils d'alerte ────────────────────────────────────────────────────
      AdminCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const AdminSectionTitle("Seuils d'alerte",
              icon: Icons.warning_amber_rounded,
              subtitle: 'Déclenchent une alerte automatique au franchissement'),
          const SizedBox(height: 4),
          _NumberStepper(
            icon: Icons.event_available_outlined,
            title: "Seuil d'assiduité",
            subtitle: 'Alerter sous ce taux de présence',
            value: _s.attendanceAlertThreshold,
            min: 50,
            max: 100,
            step: 5,
            suffix: '%',
            onChanged: (v) => setState(() => _s = _s.copyWith(attendanceAlertThreshold: v)),
          ),
          _NumberStepper(
            icon: Icons.trending_down_rounded,
            title: 'Seuil de note',
            subtitle: 'Alerter sous cette moyenne (sur 20)',
            value: _s.gradeAlertThreshold,
            min: 0,
            max: 20,
            suffix: '/20',
            onChanged: (v) => setState(() => _s = _s.copyWith(gradeAlertThreshold: v)),
          ),
          _NumberStepper(
            icon: Icons.money_off_csred_rounded,
            title: 'Retard de paiement',
            subtitle: "Alerter après ce délai d'impayé",
            value: _s.unpaidAlertDays,
            min: 7,
            max: 120,
            suffix: 'jours',
            onChanged: (v) => setState(() => _s = _s.copyWith(unpaidAlertDays: v)),
          ),
        ]),
      ),
      const SizedBox(height: 20),
      // ── Rappels automatiques de paiement ───────────────────────────────────
      AdminCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const AdminSectionTitle('Rappels automatiques de paiement',
              icon: Icons.notification_important_outlined,
              subtitle: 'Relances envoyées aux familles ayant un solde dû'),
          const SizedBox(height: 8),
          _ToggleRow(
            icon: Icons.autorenew_rounded,
            title: 'Activer les rappels',
            subtitle: "Programme jusqu'à trois relances échelonnées",
            value: _s.billingReminderEnabled,
            onChanged: (v) => setState(() => _s = _s.copyWith(billingReminderEnabled: v)),
          ),
          if (_s.billingReminderEnabled) ...[
            _NumberStepper(
              icon: Icons.looks_one_outlined,
              title: 'Premier rappel',
              subtitle: "Jours après l'émission de la facture",
              value: _s.billingReminderDay1,
              min: 1,
              max: 90,
              suffix: 'j',
              onChanged: (v) => setState(() => _s = _s.copyWith(billingReminderDay1: v)),
            ),
            _NumberStepper(
              icon: Icons.looks_two_outlined,
              title: 'Deuxième rappel',
              subtitle: "Jours après l'émission de la facture",
              value: _s.billingReminderDay2,
              min: 1,
              max: 120,
              suffix: 'j',
              onChanged: (v) => setState(() => _s = _s.copyWith(billingReminderDay2: v)),
            ),
            _NumberStepper(
              icon: Icons.looks_3_outlined,
              title: 'Dernier rappel',
              subtitle: "Jours après l'émission de la facture",
              value: _s.billingReminderDay3,
              min: 1,
              max: 180,
              suffix: 'j',
              onChanged: (v) => setState(() => _s = _s.copyWith(billingReminderDay3: v)),
            ),
          ],
        ]),
      ),
      const SizedBox(height: 20),
      // ── Destinataires par rôle ─────────────────────────────────────────────
      AdminCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const AdminSectionTitle('Destinataires par rôle',
              icon: Icons.groups_2_outlined,
              subtitle: 'Qui reçoit chaque type de notification'),
          const SizedBox(height: 8),
          _ToggleRow(
            icon: Icons.account_balance_outlined,
            title: 'Directeur — paiements',
            subtitle: 'Notifier le directeur à chaque encaissement',
            value: _s.notifyDirectorOnPayment,
            onChanged: (v) => setState(() => _s = _s.copyWith(notifyDirectorOnPayment: v)),
          ),
          _ToggleRow(
            icon: Icons.person_off_outlined,
            title: 'Directeur — absences',
            subtitle: 'Notifier le directeur des absences signalées',
            value: _s.notifyDirectorOnAbsence,
            onChanged: (v) => setState(() => _s = _s.copyWith(notifyDirectorOnAbsence: v)),
          ),
          _ToggleRow(
            icon: Icons.calculate_outlined,
            title: 'Comptable — paiements',
            subtitle: 'Notifier le comptable à chaque encaissement',
            value: _s.notifyAccountantOnPayment,
            onChanged: (v) => setState(() => _s = _s.copyWith(notifyAccountantOnPayment: v)),
          ),
          _ToggleRow(
            icon: Icons.co_present_outlined,
            title: 'Enseignant — absences',
            subtitle: "Notifier l'enseignant des absences de sa classe",
            value: _s.notifyTeacherOnAbsence,
            onChanged: (v) => setState(() => _s = _s.copyWith(notifyTeacherOnAbsence: v)),
          ),
        ]),
      ),
      const SizedBox(height: 20),
      _SaveBar(saving: _saving, onSave: _save, error: _error),
      const SizedBox(height: 24),
    ]);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ONGLET 4 — SÉCURITÉ  (group_settings.security)
// ═════════════════════════════════════════════════════════════════════════════
class _SecurityTab extends ConsumerWidget {
  const _SecurityTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(adminGroupSettingsProvider);
    return _TabScaffold(
      onRefresh: () async {
        ref.invalidate(adminGroupSettingsProvider);
        ref.invalidate(adminRecentLoginsProvider);
        await ref.read(adminGroupSettingsProvider.future);
      },
      children: [
        settings.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => const _CardLoader(),
          error: (e, _) => AdminCard(child: AdminErrorBanner(message: 'Erreur : $e')),
          data: (s) => _SecurityCard(initial: s.security),
        ),
        const SizedBox(height: 20),
        const _RecentLoginsCard(),
        const SizedBox(height: 20),
        const _RgpdActionsCard(),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _SecurityCard extends ConsumerStatefulWidget {
  const _SecurityCard({required this.initial});
  final SecuritySettings initial;

  @override
  ConsumerState<_SecurityCard> createState() => _SecurityCardState();
}

class _SecurityCardState extends ConsumerState<_SecurityCard> {
  late SecuritySettings _s = widget.initial;
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      await ref.read(adminSettingsServiceProvider).saveSecurity(_s);
      if (mounted) _toast(context, 'Paramètres de sécurité enregistrés.');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AdminCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const AdminSectionTitle('Politique de mot de passe',
              icon: Icons.password_rounded),
          const SizedBox(height: 4),
          _NumberStepper(
            icon: Icons.straighten_rounded,
            title: 'Longueur minimale',
            subtitle: 'Nombre de caractères requis',
            value: _s.minPasswordLength,
            min: 6,
            max: 32,
            suffix: 'car.',
            onChanged: (v) => setState(() => _s = _s.copyWith(minPasswordLength: v)),
          ),
          _ToggleRow(
            icon: Icons.shield_outlined,
            title: 'Mot de passe robuste',
            subtitle: 'Majuscule, chiffre et caractère spécial',
            value: _s.requireStrongPassword,
            onChanged: (v) => setState(() => _s = _s.copyWith(requireStrongPassword: v)),
          ),
        ]),
      ),
      const SizedBox(height: 20),
      AdminCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const AdminSectionTitle('Authentification & sessions',
              icon: Icons.verified_user_outlined),
          const SizedBox(height: 8),
          _ToggleRow(
            icon: Icons.phonelink_lock_outlined,
            title: 'Double authentification (2FA)',
            subtitle: 'Exiger un second facteur à la connexion',
            value: _s.require2fa,
            onChanged: (v) => setState(() => _s = _s.copyWith(require2fa: v)),
          ),
          _ToggleRow(
            icon: Icons.devices_other_outlined,
            title: 'Sessions multiples',
            subtitle: 'Autoriser plusieurs appareils connectés',
            value: _s.allowMultipleSessions,
            onChanged: (v) => setState(() => _s = _s.copyWith(allowMultipleSessions: v)),
          ),
          _NumberStepper(
            icon: Icons.timer_outlined,
            title: 'Expiration de session',
            subtitle: 'Déconnexion après inactivité',
            value: _s.sessionTimeoutMinutes,
            min: 15,
            max: 480,
            step: 15,
            suffix: 'min',
            onChanged: (v) => setState(() => _s = _s.copyWith(sessionTimeoutMinutes: v)),
          ),
          _NumberStepper(
            icon: Icons.lock_clock_outlined,
            title: 'Verrouillage après échecs',
            subtitle: 'Tentatives avant blocage du compte',
            value: _s.lockAfterFailedAttempts,
            min: 3,
            max: 10,
            suffix: 'essais',
            onChanged: (v) => setState(() => _s = _s.copyWith(lockAfterFailedAttempts: v)),
          ),
        ]),
      ),
      const SizedBox(height: 20),
      // ── Conservation & archivage des données ───────────────────────────────
      AdminCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const AdminSectionTitle('Conservation des données',
              icon: Icons.inventory_2_outlined,
              subtitle: 'Durée de rétention et archivage automatique'),
          const SizedBox(height: 4),
          _NumberStepper(
            icon: Icons.folder_special_outlined,
            title: 'Rétention des dossiers',
            subtitle: 'Conservation des données élèves',
            value: _s.dataRetentionMonths,
            min: 12,
            max: 120,
            step: 6,
            suffix: 'mois',
            onChanged: (v) => setState(() => _s = _s.copyWith(dataRetentionMonths: v)),
          ),
          _NumberStepper(
            icon: Icons.history_edu_outlined,
            title: 'Rétention des journaux',
            subtitle: "Conservation de l'historique d'audit",
            value: _s.auditRetentionMonths,
            min: 6,
            max: 84,
            step: 6,
            suffix: 'mois',
            onChanged: (v) => setState(() => _s = _s.copyWith(auditRetentionMonths: v)),
          ),
          _ToggleRow(
            icon: Icons.archive_outlined,
            title: 'Archivage automatique',
            subtitle: 'Archiver les comptes inactifs',
            value: _s.autoArchiveInactive,
            onChanged: (v) => setState(() => _s = _s.copyWith(autoArchiveInactive: v)),
          ),
          if (_s.autoArchiveInactive)
            _NumberStepper(
              icon: Icons.schedule_rounded,
              title: "Seuil d'inactivité",
              subtitle: 'Archiver après cette période sans connexion',
              value: _s.archiveAfterMonths,
              min: 3,
              max: 36,
              step: 3,
              suffix: 'mois',
              onChanged: (v) => setState(() => _s = _s.copyWith(archiveAfterMonths: v)),
            ),
        ]),
      ),
      const SizedBox(height: 20),
      _SaveBar(saving: _saving, onSave: _save, error: _error),
      const SizedBox(height: 24),
    ]);
  }
}

// ─── Connexions récentes (lecture seule, profiles.last_login) ────────────────
class _RecentLoginsCard extends ConsumerWidget {
  const _RecentLoginsCard();

  static String _roleLabel(String r) => switch (r) {
        'admin_groupe'   => 'Admin groupe',
        'directeur'      => 'Directeur',
        'censeur'        => 'Censeur',
        'surveillant'    => 'Surveillant',
        'enseignant'     => 'Enseignant',
        'comptable'      => 'Comptable',
        'secretaire'     => 'Secrétaire',
        'econome'        => 'Économe',
        'bibliothecaire' => 'Bibliothécaire',
        'infirmier'      => 'Infirmier',
        'parent'         => 'Parent',
        'eleve'          => 'Élève',
        _                => r,
      };

  static String _ago(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return "à l'instant";
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loginsAsync = ref.watch(adminRecentLoginsProvider);
    return AdminCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const AdminSectionTitle('Connexions récentes',
            icon: Icons.login_rounded,
            subtitle: 'Dernières activités de connexion du groupe'),
        const SizedBox(height: 14),
        loginsAsync.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(color: kNavy)),
          ),
          error: (_, _) => const AdminErrorBanner(message: 'Connexions indisponibles.'),
          data: (list) => list.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Row(children: [
                    Icon(Icons.inbox_outlined, color: kTextMuted, size: 20),
                    SizedBox(width: 10),
                    Text('Aucune connexion enregistrée.',
                        style: TextStyle(fontSize: 13, color: kTextMuted)),
                  ]),
                )
              : Column(children: [for (final l in list) _loginRow(l)]),
        ),
      ]),
    );
  }

  Widget _loginRow(RecentLogin l) {
    final name = l.name.isEmpty ? '—' : l.name;
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty)
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : (name.isNotEmpty && name != '—' ? name[0].toUpperCase() : '?');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: kNavy.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(initials,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: kNavy)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w700, color: kTextPrimary)),
            Text(_roleLabel(l.role),
                style: const TextStyle(fontSize: 12, color: kTextMuted)),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (l.isToday)
            const AdminBadge("Aujourd'hui", color: kGreen)
          else if (l.isThisWeek)
            const AdminBadge('Cette semaine', color: kNavy),
          const SizedBox(height: 4),
          Text(_ago(l.lastLogin),
              style: const TextStyle(fontSize: 11, color: kTextMuted)),
        ]),
      ]),
    );
  }
}

// ─── Conformité & protection des données (actions locales, sans écriture) ────
class _RgpdActionsCard extends StatelessWidget {
  const _RgpdActionsCard();

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const AdminSectionTitle('Conformité & protection des données',
            icon: Icons.gpp_good_outlined,
            subtitle: 'Export et reporting réglementaire'),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kNavy.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(children: [
            Icon(Icons.privacy_tip_outlined, size: 18, color: kNavy),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Les données personnelles des élèves et du personnel sont protégées. '
                'Exportez un dossier complet ou générez un rapport de conformité '
                'à présenter aux autorités.',
                style: TextStyle(fontSize: 12, color: kTextMuted, height: 1.4),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        Wrap(spacing: 12, runSpacing: 12, children: [
          AdminActionButton(
            label: 'Exporter mes données',
            icon: Icons.download_rounded,
            filled: false,
            onPressed: () => _toast(context,
                'Export demandé — vous recevrez le dossier par email sous 24 h.'),
          ),
          AdminActionButton(
            label: 'Rapport de conformité',
            icon: Icons.fact_check_outlined,
            filled: false,
            onPressed: () => _toast(context, 'Génération du rapport de conformité lancée.'),
          ),
        ]),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Widgets partagés locaux
// ═════════════════════════════════════════════════════════════════════════════
class _CardLoader extends StatelessWidget {
  const _CardLoader();
  @override
  Widget build(BuildContext context) => const AdminCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: CircularProgressIndicator(color: kNavy)),
        ),
      );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, required this.icon});
  final String label, value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        Icon(icon, size: 18, color: kTextMuted),
        const SizedBox(width: 12),
        SizedBox(width: 140, child: Text(label, style: const TextStyle(fontSize: 13, color: kTextMuted))),
        Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: kTextPrimary))),
      ]),
    );
  }
}

// ─── Historique des demandes au support ──────────────────────────────────────
class _SupportHistoryCard extends ConsumerWidget {
  const _SupportHistoryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(adminSupportTicketsProvider);
    return AdminCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AdminSectionTitle(
          'Mes demandes au support',
          icon: Icons.support_agent_rounded,
          subtitle: 'Suivi de vos demandes envoyées à la plateforme',
          trailing: OutlinedButton.icon(
            onPressed: () =>
                showDialog(context: context, builder: (_) => const _RequestUpdateDialog()),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Nouvelle demande'),
            style: OutlinedButton.styleFrom(
              foregroundColor: kNavy,
              side: const BorderSide(color: kBorder),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 14),
        ticketsAsync.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(color: kNavy)),
          ),
          error: (_, _) => const AdminErrorBanner(message: 'Impossible de charger les demandes.'),
          data: (tickets) => tickets.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Row(children: [
                    Icon(Icons.inbox_outlined, color: kTextMuted, size: 20),
                    SizedBox(width: 10),
                    Text('Aucune demande envoyée.',
                        style: TextStyle(fontSize: 13, color: kTextMuted)),
                  ]),
                )
              : Column(
                  children: [
                    for (final t in tickets) _SupportTicketRow(ticket: t),
                  ],
                ),
        ),
      ]),
    );
  }
}

class _SupportTicketRow extends StatelessWidget {
  const _SupportTicketRow({required this.ticket});
  final SupportTicketItem ticket;

  (Color, String, IconData) _statusMeta(String s) => switch (s) {
        'open'        => (kAccent,    'En attente',    Icons.hourglass_top_rounded),
        'in_progress' => (kNavy,      'En traitement', Icons.autorenew_rounded),
        'resolved'    => (kGreen,     'Résolu',        Icons.check_circle_rounded),
        'closed'      => (kTextMuted, 'Clôturé',       Icons.check_circle_outline),
        _             => (kTextMuted, ticket.status,   Icons.circle),
      };

  @override
  Widget build(BuildContext context) {
    final t = ticket;
    final (color, label, icon) = _statusMeta(t.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 6),
          Expanded(
            child: Text(t.subject,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: kTextPrimary)),
          ),
          const SizedBox(width: 8),
          AdminBadge(label, color: color),
        ]),
        if (t.body != null && t.body!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(t.body!,
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: kTextMuted, height: 1.4)),
        ],
        if (t.response != null && t.response!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kGreen.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kGreen.withValues(alpha: 0.2)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.support_agent_rounded, size: 15, color: kGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Text(t.response!,
                    style: const TextStyle(fontSize: 12, color: kTextPrimary, height: 1.4)),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          t.createdAt != null
              ? 'Envoyée le ${t.createdAt!.day.toString().padLeft(2, '0')}/'
                '${t.createdAt!.month.toString().padLeft(2, '0')}/${t.createdAt!.year}'
              : '—',
          style: TextStyle(fontSize: 10.5, color: Colors.grey.shade400),
        ),
      ]),
    );
  }
}

// ─── Dialog : demande de modification du groupe (support_tickets) ────────────
class _RequestUpdateDialog extends ConsumerStatefulWidget {
  const _RequestUpdateDialog();

  @override
  ConsumerState<_RequestUpdateDialog> createState() => _RequestUpdateDialogState();
}

class _RequestUpdateDialogState extends ConsumerState<_RequestUpdateDialog> {
  final _msg = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _msg.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_msg.text.trim().isEmpty) {
      setState(() => _error = 'Veuillez décrire la modification souhaitée');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await ref.read(adminSettingsServiceProvider).requestGroupUpdate(_msg.text.trim());
      if (mounted) {
        Navigator.of(context).pop();
        _toast(context, 'Demande envoyée au support.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const AdminDialogHeader(
            title: 'Demander une modification',
            icon: Icons.edit_note_rounded,
            subtitle: "Transmis à l'administration de la plateforme",
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: _msg,
                maxLines: 4,
                inputFormatters: [LengthLimitingTextInputFormatter(800)],
                decoration: adminInputDecoration('Modification souhaitée',
                    hint: 'Ex. : mettre à jour le numéro de téléphone du groupe…'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                AdminErrorBanner(message: _error!),
              ],
            ]),
          ),
          AdminDialogFooter(
            saving: _saving,
            submitLabel: 'Envoyer',
            submitIcon: Icons.send_rounded,
            onCancel: () => Navigator.of(context).pop(),
            onSubmit: _submit,
          ),
        ]),
      ),
    );
  }
}
