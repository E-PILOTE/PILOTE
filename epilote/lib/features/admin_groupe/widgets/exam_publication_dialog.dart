import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/list_chrome.dart';
import '../providers/admin_schools_provider.dart';
import '../providers/exam_archives_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  DÉPÔT D'UNE PUBLICATION DE LA DEC.
//
//  Un seul geste, dans l'ordre où la DSIC travaille : on a le document sous les
//  yeux, on le range, et on relève les chiffres qu'il porte. Séparer les deux
//  écrans produirait des pièces sans chiffres et des chiffres sans pièce.
//
//  Le formulaire ne LIT PAS le PDF. Une extraction ratée écrirait un faux
//  résultat sur le dossier d'un élève, et un document scanné ne rend aucun
//  texte. Le périmètre est donc DÉCLARÉ par le déposant — il l'a sous les yeux.
// ════════════════════════════════════════════════════════════════════════════
Future<void> showExamPublicationDialog(BuildContext context) => showDialog<void>(
      context: context,
      builder: (_) => const _PublicationDialog(),
    );

class _PublicationDialog extends ConsumerStatefulWidget {
  const _PublicationDialog();

  @override
  ConsumerState<_PublicationDialog> createState() => _State();
}

class _State extends ConsumerState<_PublicationDialog> {
  String? _sessionId;
  PubScope _scope = PubScope.national;
  String? _department;
  String? _schoolId;

  final _title = TextEditingController();
  final _decCode = TextEditingController();
  final _filiere = TextEditingController();
  final _registered = TextEditingController();
  final _present = TextEditingController();
  final _admitted = TextEditingController();
  final _rate = TextEditingController();
  final _source = TextEditingController();

  DateTime? _publishedAt;
  PlatformFile? _file;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _title, _decCode, _filiere, _registered,
      _present, _admitted, _rate, _source,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Les effectifs priment : dès qu'ils sont saisis, le pourcentage se déduit
  /// et le champ « taux » n'a plus lieu d'être — deux vérités concurrentes
  /// dans un même formulaire finiraient par diverger.
  bool get _hasCounts =>
      int.tryParse(_present.text.trim()) != null &&
      int.tryParse(_admitted.text.trim()) != null;

  double? get _preview => officialPassRate(
        present: int.tryParse(_present.text.trim()),
        admitted: int.tryParse(_admitted.text.trim()),
        storedRate: double.tryParse(_rate.text.trim().replaceAll(',', '.')),
      );

  Future<void> _pick() async {
    final res = await FilePicker.platform.pickFiles(
      dialogTitle: 'Publication de la DEC',
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    final f = res?.files.firstOrNull;
    if (f == null || f.bytes == null) return;
    setState(() {
      _file = f;
      if (_title.text.trim().isEmpty) {
        _title.text = f.name.replaceAll(RegExp(r'\.[A-Za-z]+$'), '');
      }
    });
  }

  String? _validate() {
    if (_sessionId == null) return 'Choisissez l\'examen et la session.';
    if (_file == null) return 'Joignez le document publié par la DEC.';
    if (_title.text.trim().isEmpty) return 'Donnez un intitulé au document.';
    if (_scope == PubScope.departement && (_department ?? '').isEmpty) {
      return 'Précisez le département couvert par ce document.';
    }
    if (_scope == PubScope.etablissement &&
        _schoolId == null &&
        _decCode.text.trim().isEmpty) {
      return 'Identifiez l\'établissement : notre école ou son code DEC.';
    }
    final present = int.tryParse(_present.text.trim());
    final admitted = int.tryParse(_admitted.text.trim());
    if (present != null && admitted != null && admitted > present) {
      return 'Il ne peut pas y avoir plus d\'admis que de présents.';
    }
    if ((present == null) != (admitted == null)) {
      return 'Présents et admis vont ensemble : saisissez les deux, ou aucun.';
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
      final actions = ref.read(archiveActionsProvider);
      final pubId = await actions.deposit(
        sessionId: _sessionId!,
        scope: _scope,
        title: _title.text,
        fileName: _file!.name,
        bytes: _file!.bytes!,
        department: _department,
        schoolId: _schoolId,
        decSchoolCode: _decCode.text,
        filiereLabel: _filiere.text,
        publishedAt: _publishedAt,
      );

      // Les chiffres ne sont enregistrés que s'ils ont été relevés : une pièce
      // peut être archivée seule, en attendant sa lecture.
      final present = int.tryParse(_present.text.trim());
      final admitted = int.tryParse(_admitted.text.trim());
      final rate = double.tryParse(_rate.text.trim().replaceAll(',', '.'));
      if ((present != null && admitted != null) || rate != null) {
        await actions.recordFigure(
          sessionId: _sessionId!,
          scope: _scope,
          department: _department,
          schoolId: _schoolId,
          filiereLabel: _filiere.text,
          registered: int.tryParse(_registered.text.trim()),
          present: present,
          admitted: admitted,
          passRate: rate,
          sourceLabel: _source.text,
          publishedAt: _publishedAt,
        );
      }

      // La pièce est archivée : on prévient les écoles concernées. Un échec
      // ici n'annule rien — une publication non notifiée reste une
      // publication.
      var notified = 0;
      try {
        notified = await actions.notify(
          publicationId: pubId,
          scope: _scope,
          title: _title.text.trim(),
          department: _department,
          schoolId: _schoolId,
        );
      } catch (_) {}

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(notified == 0
              ? 'Publication archivée. Aucun chef d\'établissement à prévenir '
                  'sur ce périmètre.'
              : 'Publication archivée · $notified chef(s) d\'établissement '
                  'prévenu(s)'),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(archiveSessionsProvider).valueOrNull ?? const [];
    final schools =
        ref.watch(adminSchoolsProvider).valueOrNull?.schools ?? const [];

    return AlertDialog(
      backgroundColor: kCardBg,
      contentPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      content: SizedBox(
        width: 640,
        child: Column(
          // Dialogue-formulaire : jamais pleine hauteur.
          mainAxisSize: MainAxisSize.min,
          children: [
            const AdminDialogHeader(
              title: 'Déposer une publication de la DEC',
              icon: Icons.inventory_2_rounded,
              subtitle: 'La pièce est archivée telle quelle ; ses chiffres sont '
                  'relevés à la main, jamais extraits',
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Examen et session'),
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
                        onChanged: (v) =>
                            setState(() => _sessionId = v.isEmpty ? null : v),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _label('Périmètre couvert par le document'),
                    _ScopePicker(
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
                    if (_scope == PubScope.etablissement) ...[
                      SizedBox(
                        height: 42,
                        child: ListFilterDropdown(
                          icon: Icons.account_balance_rounded,
                          label: 'Établissement',
                          value: _schoolId ?? '',
                          items: {
                            '': 'Non rattaché',
                            for (final s in schools) s.id: s.name,
                          },
                          onChanged: (v) =>
                              setState(() => _schoolId = v.isEmpty ? null : v),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _field(_decCode, 'Code DEC de l\'établissement',
                          hint: 'ex. AAB — tel qu\'il figure sur le document'),
                    ],
                    const SizedBox(height: 10),
                    _field(_filiere, 'Filière ou série (facultatif)',
                        hint: 'ex. F5, Électrotechnique'),
                    const SizedBox(height: 14),
                    _label('Le document'),
                    _FileTile(file: _file, onPick: _pick),
                    const SizedBox(height: 10),
                    _field(_title, 'Intitulé du document'),
                    const SizedBox(height: 10),
                    _DatePick(
                      value: _publishedAt,
                      onChanged: (d) => setState(() => _publishedAt = d),
                    ),
                    const SizedBox(height: 16),
                    const _FiguresNote(),
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
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: kGreen),
                        ),
                      ),
                    const SizedBox(height: 10),
                    _field(_source, 'Source (facultatif)',
                        hint: 'ex. Statistiques DEC, communiqué du 12/07'),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: TextStyle(fontSize: 12.5, color: kRed)),
                    ],
                  ],
                ),
              ),
            ),
            AdminDialogFooter(
              saving: _saving,
              submitLabel: 'Archiver',
              submitIcon: Icons.inventory_2_rounded,
              onCancel: () => Navigator.of(context).pop(),
              onSubmit: _save,
            ),
          ],
        ),
      ),
    );
  }

  List<String> _departments(List<dynamic> schools) {
    final set = <String>{};
    for (final s in schools) {
      final d = (s.department as String?)?.trim();
      if (d != null && d.isNotEmpty) set.add(d);
    }
    final out = set.toList()..sort();
    return out;
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: kTextPrimary,
                letterSpacing: 0.3)),
      );

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

