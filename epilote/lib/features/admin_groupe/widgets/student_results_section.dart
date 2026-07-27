import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/mention.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/list_chrome.dart';
import '../providers/passage_merit_provider.dart' show Trimester, trimestersProvider;
import '../providers/student_dossier_provider.dart';
import '../providers/student_results_provider.dart';
import 'student_dossier_sections.dart';

// ════════════════════════════════════════════════════════════════════════════
//  RÉSULTATS PAR MATIÈRE — bloc du dossier de l'élève.
//
//  Remplace l'ancienne liste « équipe enseignante », qui décrivait la classe
//  plutôt que l'élève. L'enseignant reste présent, mais en colonne : on lit
//  d'abord la matière et la note, et l'on sait qui l'a donnée.
//
//  L'enseignement technique aligne beaucoup de matières — le tableau est donc
//  dense par construction, et la moyenne de la classe est collée à celle de
//  l'élève pour que chaque ligne se lise sans calcul mental.
// ════════════════════════════════════════════════════════════════════════════
/// Trimestre affiché dans le dossier. `null` = année entière.
///
/// Volontairement HORS de la clé du dossier : on change de période sans
/// recharger l'identité, la famille ni l'établissement.
final dossierTrimesterProvider =
    StateProvider.autoDispose<String?>((ref) => _unset);

/// Sentinelle : tant que l'utilisateur n'a rien choisi, on affiche le trimestre
/// EN COURS. Un `null` initial signifierait « année entière » et masquerait la
/// période que l'établissement est en train de vivre.
const _unset = '__unset__';

class StudentResultsSection extends ConsumerWidget {
  const StudentResultsSection({super.key, required this.dossier});

  final StudentDossier dossier;

  /// Trimestre effectif : le choix de l'utilisateur, sinon celui en cours.
  String? _effective(String? chosen, List<Trimester> trimesters) {
    if (chosen != _unset) return chosen;
    for (final t in trimesters) {
      if (t.isCurrent) return t.id;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = dossier.enrollment;
    final classId = e.classId;
    final yearId = e.academicYearId;

    if (classId == null || yearId == null) {
      return const DossierSection(
        title: 'Résultats par matière',
        icon: Icons.assessment_outlined,
        child: DossierEmpty(
          'Aucune inscription pour l\'année en cours : il n\'y a pas de '
          'résultats à présenter.',
        ),
      );
    }

    final trimesters = ref.watch(trimestersProvider).valueOrNull ?? const [];
    final chosen = ref.watch(dossierTrimesterProvider);
    final trimesterId = _effective(chosen, trimesters);

    final async = ref.watch(studentResultsProvider(ResultsKey(
      studentId: dossier.id,
      classId: classId,
      academicYearId: yearId,
      trimesterId: trimesterId,
    )));

    return DossierSection(
      title: 'Résultats par matière',
      icon: Icons.assessment_outlined,
      trailing: _TrimesterPicker(
        value: trimesterId,
        trimesters: trimesters,
        onChanged: (v) =>
            ref.read(dossierTrimesterProvider.notifier).state = v,
      ),
      child: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 22),
          child: Center(
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))),
        ),
        error: (err, _) => DossierEmpty('Résultats indisponibles — $err'),
        data: (r) => r.isEmpty
            ? const DossierEmpty(
                'Aucune évaluation publiée pour cette classe. Les moyennes '
                'apparaîtront dès que l\'établissement aura publié ses notes.')
            : _Table(
                results: r,
                teachers: dossier.teachers,
                periodLabel: _periodLabel(trimesterId, trimesters),
              ),
      ),
    );
  }
}

String _periodLabel(String? id, List<Trimester> trimesters) {
  if (id == null) return 'année entière';
  for (final t in trimesters) {
    if (t.id == id) return t.label.toLowerCase();
  }
  return 'période sélectionnée';
}

/// Sélecteur de période, posé dans l'en-tête de la section.
class _TrimesterPicker extends StatelessWidget {
  const _TrimesterPicker({
    required this.value,
    required this.trimesters,
    required this.onChanged,
  });

  final String? value;
  final List<Trimester> trimesters;
  final ValueChanged<String?> onChanged;

  static const _kYear = '__annee__';

