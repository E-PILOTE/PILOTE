part of 'cahier_textes_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Briques de la page Cahier de textes : barre de filtres, en-tête, liste,
//  détail de séance.
// ════════════════════════════════════════════════════════════════════════════

// ─── Barre de filtres ─────────────────────────────────────────────────────────
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.searchCtrl,
    required this.subjectId,
    required this.subjects,
    required this.readOnly,
    required this.onSearch,
    required this.onSubject,
    required this.onReset,
    required this.onAdd,
  });
  final TextEditingController searchCtrl;
  final String? subjectId;
  final Map<String, String> subjects;
  final bool readOnly;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onSubject;
  final VoidCallback onReset, onAdd;

  @override
  Widget build(BuildContext context) {
    final hasFilter = searchCtrl.text.isNotEmpty || subjectId != null;
    return AdminCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Expanded(
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 240,
                child: TextField(
                  controller: searchCtrl,
                  onChanged: onSearch,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: adminFilledInput('Rechercher (titre, contenu…)',
                      icon: Icons.search_rounded),
                ),
              ),
              _Drop(
                  hint: 'Toutes les matières',
                  value: subjectId,
                  items: subjects,
                  onChanged: onSubject),
              if (hasFilter)
                TextButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  label: const Text('Réinitialiser'),
                  style: TextButton.styleFrom(foregroundColor: kTextMuted),
                ),
            ],
          ),
        ),
        if (!readOnly) ...[
          const SizedBox(width: 10),
          PermissionGate(
            slug: _kSlug,
            action: 'create',
            child: AdminPrimaryButton(
              label: 'Nouvelle séance',
              icon: Icons.add_rounded,
              color: kNavy,
              onTap: onAdd,
            ),
          ),
        ],
      ]),
    );
  }
}

class _Drop extends StatelessWidget {
  const _Drop(
      {required this.hint,
      required this.value,
      required this.items,
      required this.onChanged});
  final String hint;
  final String? value;
  final Map<String, String> items;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 190,
        child: DropdownButtonFormField<String>(
          initialValue: items.containsKey(value) ? value : null,
          isExpanded: true,
          style: const TextStyle(fontSize: 13, color: kTextPrimary),
          icon:
              const Icon(Icons.expand_more_rounded, size: 18, color: kTextMuted),
          decoration: adminFilledInput(hint),
          items: [
            DropdownMenuItem(value: null, child: Text(hint)),
            for (final e in items.entries)
              DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value,
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: onChanged,
        ),
      );
}

// Bandeau de filtre actif (scope choisi dans le panneau de répartition).
class _ScopeChip extends StatelessWidget {
  const _ScopeChip({required this.label, required this.onClear});
  final String label;
  final VoidCallback onClear;
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 7, 6, 7),
          decoration: BoxDecoration(
            color: kNavy.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kNavy.withValues(alpha: 0.25)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.filter_alt_rounded, size: 14, color: kNavy),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700, color: kNavy)),
            const SizedBox(width: 2),
            InkWell(
              onTap: onClear,
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.all(3),
                child: Icon(Icons.close_rounded, size: 15, color: kNavy),
              ),
            ),
          ]),
        ),
      );
}

// ─── En-tête résultats ────────────────────────────────────────────────────────
class _ResultHeader extends StatelessWidget {
  const _ResultHeader({required this.total, required this.filtered});
  final int total, filtered;
  @override
  Widget build(BuildContext context) {
    final noun = total <= 1 ? 'séance' : 'séances';
    final txt = filtered == total ? '$total $noun' : '$filtered / $total $noun';
    return Row(children: [
      const Icon(Icons.history_edu_outlined, size: 16, color: kTextMuted),
      const SizedBox(width: 8),
      Text(txt,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary)),
    ]);
  }
}

