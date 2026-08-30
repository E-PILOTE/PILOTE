part of '../admin_schools_screen.dart';

// Onglets du modal détails

// ─── Onglet Cycles d'enseignement ─────────────────────────────────────────────

class _SchoolCyclesTab extends ConsumerWidget {
  const _SchoolCyclesTab({required this.schoolId});
  final String schoolId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catAsync = ref.watch(educationCatalogProvider);
    final selAsync = ref.watch(schoolEducationProvider(schoolId));

    if (catAsync.isLoading || selAsync.isLoading) {
      return Center(child: CircularProgressIndicator(color: kNavy));
    }
    if (catAsync.hasError || selAsync.hasError) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: AdminErrorBanner(message: 'Impossible de charger les cycles.'),
        ),
      );
    }

    final cat = catAsync.valueOrNull ?? EducationCatalog.empty;
    final sel = selAsync.valueOrNull ?? SchoolEducationSelection.empty;

    if (sel.cycleIds.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: AdminEmptyState(
          icon: Icons.school_outlined,
          title: 'Aucun cycle assigné',
          message: "Modifiez l'école pour lui attribuer des cycles d'enseignement.",
        ),
      );
    }

    final assignedCycles = cat.cycles
        .where((c) => sel.cycleIds.contains(c.id))
        .toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final cycle in assignedCycles) ...[
            _CycleSection(cycle: cycle, cat: cat, sel: sel),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _CycleSection extends StatelessWidget {
  const _CycleSection({required this.cycle, required this.cat, required this.sel});
  final EducationCycle cycle;
  final EducationCatalog cat;
  final SchoolEducationSelection sel;

  static Color _cycleColor(String code) => switch (code.toLowerCase()) {
        'prescolaire' || 'pres' => const Color(0xFFFF6B35),
        'primaire'    || 'prim' => const Color(0xFF0EA5E9),
        'college'     || 'coll' => const Color(0xFF7C3AED),
        'lycee'       || 'lyc'  => kNavy,
        'fp'                    => kGreen,
        _                       => kNavy,
      };

  static IconData _cycleIcon(String code) => switch (code.toLowerCase()) {
        'prescolaire' || 'pres' => Icons.child_care_rounded,
        'primaire'    || 'prim' => Icons.menu_book_rounded,
        'college'     || 'coll' => Icons.library_books_rounded,
        'lycee'       || 'lyc'  => Icons.account_balance_rounded,
        'fp'                    => Icons.build_rounded,
        _                       => Icons.school_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final color = _cycleColor(cycle.code);
    final List<Widget> contentRows = [];

    if (cycle.hasPrograms) {
      final programs = cat.programs
          .where((p) => sel.programIds.contains(p.id) && p.cycleId == cycle.id)
          .toList()
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

      if (programs.isEmpty) {
        contentRows.add(_emptyRow('Aucune filière sélectionnée'));
      } else {
        for (final prog in programs) {
          final levels = cat.levels
              .where((l) => sel.levelIds.contains(l.id) && l.programId == prog.id)
              .toList()
            ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
          contentRows.add(_ProgramRow(program: prog, levels: levels, color: color));
        }
      }
    } else {
      final levels = cat.levels
          .where((l) => sel.levelIds.contains(l.id) && l.cycleId == cycle.id && l.programId == null)
          .toList()
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

      if (levels.isEmpty) {
        contentRows.add(_emptyRow('Aucun niveau sélectionné'));
      } else {
        contentRows.add(Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: levels
                .map((l) => _LevelChip(name: l.name, color: color))
                .toList(),
          ),
        ));
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // En-tête du cycle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.2))),
          ),
          child: Row(children: [
            Icon(_cycleIcon(cycle.code), size: 17, color: color),
            const SizedBox(width: 8),
            Text(cycle.name,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
          ]),
        ),
        ...contentRows,
      ]),
    );
  }

  static Widget _emptyRow(String msg) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Text(msg, style: TextStyle(fontSize: 12, color: kTextMuted)),
      );
}

