import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/exam_sessions_admin_provider.dart';
import 'list_chrome.dart' show kListPurple;

final _fmt = DateFormat('dd/MM', 'fr_FR');
final _fmtFull = DateFormat('dd/MM/yyyy', 'fr_FR');

// ════════════════════════════════════════════════════════════════════════════
//  SESSIONS — vue TABLEAU et vue CARTES (bascule dans la barre de filtres).
//  Même grammaire visuelle que la page Administrateurs, qui est la référence.
// ════════════════════════════════════════════════════════════════════════════

(Color, String) sessionTone(String status) => switch (status) {
      'open' => (kGreen, 'Ouverte'),
      'closed' => (kRed, 'Clôturée'),
      'running' => (kAccent, 'Épreuves'),
      'published' => (kListPurple, 'Résultats'),
      'cancelled' => (kTextMuted, 'Annulée'),
      _ => (kTextMuted, 'Brouillon'),
    };

/// Jours restants avant la clôture des inscriptions. C'est l'information la
/// plus périssable du module : après le 14 février 14h00, un candidat oublié
/// perd une année. Négatif = déjà clos.
int? daysToClose(ExamSessionAdminRow r) {
  if (r.registrationClosesAt == null) return null;
  final now = DateTime.now();
  return r.registrationClosesAt!
      .difference(DateTime(now.year, now.month, now.day))
      .inDays;
}

class SessionsTableView extends StatelessWidget {
  const SessionsTableView({
    super.key,
    required this.rows,
    required this.onEdit,
    required this.onDelete,
  });

  final List<ExamSessionAdminRow> rows;
  final ValueChanged<ExamSessionAdminRow> onEdit;
  final ValueChanged<ExamSessionAdminRow> onDelete;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const _NoMatch();
    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Column(children: [
        _HeadRow(),
        for (final r in rows)
          _BodyRow(row: r, onEdit: onEdit, onDelete: onDelete),
      ]),
    );
  }
}

class _HeadRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          border: Border(bottom: BorderSide(color: kBorder)),
        ),
        child: Row(children: [
          _h('Examen', flex: 3),
          _h('Année', flex: 2),
          _h('Inscriptions', flex: 3),
          _h('Épreuves', flex: 3),
          _h('Candidats', flex: 2),
          _h('Statut', flex: 2),
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
              color: kTextMuted,
            )),
      );
}

class _BodyRow extends StatefulWidget {
  const _BodyRow({
    required this.row,
    required this.onEdit,
    required this.onDelete,
  });

  final ExamSessionAdminRow row;
  final ValueChanged<ExamSessionAdminRow> onEdit;
  final ValueChanged<ExamSessionAdminRow> onDelete;

  @override
  State<_BodyRow> createState() => _BodyRowState();
}

