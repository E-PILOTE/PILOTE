import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/list_chrome.dart';
import '../providers/exam_archives_provider.dart';
import 'exam_publication_fields.dart';

// ════════════════════════════════════════════════════════════════════════════
//  UN RELEVÉ EN COURS DE SAISIE — modèle immuable et champs partagés.
//
//  Deux panneaux relèvent des chiffres officiels : celui qui en corrige un
//  ([showExamFigurePanel]) et celui qui en enchaîne une série depuis une même
//  pièce ([showExamFigureBatchPanel]). Ils partagent les mêmes règles — les
//  effectifs priment sur le taux publié, présents et admis vont ensemble, un
//  périmètre départemental exige son département — et il n'y en a donc qu'une
//  écriture.
//
//  Le modèle est IMMUABLE à dessein. La saisie groupée repart d'une copie
//  amputée du relevé précédent plutôt que de remettre des contrôleurs à zéro à
//  la main : c'est ce qui garantit qu'aucun effectif du Pool ne traîne sur la
//  Bouenza. Une erreur de ce genre ne se voit pas à l'écran — elle se découvre
//  des mois plus tard, dans une statistique nationale.
// ════════════════════════════════════════════════════════════════════════════

/// Sentinelle de [FigureDraft.copyWith] : distingue « paramètre non fourni »
/// de « remis explicitement à null ». Sans elle, vider un département serait
/// impossible, et c'est précisément ce qu'il faut pouvoir faire.
const Object _unset = Object();

class FigureDraft {
  const FigureDraft({
    required this.sessionId,
    required this.publicationId,
    required this.publishedAt,
    required this.scope,
    required this.department,
    required this.schoolId,
    required this.filiereLabel,
    required this.registered,
    required this.present,
    required this.admitted,
    required this.rate,
  });

  /// Un relevé neuf rattaché à une pièce : c'est le point de départ de la
  /// saisie groupée.
  factory FigureDraft.forPublication(ExamPublication p) => FigureDraft(
        sessionId: p.sessionId,
        publicationId: p.id,
        publishedAt: p.publishedAt ?? p.receivedAt,
        scope: p.scope,
        department: p.department,
        schoolId: p.schoolId,
        filiereLabel: p.filiereLabel ?? '',
        registered: null,
        present: null,
        admitted: null,
        rate: null,
      );

  final String? sessionId;
  final String? publicationId;
  final DateTime? publishedAt;
  final PubScope scope;
  final String? department;
  final String? schoolId;
  final String filiereLabel;
  final int? registered;
  final int? present;
  final int? admitted;
  final double? rate;

  /// Les effectifs priment : dès qu'ils sont saisis, le champ « taux publié »
  /// n'a plus lieu d'être — deux vérités concurrentes sur la même ligne.
  bool get hasCounts => present != null && admitted != null;

  /// Le taux retenu : les effectifs d'abord, sinon le pourcentage publié tel
  /// quel. `null` = ce n'est pas encore un relevé.
  double? get retainedRate => officialPassRate(
        present: present,
        admitted: admitted,
        storedRate: rate,
      );

  bool get isComplete => retainedRate != null;

  /// Ce qui manque au périmètre, ou `null` s'il tient debout. Un chiffre
  /// départemental sans département ne se rattache à rien : il deviendrait un
  /// second « national » silencieux.
  String? get scopeProblem {
    if (scope == PubScope.departement && (department ?? '').trim().isEmpty) {
      return 'Précisez le département auquel ce chiffre se rapporte.';
    }
    if (scope == PubScope.etablissement && (schoolId ?? '').isEmpty) {
      return 'Précisez l\'établissement auquel ce chiffre se rapporte.';
    }
    return null;
  }

  /// Ce qui cloche dans les effectifs, ou `null`.
  String? get countsProblem {
    if ((present == null) != (admitted == null)) {
      return 'Présents et admis vont ensemble : saisissez les deux, ou aucun.';
    }
    if (present != null && admitted != null && admitted! > present!) {
      return 'Il ne peut pas y avoir plus d\'admis que de présents.';
    }
    return null;
  }

