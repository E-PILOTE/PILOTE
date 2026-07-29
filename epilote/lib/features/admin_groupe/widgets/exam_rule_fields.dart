import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/exam_rule_vocabulary.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LES CHAMPS D'UNE RÈGLE D'ÉLIGIBILITÉ.
//
//  Trois idées les gouvernent :
//   • on propose ce que les classes portent VRAIMENT (avec leur effectif),
//     mais on n'enferme jamais : un niveau qui n'existe pas encore doit
//     pouvoir se saisir, sinon la réforme attend une migration ;
//   • un joker se nomme (« Toutes les filières »), il ne se devine pas d'un
//     champ vide ;
//   • chaque joker dit ce qu'il coûte : plus la règle est large, plus elle est
//     facile à battre par une règle fine — c'est voulu, il faut le lire.
// ════════════════════════════════════════════════════════════════════════════

const _kNone = '__none__';
const _kFree = '__free__';

/// Champ à vocabulaire : liste déroulante alimentée par la base, avec repli
/// en saisie libre. `onChanged(null)` = joker / non renseigné.
class ExamRuleVocabField extends StatefulWidget {
  const ExamRuleVocabField({
    super.key,
    required this.label,
    required this.hint,
    required this.value,
    required this.entries,
    required this.onChanged,
    this.allowNone = false,
    this.noneLabel = 'Non renseigné',
  });

  final String label;
  final String hint;

  /// Code courant. Chaîne vide = aucun.
  final String value;
  final List<VocabEntry> entries;
  final ValueChanged<String?> onChanged;

  /// Le champ accepte-t-il le joker (filière : oui ; cycle et niveau : non).
  final bool allowNone;
  final String noneLabel;

  @override
  State<ExamRuleVocabField> createState() => _ExamRuleVocabFieldState();
}

class _ExamRuleVocabFieldState extends State<ExamRuleVocabField> {
  late final TextEditingController _free =
      TextEditingController(text: widget.value);
  bool _freeMode = false;

  @override
  void initState() {
    super.initState();
    // Un code déjà saisi qui ne figure pas dans le vocabulaire observé ouvre
    // d'emblée la saisie libre : sinon la modification l'effacerait en silence.
    _freeMode = widget.entries.isEmpty ||
        (widget.value.isNotEmpty &&
            !widget.entries.any((e) => e.code == widget.value));
  }

  @override
  void didUpdateWidget(covariant ExamRuleVocabField old) {
    super.didUpdateWidget(old);
    // Le vocabulaire arrive après le premier rendu (requête réseau) : on sort
    // du repli dès qu'il est là et qu'il contient le code courant.
    if (old.entries.isEmpty && widget.entries.isNotEmpty) {
      final known = widget.value.isEmpty ||
          widget.entries.any((e) => e.code == widget.value);
      if (known) setState(() => _freeMode = false);
    }
  }