class _BodyRowState extends State<_BodyRow> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.row;
    final (tone, label) = sessionTone(r.status);
    final d = daysToClose(r);

    return MouseRegion(
      onEnter: (_) => setState(() => _hov = true),
      onExit: (_) => setState(() => _hov = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: _hov ? kSurface.withValues(alpha: 0.6) : Colors.transparent,
          border: Border(top: BorderSide(color: kBorder.withValues(alpha: 0.5))),
        ),
        child: Row(children: [
          Expanded(
            flex: 3,
            child: Row(children: [
              Container(
                width: 4,
                height: 26,
                decoration: BoxDecoration(
                  color: tone,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.examShortName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: kTextPrimary,
                        )),
                    if (r.tutelle != null)
                      Text(r.tutelle!.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: kTextMuted,
                          )),
                  ],
                ),
              ),
            ]),
          ),
          Expanded(
            flex: 2,
            child: Text(r.yearLabel ?? '—',
                style: TextStyle(fontSize: 12, color: kTextPrimary)),
          ),
          Expanded(
            flex: 3,
            child: _Registration(row: r, days: d),
          ),
          Expanded(
            flex: 3,
            child: Text(
              r.writtenFrom == null
                  ? 'à compléter'
                  : '${_fmt.format(r.writtenFrom!)}'
                      '${r.writtenTo != null ? ' → ${_fmt.format(r.writtenTo!)}' : ''}'
                      '${r.practicalFrom != null ? '  ·  prat. ${_fmt.format(r.practicalFrom!)}' : ''}',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                color: r.missingDates ? kListPurple : kTextMuted,
                fontStyle: r.missingDates ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              r.candidateCount == 0 ? '—' : '${r.candidateCount}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight:
                    r.candidateCount > 0 ? FontWeight.w700 : FontWeight.w400,
                color: r.candidateCount > 0 ? kTextPrimary : kTextMuted,
              ),
            ),
          ),
          Expanded(flex: 2, child: _Pill(label: label, tone: tone)),
          SizedBox(
            width: 76,
            child: Row(children: [
              _Act(
                icon: Icons.edit_outlined,
                tooltip: 'Modifier',
                onTap: () => widget.onEdit(r),
              ),
              _Act(
                icon: Icons.delete_outline_rounded,
                tooltip: r.isDeletable
                    ? 'Supprimer'
                    : '${r.candidateCount} candidature(s) — suppression impossible',
                onTap: r.isDeletable ? () => widget.onDelete(r) : null,
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// La fenêtre d'inscription + le compte à rebours. C'est la seule échéance
/// irrattrapable du module : on la montre partout où c'est possible.
class _Registration extends StatelessWidget {
  const _Registration({required this.row, required this.days});
  final ExamSessionAdminRow row;
  final int? days;

  @override
  Widget build(BuildContext context) {
    if (row.registrationOpensAt == null) {
      return Text('non datées',
          style: TextStyle(
              fontSize: 11.5, color: kTextMuted, fontStyle: FontStyle.italic));
    }
    final urgent = days != null && days! >= 0 && days! <= 30 && row.isOpen;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_fmt.format(row.registrationOpensAt!)}'
          '${row.registrationClosesAt != null ? ' → ${_fmt.format(row.registrationClosesAt!)}' : ''}',
          style: TextStyle(fontSize: 11.5, color: kTextPrimary),
        ),
        if (urgent)
          Text(
            days == 0 ? 'clôture aujourd\'hui' : 'clôture dans $days j',
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: kRed),
          )
        else if (days != null && days! < 0 && row.isOpen)
          // Statut « ouverte » alors que la date est passée : l'un des deux
          // ment. Le signaler plutôt que d'afficher un état faux.
          const Text('date dépassée — statut à revoir',
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700, color: kListPurple)),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.tone});
  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: tone.withValues(alpha: 0.3)),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w700, color: tone)),
        ),
      );
}

class _Act extends StatelessWidget {
  const _Act({required this.icon, required this.tooltip, this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: IconButton(
          onPressed: onTap,
          icon: Icon(icon, size: 16),
          color: onTap == null ? kTextMuted.withValues(alpha: 0.35) : kTextMuted,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      );
}

// ── Vue cartes ──────────────────────────────────────────────────────────────

class SessionsCardGrid extends StatelessWidget {
  const SessionsCardGrid({
    super.key,
    required this.rows,
    required this.onEdit,
    required this.onDelete,
  });

  final List<ExamSessionAdminRow> rows;
  final ValueChanged<ExamSessionAdminRow> onEdit;
  final ValueChanged<ExamSessionAdminRow> onDelete;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const _NoMatch();
    return LayoutBuilder(builder: (_, c) {
      final cols = c.maxWidth > 1180 ? 3 : (c.maxWidth > 720 ? 2 : 1);
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          mainAxisExtent: 186,
        ),
        itemCount: rows.length,
        itemBuilder: (_, i) =>
            _SessionCard(row: rows[i], onEdit: onEdit, onDelete: onDelete),
      );
    });
  }
}

class _SessionCard extends StatefulWidget {
  const _SessionCard({
    required this.row,
    required this.onEdit,
    required this.onDelete,
  });

