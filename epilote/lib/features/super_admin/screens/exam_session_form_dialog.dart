import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/exam_sessions_admin_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  SAISIR UNE SESSION depuis l'arrêté ministériel.
//
//  ── Ce que le formulaire N'EXIGE PAS, et pourquoi ──────────────────────────
//  Seuls l'examen, l'année et le statut sont requis. Les dates d'épreuves sont
//  facultatives : l'arrêté ouvre souvent les inscriptions AVANT de publier le
//  calendrier des épreuves (c'est le cas réel de CAP et CQP en 2025-2026).
//  Exiger une date qui n'existe pas encore forcerait à en inventer une.
//
//  ── L'âge maximum ──────────────────────────────────────────────────────────
//  Réglementaire (24 bacs / 20 BET-CAP / 21 BEP) mais des dérogations existent.
//  Il n'a jamais bloqué une inscription et ne le fera pas : côté école, le
//  contrôle est CONSULTATIF. Un refus serveur sur l'âge provoquerait la perte
//  silencieuse à la synchro PowerSync.
// ════════════════════════════════════════════════════════════════════════════

Future<void> showExamSessionForm(
  BuildContext context, {
  ExamSessionAdminRow? existing,
}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _ExamSessionForm(existing: existing),
    );

const _kStatuses = <(String, String)>[
  ('draft', 'Brouillon'),
  ('open', 'Inscriptions ouvertes'),
  ('closed', 'Inscriptions clôturées'),
  ('running', 'Épreuves en cours'),
  ('published', 'Résultats publiés'),
  ('cancelled', 'Annulée'),
];

class _ExamSessionForm extends ConsumerStatefulWidget {
  const _ExamSessionForm({this.existing});
  final ExamSessionAdminRow? existing;

  @override
  ConsumerState<_ExamSessionForm> createState() => _State();
}

class _State extends ConsumerState<_ExamSessionForm> {
  late String? _examId = widget.existing?.examId;
  late String _status = widget.existing?.status ?? 'draft';
  late final _year =
      TextEditingController(text: widget.existing?.yearLabel ?? _guessYear());
  late final _maxAge =
      TextEditingController(text: widget.existing?.maxAge?.toString() ?? '');
  late final _notes = TextEditingController(text: widget.existing?.notes ?? '');
  late DateTime? _regOpen = widget.existing?.registrationOpensAt;
  late DateTime? _regClose = widget.existing?.registrationClosesAt;
  late DateTime? _writtenFrom = widget.existing?.writtenFrom;
  late DateTime? _writtenTo = widget.existing?.writtenTo;
  late DateTime? _practicalFrom = widget.existing?.practicalFrom;
  late DateTime? _practicalTo = widget.existing?.practicalTo;
  bool _saving = false;
  String? _error;

  /// L'année scolaire congolaise court de septembre à juin.
  static String _guessYear() {
    final n = DateTime.now();
    final start = n.month >= 9 ? n.year : n.year - 1;
    return '$start-${start + 1}';
  }

