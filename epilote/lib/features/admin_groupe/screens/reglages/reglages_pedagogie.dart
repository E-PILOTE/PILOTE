part of '../admin_settings_screen.dart';

// Quotas, pédagogie, apparence et compte.

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
          loading: () => Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
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
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w600, color: kTextPrimary)),
        ),
        Text(hasQuota ? '$used / $max' : '$used',
            style: TextStyle(
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
    final current = ref.watch(themeIdProvider);
    return AdminCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const AdminSectionTitle('Apparence', icon: Icons.palette_outlined),
        const SizedBox(height: 4),
        Text('Votre choix, sur ce poste.',
            style: TextStyle(fontSize: 11.5, color: kTextMuted)),
        const SizedBox(height: 12),
        ThemePicker(
          current: current,
          onPick: (id) => ref.read(themeIdProvider.notifier).set(id),
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
          leading: Icon(Icons.person_outline_rounded, color: kNavy),
          title: const Text('Mon profil', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: Text('Nom, téléphone, mot de passe',
              style: TextStyle(fontSize: 12, color: kTextMuted)),
          trailing: Icon(Icons.chevron_right_rounded, color: kTextMuted),
          onTap: () => context.go(Routes.adminProfil),
        ),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ONGLET 2 — FACTURATION  (payment_configs — CRUD réel)
// ═════════════════════════════════════════════════════════════════════════════
