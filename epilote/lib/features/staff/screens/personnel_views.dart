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
                style: TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w600, color: kTextMuted)),
          ]),
      ]),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  VUE CARTES — même grille et même carte que les Inscriptions
//
//  Un agent et un élève sont deux fiches de personne : les regarder dans deux
//  formats différents oblige à réapprendre à lire d'un écran à l'autre. La
//  grille (`mainAxisExtent: 132`, mêmes points de rupture), la carte
//  (`AdminCard`, padding 12), l'avatar de 42 px, le matricule en chasse fixe
//  sous le nom et la rangée de pastilles en pied sont donc rigoureusement ceux
//  de `inscriptions_list_parts.dart`.
//
//  Ce qui diffère tient à ce que la page fait : ici pas de sélection multiple
//  — l'école n'agit pas en lot sur son personnel — donc le coin porte le
//  crayon de correction, à la place exacte de la case à cocher des élèves.
//
//  Les cartes restent groupées par catégorie métier : l'organigramme est la
//  façon dont un chef d'établissement pense son équipe.
// ════════════════════════════════════════════════════════════════════════════
class _PersonnelCards extends StatelessWidget {
  const _PersonnelCards(
      {required this.agents, required this.onOpen, this.onCorriger});
  final List<StaffMember> agents;
  final ValueChanged<StaffMember> onOpen;

  /// Corriger la fiche — nul si l'utilisateur n'a pas cette capacité. Une
  /// action qui échouerait toujours ne s'affiche pas.
  final ValueChanged<StaffMember>? onCorriger;

  @override
  Widget build(BuildContext context) {
    final groups = <StaffCategory, List<StaffMember>>{};
    for (final a in agents) {
      groups.putIfAbsent(staffCategory(a.role), () => []).add(a);
    }
    final cats = staffCategoryOrder.where(groups.containsKey).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final c in cats) ...[
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 10),
          child: Row(children: [
            Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    color: staffSegColor(c.name, StaffAxis.categorie),
                    shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(staffCategoryLabel(c).toUpperCase(),
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: kTextMuted,
                    letterSpacing: 0.4)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: staffSegColor(c.name, StaffAxis.categorie)
                    .withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${groups[c]!.length}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: staffSegColor(c.name, StaffAxis.categorie))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Divider(color: kBorder, height: 1)),
          ]),
        ),
        LayoutBuilder(builder: (_, cns) {
          // Mêmes points de rupture que les Inscriptions.
          final cols = cns.maxWidth >= 1280
              ? 4
              : cns.maxWidth >= 900
                  ? 3
                  : cns.maxWidth >= 580
                      ? 2
                      : 1;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: 132,
            ),
            itemCount: groups[c]!.length,
            itemBuilder: (_, i) => _AgentCard(
                agent: groups[c]![i], onOpen: onOpen, onCorriger: onCorriger),
          );
        }),
        const SizedBox(height: 6),
      ],
    ]);
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard(
      {required this.agent, required this.onOpen, this.onCorriger});
  final StaffMember agent;
  final ValueChanged<StaffMember> onOpen;
  final ValueChanged<StaffMember>? onCorriger;

  @override
  Widget build(BuildContext context) {
    final a = agent;
    final cat = staffSegColor(staffCategory(a.role).name, StaffAxis.categorie);
    final statut = (a.employmentStatus ?? '').trim();

    return AdminCard(
      padding: const EdgeInsets.all(12),
      // Un agent qui a quitté le service se lit au premier coup d'œil : le
      // liseré rouge évite de lui confier une classe par distraction.
      accent: a.isActive ? null : kRed,
      onTap: () => onOpen(a),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          UserAvatarCircle(
              name: a.fullName, role: a.role, avatarUrl: a.avatarUrl, radius: 21),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(a.lastFirst,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: a.isActive ? kTextPrimary : kTextMuted)),
                const SizedBox(height: 2),
                Text(
                    (a.employeeNumber ?? '').isEmpty
                        ? 'sans matricule'
                        : a.employeeNumber!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11,
                        color: kTextMuted,
                        fontStyle: (a.employeeNumber ?? '').isEmpty
                            ? FontStyle.italic
                            : FontStyle.normal,
                        fontFamily: (a.employeeNumber ?? '').isEmpty
                            ? null
                            : 'monospace')),
              ],
            ),
          ),
          // À la place exacte de la case à cocher des Inscriptions.
          if (onCorriger != null)
            _CardIconBtn(
                icon: Icons.edit_outlined,
                tooltip: 'Corriger la fiche',
                onTap: () => onCorriger!(a)),
        ]),
        const SizedBox(height: 9),
        Row(children: [
          Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: cat, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
                [
                  staffRoleLabel(a.role),
                  if ((a.phone ?? '').isNotEmpty) a.phone!,
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: kTextMuted)),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          if (!a.isActive)
            AdminBadge('Hors service',
                color: kRed, icon: Icons.person_off_outlined)
          else if (statut.isNotEmpty)
            AdminBadge(employmentStatusLabel(statut), color: kNavy)
          else
            AdminBadge('Statut à renseigner', color: kTextMuted),
          if ((a.teachingCycle ?? '').isNotEmpty) ...[
            const SizedBox(width: 6),
            Flexible(
              child: AdminBadge(scopeCycleName(a.teachingCycle),
                  color: staffSegColor(a.teachingCycle!, StaffAxis.cycle),
                  icon: Icons.school_outlined),
            ),
          ] else if (a.role == 'enseignant') ...[
            const SizedBox(width: 6),
            // Un enseignant sans classe n'est pas une anomalie de données :
            // c'est un emploi du temps qui reste à faire. On le dit ici comme
            // on le compte dans les KPI par cycle.
            Flexible(
              child: AdminBadge('Sans classe',
                  color: kAccent, icon: Icons.event_busy_outlined),
            ),
          ],
        ]),
      ]),
    );
  }
}

