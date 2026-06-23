import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../data/models/class_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../classes/providers/class_provider.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../structure/providers/academic_year_context.dart';
import '../providers/inscriptions_data_provider.dart';
import '../providers/student_documents_provider.dart';
import '../providers/student_tutors_provider.dart';
import '../providers/students_provider.dart';
import '../providers/students_registry_provider.dart';
import '../widgets/inscription_form_kit.dart';
import 'add_inscription_screen.dart';

part 'eleves_parts.dart';
part 'eleves_drawer.dart';

// ─── Accents par cycle (cohérents avec Inscriptions) ─────────────────────────
Color _cycColor(String? code) => switch (code) {
      'prescolaire' => const Color(0xFFEC4899),
      'primaire' => const Color(0xFF0EA5E9),
      'college' => kGreen,
      'lycee' => kNavy,
      'formation_pro' || 'fp' => const Color(0xFFF59E0B),
      _ => kTextMuted,
    };

String _pl(int n, String s, String p) => '$n ${n <= 1 ? s : p}';

String _enrollLabel(String? status) => switch (status) {
      'active' => 'Inscrit',
      'pending_validation' => 'En attente',
      'rejected' => 'Rejeté',
      'withdrawn' => 'Retiré',
      null => 'Non inscrit',
      _ => status,
    };

Color _enrollColor(String? status) => switch (status) {
      'active' => kGreen,
      'pending_validation' => kAccent,
      'rejected' => kRed,
      'withdrawn' => kTextMuted,
      null => const Color(0xFF94A3B8),
      _ => kTextMuted,
    };

// ════════════════════════════════════════════════════════════════════════════
//  PAGE ÉLÈVES — registre des personnes (≠ Inscriptions = inscriptions de
//  l'année). Design plateforme : KPI → filtres (recherche + sexe + statut +
//  bascule table/cartes + « Nouvel élève ») → table / cartes → tiroir détail
//  (dossier + actions : modifier, inscrire, désactiver). Offline-first.
// ════════════════════════════════════════════════════════════════════════════
class ElevesScreen extends ConsumerWidget {
  const ElevesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => const ModuleScaffold(
        slug: 'eleves',
        title: 'Élèves',
        child: _Body(),
      );
}

class _Body extends ConsumerStatefulWidget {
  const _Body();
  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  final _search = TextEditingController();
  String? _gender; // M | F
  String _status = 'all'; // all | active | pending_validation | none
  bool _isTable = true;
  bool _sortAsc = true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _resetFilters() => setState(() {
        _search.clear();
        _gender = null;
        _status = 'all';
      });

  List<StudentRow> _apply(List<StudentRow> all) {
    final q = _search.text.trim().toLowerCase();
    final out = all.where((s) {
      if (_gender != null && s.gender != _gender) return false;
      switch (_status) {
        case 'active':
          if (s.enrollmentStatus != 'active') return false;
        case 'pending_validation':
          if (s.enrollmentStatus != 'pending_validation') return false;
        case 'none':
          if (s.isEnrolled) return false;
      }
      if (q.isEmpty) return true;
      return s.fullName.toLowerCase().contains(q) ||
          s.matricule.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) {
        final c = a.lastFirst.toLowerCase().compareTo(b.lastFirst.toLowerCase());
        return _sortAsc ? c : -c;
      });
    return out;
  }

  void _openAdd() => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 40, vertical: 32),
          child: AddInscriptionScreen(),
        ),
      );

  void _openDrawer(StudentRow s) => showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Fermer',
        barrierColor: Colors.black.withValues(alpha: 0.45),
        transitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (_, _, _) => Align(
          alignment: Alignment.centerRight,
          child: _StudentDrawer(row: s),
        ),
        transitionBuilder: (_, anim, _, child) => SlideTransition(
          position: Tween(begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(studentsRegistryProvider);
    final readOnly = ref.watch(yearReadOnlyProvider);

    return async.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Erreur : $e', style: const TextStyle(color: kRed)),
        ),
      ),
      data: (all) {
        final filtered = _apply(all);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Kpis(students: all),
              const SizedBox(height: 22),
              _ElevesFilterBar(
                searchCtrl: _search,
                gender: _gender,
                status: _status,
                isTable: _isTable,
                readOnly: readOnly,
                onSearch: (_) => setState(() {}),
                onGender: (v) => setState(() => _gender = v),
                onStatus: (v) => setState(() => _status = v ?? 'all'),
                onToggleView: () => setState(() => _isTable = !_isTable),
                onReset: _resetFilters,
                onAdd: _openAdd,
              ),
              const SizedBox(height: 16),
              _ResultHeader(total: all.length, filtered: filtered.length),
              const SizedBox(height: 12),
              if (all.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: AdminEmptyState(
                    icon: Icons.groups_outlined,
                    title: 'Aucun élève',
                    message:
                        'Le registre est vide. Ajoutez un élève (création + '
                        'inscription) pour démarrer.',
                    actionLabel: readOnly ? null : 'Nouvel élève',
                    onAction: readOnly ? null : _openAdd,
                  ),
                )
              else if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 30),
                  child: AdminEmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Aucun résultat',
                    message: 'Ajustez la recherche ou les filtres.',
                  ),
                )
              else if (_isTable)
                _StudentTable(
                  rows: filtered,
                  sortAsc: _sortAsc,
                  onSort: () => setState(() => _sortAsc = !_sortAsc),
                  onOpen: _openDrawer,
                )
              else
                _StudentCards(rows: filtered, onOpen: _openDrawer),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

// ─── KPIs ─────────────────────────────────────────────────────────────────────
class _Kpis extends StatelessWidget {
  const _Kpis({required this.students});
  final List<StudentRow> students;

  @override
  Widget build(BuildContext context) {
    final filles = students.where((s) => s.gender == 'F').length;
    final garcons = students.where((s) => s.gender == 'M').length;
    final inscrits = students.where((s) => s.isActiveEnrolled).length;
    final nonInscrits = students.where((s) => !s.isEnrolled).length;
    final items = <(IconData, String, String, Color, String?)>[
      (Icons.groups_outlined, 'Élèves', '${students.length}', kNavy, null),
      (Icons.female_rounded, 'Filles', '$filles', const Color(0xFFEC4899), null),
      (Icons.male_rounded, 'Garçons', '$garcons', const Color(0xFF0EA5E9), null),
      (Icons.how_to_reg_outlined, 'Inscrits', '$inscrits', kGreen,
          'année active'),
      (Icons.person_off_outlined, 'Non inscrits', '$nonInscrits',
          const Color(0xFFF59E0B), null),
    ];
    return LayoutBuilder(builder: (ctx, cns) {
      final w = cns.maxWidth;
      final cols = w >= 1100 ? 5 : (w >= 720 ? 3 : (w >= 460 ? 2 : 1));
      return GridView.count(
        crossAxisCount: cols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: cols == 1 ? 4.6 : 2.4,
        children: [
          for (final (icon, label, value, color, sub) in items)
            AdminStatCard(
                label: label,
                value: value,
                icon: icon,
                color: color,
                subtitle: sub),
        ],
      );
    });
  }
}
