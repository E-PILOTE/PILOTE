import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/list_chrome.dart';
import '../providers/admin_schools_provider.dart';
import '../providers/admin_students_provider.dart';
import '../widgets/group_student_table.dart';

// ════════════════════════════════════════════════════════════════════════════
//  ÉLÈVES DU RÉSEAU — écran ministère (admin_groupe, online, lecture seule).
//
//  Le seul endroit d'où l'on peut retrouver UN élève dans TOUT le réseau :
//  par son nom, son matricule, ou en parcourant un établissement. C'est la
//  question qu'un cabinet reçoit sans arrêt — « où est scolarisé cet enfant,
//  dans quelle filière ? » — et à laquelle rien ne répondait jusqu'ici au
//  niveau du groupe.
//
//  L'écran s'ouvre VIDE, à dessein : sur un réseau national, une liste
//  intégrale n'a pas de sens (cf. admin_students_provider.dart). On part d'un
//  critère.
// ════════════════════════════════════════════════════════════════════════════
class AdminStudentsScreen extends ConsumerStatefulWidget {
  const AdminStudentsScreen({super.key});

  @override
  ConsumerState<AdminStudentsScreen> createState() => _State();
}

class _State extends ConsumerState<AdminStudentsScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _update(StudentQuery q) =>
      ref.read(studentQueryProvider.notifier).state = q;

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(studentQueryProvider);
    final result = ref.watch(studentSearchProvider);
    final total = ref.watch(groupStudentCountProvider).valueOrNull;
    final schools =
        ref.watch(adminSchoolsProvider).valueOrNull?.schools ?? const [];

    return AppShell(
      title: 'Élèves du réseau',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SearchPanel(
              controller: _search,
              query: query,
              schools: schools,
              total: total,
              onChanged: _update,
              onReset: () {
                _search.clear();
                _update(const StudentQuery());
              },
            ),
            const SizedBox(height: 20),
            if (!query.isRunnable)
              _Prompt(total: total)
            else
              result.when(
                skipLoadingOnReload: true,
                loading: () => const ListShimmer(),
                error: (e, _) => _Error(
                  message: '$e',
                  onRetry: () => ref.invalidate(studentSearchProvider),
                ),
                data: (r) => _Results(result: r),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Panneau de recherche ───────────────────────────────────────────────────
class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.controller,
    required this.query,
    required this.schools,
    required this.total,
    required this.onChanged,
    required this.onReset,
  });

  final TextEditingController controller;
  final StudentQuery query;
  final List<SchoolDetail> schools;
  final int? total;
  final ValueChanged<StudentQuery> onChanged;
  final VoidCallback onReset;

  static const _kAll = '__all__';

  @override
  Widget build(BuildContext context) {
    final sorted = [...schools]..sort((a, b) => a.name.compareTo(b.name));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.person_search_rounded, size: 18, color: kNavy),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              total == null
                  ? 'Rechercher un élève dans le réseau'
                  : 'Rechercher parmi ${total.toString()} élèves du réseau',
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary),
            ),
          ),
          TextButton.icon(
            onPressed: onReset,
            icon: Icon(Icons.filter_alt_off_rounded, size: 14, color: kTextMuted),
            label: Text('Effacer',
                style: TextStyle(fontSize: 11.5, color: kTextMuted)),
          ),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          onChanged: (v) => onChanged(query.copyWith(search: v)),
          style: TextStyle(fontSize: 13, color: kTextPrimary),
          decoration: InputDecoration(
            hintText: 'Nom, prénom ou matricule (2 caractères minimum)…',
            hintStyle: TextStyle(color: kTextMuted, fontSize: 13),
            prefixIcon: Icon(Icons.search_rounded, color: kTextMuted, size: 20),
            filled: true,
            fillColor: kSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 10, children: [
          SizedBox(
            width: 300,
            height: 40,
            child: ListFilterDropdown(
              icon: Icons.account_balance_rounded,
              label: 'Établissement',
              value: query.schoolId ?? _kAll,
              items: {
                _kAll: 'Tous les établissements',
                for (final s in sorted) s.id: s.name,
              },
              onChanged: (v) =>
                  onChanged(query.copyWith(schoolId: v == _kAll ? null : v)),
            ),
          ),
          SizedBox(
            width: 200,
            height: 40,
            child: ListFilterDropdown(
              icon: Icons.wc_rounded,
              label: 'Sexe',
              value: query.gender ?? _kAll,
              items: const {
                _kAll: 'Filles et garçons',
                'F': 'Filles',
                'M': 'Garçons',
              },
              onChanged: (v) =>
                  onChanged(query.copyWith(gender: v == _kAll ? null : v)),
            ),
          ),
          SizedBox(
            width: 200,
            height: 40,
            child: ListFilterDropdown(
              icon: Icons.toggle_on_rounded,
              label: 'Statut',
              value: query.activeOnly ? 'actifs' : 'tous',
              items: const {
                'actifs': 'Élèves actifs',
                'tous': 'Actifs et inactifs',
              },
              onChanged: (v) =>
                  onChanged(query.copyWith(activeOnly: v == 'actifs')),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ─── Invitation à chercher ──────────────────────────────────────────────────
class _Prompt extends StatelessWidget {
  const _Prompt({this.total});
  final int? total;

  @override
  Widget build(BuildContext context) => AdminEmptyState(
        icon: Icons.person_search_rounded,
        title: 'Par où commencer ?',
        message: total == null
            ? 'Saisissez un nom ou un matricule, ou choisissez un '
                'établissement pour en parcourir les élèves.'
            : 'Le réseau compte $total élèves actifs. Saisissez un nom ou un '
                'matricule, ou choisissez un établissement pour en parcourir '
                'les élèves.',
      );
}

// ─── Résultats ──────────────────────────────────────────────────────────────
class _Results extends StatelessWidget {
  const _Results({required this.result});
  final StudentSearchResult result;

  @override
  Widget build(BuildContext context) {
    final rows = result.students;
    if (rows.isEmpty) {
      return const AdminEmptyState(
        icon: Icons.search_off_rounded,
        title: 'Aucun élève trouvé',
        message: 'Aucun élève du réseau ne correspond à ces critères. '
            'Vérifiez l\'orthographe ou élargissez la recherche.',
      );
    }

    final unplaced = rows.where((s) => s.isUnplaced).length;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Text('${rows.length} élève${rows.length > 1 ? 's' : ''}',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: kTextPrimary)),
        const SizedBox(width: 10),
        if (unplaced > 0)
          AdminBadge('$unplaced sans classe',
              color: kRed, icon: Icons.help_outline_rounded),
      ]),
      const SizedBox(height: 12),
      if (result.truncated) ...[
        _TruncatedNotice(),
        const SizedBox(height: 12),
      ],
      GroupStudentTable(students: rows),
    ]);
  }
}

/// Le plafond atteint doit être DIT : une liste coupée en silence ferait
/// prendre 200 élèves pour l'effectif réel.
class _TruncatedNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: kAccent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: kAccent.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Icon(Icons.filter_list_rounded, size: 17, color: kAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Plus de $kStudentSearchLimit élèves correspondent. Seuls les '
              '$kStudentSearchLimit premiers sont affichés — affinez la '
              'recherche pour voir les autres.',
              style: TextStyle(fontSize: 12, color: kTextPrimary),
            ),
          ),
        ]),
      );
}

// ─── Erreur ─────────────────────────────────────────────────────────────────
class _Error extends StatelessWidget {
  const _Error({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.error_outline_rounded, size: 38, color: kRed),
            const SizedBox(height: 12),
            Text('Recherche indisponible',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: kTextMuted)),
            const SizedBox(height: 16),
            AdminActionButton(
              label: 'Réessayer',
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
          ]),
        ),
      );
}
