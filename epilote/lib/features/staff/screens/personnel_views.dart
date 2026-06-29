part of 'personnel_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Composants de la page Personnel : graphe de répartition, recherche, filtre
//  statut, vue CARTES (groupée) et vue TABLEAU.
// ════════════════════════════════════════════════════════════════════════════

// ─── Graphe de répartition (barre proportionnelle empilée) ───────────────────
class _DistributionBar extends StatelessWidget {
  const _DistributionBar({required this.segments});
  final List<StaffSegment> segments;

  @override
  Widget build(BuildContext context) {
    final total = segments.fold(0, (a, s) => a + s.total);
    if (total == 0) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Row(
          children: [
            for (final s in segments)
              Expanded(
                flex: s.total == 0 ? 0 : s.total,
                child: Container(height: 14, color: s.color),
              ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 14, runSpacing: 6, children: [
        for (final s in segments)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 9,
                height: 9,
                decoration:
                    BoxDecoration(color: s.color, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text('${s.label} · ${s.total}',
                style: const TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w600, color: kTextMuted)),
          ]),
      ]),
    ]);
  }
}

// ─── Recherche ───────────────────────────────────────────────────────────────
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.count,
    required this.onChanged,
  });
  final TextEditingController controller;
  final int count;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Rechercher un agent parmi $count…',
        hintStyle: const TextStyle(fontSize: 13, color: kTextMuted),
        prefixIcon:
            const Icon(Icons.search_rounded, size: 19, color: kTextMuted),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kBorder),
        ),
      ),
    );
  }
}

// ─── Filtre statut (Tous / Actifs / Inactifs) ────────────────────────────────
class _StatusFilter extends StatelessWidget {
  const _StatusFilter({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const opts = [('all', 'Tous'), ('active', 'Actifs'), ('inactive', 'Inactifs')];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: kBorder),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final (v, l) in opts)
          GestureDetector(
            onTap: () => onChanged(v),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: value == v ? kNavy : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(l,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: value == v ? Colors.white : kTextMuted)),
            ),
          ),
      ]),
    );
  }
}

// ─── Vue CARTES (groupée par catégorie métier) ───────────────────────────────
class _PersonnelCards extends StatelessWidget {
  const _PersonnelCards({required this.agents, required this.onOpen});
  final List<StaffMember> agents;
  final ValueChanged<StaffMember> onOpen;

  @override
  Widget build(BuildContext context) {
    // Regroupement par catégorie métier (ordre organigramme).
    final groups = <StaffCategory, List<StaffMember>>{};
    for (final a in agents) {
      groups.putIfAbsent(staffCategory(a.role), () => []).add(a);
    }
    final cats = staffCategoryOrder.where(groups.containsKey).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final c in cats) ...[
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 8),
          child: Row(children: [
            Text(staffCategoryLabel(c).toUpperCase(),
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: kTextMuted,
                    letterSpacing: 0.4)),
            const SizedBox(width: 8),
            Text('${groups[c]!.length}',
                style: const TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w700, color: kNavy)),
          ]),
        ),
        LayoutBuilder(builder: (ctx, cns) {
          final cols = cns.maxWidth >= 1100
              ? 3
              : (cns.maxWidth >= 720 ? 2 : 1);
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              mainAxisExtent: 84,
            ),
            itemCount: groups[c]!.length,
            itemBuilder: (_, i) =>
                _AgentCard(agent: groups[c]![i], onOpen: onOpen),
          );
        }),
        const SizedBox(height: 8),
      ],
    ]);
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard({required this.agent, required this.onOpen});
  final StaffMember agent;
  final ValueChanged<StaffMember> onOpen;

  @override
  Widget build(BuildContext context) {
    final a = agent;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => onOpen(a),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorder),
          ),
          child: Row(children: [
            UserAvatarCircle(
                name: a.fullName, role: a.role, avatarUrl: a.avatarUrl, radius: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(a.lastFirst,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Row(children: [
                      Flexible(
                        child: Text(staffRoleLabel(a.role),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11.5, color: kTextMuted)),
                      ),
                      if (!a.isActive) ...[
                        const SizedBox(width: 6),
                        _miniTag('Inactif', kTextMuted),
                      ],
                      if ((a.teachingCycle ?? '').isNotEmpty) ...[
                        const SizedBox(width: 6),
                        _miniTag(scopeCycleName(a.teachingCycle),
                            const Color(0xFF0EA5E9)),
                      ],
                    ]),
                  ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: kTextMuted),
          ]),
        ),
      ),
    );
  }

  Widget _miniTag(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
            color: c.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4)),
        child: Text(t,
            style: TextStyle(
                fontSize: 9.5, fontWeight: FontWeight.w800, color: c)),
      );
}

// ─── Vue TABLEAU ─────────────────────────────────────────────────────────────
class _PersonnelTable extends StatelessWidget {
  const _PersonnelTable({required this.agents, required this.onOpen});
  final List<StaffMember> agents;
  final ValueChanged<StaffMember> onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(children: [
        // En-tête
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: const Row(children: [
            Expanded(flex: 5, child: _Th('Agent')),
            Expanded(flex: 4, child: _Th('Fonction')),
            Expanded(flex: 3, child: _Th('Statut')),
            Expanded(flex: 2, child: _Th('Cycle')),
            Expanded(flex: 3, child: _Th('Matricule')),
            SizedBox(width: 28),
          ]),
        ),
        for (var i = 0; i < agents.length; i++)
          _Tr(agent: agents[i], even: i.isEven, onOpen: onOpen),
      ]),
    );
  }
}

class _Th extends StatelessWidget {
  const _Th(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: kTextMuted,
          letterSpacing: 0.3));
}

class _Tr extends StatelessWidget {
  const _Tr({required this.agent, required this.even, required this.onOpen});
  final StaffMember agent;
  final bool even;
  final ValueChanged<StaffMember> onOpen;

  @override
  Widget build(BuildContext context) {
    final a = agent;
    return InkWell(
      onTap: () => onOpen(a),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: even ? Colors.white : kSurface.withValues(alpha: 0.4),
          border: const Border(
              top: BorderSide(color: kBorder, width: 0.6)),
        ),
        child: Row(children: [
          Expanded(
            flex: 5,
            child: Row(children: [
              UserAvatarCircle(
                  name: a.fullName, role: a.role, avatarUrl: a.avatarUrl,
                  radius: 14),
              const SizedBox(width: 10),
              Expanded(
                child: Text(a.lastFirst,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: a.isActive ? kTextPrimary : kTextMuted)),
              ),
            ]),
          ),
          Expanded(
              flex: 4,
              child: Text(staffRoleLabel(a.role),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: kTextMuted))),
          Expanded(
              flex: 3,
              child: Text(
                  (a.employmentStatus ?? '').isEmpty
                      ? '—'
                      : employmentStatusLabel(a.employmentStatus),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: kTextMuted))),
          Expanded(
              flex: 2,
              child: Text(
                  (a.teachingCycle ?? '').isEmpty
                      ? '—'
                      : scopeCycleName(a.teachingCycle),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: kTextMuted))),
          Expanded(
              flex: 3,
              child: Text(a.employeeNumber ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: kTextMuted))),
          const SizedBox(
              width: 28,
              child: Icon(Icons.chevron_right_rounded,
                  size: 18, color: kTextMuted)),
        ]),
      ),
    );
  }
}
