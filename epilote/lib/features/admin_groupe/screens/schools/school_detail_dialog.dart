part of '../admin_schools_screen.dart';

// Modal détails école (coquille)

// ─── Modal détails école (style super_admin) ─────────────────────────────────

String _schoolTypeLabel(String t) => switch (t) {
  'public' => 'Public',
  'mixte'  => 'Mixte',
  _        => 'Privé',
};

Color _schoolTypeColor(String t) => switch (t) {
  'public' => _kBlue,
  'mixte'  => _kOrange,
  _        => _kGold,
};

// ─── API publique réutilisable (Vue régionale → tableau analytique) ──────────
/// Libellé du type d'établissement (Public / Privé / Mixte).
String schoolTypeLabel(String t) => _schoolTypeLabel(t);

/// Couleur associée au type d'établissement.
Color schoolTypeColor(String t) => _schoolTypeColor(t);

/// Ouvre la fiche détaillée d'une école (4 onglets : Infos / Cycles /
/// Utilisateurs / Stats) depuis n'importe quel écran admin_groupe. Réutilisée
/// par le tableau analytique de la Vue régionale pour éviter toute duplication.
Future<void> openSchoolDetailDialog(
    BuildContext context, WidgetRef ref, SchoolDetail s) {
  return showDialog(
    context: context,
    builder: (_) => _SchoolDetailModal(
      school: s,
      onEdit: () {
        Navigator.of(context).pop();
        showDialog(context: context, builder: (_) => SchoolFormDialog(school: s));
      },
      onToggle: () async {
        Navigator.of(context).pop();
        try {
          await ref.read(adminSchoolsServiceProvider).setActive(s.id, !s.isActive);
        } catch (_) {}
      },
    ),
  );
}

class _SchoolDetailModal extends StatefulWidget {
  const _SchoolDetailModal({
    required this.school,
    required this.onEdit,
    required this.onToggle,
  });
  final SchoolDetail school;
  final VoidCallback onEdit, onToggle;

  @override
  State<_SchoolDetailModal> createState() => _SchoolDetailModalState();
}

class _SchoolDetailModalState extends State<_SchoolDetailModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.school;
    final typeColor = _schoolTypeColor(s.type);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Container(
        width: 760,
        constraints: const BoxConstraints(maxHeight: 680),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 30, offset: const Offset(0, 8))],
        ),
        child: Column(children: [
          // ─ Header ──────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: kBorder)),
            ),
            child: Row(children: [
              _SchoolAvatar(
                logoUrl: s.logoUrl,
                size: 66, radius: 14, iconSize: 30,
                iconColor: s.isActive ? kNavy : kTextMuted,
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name, style: TextStyle(
                      color: kTextPrimary, fontSize: 17, fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    _TypeBadge(type: s.type),
                    AdminBadge(s.isActive ? 'Active' : 'Inactive',
                        color: s.isActive ? kGreen : kRed,
                        icon: s.isActive ? Icons.check_circle : Icons.block_rounded),
                    if (s.code != null)
                      AdminBadge('Code ${s.code}', color: kTextMuted, icon: Icons.tag_rounded),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.location_on_outlined, size: 12, color: kTextMuted),
                    const SizedBox(width: 3),
                    Flexible(child: Text(
                        [s.city, s.department].where((e) => e != null && e.isNotEmpty).join(', '),
                        style: TextStyle(color: kTextMuted, fontSize: 11.5),
                        overflow: TextOverflow.ellipsis)),
                    if (s.foundedYear != null) ...[
                      const SizedBox(width: 10),
                      Icon(Icons.history_edu_outlined, size: 12, color: kTextMuted),
                      const SizedBox(width: 3),
                      Text('Fondée en ${s.foundedYear}',
                          style: TextStyle(color: kTextMuted, fontSize: 11.5)),
                    ],
                  ]),
                ],
              )),
              const SizedBox(width: 8),
              Row(children: [
                AdminModalIconBtn(icon: Icons.edit_rounded, color: kNavy,
                    tooltip: 'Modifier', onTap: widget.onEdit),
                const SizedBox(width: 4),
                AdminModalIconBtn(icon: Icons.close_rounded, color: kTextMuted,
                    tooltip: 'Fermer', onTap: () => Navigator.pop(context)),
              ]),
            ]),
          ),
          // ─ Tabs ────────────────────────────────────────────────────────────
          Container(
            color: kSurface,
            child: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: kNavy,
              unselectedLabelColor: kTextMuted,
              indicatorColor: kNavy,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              tabs: const [
                Tab(icon: Icon(Icons.info_outline_rounded, size: 16), text: 'Informations'),
                Tab(icon: Icon(Icons.school_outlined, size: 16),      text: 'Cycles'),
                Tab(icon: Icon(Icons.people_outline_rounded, size: 16), text: 'Utilisateurs'),
                Tab(icon: Icon(Icons.bar_chart_rounded, size: 16),    text: 'Statistiques'),
              ],
            ),
          ),
          // ─ Content ──────────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _SchoolInfoTab(school: s),
                _SchoolCyclesTab(schoolId: s.id),
                _SchoolUsersTab(schoolId: s.id),
                _SchoolStatsTab(school: s, typeColor: typeColor),
              ],
            ),
          ),
          // ─ Footer ───────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: kBorder)),
            ),
            child: Row(children: [
              OutlinedButton.icon(
                onPressed: widget.onToggle,
                icon: Icon(s.isActive ? Icons.block_rounded : Icons.check_rounded, size: 16),
                label: Text(s.isActive ? 'Désactiver' : 'Activer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: s.isActive ? _kOrange : kGreen,
                  side: BorderSide(color: s.isActive ? _kOrange : kGreen),
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: widget.onEdit,
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Modifier'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kNavy, foregroundColor: Colors.white, elevation: 0,
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

