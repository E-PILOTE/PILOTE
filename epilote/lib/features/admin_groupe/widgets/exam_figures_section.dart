import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/list_chrome.dart';
import '../providers/exam_archives_provider.dart';
import 'exam_figure_panel.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LES CHIFFRES RELEVÉS — la contrepartie de l'archive.
//
//  L'écran savait dire combien de chiffres n'avaient pas de source ; il ne
//  savait pas dire LESQUELS, ni permettre d'y remédier. Un indicateur qu'on ne
//  peut pas suivre jusqu'à la ligne fautive n'est pas un indicateur de
//  pilotage, c'est un reproche.
//
//  Cette section liste les relevés d'une session, signale ceux qui ne
//  s'appuient sur aucune pièce, et ouvre chacun à la correction. C'est aussi le
//  seul endroit d'où l'on peut relever un chiffre annoncé avant que le document
//  n'arrive — cas ordinaire : la DEC proclame, le PDF suit.
// ════════════════════════════════════════════════════════════════════════════
final _sessionFilterProvider = StateProvider.autoDispose<String?>((_) => null);
final _unsourcedOnlyProvider = StateProvider.autoDispose<bool>((_) => false);

class ExamFiguresSection extends ConsumerWidget {
  const ExamFiguresSection({super.key, required this.figures});

  /// Reçus de l'écran. `archiveSessionsProvider` reste observé localement :
  /// c'est un référentiel (la liste des sessions), pas une donnée de page.
  final List<OfficialFigure> figures;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(archiveSessionsProvider).valueOrNull ?? const [];
    final sessionId = ref.watch(_sessionFilterProvider);
    final unsourcedOnly = ref.watch(_unsourcedOnlyProvider);

    return AdminCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(
            child: AdminSectionTitle(
              'Chiffres relevés',
              icon: Icons.fact_check_rounded,
              subtitle: 'Ce que la DSIC a lu sur les publications — corrigeable '
                  'ligne par ligne',
            ),
          ),
          FilledButton.icon(
            onPressed: () =>
                showExamFigurePanel(context, sessionId: sessionId),
            icon: const Icon(Icons.add_rounded, size: 17),
            label: const Text('Relever un chiffre'),
            style: FilledButton.styleFrom(backgroundColor: kNavy),
          ),
        ]),
        const SizedBox(height: 14),
        Builder(builder: (context) {
          final all = figures;
          final unsourced = all.where((f) => !f.hasSource).length;
          var rows = all;
          if (sessionId != null) {
            rows = rows.where((f) => f.sessionId == sessionId).toList();
          }
          if (unsourcedOnly) {
            rows = rows.where((f) => !f.hasSource).toList();
          }
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Filters(
                  sessions: sessions,
                  sessionId: sessionId,
                  unsourcedOnly: unsourcedOnly,
                  unsourcedCount: unsourced,
                  onSession: (v) =>
                      ref.read(_sessionFilterProvider.notifier).state = v,
                  onUnsourced: (v) =>
                      ref.read(_unsourcedOnlyProvider.notifier).state = v,
                ),
                const SizedBox(height: 14),
                if (all.isEmpty)
                  const AdminEmptyState(
                    icon: Icons.fact_check_outlined,
                    title: 'Aucun chiffre officiel relevé',
                    message: 'Déposez une publication de la DEC en relevant '
                        'ses chiffres, ou enregistrez ici un taux annoncé '
                        'dont le document n\'est pas encore parvenu.',
                  )
                else if (rows.isEmpty)
                  _Empty(
                    unsourcedOnly: unsourcedOnly,
                  )
                else
                  _FiguresTable(
                    rows: rows,
                    onTap: (f) => showExamFigurePanel(context, figure: f),
                  ),
              ]);
        }),
      ]),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.sessions,
    required this.sessionId,
    required this.unsourcedOnly,
    required this.unsourcedCount,
    required this.onSession,
    required this.onUnsourced,
  });

  final List<ArchiveSession> sessions;
  final String? sessionId;
  final bool unsourcedOnly;
  final int unsourcedCount;
  final ValueChanged<String?> onSession;
  final ValueChanged<bool> onUnsourced;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
            height: 40,
            child: ListFilterDropdown(
              icon: Icons.workspace_premium_rounded,
              label: 'Session',
              value: sessionId ?? '',
              items: {
                '': 'Toutes les sessions',
                for (final s in sessions) s.id: s.label,
              },
              onChanged: (v) => onSession(v.isEmpty ? null : v),
            ),
          ),
          // Le filtre qui rend l'indicateur actionnable : d'un clic, la liste
          // des lignes à sourcer.
          FilterChip(
            selected: unsourcedOnly,
            onSelected: onUnsourced,
            avatar: Icon(Icons.link_off_rounded,
                size: 15, color: unsourcedOnly ? kRed : kTextMuted),
            label: Text('Sans source ($unsourcedCount)',
                style: const TextStyle(fontSize: 12.5)),
            selectedColor: kRed.withValues(alpha: 0.12),
            checkmarkColor: kRed,
          ),
        ],
      );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.unsourcedOnly});
  final bool unsourcedOnly;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorder),
        ),
        child: Row(children: [
          Icon(unsourcedOnly ? Icons.verified_rounded : Icons.filter_alt_off_rounded,
              size: 19, color: unsourcedOnly ? kGreen : kTextMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              unsourcedOnly
                  ? 'Chaque chiffre de ce périmètre est adossé à une pièce.'
                  : 'Aucun relevé sur ce périmètre.',
              style: TextStyle(fontSize: 12.5, color: kTextMuted),
            ),
          ),
        ]),
      );
}