/// Bouton d'action d'angle — l'empreinte de la case à cocher des Inscriptions,
/// pour que les deux grilles se superposent au pixel près.
class _CardIconBtn extends StatelessWidget {
  const _CardIconBtn(
      {required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: kBorder),
              ),
              child: Icon(icon, size: 15, color: kTextMuted),
            ),
          ),
        ),
      );
}


// ─── Vue TABLEAU ─────────────────────────────────────────────────────────────
class _PersonnelTable extends StatelessWidget {
  const _PersonnelTable(
      {required this.agents, required this.onOpen, this.onCorriger});
  final List<StaffMember> agents;
  final ValueChanged<StaffMember> onOpen;
  final ValueChanged<StaffMember>? onCorriger;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(children: [
        // En-tête
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: const Row(children: [
            Expanded(flex: 5, child: _Th('Agent')),
            Expanded(flex: 4, child: _Th('Fonction')),
            Expanded(flex: 3, child: _Th('Statut')),
            Expanded(flex: 2, child: _Th('Cycle')),
            Expanded(flex: 3, child: _Th('Matricule')),
            SizedBox(width: 68),
          ]),
        ),
        for (var i = 0; i < agents.length; i++)
          _Tr(
              agent: agents[i],
              even: i.isEven,
              onOpen: onOpen,
              onCorriger: onCorriger),
      ]),
    );
  }
}

class _Th extends StatelessWidget {
  const _Th(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: kTextMuted,
          letterSpacing: 0.3));
}

class _Tr extends StatelessWidget {
  const _Tr(
      {required this.agent,
      required this.even,
      required this.onOpen,
      this.onCorriger});
  final StaffMember agent;
  final bool even;
  final ValueChanged<StaffMember> onOpen;
  final ValueChanged<StaffMember>? onCorriger;

  @override
  Widget build(BuildContext context) {
    final a = agent;
    return InkWell(
      onTap: () => onOpen(a),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: even ? kCardBg : kSurface.withValues(alpha: 0.4),
          border: Border(
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
                  style: TextStyle(fontSize: 12.5, color: kTextMuted))),
          Expanded(
              flex: 3,
              child: Text(
                  (a.employmentStatus ?? '').isEmpty
                      ? '—'
                      : employmentStatusLabel(a.employmentStatus),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: kTextMuted))),
          Expanded(
              flex: 2,
              child: Text(
                  (a.teachingCycle ?? '').isEmpty
                      ? '—'
                      : scopeCycleName(a.teachingCycle),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: kTextMuted))),
          Expanded(
              flex: 3,
              child: Text(a.employeeNumber ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: kTextMuted))),
          SizedBox(
            width: 68,
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (onCorriger != null)
                IconButton(
                  tooltip: 'Corriger la fiche',
                  icon: Icon(Icons.edit_outlined, size: 16, color: kTextMuted),
                  onPressed: () => onCorriger!(a),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                ),
              Icon(Icons.chevron_right_rounded, size: 18, color: kTextMuted),
            ]),
          ),
        ]),
      ),
    );
  }
}