class _ProgramRow extends StatelessWidget {
  const _ProgramRow({required this.program, required this.levels, required this.color});
  final EducationProgram program;
  final List<EducationLevel> levels;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.folder_outlined, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(program.name,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
          ),
        ]),
        if (levels.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: levels.map((l) => _LevelChip(name: l.name, color: color)).toList(),
          ),
        ],
      ]),
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({required this.name, required this.color});
  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Text(name,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
      );
}

// ─── Onglet Utilisateurs ───────────────────────────────────────────────────────

class _SchoolUsersTab extends ConsumerWidget {
  const _SchoolUsersTab({required this.schoolId});
  final String schoolId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(schoolUsersProvider(schoolId));

    return usersAsync.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => Center(child: CircularProgressIndicator(color: kNavy)),
      error: (_, _) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: AdminErrorBanner(message: 'Impossible de charger les utilisateurs.'),
        ),
      ),
      data: (users) => users.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(32),
              child: AdminEmptyState(
                icon: Icons.person_off_outlined,
                title: 'Aucun utilisateur',
                message: "Cette école n'a pas encore d'utilisateurs enregistrés.",
              ),
            )
          : _SchoolUsersList(users: users),
    );
  }
}

class _SchoolUsersList extends StatelessWidget {
  const _SchoolUsersList({required this.users});
  final List<SchoolUser> users;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: AdminCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (int i = 0; i < users.length; i++) ...[
              _SchoolUserRow(user: users[i]),
              if (i < users.length - 1) Divider(height: 1, color: kBorder),
            ],
          ],
        ),
      ),
    );
  }
}

class _SchoolUserRow extends StatelessWidget {
  const _SchoolUserRow({required this.user});
  final SchoolUser user;

  static Color _roleColor(String role) => switch (role) {
        'directeur' || 'proviseur' => kNavy,
        'enseignant'               => const Color(0xFF0EA5E9),
        'cpe' || 'surveillant'     => const Color(0xFF7C3AED),
        'comptable'                => kGreen,
        'secretaire'               => const Color(0xFFFF6B35),
        _                          => kTextMuted,
      };

  @override
  Widget build(BuildContext context) {
    final roleColor = _roleColor(user.role);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: roleColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.person_rounded, color: roleColor, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user.fullName.isEmpty ? '—' : user.fullName,
                style: TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w700, color: kTextPrimary)),
            const SizedBox(height: 3),
            Wrap(spacing: 6, runSpacing: 4, children: [
              AdminBadge(roleLabel(user.role), color: roleColor),
              if (user.accessProfileName != null)
                AdminBadge(user.accessProfileName!, color: kNavy,
                    icon: Icons.shield_outlined),
            ]),
          ]),
        ),
        const SizedBox(width: 8),
        AdminBadge(
          user.isActive ? 'Actif' : 'Inactif',
          color: user.isActive ? kGreen : kRed,
        ),
      ]),
    );
  }
}

// ─── Onglet Informations ───────────────────────────────────────────────────────

class _SchoolInfoTab extends StatelessWidget {
  const _SchoolInfoTab({required this.school});
  final SchoolDetail school;

