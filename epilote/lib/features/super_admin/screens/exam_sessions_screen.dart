import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/app_shell.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/exam_sessions_admin_provider.dart';
import 'exam_session_form_dialog.dart';

final _fmt = DateFormat('dd/MM/yyyy', 'fr_FR');

// ════════════════════════════════════════════════════════════════════════════
//  CALENDRIER NATIONAL DES EXAMENS — administration super_admin.
//
//  Les sessions 2025-2026 avaient été semées par une MIGRATION : à l'ouverture
//  de 2026-2027, personne n'aurait pu en créer une sans écrire du SQL. Cet
//  écran comble ce trou.
//
//  Ce qu'on saisit ici est une COPIE DE RÉFÉRENCE de l'arrêté ministériel — pas
//  la vérité. La DEC reste la source ; le jour où l'interface d'échange existe,
//  ce calendrier se tirera de chez eux.
// ════════════════════════════════════════════════════════════════════════════
class ExamSessionsScreen extends ConsumerWidget {
  const ExamSessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(examSessionsAdminProvider);

    return AppShell(
      title: 'Sessions d\'examen',
      actions: [
        FilledButton.icon(
          onPressed: () => showExamSessionForm(context),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Nouvelle session'),
          style: FilledButton.styleFrom(backgroundColor: kNavy),
        ),
      ],
      child: async.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.error_outline_rounded, color: kRed, size: 40),
            const SizedBox(height: 12),
            Text('Erreur : $e',
                textAlign: TextAlign.center,
                style: TextStyle(color: kTextMuted)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => ref.invalidate(examSessionsAdminProvider),
              child: const Text('Réessayer'),
            ),
          ]),
        ),
        data: (rows) => rows.isEmpty ? const _Empty() : _Body(rows: rows),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.rows});
  final List<ExamSessionAdminRow> rows;

  @override
  Widget build(BuildContext context) {
    // Groupées par année : c'est l'unité de travail réelle (un arrêté par an).
    final byYear = <String, List<ExamSessionAdminRow>>{};
    for (final r in rows) {
      byYear.putIfAbsent(r.yearLabel ?? '—', () => []).add(r);
    }
    final incomplete = rows.where((r) => r.missingDates).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: [
        _Intro(total: rows.length, incomplete: incomplete),
        const SizedBox(height: 24),
        for (final entry in byYear.entries) ...[
          Row(children: [
            Text(entry.key,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary)),
            const SizedBox(width: 8),
            Text('${entry.value.length} session(s)',
                style: TextStyle(fontSize: 12, color: kTextMuted)),
          ]),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kBorder),
            ),
            child: Column(children: [
              for (final (i, r) in entry.value.indexed)
                _SessionRow(row: r, first: i == 0),
            ]),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.total, required this.incomplete});
  final int total;
  final int incomplete;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: kNavy.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kNavy.withValues(alpha: 0.22)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.gavel_rounded, size: 18, color: kNavy),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Copie de référence de l\'arrêté ministériel',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary),
                ),
                const SizedBox(height: 3),
                Text(
                  '$total session(s) publiées vers toutes les écoles. '
                  'La DEC reste la source : en cas d\'écart, l\'arrêté fait foi.'
                  '${incomplete > 0 ? ' — $incomplete session(s) sans date d\'épreuve, à compléter.' : ''}',
                  style:
                      TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.4),
                ),
              ],
            ),
          ),
        ]),
      );
}

class _SessionRow extends ConsumerWidget {
  const _SessionRow({required this.row, required this.first});
  final ExamSessionAdminRow row;
  final bool first;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = row;
    final (Color tone, String label) = switch (r.status) {
      'open' => (kGreen, 'Ouverte'),
      'closed' => (kRed, 'Clôturée'),
      'running' => (kAccent, 'En cours'),
      'published' => (kNavy, 'Résultats publiés'),
      'cancelled' => (kTextMuted, 'Annulée'),
      _ => (kTextMuted, 'Brouillon'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: first
            ? null
            : Border(top: BorderSide(color: kBorder.withValues(alpha: 0.5))),
      ),
      child: Row(children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(r.examShortName,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: kTextPrimary)),
                if (r.tutelle != null) ...[
                  const SizedBox(width: 6),
                  Text(r.tutelle!.toUpperCase(),
                      style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: kTextMuted)),
                ],
              ]),
              Text(
                r.registrationOpensAt == null
                    ? 'inscriptions non datées'
                    : 'inscriptions ${_fmt.format(r.registrationOpensAt!)}'
                        '${r.registrationClosesAt != null ? ' → ${_fmt.format(r.registrationClosesAt!)}' : ''}',
                style: TextStyle(fontSize: 11, color: kTextMuted),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            r.writtenFrom == null
                ? '—'
                : 'écrits ${_fmt.format(r.writtenFrom!)}'
                    '${r.writtenTo != null ? ' → ${_fmt.format(r.writtenTo!)}' : ''}',
            style: TextStyle(
                fontSize: 11,
                color: r.missingDates ? kRed : kTextMuted,
                fontWeight: r.missingDates ? FontWeight.w600 : FontWeight.w400),
          ),
        ),
        SizedBox(
          width: 72,
          child: Text(
            r.candidateCount == 0 ? '—' : '${r.candidateCount} cand.',
            style: TextStyle(fontSize: 11.5, color: kTextMuted),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w700, color: tone)),
        ),
        IconButton(
          onPressed: () => showExamSessionForm(context, existing: r),
          icon: const Icon(Icons.edit_outlined, size: 17),
          color: kTextMuted,
          tooltip: 'Modifier',
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          // Supprimer une session emporterait ses candidatures — donc le
          // travail des écoles. Interdit dès qu'il y en a une.
          onPressed: r.isDeletable ? () => _confirmDelete(context, ref) : null,
          icon: const Icon(Icons.delete_outline_rounded, size: 17),
          color: r.isDeletable ? kTextMuted : kTextMuted.withValues(alpha: 0.35),
          tooltip: r.isDeletable
              ? 'Supprimer'
              : '${r.candidateCount} candidature(s) — suppression impossible',
          visualDensity: VisualDensity.compact,
        ),
      ]),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Supprimer la session ${row.examShortName} ?',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: kTextPrimary)),
        content: Text(
          'Elle disparaîtra de toutes les écoles à la prochaine synchronisation.',
          style: TextStyle(fontSize: 12.5, color: kTextMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Annuler', style: TextStyle(color: kTextMuted)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: kRed),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await deleteExamSession(ref.read(supabaseClientProvider), row.id);
      ref.invalidate(examSessionsAdminProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.event_busy_rounded, size: 44, color: kTextMuted),
            const SizedBox(height: 14),
            Text('Aucune session',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary)),
            const SizedBox(height: 8),
            Text(
              'Saisissez le calendrier de l\'arrêté ministériel : sans session '
              'ouverte, aucune école ne peut inscrire de candidat.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: kTextMuted, height: 1.5),
            ),
          ]),
        ),
      );
}
