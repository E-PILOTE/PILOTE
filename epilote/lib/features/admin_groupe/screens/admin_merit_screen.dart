import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/list_chrome.dart';
import '../../../core/widgets/pdf_preview_dialog.dart';
import '../providers/admin_dashboard_provider.dart';
import '../providers/admin_merit_provider.dart';
import '../providers/student_dossier_provider.dart';
import '../services/merit_pdf_service.dart';
import '../widgets/merit_podium.dart';
import '../widgets/merit_table.dart';
import '../widgets/student_dossier_dialog.dart';

// ════════════════════════════════════════════════════════════════════════════
//  MEILLEURS ÉLÈVES — écran du ministère (admin_groupe, online).
//
//  Le titre dit ce que la page FAIT, pas comment on l'appelle en séance :
//  « Palmarès national » supposait qu'on sache déjà de quoi il s'agit. Le
//  document imprimé, lui, garde le vocabulaire officiel (« Palmarès des
//  lauréats ») — c'est la pièce, pas la porte d'entrée.
//
//  À quoi il sert concrètement : constituer la liste courte d'une commission
//  de bourses, d'une distinction ou d'une affectation, et l'emporter en séance
//  sous forme de document officiel.
//
//  Le classement repose sur l'examen d'État — seule épreuve commune à tous les
//  établissements (cf. admin_merit_provider.dart). Le contrôle continu est
//  montré à part, et n'est jamais présenté comme un classement inter-écoles :
//  c'est le point de rigueur de cet écran.
// ════════════════════════════════════════════════════════════════════════════
class AdminMeritScreen extends ConsumerStatefulWidget {
  const AdminMeritScreen({super.key});

  @override
  ConsumerState<AdminMeritScreen> createState() => _State();
}

class _State extends ConsumerState<AdminMeritScreen> {
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminMeritProvider);
    final filter = ref.watch(meritFilterProvider);

    return AppShell(
      title: 'Meilleurs élèves du réseau',
      child: async.when(
        skipLoadingOnReload: true,
        loading: () => const ListShimmer(),
        error: (e, _) => _ErrorView(
            message: '$e', onRetry: () => ref.invalidate(adminMeritProvider)),
        data: (d) {
          // L'examen est arrêté AVANT tout classement : sans lui, `rankMerit`
          // alignerait des épreuves de niveaux différents. On corrige l'état
          // après la frame — le modifier pendant le build relancerait la
          // construction en cours.
          final exam = resolveExam(d, filter.exam);
          if (exam != filter.exam) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              ref.read(meritFilterProvider.notifier).state =
                  filter.copyWith(exam: exam);
            });
          }
          final rows = rankMerit(d.entries, filter.copyWith(exam: exam));
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Intro(yearLabel: d.yearLabel, exam: exam),
                const SizedBox(height: 18),
                KpiGrid(items: _kpis(d, rows, exam)),
                const SizedBox(height: 20),
                if (d.unranked > 0) ...[
                  _UnrankedNotice(count: d.unranked),
                  const SizedBox(height: 16),
                ],
                MeritPodium(rows: rows, onTap: (r) => _openLaureate(r, d, exam)),
                const SizedBox(height: 20),
                _Filters(data: d, filter: filter),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: ListResultHeader(
                        total: d.entries.length,
                        filtered: rows.length,
                        noun: 'lauréat'),
                  ),
                  if (rows.isNotEmpty)
                    AdminPdfButton(
                      label: 'Palmarès officiel',
                      onTap: () => _openPdf(d, rows, exam),
                    ),
                ]),
                const SizedBox(height: 12),
                if (rows.isEmpty)
                  AdminEmptyState(
                    icon: Icons.emoji_events_outlined,
                    title: d.entries.isEmpty
                        ? 'Aucun résultat proclamé'
                        : 'Aucun lauréat sur ce périmètre',
                    message: d.entries.isEmpty
                        ? 'Le palmarès se construit à partir des résultats aux '
                            'examens d\'État. Il apparaîtra dès qu\'une session '
                            'sera proclamée et les moyennes saisies.'
                        : 'Élargissez les critères pour retrouver des lauréats.',
                  )
                else
                  MeritTable(
                      rows: rows, onTap: (r) => _openLaureate(r, d, exam)),
                const SizedBox(height: 24),
                const _ContinuousAssessmentNote(),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Ouvre le dossier complet du lauréat, précédé de sa distinction.
  ///
  /// On ne construit PAS une seconde fiche « lauréat » : le dossier de l'élève
  /// existe déjà et fait autorité. On lui ajoute seulement le contexte
  /// d'examen — rang, moyenne, mention — et surtout LE PÉRIMÈTRE dans lequel ce
  /// rang a été calculé : un 1ᵉʳ filtré sur une filière n'est pas un 1ᵉʳ
  /// national, et le laisser croire ferait attribuer une bourse de travers.
  void _openLaureate(RankedMerit r, MeritData d, String? exam) {
    // On relit le filtre en y réinjectant l'examen résolu : au tout premier
    // rendu, l'état n'a pas encore été recalé et porterait un périmètre faux.
    final filter = ref.read(meritFilterProvider).copyWith(exam: exam);
    showStudentDossierDialog(
      context,
      r.entry.studentId,
      distinction: DossierDistinction(
        rank: r.rank,
        average: r.entry.average,
        mention: r.entry.mention,
        scope: filter.scopeLabel,
        exAequo: r.exAequo,
        sessionLabel: d.yearLabel,
        candidateNumber: r.entry.candidateNumber,
      ),
    );
  }

  List<KpiData> _kpis(MeritData d, List<RankedMerit> rows, String? exam) {
    final share = femaleShare(rows);
    final schools = rows.map((r) => r.entry.schoolId).toSet().length;
    final best = rows.isEmpty ? null : rows.first.entry;

    // Assiette de l'examen affiché, et non le total du réseau : rapporter un
    // top 10 du BET aux admis de TOUS les examens donnerait une proportion qui
    // ne veut rien dire.
    final classable =
        d.entries.where((e) => exam == null || e.examShortName == exam).length;

    return [
      KpiData(
        label: 'Lauréats au palmarès',
        value: '${rows.length}',
        sub: exam == null
            ? 'sur ${d.admittedTotal} admis du réseau'
            : 'sur $classable classés au $exam',
        icon: Icons.emoji_events_rounded,
        color: kNavy,
      ),
      KpiData(
        label: 'Meilleure moyenne',
        value: best == null ? '—' : best.average.toStringAsFixed(2),
        sub: best?.schoolName,
        icon: Icons.star_rounded,
        color: const Color(0xFFD4AF37),
      ),
      KpiData(
        label: 'Établissements représentés',
        value: '$schools',
        sub: schools > 1
            ? 'le mérite n\'est pas concentré'
            : 'un seul établissement',
        icon: Icons.account_balance_rounded,
        color: kGreen,
      ),
      KpiData(
        label: 'Part de filles',
        value: share == null ? '—' : '${share.toStringAsFixed(0)} %',
        sub: 'parité du palmarès',
        icon: Icons.female_rounded,
        color: const Color(0xFF7C3AED),
        progressValue: share == null ? null : share / 100,
      ),
    ];
  }

  void _openPdf(MeritData d, List<RankedMerit> rows, String? exam) {
    final groupName = ref.read(adminDashboardProvider).valueOrNull?.groupName ??
        'Groupe scolaire';
    final filter = ref.read(meritFilterProvider).copyWith(exam: exam);
    showPdfPreviewDialog(
      context,
      // Le document garde le vocabulaire officiel : c'est la pièce qu'une
      // commission verse au dossier, pas l'intitulé de la page.
      title: 'Palmarès des lauréats',
      subtitle: filter.scopeLabel,
      pdfFileName: 'palmares_national.pdf',
      build: (_) => MeritPdfService.buildPdf(
          groupName: groupName, rows: rows, filter: filter, data: d),
      onDownload: () => MeritPdfService.download(
          groupName: groupName, rows: rows, filter: filter, data: d),
    );
  }
}