  final ExamSessionAdminRow row;
  final ValueChanged<ExamSessionAdminRow> onEdit;
  final ValueChanged<ExamSessionAdminRow> onDelete;

  @override
  State<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<_SessionCard> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.row;
    final (tone, label) = sessionTone(r.status);
    final d = daysToClose(r);

    return MouseRegion(
      onEnter: (_) => setState(() => _hov = true),
      onExit: (_) => setState(() => _hov = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _hov ? tone.withValues(alpha: 0.4) : kBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _hov ? 0.08 : 0.03),
              blurRadius: _hov ? 12 : 4,
              offset: Offset(0, _hov ? 4 : 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(children: [
            Container(height: 3, color: tone),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.examShortName,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: kTextPrimary,
                                )),
                            Text(
                              '${r.yearLabel ?? '—'}'
                              '${r.tutelle != null ? ' · ${r.tutelle!.toUpperCase()}' : ''}',
                              style: TextStyle(fontSize: 11, color: kTextMuted),
                            ),
                          ],
                        ),
                      ),
                      _Pill(label: label, tone: tone),
                    ]),
                    const SizedBox(height: 10),
                    _Line(
                      icon: Icons.how_to_reg_rounded,
                      text: r.registrationOpensAt == null
                          ? 'inscriptions non datées'
                          : '${_fmtFull.format(r.registrationOpensAt!)}'
                              '${r.registrationClosesAt != null ? ' → ${_fmtFull.format(r.registrationClosesAt!)}' : ''}',
                    ),
                    _Line(
                      icon: Icons.edit_note_rounded,
                      text: r.writtenFrom == null
                          ? 'épreuves à compléter'
                          : 'écrits ${_fmtFull.format(r.writtenFrom!)}'
                              '${r.writtenTo != null ? ' → ${_fmt.format(r.writtenTo!)}' : ''}',
                      tone: r.missingDates ? kListPurple : null,
                    ),
                    _Line(
                      icon: Icons.groups_rounded,
                      text: r.candidateCount == 0
                          ? 'aucun candidat'
                          : '${r.candidateCount} candidat(s)',
                    ),
                    const Spacer(),
                    Row(children: [
                      if (d != null && d >= 0 && d <= 30 && r.isOpen)
                        Expanded(
                          child: Text(
                            d == 0 ? 'Clôture aujourd\'hui' : 'Clôture dans $d j',
                            style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: kRed),
                          ),
                        )
                      else if (r.maxAge != null)
                        Expanded(
                          child: Text('âge max ${r.maxAge} ans',
                              style:
                                  TextStyle(fontSize: 10.5, color: kTextMuted)),
                        )
                      else
                        const Spacer(),
                      _Act(
                        icon: Icons.edit_outlined,
                        tooltip: 'Modifier',
                        onTap: () => widget.onEdit(r),
                      ),
                      _Act(
                        icon: Icons.delete_outline_rounded,
                        tooltip: r.isDeletable
                            ? 'Supprimer'
                            : '${r.candidateCount} candidature(s) — impossible',
                        onTap: r.isDeletable ? () => widget.onDelete(r) : null,
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text, this.tone});
  final IconData icon;
  final String text;
  final Color? tone;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          Icon(icon, size: 13, color: tone ?? kTextMuted),
          const SizedBox(width: 7),
          Expanded(
            child: Text(text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: tone ?? kTextMuted)),
          ),
        ]),
      );
}

class _NoMatch extends StatelessWidget {
  const _NoMatch();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 48),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorder),
        ),
        child: Column(children: [
          Icon(Icons.search_off_rounded, size: 36, color: kTextMuted),
          const SizedBox(height: 10),
          Text('Aucune session ne correspond',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary)),
          const SizedBox(height: 4),
          Text('Ajustez la recherche ou réinitialisez les filtres.',
              style: TextStyle(fontSize: 11.5, color: kTextMuted)),
        ]),
      );
}
