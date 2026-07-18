import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../navigation/providers/permissions_provider.dart';
import '../providers/examens_provider.dart';
import 'class_candidates_dialog.dart';
import 'exam_register_dialog.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Briques de la page Examens. Aucune couleur en dur : jetons de thème
//  uniquement (kNavy, kGreen…) — les 3 thèmes doivent tenir.
// ════════════════════════════════════════════════════════════════════════════

const _kMonths = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

String formatDate(DateTime? d) =>
    d == null ? '—' : '${d.day} ${_kMonths[d.month - 1]} ${d.year}';

// ─── Bandeau de session ─────────────────────────────────────────────────────
/// Rappelle l'échéance d'inscription. C'est l'information PÉRISSABLE : une
/// clôture manquée est irrattrapable (l'élève perd une année).
class ExamSessionBanner extends StatelessWidget {
  const ExamSessionBanner({super.key, required this.session, this.onTap});
  final ExamSessionRow session;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final days = s.daysLeft;

    // L'urgence pilote la couleur : rouge sous 15 jours, ambre sous 45.
    final (Color tone, String urgency) = switch (days) {
      null => (kNavy, ''),
      < 0 => (kTextMuted, 'inscriptions closes'),
      0 => (kRed, 'dernier jour !'),
      <= 15 => (kRed, 'plus que $days jour(s)'),
      <= 45 => (kAccent, '$days jours restants'),
      _ => (kGreen, '$days jours restants'),
    };

    return Material(
      color: kCardBg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tone.withValues(alpha: 0.45)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.event_available_rounded, color: tone, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(
                  '${s.examShortName} — session ${s.yearLabel}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                if (urgency.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: tone.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      urgency,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: tone,
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 4),
              Text(
                'Inscriptions du ${formatDate(s.opensAt)} au ${formatDate(s.closesAt)}'
                '${s.writtenFrom != null ? ' · écrits le ${formatDate(s.writtenFrom)}' : ''}'
                '${s.maxAge != null ? ' · âge max ${s.maxAge} ans' : ''}',
                style: TextStyle(fontSize: 12, color: kTextMuted, height: 1.4),
              ),
            ],
          ),
        ),
        if (onTap != null)
          Icon(Icons.chevron_right_rounded, color: kTextMuted, size: 20),
      ]),
        ),
      ),
    );
  }
}

// ─── Groupe de classes par diplôme ──────────────────────────────────────────
class ExamGroupCard extends StatelessWidget {
  const ExamGroupCard({
    super.key,
    required this.examCode,
    required this.examName,
    required this.rows,
  });

  final String examCode;
  final String examName;
  final List<ExamClassRow> rows;

  @override
  Widget build(BuildContext context) {
    final students = rows.fold(0, (s, r) => s + r.effectif);
    final candidates = rows.fold(0, (s, r) => s + r.candidates);

    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(children: [
        // En-tête du diplôme
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: kNavy.withValues(alpha: 0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border(bottom: BorderSide(color: kBorder)),
          ),
          child: Row(children: [
            Icon(Icons.workspace_premium_rounded, color: kNavy, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    examName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary,
                    ),
                  ),
                  Text(
                    '$examCode · ${rows.length} classe(s) · $students élève(s)',
                    style: TextStyle(fontSize: 11.5, color: kTextMuted),
                  ),
                ],
              ),
            ),
            _CountPill(
              value: '$candidates/$students',
              tone: candidates == students && students > 0 ? kGreen : kAccent,
              label: 'inscrits',
            ),
          ]),
        ),
        for (final r in rows) _ClassRow(row: r),
      ]),
    );
  }
}