// ─── Périmètre ──────────────────────────────────────────────────────────────
class _ScopePicker extends StatelessWidget {
  const _ScopePicker({required this.scope, required this.onChanged});
  final PubScope scope;
  final ValueChanged<PubScope> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        children: [
          for (final s in PubScope.values)
            ChoiceChip(
              label: Text(s.label, style: const TextStyle(fontSize: 12.5)),
              selected: scope == s,
              onSelected: (_) => onChanged(s),
            ),
        ],
      );
}

// ─── Fichier ────────────────────────────────────────────────────────────────
class _FileTile extends StatelessWidget {
  const _FileTile({required this.file, required this.onPick});
  final PlatformFile? file;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final f = file;
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: f == null ? kBorder : kGreen),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Icon(f == null ? Icons.upload_file_rounded : Icons.description_rounded,
              size: 20, color: f == null ? kTextMuted : kGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              f == null
                  ? 'Joindre le PDF publié par la DEC'
                  : '${f.name}  ·  ${(f.size / 1024).round()} Ko',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: f == null ? kTextMuted : kTextPrimary),
            ),
          ),
          if (f != null)
            Text('Changer',
                style: TextStyle(fontSize: 11.5, color: kTextMuted)),
        ]),
      ),
    );
  }
}

// ─── Date de proclamation ───────────────────────────────────────────────────
class _DatePick extends StatelessWidget {
  const _DatePick({required this.value, required this.onChanged});
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () async {
          final now = DateTime.now();
          final d = await showDatePicker(
            context: context,
            initialDate: value ?? now,
            firstDate: DateTime(now.year - 30),
            lastDate: now,
            helpText: 'Date de publication par la DEC',
          );
          if (d != null) onChanged(d);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              border: Border.all(color: kBorder),
              borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            Icon(Icons.event_rounded, size: 18, color: kTextMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value == null
                    ? 'Date de publication par la DEC (recommandée)'
                    : 'Publié le ${value!.day.toString().padLeft(2, '0')}/'
                        '${value!.month.toString().padLeft(2, '0')}/${value!.year}',
                style: TextStyle(
                    fontSize: 12.5,
                    color: value == null ? kTextMuted : kTextPrimary),
              ),
            ),
          ]),
        ),
      );
}

// ─── Rappel de la règle de calcul ───────────────────────────────────────────
class _FiguresNote extends StatelessWidget {
  const _FiguresNote();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: kNavy.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.calculate_rounded, size: 17, color: kNavy),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Chiffres officiels portés par ce document (facultatif). Le taux '
              'se calcule sur les PRÉSENTS, jamais sur les inscrits : les '
              'absents sortent du dénominateur. Si la publication ne donne '
              'qu\'un pourcentage, saisissez-le tel quel.',
              style: TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.4),
            ),
          ),
        ]),
      );
}
