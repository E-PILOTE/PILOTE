import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/list_chrome.dart';
import '../providers/admin_schools_provider.dart';
import '../providers/exam_archives_provider.dart';
import 'exam_publication_fields.dart';

// ════════════════════════════════════════════════════════════════════════════
//  RELEVER — OU CORRIGER — UN CHIFFRE OFFICIEL.
//
//  Jusqu'ici un chiffre ne pouvait naître qu'au dépôt d'une pièce. Trois
//  situations, toutes ordinaires, restaient donc sans issue :
//   • la DEC communique un taux avant d'envoyer le document (radio, conférence
//     de presse) — le chiffre existe, la pièce viendra ;
//   • une publication rectificative corrige un effectif — rien ne permettait
//     de reprendre la ligne déjà enregistrée ;
//   • un relevé ancien n'a jamais eu de pièce jointe — et rien ne permettait
//     de lui en rattacher une, alors que l'écran le signale comme non sourcé.
//
//  Le panneau ne calcule rien : il enregistre ce qui est écrit sur le document.
//  Le taux se déduit des effectifs quand ils sont donnés ; sinon c'est le
//  pourcentage publié qui fait foi, tel quel.
// ════════════════════════════════════════════════════════════════════════════
Future<void> showExamFigurePanel(
  BuildContext context, {
  OfficialFigure? figure,
  String? sessionId,
}) =>
    showAdminSidePanel<void>(
      context,
      builder: (_) => _FigurePanel(figure: figure, sessionId: sessionId),
    );

class _FigurePanel extends ConsumerStatefulWidget {
  const _FigurePanel({this.figure, this.sessionId});

  /// Non nul = correction d'un relevé existant.
  final OfficialFigure? figure;
  final String? sessionId;

  @override
  ConsumerState<_FigurePanel> createState() => _State();
}

class _State extends ConsumerState<_FigurePanel> {
  late String? _sessionId = widget.figure?.sessionId ?? widget.sessionId;
  late PubScope _scope = widget.figure?.scope ?? PubScope.national;
  late String? _department = widget.figure?.department;
  late String? _schoolId = widget.figure?.schoolId;
  late String? _publicationId = widget.figure?.publicationId;
  late DateTime? _publishedAt = widget.figure?.publishedAt;

  late final _filiere =
      TextEditingController(text: widget.figure?.filiereLabel ?? '');
  late final _registered =
      TextEditingController(text: widget.figure?.registered?.toString() ?? '');
  late final _present =
      TextEditingController(text: widget.figure?.present?.toString() ?? '');
  late final _admitted =
      TextEditingController(text: widget.figure?.admitted?.toString() ?? '');
  late final _rate = TextEditingController(
      text: widget.figure?.storedRate?.toString().replaceAll('.', ',') ?? '');
  late final _source =
      TextEditingController(text: widget.figure?.sourceLabel ?? '');

  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.figure != null;