// ─── Bandeau d'intention ────────────────────────────────────────────────────
class _Intro extends StatelessWidget {
  const _Intro({this.yearLabel, this.exam});
  final String? yearLabel;
  final String? exam;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      accent: kNavy,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.workspace_premium_rounded, size: 26, color: kNavy),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              [
                'Les meilleurs lauréats du réseau',
                if (exam != null) 'au $exam',
                if (yearLabel != null) '— session $yearLabel',
              ].join(' '),
              style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary),
            ),
            const SizedBox(height: 5),
            Text(
              'Classement établi sur la moyenne obtenue à l\'examen d\'État : '
              'même sujet, même jury, même barème pour tous les établissements. '
              'C\'est la seule base comparable entre écoles, donc la seule '
              'opposable pour une bourse ou une distinction.',
              style: TextStyle(fontSize: 12.5, color: kTextMuted, height: 1.45),
            ),
            const SizedBox(height: 5),
            Text(
              'Un palmarès porte sur UN examen : les moyennes du CEPE, du BET '
              'et du Baccalauréat ne se comparent pas entre elles. Changez '
              'd\'examen dans le périmètre ci-dessous pour voir les meilleurs '
              'de chaque épreuve.',
              style: TextStyle(fontSize: 12, color: kTextMuted, height: 1.45),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ─── Admis non classés ──────────────────────────────────────────────────────
class _UnrankedNotice extends StatelessWidget {
  const _UnrankedNotice({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kRed.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kRed.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(Icons.info_outline_rounded, size: 18, color: kRed),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '$count admis ne peuvent pas être classés : leur moyenne n\'est pas '
            'saisie. Ils sont exclus du palmarès, jamais placés en fin de liste.',
            style: TextStyle(fontSize: 12.5, color: kTextPrimary),
          ),
        ),
      ]),
    );
  }
}

// ─── Filtres ────────────────────────────────────────────────────────────────
class _Filters extends ConsumerWidget {
  const _Filters({required this.data, required this.filter});
  final MeritData data;
  final MeritFilter filter;

  static const _kAll = '__all__';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void update(MeritFilter f) =>
        ref.read(meritFilterProvider.notifier).state = f;

