import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/list_chrome.dart' show kListOrange, kListPurple;
import '../providers/exam_referential_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  RÉFÉRENTIEL DES EXAMENS — vue TABLEAU et vue CARTES.
//
//  La colonne qui compte est « Règles ». Un examen sans règle est inerte : il
//  s'affiche partout et ne qualifie personne. On ne se contente donc pas d'un
//  compteur — un zéro se signale en rouge et s'énonce.
// ════════════════════════════════════════════════════════════════════════════

typedef ExamAction = void Function(NationalExamRow row);

class ExamReferentialTable extends StatelessWidget {
  const ExamReferentialTable({
    super.key,
    required this.rows,
    required this.onEdit,
    required this.onRules,
    required this.onToggle,
    required this.onDelete,
  });

  final List<NationalExamRow> rows;
  final ExamAction onEdit;
  final ExamAction onRules;
  final ExamAction onToggle;
  final ExamAction onDelete;

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
        _Head(),
        for (final r in rows)
          _BodyRow(
            row: r,
            onEdit: onEdit,
            onRules: onRules,
            onToggle: onToggle,
            onDelete: onDelete,
          ),
      ]),
    );
  }
}

class _Head extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          border: Border(bottom: BorderSide(color: kBorder)),
        ),
        child: Row(children: [
          _h('Examen', flex: 4),
          _h('Tutelle', flex: 2),
          _h('Nature', flex: 2),
          _h('Cycle', flex: 2),
          _h('Règles', flex: 3),
          _h('Sessions', flex: 2),
          const SizedBox(width: 128),
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

class _BodyRow extends StatelessWidget {
  const _BodyRow({
    required this.row,
    required this.onEdit,
    required this.onRules,
    required this.onToggle,
    required this.onDelete,
  });

  final NationalExamRow row;
  final ExamAction onEdit;
  final ExamAction onRules;
  final ExamAction onToggle;
  final ExamAction onDelete;

  @override
  Widget build(BuildContext context) {
    final off = !row.isActive;
    return InkWell(
      onTap: () => onRules(row),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: off ? kSurface.withValues(alpha: 0.45) : null,
          border: Border(bottom: BorderSide(color: kBorder)),
        ),
        child: Row(children: [
          Expanded(flex: 4, child: _Identity(row: row)),
          Expanded(
            flex: 2,
            child: AdminBadge(
              row.tutelle.toUpperCase(),
              color: row.tutelle == 'metp' ? kListPurple : kNavy,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(row.isDiplome ? 'Diplôme' : 'Concours',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: off ? kTextMuted : kTextPrimary)),
          ),
          Expanded(
            flex: 2,
            child: Text(row.cycleCode ?? '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: kTextMuted)),
          ),
          Expanded(flex: 3, child: RuleCountCell(row: row)),
          Expanded(
            flex: 2,
            child: Text(
              row.sessionCount == 0 ? 'aucune' : '${row.sessionCount}',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      row.sessionCount == 0 ? FontWeight.w400 : FontWeight.w700,
                  color: row.sessionCount == 0 ? kListOrange : kTextPrimary),
            ),
          ),
          SizedBox(
            width: 128,
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              IconButton(
                tooltip: 'Règles d\'éligibilité',
                icon: const Icon(Icons.rule_rounded, size: 17, color: kListPurple),
                onPressed: () => onRules(row),
              ),
              IconButton(
                tooltip: 'Modifier',
                icon: Icon(Icons.edit_outlined, size: 17, color: kNavy),
                onPressed: () => onEdit(row),
              ),
              IconButton(
                tooltip: off ? 'Réactiver' : 'Désactiver',
                icon: Icon(
                    off
                        ? Icons.toggle_off_outlined
                        : Icons.toggle_on_rounded,
                    size: 19,
                    color: off ? kTextMuted : kGreen),
                onPressed: () => onToggle(row),
              ),
              if (row.looksDeletable)
                IconButton(
                  tooltip: 'Supprimer',
                  icon:
                      Icon(Icons.delete_outline_rounded, size: 17, color: kRed),
                  onPressed: () => onDelete(row),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({required this.row});
  final NationalExamRow row;

  @override
  Widget build(BuildContext context) {
    final off = !row.isActive;
    return Row(children: [
      Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: (off ? kTextMuted : kNavy).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
            row.isDiplome
                ? Icons.workspace_premium_rounded
                : Icons.emoji_events_rounded,
            size: 17,
            color: off ? kTextMuted : kNavy),
      ),
      const SizedBox(width: 11),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Flexible(
                child: Text(row.shortName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: off ? kTextMuted : kTextPrimary)),
              ),
              if (off) ...[
                const SizedBox(width: 7),
                AdminBadge('Désactivé', color: kTextMuted),
              ],
            ]),
            const SizedBox(height: 1),
            Text('${row.code} · ${row.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, color: kTextMuted)),
          ],
        ),
      ),
    ]);
  }
}

