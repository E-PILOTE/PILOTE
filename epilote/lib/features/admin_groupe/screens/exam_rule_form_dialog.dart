import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/list_chrome.dart' show kListOrange, kListPurple;
import '../../auth/providers/auth_provider.dart';
import '../providers/exam_referential_provider.dart';
import '../providers/exam_rule_vocabulary.dart';
import '../widgets/exam_rule_fields.dart';

final _fmtDay = DateFormat('dd/MM/yyyy', 'fr_FR');

// ════════════════════════════════════════════════════════════════════════════
//  SAISIR UNE RÈGLE D'ÉLIGIBILITÉ — « quelle classe prépare cet examen ».
//
//  ── CE QUE ÇA DÉCIDE ───────────────────────────────────────────────────────
//  Tout. `classes.exam_id` est DÉRIVÉ de ces règles ; sans règle, une classe
//  reste « à qualifier » et l'école ne peut inscrire personne. Avec une règle
//  FAUSSE, elle inscrit ses élèves au mauvais examen — et on ne s'en aperçoit
//  qu'à la proclamation. D'où l'aperçu « cette règle concerne N classe(s) »,
//  calculé à blanc avant l'enregistrement.
//
//  ── LE VOCABULAIRE VIENT DE LA BASE ────────────────────────────────────────
//  Les codes de cycle/niveau/filière sont dénormalisés depuis le référentiel
//  de chaque groupe : aucune liste figée dans le Dart ne pourrait les
//  connaître. On propose ce que les classes portent VRAIMENT, en laissant la
//  saisie libre ouverte pour un niveau qui n'existe pas encore.
//
//  ── DU PLUS GÉNÉRAL AU PLUS PRÉCIS ─────────────────────────────────────────
//  Filière et tutelle sont des JOKERS : les laisser vides élargit la règle.
//  Le serveur départage du plus spécifique au plus général — groupe (4) >
//  filière (2) > tutelle (1) — donc une règle large ne « casse » pas une règle
//  fine, elle lui sert de filet.
// ════════════════════════════════════════════════════════════════════════════

/// `true` si une règle a été enregistrée.
Future<bool> showExamRuleForm(
  BuildContext context, {
  required NationalExamRow exam,
  ExamRuleRow? existing,
}) async =>
    await showAdminSidePanel<bool>(
      context,
      builder: (_) => _RuleForm(exam: exam, existing: existing),
    ) ??
    false;

class _RuleForm extends ConsumerStatefulWidget {
  const _RuleForm({required this.exam, this.existing});

  final NationalExamRow exam;
  final ExamRuleRow? existing;

  @override
  ConsumerState<_RuleForm> createState() => _RuleFormState();
}

class _RuleFormState extends ConsumerState<_RuleForm> {
  late String _cycle = widget.existing?.cycleCode ?? widget.exam.cycleCode ?? '';
  late String _level = widget.existing?.levelCode ?? '';
  late String? _program = widget.existing?.programCode;

  /// `null` = joker « toutes tutelles ». Par défaut on préremplit avec la
  /// tutelle de l'examen : un diplôme METP concerne le technique.
  late String? _tutelle = widget.existing?.tutelle ??
      (widget.existing == null ? widget.exam.tutelle : null);
  late String? _groupId = widget.existing?.groupId;
  late DateTime? _from = widget.existing?.validFrom;
  late DateTime? _to = widget.existing?.validTo;
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  late bool _active = widget.existing?.isActive ?? true;

  bool _saving = false;
  String? _error;

