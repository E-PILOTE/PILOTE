import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/exam_referential_provider.dart';
import '../providers/exam_sessions_admin_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  DÉCLARER OU CORRIGER UN EXAMEN NATIONAL.
//
//  ── LE TROU QUE ÇA COMBLE ──────────────────────────────────────────────────
//  Les 12 examens (CEPE → Bac) ont été semés par une migration. Aucun écran ne
//  permettait d'en ajouter : une réforme (le METP en publie régulièrement)
//  aurait exigé du SQL. C'est la même bombe que les sessions, un cran plus haut.
//  Et aucun ne permettait d'en CORRIGER un : une faute dans l'intitulé du BET
//  vivait en base pour toujours.
//
//  ── CE QUE ÇA N'EST PAS ────────────────────────────────────────────────────
//  On ne saisit PAS ici une session ni un candidat : on déclare un DIPLÔME ou un
//  CONCOURS de portée nationale. Le geste est rare et réservé au super_admin
//  (RLS `is_super_admin()`). La DEC reste la source ; ceci est une copie de
//  référence tant que l'API n'existe pas.
//
//  ── ET ÇA NE SUFFIT PAS ────────────────────────────────────────────────────
//  Un examen créé ici n'est relié à AUCUNE classe. C'est la règle d'éligibilité
//  qui fait ce travail (feuille « Règles » du référentiel). Le formulaire le
//  dit, parce que l'oublier est le piège n°1 du module.
// ════════════════════════════════════════════════════════════════════════════

/// Renvoie l'`id` de l'examen créé ou modifié (pour présélection dans le
/// formulaire de session), ou `null` si annulé.
Future<String?> showNationalExamForm(
  BuildContext context, {
  NationalExamRow? existing,
}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _NationalExamForm(existing: existing),
    );

const _kTutelles = <(String, String)>[
  ('metp', 'METP — technique & professionnel'),
  ('mepsa', 'MEPSA — enseignement général'),
];

const _kKinds = <(String, String)>[
  ('diplome', 'Diplôme'),
  ('concours', 'Concours'),
];

// Les 5 codes de cycle du référentiel national (migration 0010). `prescolaire`
// y figure : aucun examen d'État ne s'y rattache aujourd'hui, mais amputer la
// liste rendrait le champ menteur.
const _kCycles = <(String?, String)>[
  (null, 'Non précisé'),
  ('prescolaire', 'Préscolaire'),
  ('primaire', 'Primaire'),
  ('college', 'Collège'),
  ('formation_pro', 'Formation professionnelle'),
  ('lycee', 'Lycée'),
];

class _NationalExamForm extends ConsumerStatefulWidget {
  const _NationalExamForm({this.existing});
  final NationalExamRow? existing;

  @override
  ConsumerState<_NationalExamForm> createState() => _State();
}

class _State extends ConsumerState<_NationalExamForm> {
  late final _code = TextEditingController(text: widget.existing?.code ?? '');
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _shortName =
      TextEditingController(text: widget.existing?.shortName ?? '');
  late final _minAvg = TextEditingController(
      text: widget.existing?.minAverage == null
          ? ''
          : _trimZero(widget.existing!.minAverage!));
  late String _tutelle = widget.existing?.tutelle ?? 'metp';
  late String _kind = widget.existing?.kind ?? 'diplome';
  late String? _cycle = widget.existing?.cycleCode;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  /// « 10.00 » n'est pas une note, c'est un format de colonne numérique.
  static String _trimZero(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

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
          child: Text(_isEdit ? 'Modifier l\'examen' : 'Nouvel examen national',
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
                      _isEdit
                          // Le code porte les rattachements : archives de la
                          // DEC, alerte « stage obligatoire », règles. Le
                          // changer est licite (BAC_TP → BAC_T par la 0079,
                          // puis BAC_T → BAC par la 0105), mais ce n'est pas
                          // une correction de forme.
                          ? 'Le CODE identifie l\'examen dans les archives et '
                              'les alertes. Le modifier est possible, mais il '
                              'ne s\'agit pas d\'une simple correction de '
                              'libellé.'
                          : 'Un diplôme ou concours de portée nationale (issu '
                              'd\'un arrêté). Il faudra ensuite une RÈGLE '
                              'D\'ÉLIGIBILITÉ pour que des classes s\'y '
                              'rattachent, puis une session pour l\'année.',
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
          child: Text(_saving
              ? 'Enregistrement…'
              : (_isEdit ? 'Enregistrer' : 'Créer l\'examen')),
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
      final client = ref.read(supabaseClientProvider);
      final existing = widget.existing;
      if (existing != null) {
        await updateNationalExam(
          client,
          id: existing.id,
          code: _code.text,
          name: _name.text,
          shortName: _shortName.text,
          tutelle: _tutelle,
          kind: _kind,
          cycleCode: _cycle,
          minAverage: parsedAvg,
        );
      } else {
        await createNationalExam(
          client,
          code: _code.text,
          name: _name.text,
          shortName: _shortName.text,
          tutelle: _tutelle,
          kind: _kind,
          cycleCode: _cycle,
          minAverage: parsedAvg,
        );
      }
      ref
        ..invalidate(examRefsProvider)
        ..invalidate(examReferentialProvider);
      if (existing != null) {
        if (mounted) Navigator.of(context).pop(existing.id);
        return;
      }
      // On récupère l'id pour le présélectionner dans le formulaire de session.
      final created = await client
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