class _ClassRow extends ConsumerWidget {
  const _ClassRow({required this.row});
  final ExamClassRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = row;
    // Verrou 3 : seul qui peut créer une candidature voit le bouton.
    final canRegister =
        ref.watch(canProvider((slug: 'examens', action: 'create')));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: kBorder.withValues(alpha: 0.5))),
      ),
      child: Row(children: [
        Expanded(
          flex: 3,
          child: Row(children: [
            Text(
              r.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: kTextPrimary,
              ),
            ),
            if (r.filiereLabel != null && r.filiereLabel!.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                r.filiereLabel!,
                style: TextStyle(fontSize: 11, color: kTextMuted),
              ),
            ],
            // La surcharge doit se voir : c'est une décision humaine qui écarte
            // la règle nationale, elle doit rester traçable à l'œil.
            if (r.isOverridden) ...[
              const SizedBox(width: 8),
              Tooltip(
                message: 'Examen forcé manuellement (surcharge de la règle nationale)',
                child: Icon(Icons.edit_note_rounded, size: 15, color: kAccent),
              ),
            ],
          ]),
        ),
        Expanded(
          flex: 2,
          child: Text(
            '${r.effectif} élève(s)',
            style: TextStyle(fontSize: 12, color: kTextMuted),
          ),
        ),
        if (r.missing > 0)
          _CountPill(
            value: '${r.missing}',
            tone: kRed,
            label: 'à inscrire',
          )
        else if (r.effectif > 0)
          _CountPill(value: '✓', tone: kGreen, label: 'complet'),
        const SizedBox(width: 8),
        if (canRegister)
          Tooltip(
            message: r.missing > 0
                ? 'Inscrire les élèves à ${r.examShortName}'
                : 'Gérer les candidatures',
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: r.missing > 0 ? kNavy : kTextMuted,
                side: BorderSide(color: r.missing > 0 ? kNavy : kBorder),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: const Size(0, 32),
                visualDensity: VisualDensity.compact,
              ),
              // Deux intentions, deux écrans : on INSCRIT ceux qui manquent,
              // on CONSULTE ceux qui sont déjà là. Le même modal pour les deux
              // rendait la consultation illisible passé quelques dizaines
              // d'inscrits.
              onPressed: () => r.missing > 0
                  ? showExamRegisterDialog(
                      context,
                      classId: r.id,
                      className: r.name,
                    )
                  : showClassCandidatesDialog(
                      context,
                      classId: r.id,
                      className: r.name,
                    ),
              icon: const Icon(Icons.how_to_reg_rounded, size: 15),
              label: Text(r.missing > 0 ? 'Inscrire' : 'Voir',
                  style: const TextStyle(fontSize: 12)),
            ),
          ),
      ]),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.value, required this.tone, required this.label});
  final String value;
  final Color tone;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '$value $label',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: tone,
          ),
        ),
      );
}

// ─── Anomalies ──────────────────────────────────────────────────────────────
/// Classes de niveau TERMINAL sans examen résolu. Ce n'est pas un bug : c'est
/// une règle manquante au référentiel, ou une filière non saisie sur la classe.
/// L'afficher explicitement évite le pire — des candidats jamais inscrits.
class ExamAnomalyCard extends StatelessWidget {
  const ExamAnomalyCard({super.key, required this.rows});
  final List<ExamClassRow> rows;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kAccent.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kAccent.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.help_outline_rounded, color: kAccent, size: 20),
              const SizedBox(width: 10),
              Text(
                '${rows.length} classe(s) à qualifier',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary,
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Text(
              'Ces classes sont au niveau terminal de leur cycle : un examen d\'État '
              'y est attendu, mais aucune règle ne l\'a déterminé. Cause probable : '
              'la filière n\'est pas renseignée sur la classe, ou la règle manque au '
              'référentiel national.',
              style: TextStyle(fontSize: 12, color: kTextMuted, height: 1.5),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in rows)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: kCardBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kBorder),
                    ),
                    child: Text(
                      '${r.name} · ${r.levelCode}'
                      '${r.filiereLabel != null && r.filiereLabel!.isNotEmpty ? ' · ${r.filiereLabel}' : ' · sans filière'}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: kTextPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
}

// ─── Étiquette de section ───────────────────────────────────────────────────
class ExamSectionLabel extends StatelessWidget {
  const ExamSectionLabel(this.text, {super.key, this.trailing});
  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Row(children: [
        Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: kTextMuted,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Divider(color: kBorder, height: 1)),
        if (trailing != null) ...[
          const SizedBox(width: 10),
          Text(trailing!, style: TextStyle(fontSize: 11.5, color: kTextMuted)),
        ],
      ]);
}

// ─── États vides / erreur ───────────────────────────────────────────────────
class ExamEmptyState extends StatelessWidget {
  const ExamEmptyState({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.workspace_premium_outlined, size: 44, color: kTextMuted),
              const SizedBox(height: 14),
              Text(
                'Aucune classe d\'examen',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Aucune classe de cette école n\'est au niveau terminal d\'un cycle '
                '(CM2, 3e, Terminale…). Les classes de passage n\'apparaissent pas ici.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: kTextMuted, height: 1.5),
              ),
            ],
          ),
        ),
      );
}

class ExamErrorCard extends StatelessWidget {
  const ExamErrorCard({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 40, color: kRed),
              const SizedBox(height: 12),
              Text(
                'Impossible de charger les examens',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: kTextMuted),
              ),
            ],
          ),
        ),
      );
}
