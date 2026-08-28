import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/exam_candidates_provider.dart';
import '../providers/exam_registration_provider.dart';
import '../../../core/utils/message_erreur.dart';

// ════════════════════════════════════════════════════════════════════════════
//  ATTRIBUER LES NUMÉROS DE CANDIDAT — en masse.
//
//  La DEC renvoie les numéros sous forme de liste, dans l'ordre alphabétique.
//  Les reporter un par un sur 300 candidats prend une journée et produit des
//  fautes de frappe.
//
//  ── Pas de centre d'examen ici, et c'est délibéré ──────────────────────────
//  L'affectation des centres relève de la DEC/DSIC, qui ne la notifie pas aux
//  établissements. L'école prépare sa liste, la dépose, reçoit les numéros —
//  rien d'autre. Un champ « centre » que personne ne peut renseigner n'est pas
//  une fonctionnalité, c'est une impasse à l'écran.
//
//  ── La correspondance est POSITIONNELLE, et c'est assumé ───────────────────
//  Le n-ième numéro collé va au n-ième candidat de la liste affichée. C'est
//  exactement la forme sous laquelle la DEC transmet. L'écran montre donc
//  l'appariement AVANT d'écrire : coller une liste décalée d'une ligne
//  donnerait à chaque élève le numéro de son voisin, et la faute ne se verrait
//  qu'à l'épreuve.
// ════════════════════════════════════════════════════════════════════════════

Future<bool> showBulkAssignDialog(
  BuildContext context, {
  required List<ExamCandidateRow> candidates,
  required String sessionId,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) =>
          _BulkAssignDialog(candidates: candidates, sessionId: sessionId),
    ) ??
    false;

class _BulkAssignDialog extends ConsumerStatefulWidget {
  const _BulkAssignDialog({required this.candidates, required this.sessionId});

  final List<ExamCandidateRow> candidates;
  final String sessionId;

  @override
  ConsumerState<_BulkAssignDialog> createState() => _State();
}

class _State extends ConsumerState<_BulkAssignDialog> {
  final _numbers = TextEditingController();
  bool _saving = false;
  String? _error;
  String? _done;

  @override
  void dispose() {
    _numbers.dispose();
    super.dispose();
  }

  List<String> get _lines => _numbers.text
      .split('\n')
      .map((l) => l.trim())
      .toList();

  @override
  Widget build(BuildContext context) {
    final n = widget.candidates.length;
    final filled = _lines.where((l) => l.isNotEmpty).length;

    return AlertDialog(
      backgroundColor: kCardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Numéros de candidat',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary)),
          const SizedBox(height: 2),
          Text('$n candidat(s) sélectionné(s)',
              style: TextStyle(fontSize: 12, color: kTextMuted)),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('NUMÉROS DE CANDIDAT',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: kTextMuted)),
              const SizedBox(height: 6),
              Text(
                'Collez la colonne du tableur de la DEC — un numéro par ligne, '
                'dans l\'ordre de la liste ci-dessous. Les lignes vides sont '
                'ignorées et n\'effacent rien.',
                style: TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.4),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _numbers,
                maxLines: 6,
                onChanged: (_) => setState(() {}),
                style: TextStyle(
                    fontSize: 12.5, color: kTextPrimary, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: '2026BET00123\n2026BET00124\n…',
                  hintStyle: TextStyle(fontSize: 12, color: kTextMuted),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              if (filled > 0) ...[
                const SizedBox(height: 8),
                _pairingWarning(filled, n),
                const SizedBox(height: 10),
                _preview(),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: TextStyle(
                        fontSize: 12, color: kRed, fontWeight: FontWeight.w600)),
              ],
              if (_done != null) ...[
                const SizedBox(height: 12),
                Text(_done!,
                    style: TextStyle(
                        fontSize: 12,
                        color: kGreen,
                        fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text('Annuler', style: TextStyle(color: kTextMuted)),
        ),
        FilledButton(
          onPressed: _saving || filled == 0 ? null : _apply,
          style: FilledButton.styleFrom(backgroundColor: kNavy),
          child: Text(_saving ? 'Application…' : 'Appliquer'),
        ),
      ],
    );
  }

  /// Un collage plus long ou plus court que la sélection est presque toujours
  /// un décalage — on le dit avant d'écrire, pas après.
  Widget _pairingWarning(int filled, int n) {
    if (filled == n) {
      return Row(children: [
        Icon(Icons.check_circle_rounded, size: 14, color: kGreen),
        const SizedBox(width: 6),
        Text('$filled numéro(s) pour $n candidat(s) — appariement complet.',
            style: TextStyle(
                fontSize: 11, color: kGreen, fontWeight: FontWeight.w600)),
      ]);
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.warning_amber_rounded, size: 14, color: kAccent),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          filled > n
              ? '$filled numéros pour $n candidat(s) : les numéros en trop '
                  'seront ignorés. Vérifiez que la liste commence au bon élève.'
              : '$filled numéro(s) pour $n candidat(s) : les derniers candidats '
                  'resteront sans numéro. Vérifiez qu\'il ne manque pas une ligne.',
          style: TextStyle(fontSize: 11, color: kAccent, height: 1.35),
        ),
      ),
    ]);
  }

  /// L'appariement, montré AVANT d'écrire : c'est la seule protection contre
  /// un collage décalé d'une ligne.
  Widget _preview() {
    final lines = _lines;
    final rows = <Widget>[];
    for (var i = 0; i < widget.candidates.length && i < 6; i++) {
      final num = i < lines.length ? lines[i] : '';
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(
            child: Text(widget.candidates[i].fullName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: kTextPrimary)),
          ),
          Icon(Icons.arrow_forward_rounded, size: 13, color: kTextMuted),
          const SizedBox(width: 8),
          SizedBox(
            width: 150,
            child: Text(num.isEmpty ? '— inchangé —' : num,
                style: TextStyle(
                    fontSize: 11.5,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    color: num.isEmpty ? kTextMuted : kNavy)),
          ),
        ]),
      ));
    }
    if (widget.candidates.length > 6) {
      rows.add(Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text('… et ${widget.candidates.length - 6} autre(s)',
            style: TextStyle(fontSize: 10.5, color: kTextMuted)),
      ));
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: kNavy.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows),
    );
  }

  Future<void> _apply() async {
    setState(() {
      _saving = true;
      _error = null;
      _done = null;
    });
    try {
      final lines = _lines;
      final map = <String, String>{};
      for (var i = 0; i < widget.candidates.length && i < lines.length; i++) {
        if (lines[i].isNotEmpty) map[widget.candidates[i].id] = lines[i];
      }
      final n = await assignCandidateNumbers(map, sessionId: widget.sessionId);

      ref.invalidate(sessionCandidatesProvider(widget.sessionId));
      if (mounted) {
        setState(() => _done = '$n numéro(s) attribué(s).');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) setState(() => _error = messageErreur(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
