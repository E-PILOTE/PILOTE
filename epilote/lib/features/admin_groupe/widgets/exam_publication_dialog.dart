import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/list_chrome.dart';
import '../providers/admin_schools_provider.dart';
import '../providers/exam_archives_provider.dart';
import 'exam_publication_fields.dart';

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
/// PANNEAU LATÉRAL, pas boîte modale.
///
/// Le dépôt est le geste quotidien de la DSIC : périmètre, document, date,
/// puis les chiffres relevés dessus. Une dizaine de champs à l'étroit dans une
/// boîte centrée obligeait à faire défiler un formulaire dont on ne voyait
/// jamais ni le début ni la fin. Un panneau pleine hauteur les tient tous,
/// laisse la page visible derrière — on garde sous les yeux ce qui est déjà
/// archivé — et se ferme d'un geste latéral.
///
/// Le chrome vient de `AdminSidePanel` : même en-tête, même pied que les autres
/// modales de l'espace. La version précédente empilait sa propre croix par-dessus
/// celle de l'en-tête — deux boutons « fermer » superposés.
///
/// Renvoie l'identifiant de la publication déposée — `null` si l'utilisateur
/// annule. Le panneau de relevé s'en sert pour rattacher immédiatement son
/// chiffre à la pièce qui vient d'être archivée : sans cette valeur de retour,
/// il faudrait ressortir du relevé, rouvrir, et retrouver la pièce à la main
/// dans une liste — ce qui rendait le sourcing si pénible qu'on l'omettait.
///
/// Les paramètres préremplissent le périmètre : quand le dépôt est déclenché
/// depuis un relevé qui porte déjà « Pool », on ne resaisit pas « Pool ».
Future<String?> showExamPublicationDialog(
  BuildContext context, {
  String? sessionId,
  PubScope? scope,
  String? department,
  String? schoolId,
}) =>
    showAdminSidePanel<String>(
      context,
      builder: (_) => _PublicationDialog(
        sessionId: sessionId,
        scope: scope,
        department: department,
        schoolId: schoolId,
      ),
    );

class _PublicationDialog extends ConsumerStatefulWidget {
  const _PublicationDialog({
    this.sessionId,
    this.scope,
    this.department,
    this.schoolId,
  });

  final String? sessionId;
  final PubScope? scope;
  final String? department;
  final String? schoolId;

  @override
  ConsumerState<_PublicationDialog> createState() => _State();
}

class _State extends ConsumerState<_PublicationDialog> {
  late String? _sessionId = widget.sessionId;
  late PubScope _scope = widget.scope ?? PubScope.national;
  late String? _department = widget.department;
  late String? _schoolId = widget.schoolId;

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
        Navigator.of(context).pop(pubId);
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

    return AdminSidePanel(
      icon: Icons.inventory_2_rounded,
      title: 'Déposer une publication de la DEC',
      subtitle: 'La pièce est archivée telle quelle ; ses chiffres sont '
          'relevés à la main, jamais extraits',
      footer: AdminModalActions(
        saving: _saving,
        submitLabel: 'Archiver',
        submitIcon: Icons.inventory_2_rounded,
        onSubmit: _save,
      ),
      body: Column(
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
          FileTile(file: _file, onPick: _pick),
          const SizedBox(height: 10),
          _field(_title, 'Intitulé du document'),
          const SizedBox(height: 10),
          DatePick(
            value: _publishedAt,
            onChanged: (d) => setState(() => _publishedAt = d),
          ),
          const SizedBox(height: 16),
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
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: kGreen),
              ),
            ),
          const SizedBox(height: 10),
          _field(_source, 'Source (facultatif)',
              hint: 'ex. Statistiques DEC, communiqué du 12/07'),
          if (_error != null) ...[
            const SizedBox(height: 14),
            AdminErrorBanner(message: _error!),
          ],
        ],
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

  /// Même libellé de section que les autres formulaires de l'espace admin.
  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: AdminFormSectionLabel(text.toUpperCase()),
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