  @override
  void dispose() {
    for (final c in [_filiere, _registered, _present, _admitted, _rate, _source]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Les effectifs priment : dès qu'ils sont saisis, le pourcentage se déduit
  /// et le champ « taux » n'a plus lieu d'être.
  bool get _hasCounts =>
      int.tryParse(_present.text.trim()) != null &&
      int.tryParse(_admitted.text.trim()) != null;

  double? get _preview => officialPassRate(
        present: int.tryParse(_present.text.trim()),
        admitted: int.tryParse(_admitted.text.trim()),
        storedRate: double.tryParse(_rate.text.trim().replaceAll(',', '.')),
      );

  String? _validate() {
    if (_sessionId == null) return 'Choisissez l\'examen et la session.';
    if (_scope == PubScope.departement && (_department ?? '').isEmpty) {
      return 'Précisez le département auquel ce chiffre se rapporte.';
    }
    if (_scope == PubScope.etablissement && _schoolId == null) {
      return 'Précisez l\'établissement auquel ce chiffre se rapporte.';
    }
    final present = int.tryParse(_present.text.trim());
    final admitted = int.tryParse(_admitted.text.trim());
    if ((present == null) != (admitted == null)) {
      return 'Présents et admis vont ensemble : saisissez les deux, ou aucun.';
    }
    if (present != null && admitted != null && admitted > present) {
      return 'Il ne peut pas y avoir plus d\'admis que de présents.';
    }
    if (_preview == null) {
      return 'Un relevé sans chiffre n\'en est pas un : donnez les effectifs, '
          'ou le pourcentage publié.';
    }
    return null;
  }

  Future<void> _save() async {
    final problem = _validate();
    if (problem != null) return setState(() => _error = problem);

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(archiveActionsProvider).recordFigure(
            sessionId: _sessionId!,
            scope: _scope,
            department: _department,
            schoolId: _schoolId,
            filiereLabel: _filiere.text,
            registered: int.tryParse(_registered.text.trim()),
            present: int.tryParse(_present.text.trim()),
            admitted: int.tryParse(_admitted.text.trim()),
            passRate: double.tryParse(_rate.text.trim().replaceAll(',', '.')),
            publicationId: _publicationId,
            sourceLabel: _source.text,
            publishedAt: _publishedAt,
            replacingId: widget.figure?.id,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEdit ? 'Relevé corrigé.' : 'Chiffre officiel relevé.'),
      ));
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$e';
        });
      }
    }
  }

  Future<void> _remove() async {
    final f = widget.figure;
    if (f == null) return;
    final ok = await showAdminConfirm(
      context,
      danger: true,
      title: 'Retirer ce relevé ?',
      message: 'Le chiffre disparaîtra de l\'historique et des classements. '
          'La publication, elle, reste archivée : c\'est la lecture qu\'on '
          'efface, pas le document de la DEC.',
      confirmLabel: 'Retirer le relevé',
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(archiveActionsProvider).removeFigure(f);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Relevé retiré.')));
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(archiveSessionsProvider).valueOrNull ?? const [];
    final schools =
        ref.watch(adminSchoolsProvider).valueOrNull?.schools ?? const [];
    final pubs = ref.watch(examPublicationsProvider).valueOrNull ?? const [];
    // Une pièce ne peut appuyer qu'un chiffre de SA session : proposer les
    // autres inviterait à sourcer un taux 2025 par un document 2021.
    final candidates =
        pubs.where((p) => p.sessionId == _sessionId).toList();

    return AdminSidePanel(
      icon: Icons.edit_note_rounded,
      title: _isEdit ? 'Corriger un relevé officiel' : 'Relever un chiffre officiel',
      subtitle: 'Ce qui est écrit sur la publication de la DEC — rien de calculé',
      footer: AdminModalActions(
        saving: _saving,
        submitLabel: _isEdit ? 'Corriger' : 'Enregistrer',
        submitIcon: Icons.check_rounded,
        leading: _isEdit
            ? TextButton.icon(
                onPressed: _saving ? null : _remove,
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: const Text('Retirer'),
                style: TextButton.styleFrom(foregroundColor: kRed),
              )
            : null,
        onSubmit: _save,
      ),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const AdminFormSectionLabel('EXAMEN ET SESSION'),
        const SizedBox(height: 9),
        SizedBox(
          height: 42,
          child: ListFilterDropdown(
            icon: Icons.workspace_premium_rounded,
            label: 'Session',
            value: _sessionId ?? '',
            items: {
              '': 'Choisir…',
              for (final s in sessions) s.id: s.label,
            },
            onChanged: (v) => setState(() {
              _sessionId = v.isEmpty ? null : v;
              // La pièce rattachée appartenait à l'autre session.
              _publicationId = null;
            }),
          ),
        ),
        const SizedBox(height: 16),
        const AdminFormSectionLabel('PÉRIMÈTRE DU CHIFFRE'),
        const SizedBox(height: 9),
        ScopePicker(
          scope: _scope,
          onChanged: (s) => setState(() => _scope = s),
        ),
        const SizedBox(height: 10),
        if (_scope == PubScope.departement)
          SizedBox(
            height: 42,
            child: ListFilterDropdown(
              icon: Icons.map_rounded,
              label: 'Département',
              value: _department ?? '',
              items: {
                '': 'Choisir…',
                for (final d in _departments(schools)) d: d,
              },
              onChanged: (v) =>
                  setState(() => _department = v.isEmpty ? null : v),
            ),
          ),
        if (_scope == PubScope.etablissement)
          SizedBox(
            height: 42,
            child: ListFilterDropdown(
              icon: Icons.account_balance_rounded,
              label: 'Établissement',
              value: _schoolId ?? '',
              items: {
                '': 'Choisir…',
                for (final s in schools) s.id: s.name,
              },
              onChanged: (v) =>
                  setState(() => _schoolId = v.isEmpty ? null : v),
            ),
          ),
        const SizedBox(height: 10),
        _field(_filiere, 'Filière ou série (facultatif)',
            hint: 'ex. F5, Électrotechnique'),
        const SizedBox(height: 16),
        const AdminFormSectionLabel('CHIFFRES PORTÉS PAR LA PUBLICATION'),
        const SizedBox(height: 9),
        const FiguresNote(),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _num(_registered, 'Inscrits')),
          const SizedBox(width: 10),
          Expanded(child: _num(_present, 'Présents')),
          const SizedBox(width: 10),
          Expanded(child: _num(_admitted, 'Admis')),
        ]),
        const SizedBox(height: 10),
        if (!_hasCounts)
          _field(_rate, 'Taux publié (%)',
              hint: 'si la publication ne donne que le pourcentage'),
        if (_preview != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Taux retenu : ${_preview!.toStringAsFixed(2)} % '
              '${_hasCounts ? '(admis ÷ présents)' : '(publié)'}',
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w700, color: kGreen),
            ),
          ),
        const SizedBox(height: 16),
        const AdminFormSectionLabel('SOURCE'),
        const SizedBox(height: 9),
        _SourcePicker(
          publications: candidates,
          selected: _publicationId,
          onChanged: (v) => setState(() => _publicationId = v),
          sessionChosen: _sessionId != null,
        ),
        const SizedBox(height: 10),
        _field(_source, 'Référence de la source (facultatif)',
            hint: 'ex. Statistiques DEC, communiqué du 12/07'),
        const SizedBox(height: 10),
        DatePick(
          value: _publishedAt,
          onChanged: (d) => setState(() => _publishedAt = d),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          AdminErrorBanner(message: _error!),
        ],
      ]),
    );
  }

  List<String> _departments(List<dynamic> schools) {
    final set = <String>{};
    for (final s in schools) {
      final d = (s.department as String?)?.trim();
      if (d != null && d.isNotEmpty) set.add(d);
    }
    return set.toList()..sort();
  }

  Widget _field(TextEditingController c, String label, {String? hint}) =>
      TextField(
        controller: c,
        onChanged: (_) => setState(() {}),
        style: TextStyle(fontSize: 13, color: kTextPrimary),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          isDense: true,
          labelStyle: TextStyle(fontSize: 12.5, color: kTextMuted),
          hintStyle: TextStyle(fontSize: 12, color: kTextMuted),
          border: const OutlineInputBorder(),
        ),
      );

  Widget _num(TextEditingController c, String label) => TextField(
        controller: c,
        onChanged: (_) => setState(() {}),
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

/// Rattachement à une pièce archivée — ce qui sépare un chiffre opposable
/// d'une note de service.
class _SourcePicker extends StatelessWidget {
  const _SourcePicker({
    required this.publications,
    required this.selected,
    required this.onChanged,
    required this.sessionChosen,
  });

  final List<ExamPublication> publications;
  final String? selected;
  final ValueChanged<String?> onChanged;
  final bool sessionChosen;

  @override
  Widget build(BuildContext context) {
    if (!sessionChosen) {
      return _note('Choisissez d\'abord la session : les pièces proposées sont '
          'celles qui la couvrent.');
    }
    if (publications.isEmpty) {
      return _note('Aucune pièce archivée pour cette session. Le chiffre sera '
          'enregistré SANS source — l\'écran le signalera jusqu\'à ce qu\'une '
          'publication lui soit rattachée.');
    }
    return SizedBox(
      height: 42,
      child: ListFilterDropdown(
        icon: Icons.attach_file_rounded,
        label: 'Pièce',
        value: selected ?? '',
        items: {
          '': 'Aucune — chiffre non sourcé',
          for (final p in publications) p.id: '${p.scopeLabel} · ${p.title}',
        },
        onChanged: (v) => onChanged(v.isEmpty ? null : v),
      ),
    );
  }

  Widget _note(String text) => Builder(
        builder: (context) => Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: kTextMuted.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.link_off_rounded, size: 16, color: kTextMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  style: TextStyle(
                      fontSize: 11.5, color: kTextMuted, height: 1.4)),
            ),
          ]),
        ),
      );
}
