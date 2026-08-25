import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/list_chrome.dart';
import '../../../core/widgets/pdf_preview_dialog.dart';
import '../providers/admin_dashboard_provider.dart';
import '../providers/admin_schools_provider.dart';
import '../providers/admin_students_provider.dart';
import '../services/group_students_pdf_service.dart';
import '../widgets/group_student_filters.dart';
import '../widgets/group_student_kpis.dart';
import '../widgets/group_student_table.dart';

// ════════════════════════════════════════════════════════════════════════════
//  ÉLÈVES DU RÉSEAU — écran ministère (admin_groupe, online, lecture seule).
//
//  Le seul endroit d'où l'on peut retrouver UN élève dans TOUT le réseau :
//  par son nom, son matricule, ou en parcourant un territoire. C'est la
//  question qu'un cabinet reçoit sans arrêt — « où est scolarisé cet enfant,
//  dans quelle filière ? » — et à laquelle rien ne répondait jusqu'ici au
//  niveau du groupe.
//
//  L'écran s'ouvre VIDE, à dessein : sur un réseau national, une liste
//  intégrale n'a pas de sens (cf. admin_students_provider.dart). On part d'un
//  critère.
// ════════════════════════════════════════════════════════════════════════════

/// Délai d'inactivité avant de lancer la requête. Sans lui, « Mabiala » fait
/// partir SEPT requêtes serveur — chacune ramenant jusqu'à 200 élèves et leurs
/// inscriptions — dont six sont périmées avant d'arriver. Sur une liaison
/// congolaise, c'est la différence entre un écran qui répond et un écran qui
/// clignote.
const _kDebounce = Duration(milliseconds: 350);

class AdminStudentsScreen extends ConsumerStatefulWidget {
  const AdminStudentsScreen({super.key});

  @override
  ConsumerState<AdminStudentsScreen> createState() => _State();
}

class _State extends ConsumerState<AdminStudentsScreen> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  /// Seule la saisie au clavier est temporisée : un menu déroulant est un choix
  /// déjà arrêté, le faire attendre 350 ms le ferait paraître poussif.
  void _update(StudentQuery q) {
    final typing = q.search != ref.read(studentQueryProvider).search;
    _debounce?.cancel();
    if (!typing) {
      ref.read(studentQueryProvider.notifier).state = q;
      return;
    }
    _debounce = Timer(_kDebounce, () {
      if (mounted) ref.read(studentQueryProvider.notifier).state = q;
    });
  }

  void _reset() {
    _debounce?.cancel();
    _search.clear();
    ref.read(studentQueryProvider.notifier).state = const StudentQuery();
  }

  /// Ce que couvre la sélection courante — accolé aux KPI pour qu'un
  /// pourcentage ne soit jamais lu comme celui du réseau entier.
  String _scopeLabel(StudentQuery q, List<SchoolDetail> schools) {
    final school = _schoolName(q, schools);
    if (school != null) return school;
    if (q.department != null) return 'département ${q.department}';
    if (q.filiere != null) return 'filière ${q.filiere}';
    return q.safeSearch.isEmpty
        ? 'sur le réseau'
        : 'résultats de « ${q.safeSearch} »';
  }

  String? _schoolName(StudentQuery q, List<SchoolDetail> schools) {
    if (q.schoolId == null) return null;
    for (final s in schools) {
      if (s.id == q.schoolId) return s.name;
    }
    return 'établissement sélectionné';
  }

  void _openPdf(StudentSearchResult r, List<GroupStudent> rows) {
    final query = ref.read(studentQueryProvider);
    final schools =
        ref.read(adminSchoolsProvider).valueOrNull?.schools ?? const [];
    final groupName = ref.read(adminDashboardProvider).valueOrNull?.groupName ??
        'Groupe scolaire';
    final schoolLabel = _schoolName(query, schools);

    showPdfPreviewDialog(
      context,
      title: 'Élèves du réseau',
      subtitle: _scopeLabel(query, schools),
      pdfFileName: 'eleves_reseau.pdf',
      build: (_) => GroupStudentsPdfService.buildPdf(
        groupName: groupName,
        rows: rows,
        query: query,
        truncated: r.truncated,
        schoolLabel: schoolLabel,
      ),
      onDownload: () => GroupStudentsPdfService.download(
        groupName: groupName,
        rows: rows,
        query: query,
        truncated: r.truncated,
        schoolLabel: schoolLabel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(studentQueryProvider);
    final result = ref.watch(studentSearchProvider);
    final sort = ref.watch(studentSortProvider);
    final total = ref.watch(groupStudentCountProvider).valueOrNull;
    final schools =
        ref.watch(adminSchoolsProvider).valueOrNull?.schools ?? const [];
    final filieres = ref.watch(groupFilieresProvider).valueOrNull ?? const [];

    return AppShell(
      title: 'Élèves du réseau',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GroupStudentFilters(
              controller: _search,
              query: query,
              schools: schools,
              filieres: filieres,
              total: total,
              onChanged: _update,
              onReset: _reset,
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
                data: (r) => _Results(
                  result: r,
                  sort: sort,
                  scopeLabel: _scopeLabel(query, schools),
                  onSort: (k) => ref.read(studentSortProvider.notifier).state =
                      sort.toggled(k),
                  onExport: (rows) => _openPdf(r, rows),
                ),
              ),
          ],
        ),
      ),
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
            ? 'Saisissez un nom ou un matricule, ou choisissez un département, '
                'un établissement ou une filière à parcourir.'
            : 'Le réseau compte $total élèves actifs. Saisissez un nom ou un '
                'matricule, ou choisissez un département, un établissement ou '
                'une filière à parcourir.',
      );
}

// ─── Résultats ──────────────────────────────────────────────────────────────
class _Results extends StatelessWidget {
  const _Results({
    required this.result,
    required this.sort,
    required this.scopeLabel,
    required this.onSort,
    required this.onExport,
  });

  final StudentSearchResult result;
  final StudentSortState sort;
  final String scopeLabel;
  final ValueChanged<StudentSort> onSort;
  final ValueChanged<List<GroupStudent>> onExport;

  @override
  Widget build(BuildContext context) {
    if (result.students.isEmpty) {
      return const AdminEmptyState(
        icon: Icons.search_off_rounded,
        title: 'Aucun élève trouvé',
        message: 'Aucun élève du réseau ne correspond à ces critères. '
            'Vérifiez l\'orthographe ou élargissez la recherche.',
      );
    }

    // Le tri s'applique à ce qui est affiché : c'est aussi l'ordre exporté,
    // pour que le PDF soit la copie fidèle de l'écran qui l'a demandé.
    final rows = sortStudents(result.students, sort);
    final unplaced = rows.where((s) => s.isUnplaced).length;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GroupStudentKpis(students: rows, scopeLabel: scopeLabel),
      const SizedBox(height: 20),
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
        const Spacer(),
        AdminPdfButton(
          label: 'Exporter la liste',
          onTap: () => onExport(rows),
        ),
      ]),
      const SizedBox(height: 12),
      if (result.truncated) ...[
        const _TruncatedNotice(),
        const SizedBox(height: 12),
      ],
      GroupStudentTable(students: rows, sort: sort, onSort: onSort),
    ]);
  }
}

/// Le plafond atteint doit être DIT : une liste coupée en silence ferait
/// prendre 200 élèves pour l'effectif réel.
class _TruncatedNotice extends StatelessWidget {
  const _TruncatedNotice();

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
              '$kStudentSearchLimit premiers (ordre alphabétique) sont '
              'affichés — affinez par département ou par filière pour voir '
              'les autres.',
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
