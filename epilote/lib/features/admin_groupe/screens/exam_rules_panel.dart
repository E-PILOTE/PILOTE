import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/list_chrome.dart' show kListOrange, kListPurple;
import '../../auth/providers/auth_provider.dart';
import '../providers/exam_referential_provider.dart';
import 'exam_rule_form_dialog.dart';

final _fmtDay = DateFormat('dd/MM/yyyy', 'fr_FR');

// ════════════════════════════════════════════════════════════════════════════
//  LES RÈGLES D'UN EXAMEN — ce qui le relie aux classes du pays.
//
//  Une feuille montante, pas une page : on consulte les règles DEPUIS le
//  référentiel, on ne quitte pas l'examen des yeux. Les règles se lisent en
//  largeur (cycle · niveau · filière · tutelle · portée · validité) — la
//  géométrie qui convient à ce qui se lit en colonnes.
//
//  L'ordre d'affichage est celui du SERVEUR : de la plus spécifique à la plus
//  générale. C'est l'ordre dans lequel `resolve_class_exam` les départage,
//  donc le seul qui permette de prévoir laquelle l'emportera.
// ════════════════════════════════════════════════════════════════════════════
Future<void> showExamRulesPanel(
  BuildContext context, {
  required NationalExamRow exam,
}) =>
    showAdminBottomModal<void>(
      context,
      builder: (_) => _RulesPanel(exam: exam),
    );

class _RulesPanel extends ConsumerWidget {
  const _RulesPanel({required this.exam});
  final NationalExamRow exam;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(examReferentialProvider).valueOrNull;
    // On repart du référentiel rechargé : après une écriture, la règle neuve
    // doit apparaître sans refermer la feuille.
    final row = d?.exams.where((e) => e.id == exam.id).firstOrNull ?? exam;
    final rules = d?.rulesOf(exam.id) ?? const <ExamRuleRow>[];
    final today = DateTime.now();

    return AdminBottomModal(
      icon: Icons.rule_rounded,
      title: 'Règles d\'éligibilité · ${row.shortName}',
      subtitle: row.name,
      accent: kListPurple,
      maxWidth: 1080,
      headerTrailing: FilledButton.icon(
        onPressed: () => _add(context, ref, row),
        icon: const Icon(Icons.add_rounded, size: 16),
        label: const Text('Nouvelle règle'),
        style: FilledButton.styleFrom(backgroundColor: kListPurple),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!row.isDiplome)
            _Note(
              color: kNavy,
              icon: Icons.info_outline_rounded,
              text: '${row.shortName} est un CONCOURS : s\'y présenter est un '
                  'choix de l\'élève, pas une propriété de la classe. Aucune '
                  'règle n\'est nécessaire — la dérivation ne concerne que les '
                  'diplômes.',
            )
          else if (rules.isEmpty)
            _Note(
              color: kRed,
              icon: Icons.link_off_rounded,
              text: 'Aucune règle : aucune classe du pays ne prépare cet '
                  'examen. Les écoles verront leurs classes « à qualifier » et '
                  'ne pourront inscrire aucun candidat.',
            )
          else
            _Note(
              color: kTextMuted,
              icon: Icons.sort_rounded,
              text: 'De la plus spécifique à la plus générale — c\'est l\'ordre '
                  'dans lequel le serveur les départage : portée de groupe, '
                  'puis filière, puis tutelle. La première qui correspond '
                  'gagne.',
            ),
          const SizedBox(height: 16),
          if (rules.isNotEmpty) ...[
            _Head(),
            for (final r in rules)
              _Row(
                rule: r,
                inForce: r.isInForceOn(today),
                onEdit: () => _edit(context, ref, row, r),
                onDelete: () => _delete(context, ref, r),
              ),
          ] else if (row.isDiplome)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Center(
                child: OutlinedButton.icon(
                  onPressed: () => _add(context, ref, row),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Créer la première règle'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: kListPurple,
                      side: BorderSide(
                          color: kListPurple.withValues(alpha: 0.45)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 13)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _add(
      BuildContext context, WidgetRef ref, NationalExamRow row) async {
    final saved = await showExamRuleForm(context, exam: row);
    if (saved) ref.invalidate(examReferentialProvider);
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, NationalExamRow row,
      ExamRuleRow rule) async {
    final saved = await showExamRuleForm(context, exam: row, existing: rule);
    if (saved) ref.invalidate(examReferentialProvider);
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, ExamRuleRow rule) async {
    // Capturé AVANT la confirmation : après l'attente, le contexte de la
    // feuille peut avoir disparu.
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showAdminConfirm(
      context,
      title: 'Supprimer cette règle ?',
      message: 'Les classes qu\'elle qualifiait repasseront « à qualifier » '
          'dès le recalcul. Rien d\'irremplaçable n\'est détruit — '
          '`classes.exam_id` est dérivé — mais les écoles concernées ne '
          'pourront plus inscrire de candidat tant qu\'aucune autre règle ne '
          'les couvre.',
      confirmLabel: 'Supprimer',
      danger: true,
    );
    if (!ok) return;
    try {
      final client = ref.read(supabaseClientProvider);
      await deleteExamRule(client, rule.id);
      final n = await recomputeClassExams(client);
      ref.invalidate(examReferentialProvider);
      messenger.showSnackBar(SnackBar(
        content: Text(n == 0
            ? 'Règle supprimée. Aucune classe n\'a changé.'
            : 'Règle supprimée · $n classe(s) requalifiée(s).'),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.color, required this.icon, required this.text});
  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style:
                    TextStyle(fontSize: 12, color: kTextPrimary, height: 1.45)),
          ),
        ]),
      );
}