    Map<String, String> opts(List<String> values, String allLabel) => {
          _kAll: allLabel,
          for (final v in values) v: v,
        };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.tune_rounded, size: 16, color: kTextMuted),
          const SizedBox(width: 8),
          Text('Périmètre du palmarès',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary)),
          const Spacer(),
          if (!filter.isDefault)
            TextButton.icon(
              onPressed: () =>
                  update(MeritFilter(exam: filter.exam, topN: filter.topN)),
              icon: Icon(Icons.filter_alt_off_rounded, size: 14, color: kRed),
              label: Text('Réinitialiser',
                  style: TextStyle(fontSize: 11.5, color: kRed)),
            ),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: [
          // PAS d'option « tous les examens » : un classement qui mêlerait le
          // CEPE et le Baccalauréat n'aurait aucun sens (cf. MeritFilter.exam).
          // L'examen est toujours l'un de ceux qui ont des lauréats.
          _Slot(
            child: ListFilterDropdown(
              icon: Icons.workspace_premium_rounded,
              label: 'Examen',
              value: filter.exam ?? (data.exams.isEmpty ? _kAll : data.exams.first),
              items: data.exams.isEmpty
                  ? {_kAll: 'Aucun examen proclamé'}
                  : {for (final v in data.exams) v: v},
              onChanged: (v) =>
                  update(filter.copyWith(exam: v == _kAll ? null : v)),
            ),
          ),
          _Slot(
            child: ListFilterDropdown(
              icon: Icons.engineering_rounded,
              label: 'Filière',
              value: filter.filiere ?? _kAll,
              items: opts(data.filieres, 'Toutes les filières'),
              onChanged: (v) =>
                  update(filter.copyWith(filiere: v == _kAll ? null : v)),
            ),
          ),
          _Slot(
            child: ListFilterDropdown(
              icon: Icons.map_rounded,
              label: 'Département',
              value: filter.department ?? _kAll,
              items: opts(data.departments, 'Tout le territoire'),
              onChanged: (v) =>
                  update(filter.copyWith(department: v == _kAll ? null : v)),
            ),
          ),
          _Slot(
            child: ListFilterDropdown(
              icon: Icons.wc_rounded,
              label: 'Sexe',
              value: filter.gender ?? _kAll,
              items: const {_kAll: 'Filles et garçons', 'F': 'Filles', 'M': 'Garçons'},
              onChanged: (v) =>
                  update(filter.copyWith(gender: v == _kAll ? null : v)),
            ),
          ),
          _Slot(
            child: ListFilterDropdown(
              icon: Icons.format_list_numbered_rounded,
              label: 'Taille',
              value: '${filter.topN}',
              items: const {
                '5': 'Top 5',
                '10': 'Top 10',
                '20': 'Top 20',
                '50': 'Top 50',
              },
              onChanged: (v) =>
                  update(filter.copyWith(topN: int.tryParse(v) ?? 10)),
            ),
          ),
        ]),
      ]),
    );
  }
}

/// Largeur fixe : les listes déroulantes d'un `Wrap` doivent être bornées,
/// sinon elles s'étirent à l'infini et le retour à la ligne ne se produit pas.
class _Slot extends StatelessWidget {
  const _Slot({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 224, height: 40, child: child);
}

// ─── Contrôle continu : dit, mais jamais classé ─────────────────────────────
class _ContinuousAssessmentNote extends ConsumerWidget {
  const _ContinuousAssessmentNote();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(publishedBulletinsCountProvider).valueOrNull;

    return AdminCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const AdminSectionTitle(
          'Contrôle continu',
          icon: Icons.menu_book_rounded,
          subtitle: 'Pourquoi il n\'entre pas dans ce classement',
        ),
        const SizedBox(height: 12),
        Text(
          'Les moyennes de bulletin ne sont pas comparables d\'un établissement '
          'à l\'autre : enseignants, exigences et coefficients diffèrent. Les '
          'classer entre écoles reviendrait à récompenser l\'indulgence d\'un '
          'correcteur — et se contesterait devant la première famille écartée.',
          style: TextStyle(fontSize: 12.5, color: kTextMuted, height: 1.5),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kBorder),
          ),
          child: Row(children: [
            Icon(
              count == null || count == 0
                  ? Icons.hourglass_empty_rounded
                  : Icons.check_circle_outline_rounded,
              size: 17,
              color: count == null || count == 0 ? kTextMuted : kGreen,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                switch (count) {
                  null => 'Bulletins publiés sur le réseau : lecture en cours…',
                  0 => 'Aucun bulletin publié sur le réseau à ce jour. Le suivi '
                      'du contrôle continu s\'activera dès que les établissements '
                      'publieront leurs bulletins.',
                  _ => '$count bulletins publiés sur le réseau. Ils alimentent le '
                      'suivi par établissement, jamais un classement entre écoles.',
                },
                style: TextStyle(fontSize: 12, color: kTextPrimary, height: 1.4),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ─── Erreur ─────────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.error_outline_rounded, size: 40, color: kRed),
            const SizedBox(height: 12),
            Text('Palmarès indisponible',
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
