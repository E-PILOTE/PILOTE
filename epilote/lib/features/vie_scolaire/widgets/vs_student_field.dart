import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../students/widgets/scope_drilldown_panel.dart';
import '../providers/vs_students_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CHAMP DE SÉLECTION D'ÉLÈVE — un champ « filled » ouvrant un sélecteur avec
//  RECHERCHE et regroupement par CLASSE. Réutilisé par Discipline, Infirmerie,
//  Orientation. Passe à l'échelle (recherche nom/matricule).
// ════════════════════════════════════════════════════════════════════════════
class VsStudentField extends StatelessWidget {
  const VsStudentField({
    super.key,
    required this.students,
    required this.selectedId,
    required this.onSelect,
    this.enabled = true,
    this.label = 'Élève',
  });
  final List<VsStudent> students;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final bool enabled;
  final String label;

  @override
  Widget build(BuildContext context) {
    final sel = students.where((s) => s.id == selectedId).firstOrNull;
    return InkWell(
      onTap: enabled
          ? () async {
              final picked = await showModalBottomSheet<VsStudent>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => _StudentPickerSheet(students: students),
              );
              if (picked != null) onSelect(picked.id);
            }
          : null,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: adminFilledInput(label, icon: Icons.person_search_rounded),
        child: Row(children: [
          Expanded(
            child: Text(
                sel == null ? 'Choisir un élève…' : '${sel.name} · ${sel.classLabel}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: sel == null ? FontWeight.w400 : FontWeight.w700,
                    color: sel == null ? kTextMuted : kTextPrimary)),
          ),
          const Icon(Icons.expand_more_rounded, size: 18, color: kTextMuted),
        ]),
      ),
    );
  }
}

class _StudentPickerSheet extends StatefulWidget {
  const _StudentPickerSheet({required this.students});
  final List<VsStudent> students;
  @override
  State<_StudentPickerSheet> createState() => _StudentPickerSheetState();
}

class _StudentPickerSheetState extends State<_StudentPickerSheet> {
  final _ctrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final list = [
      for (final s in widget.students)
        if (q.isEmpty ||
            s.name.toLowerCase().contains(q) ||
            (s.matricule ?? '').toLowerCase().contains(q) ||
            (s.className ?? '').toLowerCase().contains(q))
          s,
    ];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          const SizedBox(height: 10),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: kBorder, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(
                hintText: 'Rechercher un élève (nom, matricule, classe)…',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                filled: true,
                fillColor: kSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: list.isEmpty
                ? const Center(
                    child: Text('Aucun élève',
                        style: TextStyle(color: kTextMuted)))
                : ListView.builder(
                    controller: scroll,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final s = list[i];
                      final color = scopeCycleColor(s.cycleCode);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.12),
                          child: Text(
                              s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                              style: TextStyle(
                                  color: color, fontWeight: FontWeight.w800)),
                        ),
                        title: Text(s.name,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                            '${s.classLabel}${s.matricule != null ? ' · ${s.matricule}' : ''}',
                            style: const TextStyle(fontSize: 12)),
                        onTap: () => Navigator.pop(context, s),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}
