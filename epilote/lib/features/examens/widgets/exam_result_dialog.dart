import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/mention.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/active_agent_provider.dart';
import '../providers/exam_candidates_provider.dart';
import '../providers/exam_registration_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  RÉSULTAT D'EXAMEN — une donnée REÇUE, jamais produite.
//
//  E-PILOTE n'est pas le système d'inscription : la DEC proclame. Cet écran ne
//  « décide » donc rien — il ENREGISTRE ce que l'école a lu sur la publication
//  officielle. D'où deux exigences que l'interface rend visibles :
//
//   • la SOURCE (ici : saisie manuelle) est affichée, pas cachée. Le jour où
//     l'import CSV ou l'API existeront, on saura lequel prime.
//   • la date de PROCLAMATION (celle de la DEC) est distincte de la date de
//     RÉCEPTION (la nôtre, posée automatiquement). Confondre les deux, c'est
//     dater la proclamation du jour de la frappe — une date fausse, opposable.
//
//  Une moyenne n'est PAS exigée : un « absent » ou une « fraude » n'en a pas.
// ════════════════════════════════════════════════════════════════════════════

Future<void> showExamResultDialog(
  BuildContext context, {
  required ExamCandidateRow row,
  required String sessionId,
}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _ExamResultDialog(row: row, sessionId: sessionId),
    );

// Pas de `const` : les couleurs sont des JETONS RUNTIME depuis la refonte des
// thèmes (Clair · Sombre · Melack) — elles changent avec le thème de l'agent.
List<(String, String, Color)> _results() => [
      ('admis', 'Admis', kGreen),
      ('ajourne', 'Ajourné', kRed),
      ('absent', 'Absent', kTextMuted),
      ('fraude', 'Fraude', kRed),
    ];

class _ExamResultDialog extends ConsumerStatefulWidget {
  const _ExamResultDialog({required this.row, required this.sessionId});
  final ExamCandidateRow row;
  final String sessionId;

  @override
  ConsumerState<_ExamResultDialog> createState() => _State();
}