  @override
  void dispose() {
    for (final c in [_year, _maxAge, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _valid => _examId != null && _year.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final exams = ref.watch(examRefsProvider);
    final isEdit = widget.existing != null;

    return AlertDialog(
      backgroundColor: kCardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(isEdit ? 'Modifier la session' : 'Nouvelle session',
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800, color: kTextPrimary)),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              exams.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('$e', style: TextStyle(color: kRed)),
                data: (list) => DropdownButtonFormField<String>(
                  initialValue: _examId,
                  isExpanded: true,
                  decoration: _dec('Examen *'),
                  style: TextStyle(fontSize: 13, color: kTextPrimary),
                  items: [
                    for (final e in list)
                      DropdownMenuItem(
                        value: e.id,
                        child: Text(
                          '${e.shortName}'
                          '${e.tutelle != null ? ' · ${e.tutelle!.toUpperCase()}' : ''}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _examId = v),
                ),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _year,
                    style: TextStyle(fontSize: 13, color: kTextPrimary),
                    decoration: _dec('Année scolaire *', hint: '2026-2027'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    initialValue: _status,
                    isExpanded: true,
                    decoration: _dec('Statut *'),
                    style: TextStyle(fontSize: 13, color: kTextPrimary),
                    items: [
                      for (final (code, label) in _kStatuses)
                        DropdownMenuItem(value: code, child: Text(label)),
                    ],
                    onChanged: (v) => setState(() => _status = v ?? 'draft'),
                  ),
                ),
              ]),
              const SizedBox(height: 18),
              const _Section('Inscriptions'),
              _DateRow(
                fromLabel: 'Ouverture',
                toLabel: 'Clôture',
                from: _regOpen,
                to: _regClose,
                onFrom: (d) => setState(() => _regOpen = d),
                onTo: (d) => setState(() => _regClose = d),
              ),
              const SizedBox(height: 18),
              const _Section('Épreuves écrites'),
              _DateRow(
                fromLabel: 'Début',
                toLabel: 'Fin',
                from: _writtenFrom,
                to: _writtenTo,
                onFrom: (d) => setState(() => _writtenFrom = d),
                onTo: (d) => setState(() => _writtenTo = d),
              ),
              const SizedBox(height: 18),
              const _Section('Épreuves pratiques',
                  hint: 'Le cas échéant (BET, BEP, BTF…)'),
              _DateRow(
                fromLabel: 'Début',
                toLabel: 'Fin',
                from: _practicalFrom,
                to: _practicalTo,
                onFrom: (d) => setState(() => _practicalFrom = d),
                onTo: (d) => setState(() => _practicalTo = d),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _maxAge,
                keyboardType: TextInputType.number,
                style: TextStyle(fontSize: 13, color: kTextPrimary),
                decoration: _dec('Âge maximum',
                    hint: '24 · 20 · 21',
                    helper: 'Consultatif : signalé à l\'école, jamais bloquant '
                        '(des dérogations existent).'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _notes,
                maxLines: 2,
                style: TextStyle(fontSize: 13, color: kTextPrimary),
                decoration: _dec('Référence de l\'arrêté / notes',
                    hint: 'ex. note N°157/MEPPSA-CAB-DEC'),
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
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text('Annuler', style: TextStyle(color: kTextMuted)),
        ),
        FilledButton(
          onPressed: _saving || !_valid ? null : _save,
          style: FilledButton.styleFrom(backgroundColor: kNavy),
          child: Text(_saving
              ? 'Enregistrement…'
              : (isEdit ? 'Enregistrer' : 'Créer')),
        ),
      ],
    );
  }

  InputDecoration _dec(String label, {String? hint, String? helper}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 2,
        helperStyle: TextStyle(fontSize: 11, color: kTextMuted),
        labelStyle: TextStyle(color: kTextMuted),
        border: const OutlineInputBorder(),
        isDense: true,
      );

  String? _checkOrder() {
    final pairs = <(DateTime?, DateTime?, String)>[
      (_regOpen, _regClose, 'La clôture des inscriptions précède l\'ouverture.'),
      (_writtenFrom, _writtenTo, 'La fin des écrits précède leur début.'),
      (_practicalFrom, _practicalTo, 'La fin des pratiques précède leur début.'),
    ];
    for (final (a, b, msg) in pairs) {
      if (a != null && b != null && b.isBefore(a)) return msg;
    }
    return null;
  }

  Future<void> _save() async {
    final orderError = _checkOrder();
    if (orderError != null) {
      setState(() => _error = orderError);
      return;
    }
    final age = _maxAge.text.trim();
    final parsedAge = age.isEmpty ? null : int.tryParse(age);
    if (age.isNotEmpty && parsedAge == null) {
      setState(() => _error = 'Âge maximum illisible.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await upsertExamSession(
        ref.read(supabaseClientProvider),
        id: widget.existing?.id,
        examId: _examId!,
        yearLabel: _year.text,
        status: _status,
        registrationOpensAt: _regOpen,
        registrationClosesAt: _regClose,
        writtenFrom: _writtenFrom,
        writtenTo: _writtenTo,
        practicalFrom: _practicalFrom,
        practicalTo: _practicalTo,
        maxAge: parsedAge,
        notes: _notes.text,
      );
      ref.invalidate(examSessionsAdminProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      // UNIQUE(exam_id, year_label) côté serveur : le dire en clair plutôt que
      // d'afficher une erreur Postgres brute.
      setState(() => _error = '$e'.contains('duplicate') ||
              '$e'.contains('unique')
          ? 'Une session existe déjà pour cet examen et cette année.'
          : '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, {this.hint});
  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Text(title.toUpperCase(),
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: kTextMuted)),
          if (hint != null) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(hint!,
                  style: TextStyle(fontSize: 10.5, color: kTextMuted),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ]),
      );
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.fromLabel,
    required this.toLabel,
    required this.from,
    required this.to,
    required this.onFrom,
    required this.onTo,
  });

  final String fromLabel;
  final String toLabel;
  final DateTime? from;
  final DateTime? to;
  final ValueChanged<DateTime?> onFrom;
  final ValueChanged<DateTime?> onTo;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: _DateBtn(label: fromLabel, value: from, onPick: onFrom)),
        const SizedBox(width: 10),
        Expanded(child: _DateBtn(label: toLabel, value: to, onPick: onTo)),
      ]);
}

class _DateBtn extends StatelessWidget {
  const _DateBtn({
    required this.label,
    required this.value,
    required this.onPick,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onPick;

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? label
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
              firstDate: DateTime(now.year - 2),
              lastDate: DateTime(now.year + 3),
              helpText: label,
            );
            if (d != null) onPick(d);
          },
          icon: Icon(Icons.event_rounded, size: 15, color: kTextMuted),
          label: Align(
            alignment: Alignment.centerLeft,
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12,
                    color: value == null ? kTextMuted : kTextPrimary)),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: kBorder),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
          ),
        ),
      ),
      if (value != null)
        IconButton(
          onPressed: () => onPick(null),
          icon: const Icon(Icons.close_rounded, size: 14),
          color: kTextMuted,
          visualDensity: VisualDensity.compact,
          tooltip: 'Effacer',
        ),
    ]);
  }
}