  /// Aperçu serveur : nombre de classes concernées. `null` = pas encore
  /// calculé ou RPC absente.
  int? _matches;
  bool _counting = false;
  int _previewToken = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshPreview());
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _valid => _cycle.trim().isNotEmpty && _level.trim().isNotEmpty;

  /// Recalcule l'aperçu à chaque changement de critère. Le jeton évite qu'une
  /// réponse lente écrase le résultat d'une saisie plus récente.
  Future<void> _refreshPreview() async {
    if (!_valid) {
      setState(() {
        _matches = null;
        _counting = false;
      });
      return;
    }
    final token = ++_previewToken;
    setState(() => _counting = true);
    final n = await examRuleMatchCount(
      ref.read(supabaseClientProvider),
      cycleCode: _cycle.trim(),
      levelCode: _level.trim(),
      programCode: _program,
      tutelle: _tutelle,
      groupId: _groupId,
    );
    if (!mounted || token != _previewToken) return;
    setState(() {
      _matches = n;
      _counting = false;
    });
  }

  void _set(VoidCallback change) {
    setState(change);
    _refreshPreview();
  }

  @override
  Widget build(BuildContext context) {
    final vocab =
        ref.watch(examRuleVocabularyProvider).valueOrNull ??
            ExamRuleVocabulary.empty;
    final groups = ref.watch(ruleScopeGroupsProvider).valueOrNull ?? const [];
    final isEdit = widget.existing != null;

    return AdminSidePanel(
      icon: Icons.rule_rounded,
      title: isEdit ? 'Modifier la règle' : 'Nouvelle règle d\'éligibilité',
      subtitle: '${widget.exam.shortName} · ${widget.exam.name}',
      accent: kListPurple,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminFormSectionLabel('Classes concernées'),
          const SizedBox(height: 12),
          ExamRuleVocabField(
            label: 'Cycle *',
            hint: 'ex. lycee',
            value: _cycle,
            entries: vocab.cycles,
            onChanged: (v) => _set(() => _cycle = v ?? ''),
          ),
          const SizedBox(height: 14),
          ExamRuleVocabField(
            label: 'Niveau *',
            hint: 'ex. Tle',
            value: _level,
            entries: vocab.levels,
            onChanged: (v) => _set(() => _level = v ?? ''),
          ),
          const SizedBox(height: 14),
          ExamRuleVocabField(
            label: 'Filière',
            hint: 'ex. serie_f7',
            value: _program ?? '',
            entries: vocab.filieres,
            allowNone: true,
            noneLabel: 'Toutes les filières',
            onChanged: (v) => _set(() => _program = v),
          ),
          const SizedBox(height: 14),
          ExamRuleTutelleField(
            value: _tutelle,
            onChanged: (v) => _set(() => _tutelle = v),
          ),
          const SizedBox(height: 16),
          _Preview(count: _matches, counting: _counting, valid: _valid),
          const SizedBox(height: 20),
          const AdminFormDivider(),
          const SizedBox(height: 6),
          const AdminFormSectionLabel('Portée et validité'),
          const SizedBox(height: 12),
          ExamRuleScopeField(
            groupId: _groupId,
            groups: groups,
            onChanged: (v) => _set(() => _groupId = v),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: _DateField(
                label: 'En vigueur à partir du',
                value: _from,
                onPick: (d) => setState(() => _from = d),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DateField(
                label: 'Jusqu\'au',
                value: _to,
                onPick: (d) => setState(() => _to = d),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            'Laisser vide = toujours en vigueur. Une réforme se saisit en '
            'FERMANT l\'ancienne règle et en ouvrant la nouvelle : l\'historique '
            'reste lisible, aucune donnée n\'est réécrite.',
            style: TextStyle(fontSize: 11, color: kTextMuted, height: 1.4),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            maxLines: 2,
            style: TextStyle(fontSize: 13, color: kTextPrimary),
            decoration: _dec('Note / référence de l\'arrêté',
                hint: 'ex. arrêté N°… — série F7 vers le Bac T&P'),
          ),
          const SizedBox(height: 10),
          SwitchListTile.adaptive(
            value: _active,
            onChanged: (v) => setState(() => _active = v),
            contentPadding: EdgeInsets.zero,
            title: Text('Règle active',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary)),
            subtitle: Text(
              _active
                  ? 'Elle participe à la dérivation.'
                  : 'Conservée, mais ignorée par la dérivation.',
              style: TextStyle(fontSize: 11, color: kTextMuted),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: TextStyle(
                    fontSize: 12, color: kRed, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
      footer: AdminModalActions(
        submitLabel: isEdit ? 'Enregistrer' : 'Créer la règle',
        submitIcon: Icons.check_rounded,
        submitColor: kListPurple,
        saving: _saving,
        onSubmit: _valid && !_saving ? _save : () {},
      ),
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
    if (_from != null && _to != null && _to!.isBefore(_from!)) {
      setState(() => _error = 'La fin de validité précède son début.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final client = ref.read(supabaseClientProvider);
      await upsertExamRule(
        client,
        id: widget.existing?.id,
        examId: widget.exam.id,
        cycleCode: _cycle,
        levelCode: _level,
        programCode: _program,
        tutelle: _tutelle,
        validFrom: _from,
        validTo: _to,
        groupId: _groupId,
        note: _note.text,
        isActive: _active,
      );
      // Le trigger ne s'arme qu'à l'écriture d'une CLASSE : sans ce recalcul,
      // la règle nouvelle ne toucherait aucune classe existante et paraîtrait
      // sans effet.
      final n = await recomputeClassExams(client);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(n == 0
            ? 'Règle enregistrée. Aucune classe n\'a changé d\'examen.'
            : 'Règle enregistrée · $n classe(s) requalifiée(s).'),
      ));
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

/// L'aperçu. Un « 0 » est l'information la plus utile de l'écran : la règle
/// est syntaxiquement valide et ne servira à rien.
class _Preview extends StatelessWidget {
  const _Preview(
      {required this.count, required this.counting, required this.valid});

  final int? count;
  final bool counting;
  final bool valid;

  @override
  Widget build(BuildContext context) {
    if (!valid) {
      return _box(kTextMuted, Icons.info_outline_rounded,
          'Renseignez un cycle et un niveau pour voir les classes concernées.');
    }
    if (counting) {
      return _box(kTextMuted, Icons.hourglass_empty_rounded, 'Calcul…');
    }
    if (count == null) {
      // RPC absente (migration 0070 non déployée) : on le dit, on ne bluffe pas.
      return _box(kTextMuted, Icons.help_outline_rounded,
          'Aperçu indisponible sur ce serveur — la règle reste enregistrable.');
    }
    if (count == 0) {
      return _box(
          kListOrange,
          Icons.filter_alt_off_rounded,
          'Aucune classe ne correspond aujourd\'hui. La règle sera enregistrée '
          'mais ne qualifiera personne — vérifiez le code de niveau.');
    }
    return _box(kGreen, Icons.check_circle_outline_rounded,
        'Cette règle concerne $count classe(s) du parc.');
  }

  Widget _box(Color c, IconData i, String text) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.withValues(alpha: 0.25)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(i, size: 17, color: c),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style:
                    TextStyle(fontSize: 12, color: kTextPrimary, height: 1.4)),
          ),
        ]),
      );
}

class _DateField extends StatelessWidget {
  const _DateField(
      {required this.label, required this.value, required this.onPick});

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onPick;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () async {
          final now = DateTime.now();
          final d = await showDatePicker(
            context: context,
            initialDate: value ?? now,
            firstDate: DateTime(now.year - 10),
            lastDate: DateTime(now.year + 15),
          );
          if (d != null) onPick(d);
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: kTextMuted),
            border: const OutlineInputBorder(),
            isDense: true,
            suffixIcon: value == null
                ? Icon(Icons.calendar_today_rounded, size: 15, color: kTextMuted)
                : IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 15),
                    onPressed: () => onPick(null),
                    tooltip: 'Effacer',
                  ),
          ),
          child: Text(
            value == null ? '—' : _fmtDay.format(value!),
            style: TextStyle(
                fontSize: 13,
                color: value == null ? kTextMuted : kTextPrimary),
          ),
        ),
      );
}