class _State extends ConsumerState<_ExamResultDialog> {
  late String? _result = widget.row.hasResult ? widget.row.result : null;
  late final _avg = TextEditingController(
      text: widget.row.average?.toStringAsFixed(2).replaceAll('.', ',') ?? '');
  DateTime? _decidedAt;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _avg.dispose();
    super.dispose();
  }

  /// Une moyenne n'a de sens que si le candidat a composé.
  bool get _acceptsAverage => _result == 'admis' || _result == 'ajourne';

  @override
  Widget build(BuildContext context) {
    final c = widget.row;

    return AlertDialog(
      backgroundColor: kCardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(c.fullName,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary)),
          const SizedBox(height: 2),
          Text('Résultat officiel',
              style: TextStyle(fontSize: 12, color: kTextMuted)),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SourceBanner(),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (code, label, tone) in _results())
                    ChoiceChip(
                      selected: _result == code,
                      onSelected: (_) => setState(() {
                        _result = code;
                        if (!_acceptsAverage) _avg.clear();
                      }),
                      label: Text(label),
                      labelStyle: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _result == code ? tone : kTextMuted,
                      ),
                      selectedColor: tone.withValues(alpha: 0.14),
                      backgroundColor: kSurface,
                      side: BorderSide(
                          color: _result == code
                              ? tone.withValues(alpha: 0.5)
                              : kBorder),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (_acceptsAverage) ...[
                TextField(
                  controller: _avg,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(fontSize: 13, color: kTextPrimary),
                  decoration: InputDecoration(
                    labelText: 'Moyenne (facultatif)',
                    hintText: 'ex. 12,45',
                    // ⚠️ Ce texte annonçait « calculée par la base
                    // (get_mention) ». C'était faux à deux titres : rien en
                    // base ne l'appelait — ni trigger, ni colonne générée — et
                    // `setResult` était appelé SANS `mention`, donc la colonne
                    // recevait NULL. Un agent saisissait 15,20 en croyant la
                    // mention acquise, et la répartition des mentions du
                    // cockpit METP restait vide. Elle se calcule ici, par le
                    // barème officiel, comme partout ailleurs.
                    helperText: 'La mention se déduit de la moyenne '
                        '(barème officiel).',
                    helperStyle: TextStyle(fontSize: 11, color: kTextMuted),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _DecidedAtField(
                value: _decidedAt,
                onPick: (d) => setState(() => _decidedAt = d),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: TextStyle(
                        fontSize: 12, color: kRed, fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (widget.row.hasResult)
          TextButton(
            onPressed: _saving ? null : _clear,
            child: Text('Effacer', style: TextStyle(color: kRed)),
          ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text('Annuler', style: TextStyle(color: kTextMuted)),
        ),
        FilledButton(
          onPressed: _saving || _result == null ? null : _save,
          style: FilledButton.styleFrom(backgroundColor: kNavy),
          child: Text(_saving ? 'Enregistrement…' : 'Enregistrer'),
        ),
      ],
    );
  }

  /// Accepte « 12,45 » comme « 12.45 » : le clavier congolais met une virgule.
  double? _parseAverage() {
    final raw = _avg.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  Future<void> _save() async {
    final avg = _acceptsAverage ? _parseAverage() : null;
    if (_acceptsAverage && _avg.text.trim().isNotEmpty && avg == null) {
      setState(() => _error = 'Moyenne illisible. Exemple : 12,45');
      return;
    }
    if (avg != null && (avg < 0 || avg > 20)) {
      setState(() => _error = 'Une moyenne va de 0 à 20.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await setResult(
        widget.row.id,
        result: _result!,
        average: avg,
        // Sans moyenne, pas de mention : `mentionFor` rendrait « — », qui
        // s'inscrirait en base comme s'il s'agissait d'une mention.
        mention: avg == null ? null : mentionFor(avg),
        decidedAt: _decidedAt,
        // Poste partagé : c'est l'AGENT ACTIF qui saisit, pas l'appareil.
        recordedBy: ref.read(activeAgentIdProvider),
      );
      ref.invalidate(sessionCandidatesProvider(widget.sessionId));
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clear() async {
    setState(() => _saving = true);
    try {
      await clearResult(widget.row.id);
      ref.invalidate(sessionCandidatesProvider(widget.sessionId));
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

/// Dire d'où vient l'information, plutôt que de la présenter comme la nôtre.
class _SourceBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: kNavy.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kNavy.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          Icon(Icons.south_west_rounded, size: 16, color: kNavy),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Résultat proclamé par la DEC, saisi ici à la main. '
              'En cas de divergence, la publication officielle fait foi.',
              style: TextStyle(fontSize: 11.5, color: kTextPrimary, height: 1.35),
            ),
          ),
        ]),
      );
}

class _DecidedAtField extends StatelessWidget {
  const _DecidedAtField({required this.value, required this.onPick});
  final DateTime? value;
  final ValueChanged<DateTime?> onPick;

  @override
  Widget build(BuildContext context) {
    final label = value == null
        ? 'Date de proclamation (facultative)'
        : '${value!.day.toString().padLeft(2, '0')}/'
            '${value!.month.toString().padLeft(2, '0')}/${value!.year}';

    return Row(children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: () async {
            final now = DateTime.now();
            final d = await showDatePicker(
              context: context,
              initialDate: value ?? now,
              firstDate: DateTime(now.year - 5),
              lastDate: now,
              helpText: 'Date de proclamation par la DEC',
            );
            if (d != null) onPick(d);
          },
          icon: Icon(Icons.event_rounded, size: 16, color: kTextMuted),
          label: Align(
            alignment: Alignment.centerLeft,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    color: value == null ? kTextMuted : kTextPrimary)),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: kBorder),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
        ),
      ),
      if (value != null)
        IconButton(
          onPressed: () => onPick(null),
          icon: const Icon(Icons.close_rounded, size: 16),
          color: kTextMuted,
          tooltip: 'Effacer la date',
        ),
    ]);
  }
}