/// Le compteur de règles — et son verdict. Un concours n'en a pas besoin
/// (seuls les diplômes se dérivent) : ne pas le dire ferait passer le concours
/// d'entrée en Seconde pour un examen mal câblé.
class RuleCountCell extends StatelessWidget {
  const RuleCountCell({super.key, required this.row});
  final NationalExamRow row;

  @override
  Widget build(BuildContext context) {
    if (!row.needsRules) {
      return Text('sans objet',
          style: TextStyle(
              fontSize: 11.5, fontStyle: FontStyle.italic, color: kTextMuted));
    }
    if (row.ruleCount == 0) {
      return Row(children: [
        Icon(Icons.link_off_rounded, size: 14, color: kRed),
        const SizedBox(width: 6),
        Flexible(
          child: Text(row.isActive ? 'Aucune — inerte' : 'Aucune',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: row.isActive ? kRed : kTextMuted)),
        ),
      ]);
    }
    return Row(children: [
      Icon(Icons.rule_rounded, size: 14, color: kGreen),
      const SizedBox(width: 6),
      Text('${row.ruleCount}',
          style: TextStyle(
              fontSize: 12.5, fontWeight: FontWeight.w800, color: kGreen)),
    ]);
  }
}

// ─── Vue cartes ─────────────────────────────────────────────────────────────

class ExamReferentialCards extends StatelessWidget {
  const ExamReferentialCards({
    super.key,
    required this.rows,
    required this.onEdit,
    required this.onRules,
    required this.onToggle,
    required this.onDelete,
  });

  final List<NationalExamRow> rows;
  final ExamAction onEdit;
  final ExamAction onRules;
  final ExamAction onToggle;
  final ExamAction onDelete;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const _NoMatch();
    return LayoutBuilder(builder: (ctx, c) {
      // Largeur PLANCHER de carte, pas palier d'écran : les colonnes se
      // retirent d'elles-mêmes avant que les libellés n'étouffent.
      final cross = (c.maxWidth / 320).floor().clamp(1, 4);
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cross,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 168,
        ),
        itemCount: rows.length,
        itemBuilder: (_, i) => _Card(
          row: rows[i],
          onEdit: onEdit,
          onRules: onRules,
          onToggle: onToggle,
          onDelete: onDelete,
        ),
      );
    });
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.row,
    required this.onEdit,
    required this.onRules,
    required this.onToggle,
    required this.onDelete,
  });

  final NationalExamRow row;
  final ExamAction onEdit;
  final ExamAction onRules;
  final ExamAction onToggle;
  final ExamAction onDelete;

  @override
  Widget build(BuildContext context) {
    final off = !row.isActive;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onRules(row),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: off ? kSurface.withValues(alpha: 0.5) : kCardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: row.isInert ? kRed.withValues(alpha: 0.4) : kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Identity(row: row),
            const Spacer(),
            RuleCountCell(row: row),
            const SizedBox(height: 8),
            Row(children: [
              AdminBadge(
                row.tutelle.toUpperCase(),
                color: row.tutelle == 'metp' ? kListPurple : kNavy,
              ),
              const SizedBox(width: 7),
              Text(
                row.sessionCount == 0
                    ? 'aucune session'
                    : '${row.sessionCount} session(s)',
                style: TextStyle(fontSize: 11, color: kTextMuted),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Modifier',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.edit_outlined, size: 16, color: kNavy),
                onPressed: () => onEdit(row),
              ),
              IconButton(
                tooltip: off ? 'Réactiver' : 'Désactiver',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                    off ? Icons.toggle_off_outlined : Icons.toggle_on_rounded,
                    size: 18,
                    color: off ? kTextMuted : kGreen),
                onPressed: () => onToggle(row),
              ),
              if (row.looksDeletable)
                IconButton(
                  tooltip: 'Supprimer',
                  visualDensity: VisualDensity.compact,
                  icon:
                      Icon(Icons.delete_outline_rounded, size: 16, color: kRed),
                  onPressed: () => onDelete(row),
                ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _NoMatch extends StatelessWidget {
  const _NoMatch();

  @override
  Widget build(BuildContext context) => const AdminEmptyState(
        icon: Icons.search_off_rounded,
        title: 'Aucun examen ne correspond',
        message: 'Modifiez la recherche ou réinitialisez les filtres.',
      );
}