class _Head extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          border: Border.all(color: kBorder),
        ),
        child: Row(children: [
          _h('Cycle · Niveau', flex: 3),
          _h('Filière', flex: 3),
          _h('Tutelle', flex: 2),
          _h('Portée', flex: 2),
          _h('Validité', flex: 3),
          const SizedBox(width: 76),
        ]),
      );

  Widget _h(String t, {required int flex}) => Expanded(
        flex: flex,
        child: Text(t.toUpperCase(),
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: kTextMuted)),
      );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.rule,
    required this.inForce,
    required this.onEdit,
    required this.onDelete,
  });

  final ExamRuleRow rule;
  final bool inForce;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    // Une règle hors vigueur (datée pour plus tard, close, ou désactivée)
    // s'affiche mais ne dérive rien : elle s'estompe au lieu de mentir.
    final dim = !inForce;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: dim ? kSurface.withValues(alpha: 0.5) : kCardBg,
        border: Border(
          left: BorderSide(color: kBorder),
          right: BorderSide(color: kBorder),
          bottom: BorderSide(color: kBorder),
        ),
      ),
      child: Row(children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${rule.cycleCode} · ${rule.levelCode}',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: dim ? kTextMuted : kTextPrimary)),
              if (rule.note != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(rule.note!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5, color: kTextMuted)),
                ),
            ],
          ),
        ),
        Expanded(
          flex: 3,
          child: _Cell(
            text: rule.programCode ?? 'Toutes filières',
            joker: rule.programCode == null,
            dim: dim,
          ),
        ),
        Expanded(
          flex: 2,
          child: _Cell(
            text: rule.tutelle?.toUpperCase() ?? 'Toutes',
            joker: rule.tutelle == null,
            dim: dim,
          ),
        ),
        Expanded(
          flex: 2,
          child: Row(children: [
            Icon(rule.isNational ? Icons.public_rounded : Icons.hub_rounded,
                size: 13,
                color: rule.isNational ? kTextMuted : kListOrange),
            const SizedBox(width: 6),
            Expanded(
              child: Text(rule.isNational ? 'Nationale' : 'Groupe',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight:
                          rule.isNational ? FontWeight.w500 : FontWeight.w700,
                      color: rule.isNational ? kTextMuted : kListOrange)),
            ),
          ]),
        ),
        Expanded(
          flex: 3,
          child: Text(
            _validity(rule),
            style: TextStyle(
                fontSize: 11.5,
                color: inForce ? kTextPrimary : kListOrange,
                fontWeight: inForce ? FontWeight.w500 : FontWeight.w700),
          ),
        ),
        SizedBox(
          width: 76,
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            IconButton(
              tooltip: 'Modifier',
              icon: Icon(Icons.edit_outlined, size: 17, color: kNavy),
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: 'Supprimer',
              icon: Icon(Icons.delete_outline_rounded, size: 17, color: kRed),
              onPressed: onDelete,
            ),
          ]),
        ),
      ]),
    );
  }

  static String _validity(ExamRuleRow r) {
    if (!r.isActive) return 'Désactivée';
    if (r.validFrom == null && r.validTo == null) return 'Toujours';
    final from = r.validFrom == null ? '…' : _fmtDay.format(r.validFrom!);
    final to = r.validTo == null ? '…' : _fmtDay.format(r.validTo!);
    return '$from → $to';
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.text, required this.joker, required this.dim});
  final String text;
  final bool joker;
  final bool dim;

  @override
  Widget build(BuildContext context) => Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11.5,
          // Le joker s'écrit en italique discret : il se lit « n'importe
          // laquelle », pas comme une valeur saisie.
          fontStyle: joker ? FontStyle.italic : FontStyle.normal,
          color: joker || dim ? kTextMuted : kTextPrimary,
        ),
      );
}
