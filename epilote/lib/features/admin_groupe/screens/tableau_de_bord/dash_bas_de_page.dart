part of '../admin_dashboard_screen.dart';

// Meilleures écoles et activité récente.

class _BottomRow extends StatelessWidget {
  const _BottomRow({required this.data});
  final AdminDashboardData data;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, c) {
        final top = _TopSchools(data: data);
        final act = _ActivityCard(data: data);
        if (c.maxWidth < 840) {
          return Column(children: [top, const SizedBox(height: 18), act]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: top),
            const SizedBox(width: 18),
            Expanded(flex: 2, child: act),
          ],
        );
      },
    );
  }
}

class _TopSchools extends StatelessWidget {
  const _TopSchools({required this.data});
  final AdminDashboardData data;

  @override
  Widget build(BuildContext context) {
    final ranked = [...data.schools]
      ..sort((a, b) => b.students.compareTo(a.students));
    final top = ranked.take(5).toList();
    final maxStu =
        top.isEmpty ? 0 : top.map((s) => s.students).reduce(math.max);
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionTitle(
            'Établissements en tête',
            icon: Icons.emoji_events_rounded,
            subtitle: 'Classés par effectif élèves',
            trailing: TextButton(
              onPressed: () => context.go(Routes.adminEcoles),
              child: Text('Tout voir',
                  style: TextStyle(
                      color: kNavy, fontWeight: FontWeight.w600, fontSize: 12.5)),
            ),
          ),
          const SizedBox(height: 6),
          if (top.isEmpty)
            const _InlineEmpty(message: 'Aucune école enregistrée pour le moment.')
          else
            for (int i = 0; i < top.length; i++)
              _SchoolRankRow(
                rank: i + 1,
                s: top[i],
                maxStu: maxStu,
                onTap: () => context.go(Routes.adminEcoles),
              ),
        ],
      ),
    );
  }
}

class _SchoolRankRow extends StatelessWidget {
  const _SchoolRankRow({
    required this.rank,
    required this.s,
    required this.maxStu,
    required this.onTap,
  });
  final int rank;
  final SchoolSummary s;
  final int maxStu;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RankBadge(rank: rank),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(s.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: kTextPrimary)),
                        ),
                        const SizedBox(width: 8),
                        _TypeChip(s.type),
                      ],
                    ),
                    const SizedBox(height: 7),
                    AdminProgressBar(
                        value: s.students,
                        max: maxStu <= 0 ? 1 : maxStu,
                        height: 6,
                        color: kNavy),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        _MiniStat(emoji: '🎓', value: '${s.students}'),
                        _MiniStat(emoji: '👨‍🏫', value: '${s.staff}'),
                        _MiniStat(emoji: '📚', value: '${s.classes}'),
                        if (s.city != null && s.city!.isNotEmpty)
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.place_rounded,
                                    size: 12, color: kTextMuted.withValues(alpha: 0.7)),
                                const SizedBox(width: 2),
                                Flexible(
                                  child: Text(s.city!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 11, color: kTextMuted)),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});
  final int rank;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (rank) {
      1 => (kAccent, const Color(0xFF7A5C00)),
      2 => (const Color(0xFFCBD5E1), const Color(0xFF334155)),
      3 => (const Color(0xFFFAD9B8), const Color(0xFF8A4B14)),
      _ => (kNavy.withValues(alpha: 0.1), kNavy),
    };
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text('$rank',
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w800, color: fg)),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.emoji, required this.value});
  final String emoji;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 3),
          Text(value,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: kTextMuted)),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.data});
  final AdminDashboardData data;

  @override
  Widget build(BuildContext context) {
    final acts = data.recentActivity;
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionTitle(
            'Activité récente',
            icon: Icons.history_rounded,
            trailing: TextButton(
              onPressed: () => context.go(Routes.adminAudit),
              child: Text('Journal',
                  style: TextStyle(
                      color: kNavy, fontWeight: FontWeight.w600, fontSize: 12.5)),
            ),
          ),
          const SizedBox(height: 6),
          if (acts.isEmpty)
            const _InlineEmpty(message: 'Aucune activité récente à afficher.')
          else
            for (final a in acts.take(7))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: kSurface,
                          borderRadius: BorderRadius.circular(9)),
                      child: Text(a.icon, style: const TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: kTextPrimary)),
                          Text(a.time,
                              style: TextStyle(
                                  fontSize: 11, color: kTextMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration:
          BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(Icons.inbox_rounded, size: 18, color: kTextMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(fontSize: 12.5, color: kTextMuted)),
          ),
        ],
      ),
    );
  }
}

// ─── États chargement / erreur ──────────────────────────────────────────────
