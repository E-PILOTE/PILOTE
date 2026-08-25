import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/transfers_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  SÉLECTEUR DE DESTINATION (cascade) : Groupe scolaire → École de destination.
//  Offline : propose les groupes/écoles du périmètre synchronisé (le propre
//  groupe du personnel + ses écoles, hors école courante). Option « hors
//  plateforme » → saisie libre du nom (pour un établissement non géré par
//  E-PILOTE). Réutilisé par la page Transferts ET la fiche élève.
// ════════════════════════════════════════════════════════════════════════════

const String kDestOther = '__other__';

/// Résultat du sélecteur : `schoolId` non nul = école plateforme ; sinon nom
/// libre (hors plateforme). `isValid` = prêt à enregistrer.
class TransferDestination {
  const TransferDestination({this.schoolId, required this.schoolName});
  final String? schoolId;
  final String schoolName;
  bool get isValid => schoolName.trim().isNotEmpty;
}

class TransferDestinationPicker extends ConsumerStatefulWidget {
  const TransferDestinationPicker({super.key, required this.onChanged});
  final ValueChanged<TransferDestination?> onChanged;

  @override
  ConsumerState<TransferDestinationPicker> createState() =>
      _TransferDestinationPickerState();
}

class _TransferDestinationPickerState
    extends ConsumerState<TransferDestinationPicker> {
  String? _groupId; // id du groupe, ou kDestOther
  String? _schoolId;
  final _otherName = TextEditingController();

  @override
  void dispose() {
    _otherName.dispose();
    super.dispose();
  }

  void _emit(List<DestGroup> groups) {
    if (_groupId == kDestOther) {
      final n = _otherName.text.trim();
      widget.onChanged(n.isEmpty ? null : TransferDestination(schoolName: n));
      return;
    }
    if (_groupId == null || _schoolId == null) {
      widget.onChanged(null);
      return;
    }
    final g = groups.where((g) => g.id == _groupId).toList();
    if (g.isEmpty) {
      widget.onChanged(null);
      return;
    }
    final s = g.first.schools.where((s) => s.id == _schoolId).toList();
    if (s.isEmpty) {
      widget.onChanged(null);
      return;
    }
    widget.onChanged(
        TransferDestination(schoolId: s.first.id, schoolName: s.first.name));
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(transferDestinationsProvider).valueOrNull ?? const [];
    final selectedGroup =
        _groupId != null && _groupId != kDestOther
            ? groups.where((g) => g.id == _groupId).firstOrNull
            : null;
    final schools = selectedGroup?.schools ?? const <DestSchool>[];

    // Entrées groupe : groupes synchronisés + « hors plateforme ».
    final groupItems = <(String, String)>[
      for (final g in groups) (g.id, g.name),
      (kDestOther, 'Autre établissement (hors plateforme)'),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _Lbl('Groupe scolaire'),
      _Dropdown(
        hint: 'Sélectionner un groupe',
        icon: Icons.domain_rounded,
        value: _groupId,
        items: groupItems,
        onChanged: (v) {
          setState(() {
            _groupId = v;
            _schoolId = null;
          });
          _emit(groups);
        },
      ),
      const SizedBox(height: 14),
      if (_groupId == kDestOther) ...[
        const _Lbl('Nom de l\'établissement'),
        TextField(
          controller: _otherName,
          style: const TextStyle(fontSize: 13.5),
          onChanged: (_) => _emit(groups),
          decoration: adminFilledInput('Nom de l\'école d\'accueil',
              icon: Icons.school_outlined),
        ),
      ] else ...[
        const _Lbl('École de destination'),
        _Dropdown(
          hint: _groupId == null
              ? 'Choisissez d\'abord un groupe'
              : (schools.isEmpty
                  ? 'Aucune autre école dans ce groupe'
                  : 'Sélectionner une école'),
          icon: Icons.school_outlined,
          value: _schoolId,
          enabled: _groupId != null && schools.isNotEmpty,
          items: [for (final s in schools) (s.id, s.name)],
          onChanged: (v) {
            setState(() => _schoolId = v);
            _emit(groups);
          },
        ),
      ],
    ]);
  }
}

class _Lbl extends StatelessWidget {
  const _Lbl(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Text(text,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: kTextPrimary)),
      );
}

// Dropdown compact (texte sur une ligne, ellipsis) — style cohérent app.
class _Dropdown extends StatelessWidget {
  const _Dropdown({
    required this.hint,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });
  final String hint;
  final IconData icon;
  final String? value;
  final List<(String, String)> items;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      style: TextStyle(fontSize: 13, color: kTextPrimary),
      icon: Icon(Icons.expand_more_rounded, size: 18, color: kTextMuted),
      decoration: adminFilledInput(hint, icon: icon),
      selectedItemBuilder: (context) => [
        for (final e in items)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(e.$2,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: kTextPrimary)),
          ),
      ],
      items: [
        for (final e in items)
          DropdownMenuItem(
              value: e.$1,
              child:
                  Text(e.$2, maxLines: 1, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: enabled ? onChanged : null,
    );
  }
}
