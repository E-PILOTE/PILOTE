part of 'infirmerie_screen.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  INFIRMERIE — pièces d'affichage : barre de filtres (recherche, « suivi
//  requis », nouveau passage) et carte d'un passage. Séparées de l'écran quand
//  celui-ci a dépassé 500 lignes ; la coupe suit la couture naturelle — l'état
//  et les actions restent dans l'écran, les widgets muets viennent ici.
// ═════════════════════════════════════════════════════════════════════════════

// ─── Barre de filtres ────────────────────────────────────────────────────────
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.search,
    required this.canCreate,
    required this.suiviSeul,
    required this.suivisOuverts,
    required this.onToggleSuivi,
    required this.onSearch,
    required this.onReset,
    required this.onAdd,
  });
  final TextEditingController search;
  final bool canCreate, suiviSeul;
  final int suivisOuverts;
  final ValueChanged<String> onSearch;
  final VoidCallback onReset, onAdd, onToggleSuivi;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: search,
            onChanged: onSearch,
            decoration: InputDecoration(
              hintText:
                  'Rechercher (élève, symptôme, diagnostic, traitement)…',
              hintStyle: TextStyle(color: kTextMuted, fontSize: 13),
              prefixIcon:
                  Icon(Icons.search_rounded, color: kTextMuted, size: 20),
              filled: true,
              fillColor: kSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 10),
        if (suivisOuverts > 0)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              selected: suiviSeul,
              onSelected: (_) => onToggleSuivi(),
              showCheckmark: false,
              avatar: Icon(Icons.medical_services_rounded,
                  size: 15,
                  color: suiviSeul ? Colors.white : const Color(0xFFF59E0B)),
              label: Text('Suivi requis ($suivisOuverts)',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: suiviSeul ? Colors.white : kTextPrimary)),
              selectedColor: const Color(0xFFF59E0B),
              backgroundColor: kSurface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: kBorder)),
            ),
          ),
        IconButton(
          tooltip: 'Réinitialiser',
          onPressed: onReset,
          icon: Icon(Icons.filter_alt_off_outlined, color: kTextMuted),
        ),
        const SizedBox(width: 4),
        if (canCreate)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [kNavyDark, kNavy],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add_rounded, size: 16, color: Colors.white),
                  SizedBox(width: 6),
                  Text('Passage',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}

// ─── Carte passage ───────────────────────────────────────────────────────────
class _VisitCard extends StatelessWidget {
  const _VisitCard({
    required this.visit,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
    required this.onCloreSuivi,
  });
  final InfirmaryVisit visit;
  final bool canEdit, canDelete;
  final VoidCallback onEdit, onDelete, onCloreSuivi;

  @override
  Widget build(BuildContext context) {
    final v = visit;
    final line = [
      if ((v.diagnosis ?? '').isNotEmpty) v.diagnosis!,
      if ((v.treatment ?? '').isNotEmpty) 'Traitement : ${v.treatment}',
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: kRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.local_hospital_rounded, size: 20, color: kRed),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(v.studentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: kTextPrimary)),
                  const SizedBox(height: 3),
                  Text(
                      '${v.date}${v.time != null ? ' · ${v.time!.substring(0, 5)}' : ''}'
                      '${v.className != null ? ' · ${v.className}' : ''}'
                      '${v.restHours != null ? ' · repos ${v.restHours}h' : ''}',
                      style: TextStyle(fontSize: 12, color: kTextMuted)),
                  if ((v.symptoms ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('Symptômes : ${v.symptoms!.trim()}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, height: 1.35)),
                  ],
                  if (line.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(line,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: kTextMuted, height: 1.3)),
                  ],
                  const SizedBox(height: 8),
                  Row(children: [
                    _Tag(
                      v.parentNotified
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_off_outlined,
                      v.parentNotified ? 'Parents notifiés' : 'Parents non notifiés',
                      v.parentNotified ? kGreen : kTextMuted,
                    ),
                    if (v.followUpRequired) ...[
                      const SizedBox(width: 8),
                      const _Tag(Icons.medical_services_rounded, 'Suivi requis',
                          Color(0xFFF59E0B)),
                    ],
                  ]),
                ]),
          ),
          if (canEdit || canDelete)
            PopupMenuButton<String>(
              icon:
                  Icon(Icons.more_vert_rounded, size: 20, color: kTextMuted),
              onSelected: (x) => switch (x) {
                'edit' => onEdit(),
                'suivi' => onCloreSuivi(),
                _ => onDelete(),
              },
              itemBuilder: (ctx) => [
                // Clore le suivi est une MODIFICATION du passage, pas une
                // suppression : c'est `canEdit` qui l'ouvre.
                if (canEdit && visit.followUpRequired)
                  PopupMenuItem(
                      value: 'suivi',
                      child: Row(children: [
                        Icon(Icons.task_alt_rounded, size: 16, color: kGreen),
                        const SizedBox(width: 8),
                        const Text('Suivi effectué'),
                      ])),
                if (canEdit)
                  const PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit_outlined, size: 16),
                        SizedBox(width: 8),
                        Text('Modifier'),
                      ])),
                if (canDelete)
                  PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline_rounded, size: 16, color: kRed),
                        const SizedBox(width: 8),
                        Text('Supprimer', style: TextStyle(color: kRed)),
                      ])),
              ],
            ),
        ]),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.icon, this.label, this.color);
  final IconData icon;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ]);
}