// ─── Liste chronologique ──────────────────────────────────────────────────────
class _LessonList extends StatelessWidget {
  const _LessonList({required this.entries, required this.onOpen});
  final List<LessonEntry> entries;
  final ValueChanged<LessonEntry> onOpen;
  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: EdgeInsets.zero,
      child: Column(children: [
        for (var i = 0; i < entries.length; i++)
          _LessonTile(
            e: entries[i],
            last: i == entries.length - 1,
            onTap: () => onOpen(entries[i]),
          ),
      ]),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile(
      {required this.e, required this.last, required this.onTap});
  final LessonEntry e;
  final bool last;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          border: last ? null : const Border(bottom: BorderSide(color: kBorder)),
        ),
        child: Row(children: [
          // Pastille date.
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
                color: kNavy.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8)),
            child: Column(children: [
              Text(e.entryDate?.day.toString().padLeft(2, '0') ?? '—',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: kNavy,
                      height: 1)),
              const SizedBox(height: 2),
              Text(
                  e.entryDate != null ? _moShort(e.entryDate!.month) : '',
                  style: const TextStyle(fontSize: 10.5, color: kTextMuted)),
            ]),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: kTextPrimary)),
                  const SizedBox(height: 4),
                  Row(children: [
                    if (e.className != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: AdminBadge(e.className!, color: kNavy),
                      ),
                    Flexible(
                      child: Text(
                          [
                            if (e.subjectName != null) e.subjectName!,
                            if ((e.teacherName ?? '').isNotEmpty) e.teacherName!,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(fontSize: 12, color: kTextMuted)),
                    ),
                  ]),
                ]),
          ),
          if (e.hasHomework)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.assignment_outlined,
                    size: 12, color: Color(0xFFF59E0B)),
                SizedBox(width: 4),
                Text('Devoirs',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFF59E0B))),
              ]),
            ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, size: 18, color: kTextMuted),
        ]),
      ),
    );
  }
}

String _moShort(int m) => const [
      '', 'janv', 'févr', 'mars', 'avr', 'mai', 'juin', 'juil', 'août',
      'sept', 'oct', 'nov', 'déc'
    ][m];

// ─── Détail d'une séance ──────────────────────────────────────────────────────
class _LessonDetail extends StatelessWidget {
  const _LessonDetail({required this.entry, this.onEdit, this.onDelete});
  final LessonEntry entry;
  final VoidCallback? onEdit, onDelete;
  @override
  Widget build(BuildContext context) {
    final e = entry;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: kBorder))),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.title,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: kTextPrimary)),
                      const SizedBox(height: 3),
                      Text(
                          [
                            e.dateLabel,
                            if (e.className != null) e.className!,
                            if (e.subjectName != null) e.subjectName!,
                          ].join('  ·  '),
                          style:
                              const TextStyle(fontSize: 12.5, color: kTextMuted)),
                    ]),
              ),
              IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context)),
            ]),
          ),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.all(18),
              shrinkWrap: true,
              children: [
                if ((e.teacherName ?? '').isNotEmpty)
                  _Section('Enseignant', e.teacherName!, Icons.person_outline_rounded),
                _Section('Contenu de la séance', e.content,
                    Icons.subject_rounded),
                _Section('Objectifs', e.objectives, Icons.flag_outlined),
                _Section('Devoirs à faire', e.homework,
                    Icons.assignment_outlined,
                    accent: const Color(0xFFF59E0B)),
                _Section('Ressources', e.resources, Icons.link_rounded),
              ],
            ),
          ),
          if (onEdit != null || onDelete != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
              child: Row(children: [
                if (onDelete != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline_rounded, size: 17),
                      label: const Text('Supprimer'),
                      style: OutlinedButton.styleFrom(foregroundColor: kRed),
                    ),
                  ),
                if (onEdit != null && onDelete != null)
                  const SizedBox(width: 12),
                if (onEdit != null)
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: kNavy),
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_rounded, size: 17),
                      label: const Text('Modifier'),
                    ),
                  ),
              ]),
            ),
        ]),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.label, this.value, this.icon, {this.accent = kNavy});
  final String label;
  final String? value;
  final IconData icon;
  final Color accent;
  @override
  Widget build(BuildContext context) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 15, color: accent),
          const SizedBox(width: 7),
          Text(label.toUpperCase(),
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  color: accent)),
        ]),
        const SizedBox(height: 6),
        Text(v,
            style: const TextStyle(
                fontSize: 13, color: kTextPrimary, height: 1.45)),
      ]),
    );
  }
}