  @override
  Widget build(BuildContext context) {
    if (trimesters.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      width: 210,
      height: 34,
      child: ListFilterDropdown(
        icon: Icons.event_note_rounded,
        label: 'Période',
        value: value ?? _kYear,
        items: {
          for (final t in trimesters)
            t.id: t.isCurrent ? '${t.label} (en cours)' : t.label,
          _kYear: 'Année entière',
        },
        onChanged: (v) => onChanged(v == _kYear ? null : v),
      ),
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({
    required this.results,
    required this.teachers,
    required this.periodLabel,
  });

  final StudentResults results;
  final List<DossierTeacher> teachers;
  final String periodLabel;

  /// Enseignant de la matière, s'il est connu. La correspondance se fait par
  /// nom de matière : c'est la seule clé commune aux deux jeux de données.
  String? _teacherOf(String subject) {
    for (final t in teachers) {
      if (t.subject.toLowerCase() == subject.toLowerCase()) return t.fullName;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final overall = results.overall;

    return Column(children: [
      Container(
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorder),
        ),
        child: Column(children: [
          const _HeaderRow(),
          for (var i = 0; i < results.subjects.length; i++)
            _Row(
              result: results.subjects[i],
              teacher: _teacherOf(results.subjects[i].subject),
              striped: i.isOdd,
            ),
          _Overall(overall: overall, classOverall: results.classOverall),
        ]),
      ),
      const SizedBox(height: 8),
      // La portée de ces chiffres est écrite SOUS le tableau : sans elle, un
      // lecteur pressé comparerait deux élèves de deux écoles différentes.
      Text(
        'Contrôle continu de l\'établissement — $periodLabel — '
        '${results.evaluatedCount} matière'
        '${results.evaluatedCount > 1 ? 's' : ''} évaluée'
        '${results.evaluatedCount > 1 ? 's' : ''}. Ces moyennes situent l\'élève '
        'dans SA classe ; elles ne permettent pas de comparer des élèves '
        'd\'établissements différents (seul l\'examen d\'État le permet).',
        style: TextStyle(fontSize: 11, color: kTextMuted, height: 1.4),
      ),
    ]);
  }
}

const _kFlex = <int>[34, 8, 15, 15, 28];

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  static const _labels = ['MATIÈRE', 'COEF', 'ÉLÈVE', 'CLASSE', 'ENSEIGNANT'];

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: kBorder)),
        ),
        child: Row(children: [
          for (var i = 0; i < _labels.length; i++)
            Expanded(
              flex: _kFlex[i],
              child: Padding(
                padding:
                    EdgeInsets.only(right: i == _labels.length - 1 ? 0 : 8),
                child: Text(
                  _labels[i],
                  textAlign: (i == 1 || i == 2 || i == 3)
                      ? TextAlign.right
                      : TextAlign.left,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: kTextMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5),
                ),
              ),
            ),
        ]),
      );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.result,
    required this.teacher,
    required this.striped,
  });

  final SubjectResult result;
  final String? teacher;
  final bool striped;

  @override
  Widget build(BuildContext context) {
    final r = result;
    final avg = r.average;
    // Vert au-dessus de la classe, rouge sous la barre de réussite : la couleur
    // ne remplace pas le chiffre, elle désigne où regarder d'abord.
    final color = avg == null
        ? kTextMuted
        : avg < 10
            ? kRed
            : (r.delta ?? 0) > 0
                ? kGreen
                : kTextPrimary;

    Widget cell(int i, String text,
            {Color? c, FontWeight? w, double size = 12}) =>
        Expanded(
          flex: _kFlex[i],
          child: Padding(
            padding: EdgeInsets.only(right: i == _kFlex.length - 1 ? 0 : 8),
            child: Text(
              text,
              textAlign:
                  (i == 1 || i == 2 || i == 3) ? TextAlign.right : TextAlign.left,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: c ?? kTextMuted,
                  fontSize: size,
                  fontWeight: w ?? FontWeight.w500),
            ),
          ),
        );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: striped ? kSurface.withValues(alpha: 0.5) : Colors.transparent,
        border: Border(bottom: BorderSide(color: kBorder.withValues(alpha: 0.5))),
      ),
      child: Row(children: [
        cell(0, r.subject, c: kTextPrimary, w: FontWeight.w600),
        cell(1, '${r.coefficient}'),
        cell(2, avg == null ? 'non évaluée' : avg.toStringAsFixed(2),
            c: color, w: FontWeight.w800, size: avg == null ? 10.5 : 12.5),
        cell(3, r.classAverage == null ? '—' : r.classAverage!.toStringAsFixed(2)),
        cell(4, teacher ?? '—'),
      ]),
    );
  }
}

class _Overall extends StatelessWidget {
  const _Overall({required this.overall, required this.classOverall});

  final double? overall;
  final double? classOverall;

  @override
  Widget build(BuildContext context) {
    final v = overall;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kNavy.withValues(alpha: 0.06),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(9)),
      ),
      child: Row(children: [
        Expanded(
          flex: _kFlex[0],
          child: Text('Moyenne générale',
              style: TextStyle(
                  color: kTextPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800)),
        ),
        Expanded(flex: _kFlex[1], child: const SizedBox()),
        Expanded(
          flex: _kFlex[2],
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              v == null ? '—' : v.toStringAsFixed(2),
              textAlign: TextAlign.right,
              style: TextStyle(
                  color: v == null
                      ? kTextMuted
                      : (v < 10 ? kRed : kNavy),
                  fontSize: 14,
                  fontWeight: FontWeight.w900),
            ),
          ),
        ),
        Expanded(
          flex: _kFlex[3],
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              classOverall == null ? '—' : classOverall!.toStringAsFixed(2),
              textAlign: TextAlign.right,
              style: TextStyle(color: kTextMuted, fontSize: 12),
            ),
          ),
        ),
        Expanded(
          flex: _kFlex[4],
          // Mention issue de la source unique `mentionFor` — jamais d'un
          // barème recopié ici (cf. CLAUDE.md : la dérive a déjà eu lieu).
          child: Text(v == null ? '' : mentionFor(v),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: kNavy, fontSize: 11.5, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}
