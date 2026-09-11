part of '../super_dashboard_screen.dart';

// Meilleurs groupes et fil d’activité.

class _BottomRow extends StatelessWidget {
  const _BottomRow({required this.stats});
  final SuperDashboardData stats;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, c) {
    if (c.maxWidth > 760) {
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 4, child: _TopGroupes(stats: stats)),
        const SizedBox(width: 16),
        Expanded(flex: 5, child: _ActivityFeed(stats: stats)),
      ]);
    }
    return Column(children: [
      _TopGroupes(stats: stats),
      const SizedBox(height: 16),
      _ActivityFeed(stats: stats),
    ]);
  });
}

class _TopGroupes extends StatelessWidget {
  const _TopGroupes({required this.stats});
  final SuperDashboardData stats;

  @override
  Widget build(BuildContext context) {
    final all = stats.deptStats.expand((d) => d.groups).toList()
      ..sort((a, b) => b.schoolsCount.compareTo(a.schoolsCount));
    final top = all.take(5).toList();

    return _Card(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const _SectionTitle(icon: Icons.emoji_events_rounded,
              title: 'Top Groupes', sub: "Par nombre d'écoles"),
          const Spacer(),
          TextButton(
            onPressed: () => context.go(Routes.superGroupes),
            style: TextButton.styleFrom(foregroundColor: _kNavy,
                padding: const EdgeInsets.symmetric(horizontal: 8)),
            child: const Text('Voir tout →', style: TextStyle(fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 12),
        if (top.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('Aucune donnée disponible',
                style: TextStyle(color: _kMuted, fontSize: 13))))
        else
          ...top.asMap().entries.map((e) =>
              _TopGroupRow(rank: e.key + 1, g: e.value)),
      ],
    ));
  }
}

class _TopGroupRow extends StatelessWidget {
  const _TopGroupRow({required this.rank, required this.g});
  final int rank; final DeptGroupInfo g;
  static List<Color> get _medals => [
    const Color(0xFFFFD700), const Color(0xFFB0B8C5), const Color(0xFFCD7F32), _kMuted, _kMuted,
  ];
  @override
  Widget build(BuildContext context) {
    final rc = _medals[rank <= 5 ? rank - 1 : 4];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(
          width: 26, height: 26,
          decoration: BoxDecoration(
              color: rc.withValues(alpha: rank <= 3 ? 0.15 : 0.07),
              borderRadius: BorderRadius.circular(7),
              border: rank <= 3
                  ? Border.all(color: rc.withValues(alpha: 0.40)) : null),
          child: Center(child: Text('$rank', style: TextStyle(
              color: rc, fontSize: 11, fontWeight: FontWeight.w800))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(g.name, style: TextStyle(color: _kText, fontSize: 12.5,
                fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
            _PBadge(g.planName),
          ],
        )),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Row(children: [
            Icon(Icons.domain_rounded, size: 12, color: _kMuted),
            const SizedBox(width: 3),
            Text('${g.schoolsCount}', style: TextStyle(
                color: _kText, fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
          Text('école${g.schoolsCount != 1 ? 's' : ''}',
              style: TextStyle(color: _kMuted, fontSize: 10)),
        ]),
      ]),
    );
  }
}

class _ActivityFeed extends StatelessWidget {
  const _ActivityFeed({required this.stats});
  final SuperDashboardData stats;

  // ⚠️ AUCUNE ACTIVITÉ FICTIVE ICI.
  //
  // Cette carte affichait, quand le journal d'audit était vide, cinq
  // événements écrits en dur : « Réseau EDEC Congo », « École Primaire
  // Saint-Pierre », « École Savorgnan de Brazza », un profil « Grace », un
  // plan « Premium ». Sur une plateforme sans le moindre groupe enregistré,
  // le tableau de bord racontait donc une semaine d'exploitation qui n'avait
  // pas eu lieu — avec des noms d'établissements qui n'existent pas. Une
  // pastille « Démo » le signalait, mais une pastille n'annule pas ce que
  // l'œil a lu : devant un ministère, ces cinq lignes appellent des questions
  // auxquelles personne ne peut répondre.
  //
  // Le vide se dit. Il est même informatif : il indique que le journal
  // d'audit n'a encore rien enregistré.

  @override
  Widget build(BuildContext context) {
    final items = stats.recentActivity;
    return _Card(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const _SectionTitle(icon: Icons.history_rounded,
              title: 'Activité récente',
              sub: 'Dernières modifications plateforme'),
          const Spacer(),
          if (items.isNotEmpty)
            TextButton(
              onPressed: () => context.go(Routes.superAudit),
              style: TextButton.styleFrom(foregroundColor: _kNavy,
                  padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: const Text('Journal complet →',
                  style: TextStyle(fontSize: 12)),
            ),
        ]),
        const SizedBox(height: 14),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 22),
            child: Column(children: [
              Icon(Icons.history_toggle_off_rounded, size: 26, color: _kMuted),
              const SizedBox(height: 8),
              Text('Aucune opération enregistrée',
                  style: TextStyle(color: _kText, fontSize: 12.5,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text('Le journal se remplira dès la première création de '
                  'groupe, d\'école ou d\'abonnement.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _kMuted, fontSize: 11.5)),
            ]),
          )
        else
          ...items.map((i) => _ATile(item: i)),
      ],
    ));
  }
}

class _ATile extends StatelessWidget {
  const _ATile({required this.item});
  final ActivityItem item;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
            color: _kNavy.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(9)),
        child: Center(child: Text(item.icon,
            style: const TextStyle(fontSize: 16))),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(text: TextSpan(children: [
            TextSpan(text: '${item.time} · ', style: TextStyle(
                color: _kMuted, fontSize: 11, fontWeight: FontWeight.w500)),
            TextSpan(text: item.title, style: TextStyle(
                color: _kText, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ]), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text('"${item.detail}"', style: TextStyle(
              color: _kMuted, fontSize: 11.5, fontStyle: FontStyle.italic),
              overflow: TextOverflow.ellipsis),
        ],
      )),
    ]),
  );
}

// ─── Widgets communs ──────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: _kCard, borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 16, offset: const Offset(0, 4), spreadRadius: -2)],
    ),
    padding: const EdgeInsets.all(20),
    child: child,
  );
}