  /// Le premier problème rencontré, dans l'ordre où on remplit le formulaire.
  String? get problem {
    if (sessionId == null) return 'Choisissez l\'examen et la session.';
    final scoped = scopeProblem;
    if (scoped != null) return scoped;
    final counts = countsProblem;
    if (counts != null) return counts;
    if (!isComplete) {
      return 'Un relevé sans chiffre n\'en est pas un : donnez les effectifs, '
          'ou le pourcentage publié.';
    }
    return null;
  }

  /// Étiquette d'un relevé déjà enregistré, dans la liste d'avancement de la
  /// saisie groupée. Le périmètre AVEC son taux : « Pool » seul ne dirait pas
  /// si la ligne porte un chiffre plausible.
  String get chipLabel {
    final where = switch (scope) {
      PubScope.national => 'National',
      PubScope.departement => department ?? 'Département',
      PubScope.etablissement => 'Établissement',
    };
    final r = retainedRate;
    final pct = r == null
        ? '—'
        : '${r.toStringAsFixed(2).replaceAll('.', ',')} %';
    return '$where · $pct';
  }

  FigureDraft copyWith({
    Object? sessionId = _unset,
    Object? publicationId = _unset,
    Object? publishedAt = _unset,
    PubScope? scope,
    Object? department = _unset,
    Object? schoolId = _unset,
    String? filiereLabel,
    Object? registered = _unset,
    Object? present = _unset,
    Object? admitted = _unset,
    Object? rate = _unset,
  }) =>
      FigureDraft(
        sessionId:
            sessionId == _unset ? this.sessionId : sessionId as String?,
        publicationId: publicationId == _unset
            ? this.publicationId
            : publicationId as String?,
        publishedAt:
            publishedAt == _unset ? this.publishedAt : publishedAt as DateTime?,
        scope: scope ?? this.scope,
        department:
            department == _unset ? this.department : department as String?,
        schoolId: schoolId == _unset ? this.schoolId : schoolId as String?,
        filiereLabel: filiereLabel ?? this.filiereLabel,
        registered:
            registered == _unset ? this.registered : registered as int?,
        present: present == _unset ? this.present : present as int?,
        admitted: admitted == _unset ? this.admitted : admitted as int?,
        rate: rate == _unset ? this.rate : rate as double?,
      );
}

/// Ce qui survit d'un relevé au suivant : la PIÈCE, la session, la date de
/// publication — tout ce qui décrit le document, jamais ce qu'on y a lu.
FigureDraft resetForNext(FigureDraft d) => FigureDraft(
      sessionId: d.sessionId,
      publicationId: d.publicationId,
      publishedAt: d.publishedAt,
      scope: PubScope.national,
      department: null,
      schoolId: null,
      filiereLabel: '',
      registered: null,
      present: null,
      admitted: null,
      rate: null,
    );

// ─── Champs partagés ────────────────────────────────────────────────────────

/// Périmètre du chiffre : national, un département, un établissement.
class FigureScopeFields extends StatelessWidget {
  const FigureScopeFields({
    super.key,
    required this.draft,
    required this.departments,
    required this.schools,
    required this.onChanged,
  });

  final FigureDraft draft;
  final List<String> departments;

  /// Paires (id, nom) — la liste des écoles du groupe.
  final List<(String, String)> schools;
  final ValueChanged<FigureDraft> onChanged;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScopePicker(
            scope: draft.scope,
            onChanged: (s) => onChanged(draft.copyWith(scope: s)),
          ),
          const SizedBox(height: 10),
          if (draft.scope == PubScope.departement)
            SizedBox(
              height: 42,
              child: ListFilterDropdown(
                icon: Icons.map_rounded,
                label: 'Département',
                value: draft.department ?? '',
                items: {
                  '': 'Choisir…',
                  for (final d in departments) d: d,
                },
                onChanged: (v) =>
                    onChanged(draft.copyWith(department: v.isEmpty ? null : v)),
              ),
            ),
          if (draft.scope == PubScope.etablissement)
            SizedBox(
              height: 42,
              child: ListFilterDropdown(
                icon: Icons.account_balance_rounded,
                label: 'Établissement',
                value: draft.schoolId ?? '',
                items: {
                  '': 'Choisir…',
                  for (final (id, name) in schools) id: name,
                },
                onChanged: (v) =>
                    onChanged(draft.copyWith(schoolId: v.isEmpty ? null : v)),
              ),
            ),
        ],
      );
}