  @override
  Widget build(BuildContext context) {
    final s = school;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const AdminModalSectionTitle('Coordonnées'),
        const SizedBox(height: 8),
        AdminDetailCard([
          AdminDetailRow(Icons.email_outlined, 'Email', s.email ?? '—'),
          AdminDetailRow(Icons.phone_outlined, 'Téléphone', s.phone ?? '—'),
          AdminDetailRow(Icons.home_outlined, 'Adresse', s.address ?? '—'),
          AdminDetailRow(Icons.location_city_outlined, 'Ville', s.city ?? '—'),
          AdminDetailRow(Icons.map_outlined, 'Département', s.department ?? '—', last: true),
        ]),
        const SizedBox(height: 14),
        const AdminModalSectionTitle('Identité'),
        const SizedBox(height: 8),
        AdminDetailCard([
          // DEUX lignes, deux notions distinctes : le SECTEUR juridique
          // (public / privé) et le TYPE d'établissement (CEG, CET, lycée…).
          // Les fondre en une seule était précisément l'ambiguïté que la
          // migration 0151 est venue lever.
          AdminDetailRow(Icons.business_outlined, 'Secteur', _schoolTypeLabel(s.type)),
          AdminDetailRow(Icons.school_outlined, "Type d'établissement",
              s.institutionTypeLabel ?? 'Non déclaré'),
          AdminDetailRow(Icons.tag_rounded, 'Code établissement', s.code ?? '—'),
          AdminDetailRow(Icons.history_edu_outlined, 'Année de fondation',
              s.foundedYear?.toString() ?? '—'),
          AdminDetailRow(
              s.isActive ? Icons.check_circle_outline : Icons.block_outlined,
              'Statut', s.isActive ? 'Active' : 'Inactive',
              valueColor: s.isActive ? kGreen : kRed, last: true),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: AdminMetaChip(
              icon: Icons.groups_rounded, label: '${s.students} élèves', color: _kPurple)),
          const SizedBox(width: 8),
          Expanded(child: AdminMetaChip(
              icon: Icons.badge_rounded, label: '${s.staff} personnel', color: _kBlue)),
          const SizedBox(width: 8),
          Expanded(child: AdminMetaChip(
              icon: Icons.class_rounded, label: '${s.classes} classes', color: kGreen)),
        ]),
      ]),
    );
  }
}

class _SchoolStatsTab extends StatelessWidget {
  const _SchoolStatsTab({required this.school, required this.typeColor});
  final SchoolDetail school;
  final Color typeColor;

  @override
  Widget build(BuildContext context) {
    final s = school;
    final perClass = s.classes > 0 ? (s.students / s.classes) : 0.0;
    final perStaff = s.staff > 0 ? (s.students / s.staff) : 0.0;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: _BigStat(
              icon: Icons.groups_rounded, value: '${s.students}',
              label: 'Élèves inscrits', color: _kPurple)),
          const SizedBox(width: 12),
          Expanded(child: _BigStat(
              icon: Icons.badge_rounded, value: '${s.staff}',
              label: 'Membres du personnel', color: _kBlue)),
          const SizedBox(width: 12),
          Expanded(child: _BigStat(
              icon: Icons.class_rounded, value: '${s.classes}',
              label: 'Classes ouvertes', color: kGreen)),
        ]),
        const SizedBox(height: 18),
        const AdminModalSectionTitle('Ratios d\'encadrement'),
        const SizedBox(height: 8),
        AdminDetailCard([
          AdminDetailRow(Icons.school_outlined, 'Élèves par classe',
              s.classes > 0 ? perClass.toStringAsFixed(1) : '—',
              valueColor: perClass > 50 ? kRed : kTextPrimary),
          AdminDetailRow(Icons.supervisor_account_outlined, 'Élèves par agent',
              s.staff > 0 ? perStaff.toStringAsFixed(1) : '—',
              valueColor: perStaff > 35 ? kRed : kTextPrimary, last: true),
        ]),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kNavy.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kBorder),
          ),
          child: Row(children: [
            Icon(Icons.info_outline_rounded, size: 16, color: kTextMuted),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'Les ratios élevés (rouge) signalent une surcharge potentielle : '
              '> 50 élèves/classe ou > 35 élèves/agent.',
              style: TextStyle(fontSize: 12, color: kTextMuted, height: 1.4),
            )),
          ]),
        ),
      ]),
    );
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat({required this.icon, required this.value, required this.label, required this.color});
  final IconData icon;
  final String value, label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.18)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(height: 10),
      Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 11.5, color: kTextMuted, fontWeight: FontWeight.w600)),
    ]),
  );
}

