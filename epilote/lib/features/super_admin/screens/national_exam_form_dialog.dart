import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/exam_sessions_admin_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  AJOUTER UN EXAMEN NATIONAL — la « saisie à la main » demandée.
//
//  ── LE TROU QUE ÇA COMBLE ──────────────────────────────────────────────────
//  Les 12 examens (CEPE → Bac) ont été semés par une migration. Aucun écran ne
//  permettait d'en ajouter : une réforme (le METP en publie régulièrement)
//  aurait exigé du SQL. C'est la même bombe que les sessions, un cran plus haut.
//
//  ── CE QUE ÇA N'EST PAS ────────────────────────────────────────────────────
//  On ne saisit PAS ici une session ni un candidat : on déclare un DIPLÔME ou un
//  CONCOURS de portée nationale. Le geste est rare et réservé au super_admin
//  (RLS `is_super_admin()`). La DEC reste la source ; ceci est une copie de
//  référence tant que l'API n'existe pas.
// ════════════════════════════════════════════════════════════════════════════

/// Renvoie l'`id` de l'examen créé (pour présélection dans le formulaire de
/// session), ou `null` si annulé.
Future<String?> showNationalExamForm(BuildContext context) => showDialog<String>(
      context: context,
      builder: (_) => const _NationalExamForm(),
    );

const _kTutelles = <(String, String)>[
  ('metp', 'METP — technique & professionnel'),
  ('mepsa', 'MEPSA — enseignement général'),
];

const _kKinds = <(String, String)>[
  ('diplome', 'Diplôme'),
  ('concours', 'Concours'),
];

// Alignés sur les cycles réels du référentiel (national_exams.cycle_code).
const _kCycles = <(String?, String)>[
  (null, 'Non précisé'),
  ('primaire', 'Primaire'),
  ('college', 'Collège'),
  ('formation_pro', 'Formation professionnelle'),
  ('lycee', 'Lycée'),
];

class _NationalExamForm extends ConsumerStatefulWidget {
  const _NationalExamForm();

  @override
  ConsumerState<_NationalExamForm> createState() => _State();
}

class _State extends ConsumerState<_NationalExamForm> {
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _shortName = TextEditingController();
  final _minAvg = TextEditingController();
  String _tutelle = 'metp';
  String _kind = 'diplome';
  String? _cycle;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_code, _name, _shortName, _minAvg]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _valid =>
      _code.text.trim().isNotEmpty && _name.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: kCardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(children: [
        Icon(Icons.workspace_premium_rounded, size: 20, color: kNavy),
        const SizedBox(width: 10),
        Expanded(
          child: Text('Nouvel examen national',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary)),
        ),
      ]),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: kNavy.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kNavy.withValues(alpha: 0.15)),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: kNavy),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Un diplôme ou concours de portée nationale (issu d\'un '
                      'arrêté). Vous ouvrirez ensuite une session pour l\'année.',
                      style: TextStyle(fontSize: 11.5, color: kTextMuted),
                    ),
                  ),
                ]),
              ),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'\s')),
                    ],
                    style: TextStyle(fontSize: 13, color: kTextPrimary),
                    decoration: _dec('Code *', hint: 'ex. BAC_A4'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _shortName,
                    style: TextStyle(fontSize: 13, color: kTextPrimary),
                    decoration: _dec('Sigle', hint: 'ex. Bac A4'),
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              TextField(
                controller: _name,
                style: TextStyle(fontSize: 13, color: kTextPrimary),
                decoration:
                    _dec('Intitulé complet *', hint: 'ex. Baccalauréat série A4'),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: _Dropdown(
                    label: 'Tutelle *',
                    value: _tutelle,
                    items: _kTutelles,
                    onChanged: (v) => setState(() => _tutelle = v),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Dropdown(
                    label: 'Nature *',
                    value: _kind,
                    items: _kKinds,
                    onChanged: (v) => setState(() => _kind = v),
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _cycle,
                    isExpanded: true,
                    decoration: _dec('Cycle'),
                    style: TextStyle(fontSize: 13, color: kTextPrimary),
                    items: [
                      for (final (code, label) in _kCycles)
                        DropdownMenuItem(value: code, child: Text(label)),
                    ],
                    onChanged: (v) => setState(() => _cycle = v),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _minAvg,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    style: TextStyle(fontSize: 13, color: kTextPrimary),
                    decoration: _dec('Moy. admission', hint: '10'),
                  ),
                ),
              ]),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: TextStyle(
                        fontSize: 12,
                        color: kRed,
                        fontWeight: FontWeight.w600)),
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
          child: Text(_saving ? 'Création…' : 'Créer l\'examen'),
        ),
      ],
    );
  }

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: kTextMuted),
        border: const OutlineInputBorder(),
        isDense: true,
      );

  Future<void> _save() async {
    final avg = _minAvg.text.trim();
    final parsedAvg = avg.isEmpty ? null : num.tryParse(avg.replaceAll(',', '.'));
    if (avg.isNotEmpty && parsedAvg == null) {
      setState(() => _error = 'Moyenne d\'admission illisible.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await createNationalExam(
        ref.read(supabaseClientProvider),
        code: _code.text,
        name: _name.text,
        shortName: _shortName.text,
        tutelle: _tutelle,
        kind: _kind,
        cycleCode: _cycle,
        minAverage: parsedAvg,
      );
      ref.invalidate(examRefsProvider);
      // On récupère l'id pour le présélectionner dans le formulaire de session.
      final created = await ref
          .read(supabaseClientProvider)
          .from('national_exams')
          .select('id')
          .eq('code', _code.text.trim().toUpperCase())
          .limit(1)
          .maybeSingle();
      if (mounted) {
        Navigator.of(context).pop(created?['id'] as String?);
      }
    } catch (e) {
      setState(() => _error =
          '$e'.contains('duplicate') || '$e'.contains('unique')
              ? 'Un examen porte déjà ce code.'
              : '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<(String, String)> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: kTextMuted),
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        style: TextStyle(fontSize: 12.5, color: kTextPrimary),
        items: [
          for (final (code, lbl) in items)
            DropdownMenuItem(
                value: code,
                child: Text(lbl, overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      );
}