  @override
  void dispose() {
    _free.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_freeMode) {
      return TextField(
        controller: _free,
        style: TextStyle(fontSize: 13, color: kTextPrimary),
        onChanged: (v) =>
            widget.onChanged(v.trim().isEmpty ? null : v.trim()),
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          labelStyle: TextStyle(color: kTextMuted),
          border: const OutlineInputBorder(),
          isDense: true,
          helperText: widget.entries.isEmpty
              ? 'Aucun code observé sur les classes — saisie libre.'
              : 'Saisie libre',
          helperStyle: TextStyle(fontSize: 11, color: kTextMuted),
          suffixIcon: widget.entries.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Choisir dans la liste',
                  icon: const Icon(Icons.list_rounded, size: 17),
                  onPressed: () => setState(() => _freeMode = false),
                ),
        ),
      );
    }

    final current = widget.value.isEmpty ? _kNone : widget.value;
    final known = widget.entries.any((e) => e.code == current);

    return DropdownButtonFormField<String>(
      initialValue: known || current == _kNone ? current : null,
      isExpanded: true,
      menuMaxHeight: 380,
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: TextStyle(color: kTextMuted),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      style: TextStyle(fontSize: 13, color: kTextPrimary),
      items: [
        DropdownMenuItem(
          value: _kNone,
          child: Text(
            widget.allowNone ? widget.noneLabel : '—',
            style: TextStyle(color: kTextMuted),
          ),
        ),
        for (final e in widget.entries)
          DropdownMenuItem(
            value: e.code,
            child: Text(e.display, overflow: TextOverflow.ellipsis),
          ),
        DropdownMenuItem(
          value: _kFree,
          child: Row(children: [
            Icon(Icons.edit_rounded, size: 14, color: kNavy),
            const SizedBox(width: 7),
            Text('Autre — saisir un code',
                style: TextStyle(color: kNavy, fontWeight: FontWeight.w600)),
          ]),
        ),
      ],
      onChanged: (v) {
        if (v == _kFree) {
          setState(() => _freeMode = true);
          return;
        }
        widget.onChanged(v == _kNone ? null : v);
      },
    );
  }
}

/// La tutelle est un joker à trois états — et « Toutes » n'est PAS l'absence
/// de choix : c'est la règle qui s'applique au général comme au technique.
class ExamRuleTutelleField extends StatelessWidget {
  const ExamRuleTutelleField(
      {super.key, required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
        initialValue: value ?? _kNone,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'Tutelle',
          labelStyle: TextStyle(color: kTextMuted),
          border: const OutlineInputBorder(),
          isDense: true,
          helperText: value == null
              ? 'S\'applique quelle que soit la tutelle de l\'école.'
              : 'Ne s\'applique qu\'aux écoles de cette tutelle.',
          helperMaxLines: 2,
          helperStyle: TextStyle(fontSize: 11, color: kTextMuted),
        ),
        style: TextStyle(fontSize: 13, color: kTextPrimary),
        items: [
          DropdownMenuItem(
              value: _kNone,
              child: Text('Toutes les tutelles',
                  style: TextStyle(color: kTextMuted))),
          const DropdownMenuItem(
              value: 'metp', child: Text('METP — technique & professionnel')),
          const DropdownMenuItem(
              value: 'mepsa', child: Text('MEPSA — enseignement général')),
        ],
        onChanged: (v) => onChanged(v == _kNone ? null : v),
      );
}

/// Portée : nationale, ou propre à un groupe scolaire. Une surcharge de groupe
/// bat toujours la règle nationale (poids 4 dans `resolve_class_exam`) — c'est
/// le geste d'exception, il doit se voir.
class ExamRuleScopeField extends StatelessWidget {
  const ExamRuleScopeField({
    super.key,
    required this.groupId,
    required this.groups,
    required this.onChanged,
  });

  final String? groupId;
  final List<(String, String)> groups;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
        initialValue: groupId ?? _kNone,
        isExpanded: true,
        menuMaxHeight: 380,
        decoration: InputDecoration(
          labelText: 'Portée',
          labelStyle: TextStyle(color: kTextMuted),
          border: const OutlineInputBorder(),
          isDense: true,
          helperText: groupId == null
              ? 'Règle nationale : elle s\'applique à tout le pays.'
              : 'Surcharge locale : elle prime sur la règle nationale.',
          helperMaxLines: 2,
          helperStyle: TextStyle(fontSize: 11, color: kTextMuted),
        ),
        style: TextStyle(fontSize: 13, color: kTextPrimary),
        items: [
          DropdownMenuItem(
            value: _kNone,
            child: Row(children: [
              Icon(Icons.public_rounded, size: 15, color: kNavy),
              const SizedBox(width: 8),
              const Text('Nationale'),
            ]),
          ),
          for (final (id, name) in groups)
            DropdownMenuItem(
                value: id, child: Text(name, overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (v) => onChanged(v == _kNone ? null : v),
      );
}