// ─── Tableau des relevés ────────────────────────────────────────────────────
class _FiguresTable extends StatelessWidget {
  const _FiguresTable({required this.rows, required this.onTap});
  final List<OfficialFigure> rows;
  final ValueChanged<OfficialFigure> onTap;

  /// Plafond d'affichage : au-delà, la page devient une liste sans fin. Le
  /// filtre de session est là pour ça, et la troncature est DITE.
  static const _max = 60;

  @override
  Widget build(BuildContext context) {
    final shown = rows.take(_max).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        decoration: BoxDecoration(
          border: Border.all(color: kBorder),
          borderRadius: BorderRadius.circular(11),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: kNavy.withValues(alpha: 0.05),
            child: Row(children: [
              _h('EXAMEN · SESSION', 24),
              _h('PÉRIMÈTRE', 24),
              _h('INSCRITS / PRÉSENTS / ADMIS', 24, end: true),
              _h('TAUX', 12, end: true),
              _h('SOURCE', 16, end: true),
              const SizedBox(width: 22),
            ]),
          ),
          for (var i = 0; i < shown.length; i++)
            _FigureRow(
              figure: shown[i],
              striped: i.isOdd,
              onTap: () => onTap(shown[i]),
            ),
        ]),
      ),
      if (rows.length > _max) ...[
        const SizedBox(height: 10),
        Text(
          '${rows.length} relevés — les $_max premiers sont affichés. '
          'Choisissez une session pour voir les autres.',
          style: TextStyle(fontSize: 11.5, color: kTextMuted),
        ),
      ],
    ]);
  }

  static Widget _h(String t, int flex, {bool end = false}) => Expanded(
        flex: flex,
        child: Text(t,
            textAlign: end ? TextAlign.end : TextAlign.start,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
                color: kTextMuted)),
      );
}

class _FigureRow extends StatelessWidget {
  const _FigureRow({
    required this.figure,
    required this.striped,
    required this.onTap,
  });
  final OfficialFigure figure;
  final bool striped;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final f = figure;
    final rate = f.passRate;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: striped ? kNavy.withValues(alpha: 0.02) : null,
          border: Border(top: BorderSide(color: kBorder)),
        ),
        child: Row(children: [
          _c('${f.examShortName ?? '—'} · ${f.yearLabel ?? '—'}', 24,
              bold: true),
          Expanded(
            flex: 24,
            child: Row(children: [
              Flexible(
                child: Text(_scopeLabel(f),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: kTextPrimary)),
              ),
              if (f.filiereLabel != null) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text('· ${f.filiereLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: kTextMuted)),
                ),
              ],
            ]),
          ),
          _c(
              f.hasCounts
                  ? '${f.registered ?? '—'} / ${f.present} / ${f.admitted}'
                  : 'taux publié seul',
              24,
              end: true,
              muted: true),
          _c(rate == null ? '—' : '${rate.toStringAsFixed(2)} %', 12,
              end: true, bold: true, color: kNavy),
          Expanded(
            flex: 16,
            child: Align(
              alignment: Alignment.centerRight,
              child: f.hasSource
                  ? _Pill('pièce jointe', kGreen, Icons.attachment_rounded)
                  // `kListOrange` est une constante, `kGreen` un jeton de thème
                  // : d'où le `const` d'un seul côté.
                  : const _Pill(
                      'sans source', kListOrange, Icons.link_off_rounded),
            ),
          ),
          SizedBox(
            width: 22,
            child: Icon(Icons.chevron_right_rounded, size: 16, color: kTextMuted),
          ),
        ]),
      ),
    );
  }

  static String _scopeLabel(OfficialFigure f) => switch (f.scope) {
        PubScope.national => 'National',
        PubScope.departement => f.department ?? 'Département',
        PubScope.etablissement => f.schoolName ?? 'Établissement',
      };

  static Widget _c(String t, int flex,
          {bool end = false,
          bool bold = false,
          bool muted = false,
          Color? color}) =>
      Expanded(
        flex: flex,
        child: Text(t,
            textAlign: end ? TextAlign.end : TextAlign.start,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                color: color ?? (muted ? kTextMuted : kTextPrimary))),
      );
}

class _Pill extends StatelessWidget {
  const _Pill(this.label, this.color, this.icon);
  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ]),
      );
}