/// Inscrits · présents · admis, le taux publié en repli, et l'aperçu du taux
/// retenu. Le trio ne se sépare pas : c'est la lecture d'une même ligne du
/// document.
class FigureCountsFields extends StatefulWidget {
  const FigureCountsFields({
    super.key,
    required this.draft,
    required this.onChanged,
  });

  final FigureDraft draft;
  final ValueChanged<FigureDraft> onChanged;

  @override
  State<FigureCountsFields> createState() => _FigureCountsFieldsState();
}

class _FigureCountsFieldsState extends State<FigureCountsFields> {
  late final _registered = TextEditingController(text: _s(widget.draft.registered));
  late final _present = TextEditingController(text: _s(widget.draft.present));
  late final _admitted = TextEditingController(text: _s(widget.draft.admitted));
  late final _rate = TextEditingController(
      text: widget.draft.rate?.toString().replaceAll('.', ',') ?? '');

  static String _s(int? v) => v?.toString() ?? '';

  @override
  void didUpdateWidget(FigureCountsFields old) {
    super.didUpdateWidget(old);
    // La saisie groupée remplace le draft par une version vidée : les champs
    // doivent suivre. On ne réécrit QUE sur une vraie divergence, sinon le
    // curseur sauterait à chaque frappe.
    _sync(_registered, widget.draft.registered);
    _sync(_present, widget.draft.present);
    _sync(_admitted, widget.draft.admitted);
    final r = widget.draft.rate?.toString().replaceAll('.', ',') ?? '';
    if (_num(_rate.text) != widget.draft.rate) _rate.text = r;
  }

  static double? _num(String t) =>
      double.tryParse(t.trim().replaceAll(',', '.'));

  void _sync(TextEditingController c, int? v) {
    if (int.tryParse(c.text.trim()) != v) c.text = _s(v);
  }

  @override
  void dispose() {
    for (final c in [_registered, _present, _admitted, _rate]) {
      c.dispose();
    }
    super.dispose();
  }

  void _push() => widget.onChanged(widget.draft.copyWith(
        registered: int.tryParse(_registered.text.trim()),
        present: int.tryParse(_present.text.trim()),
        admitted: int.tryParse(_admitted.text.trim()),
        rate: _num(_rate.text),
      ));

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    final preview = d.retainedRate;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const FiguresNote(),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _num_(_registered, 'Inscrits')),
        const SizedBox(width: 10),
        Expanded(child: _num_(_present, 'Présents')),
        const SizedBox(width: 10),
        Expanded(child: _num_(_admitted, 'Admis')),
      ]),
      const SizedBox(height: 10),
      if (!d.hasCounts)
        TextField(
          controller: _rate,
          onChanged: (_) => _push(),
          style: TextStyle(fontSize: 13, color: kTextPrimary),
          decoration: InputDecoration(
            labelText: 'Taux publié (%)',
            hintText: 'si la publication ne donne que le pourcentage',
            isDense: true,
            labelStyle: TextStyle(fontSize: 12.5, color: kTextMuted),
            hintStyle: TextStyle(fontSize: 12, color: kTextMuted),
            border: const OutlineInputBorder(),
          ),
        ),
      if (preview != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Taux retenu : ${preview.toStringAsFixed(2)} % '
            '${d.hasCounts ? '(admis ÷ présents)' : '(publié)'}',
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w700, color: kGreen),
          ),
        ),
    ]);
  }

  Widget _num_(TextEditingController c, String label) => TextField(
        controller: c,
        onChanged: (_) => _push(),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: TextStyle(fontSize: 13, color: kTextPrimary),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          labelStyle: TextStyle(fontSize: 12.5, color: kTextMuted),
          border: const OutlineInputBorder(),
        ),
      );
}
