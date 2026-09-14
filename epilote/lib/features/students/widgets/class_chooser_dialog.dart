import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/message_erreur.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../data/models/class_model.dart';
import '../../classes/providers/class_provider.dart';
import '../providers/inscriptions_data_provider.dart';
import 'inscription_form_kit.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CHOISIR UNE CLASSE — cascade cycle → niveau → classe
//
//  Extrait de `eleves_parts.dart` pour la même raison que le dialogue de
//  sortie : il était `part of` l'écran de la liste, donc invisible depuis la
//  fiche de l'élève. Or « changer de classe » est exactement le geste qu'on
//  fait EN CONSULTANT un dossier — l'agent voit le parcours, constate
//  l'erreur d'affectation, et doit pouvoir la corriger sans repasser par la
//  liste.
// ════════════════════════════════════════════════════════════════════════════

/// Ouvre le sélecteur et renvoie l'id de la classe choisie. `null` = abandonné.
Future<String?> choisirClasseEleve(
  BuildContext context, {
  required String titre,
  required String sousTitre,
  String slug = 'eleves',
}) =>
    showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _ClassChooser(title: titre, subtitle: sousTitre, slug: slug),
    );

class _ClassChooser extends ConsumerStatefulWidget {
  const _ClassChooser({
    required this.title,
    required this.subtitle,
    required this.slug,
  });
  final String title, subtitle, slug;
  @override
  ConsumerState<_ClassChooser> createState() => _ClassChooserState();
}

class _ClassChooserState extends ConsumerState<_ClassChooser> {
  String? _classId;

  ClassPickerEntry _entry(ClassModel c) {
    final cyc = inscriptionCycleFromCode(c.cycleCode, c.name);
    return ClassPickerEntry(
      id: c.id,
      name: c.name,
      cycleCode: cyc.code,
      cycleLabel: cyc.label,
      cycleOrder: cyc.order,
      levelCode: c.levelCode ?? '',
      levelOrder: c.levelOrder ?? 999,
      capacity: c.capacity,
      count: c.studentCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(classesForModuleProvider(widget.slug));
    return AdminFormDialog(
      icon: Icons.swap_horiz_rounded,
      title: widget.title,
      subtitle: widget.subtitle,
      width: 520,
      submitLabel: 'Valider',
      submitIcon: Icons.check_rounded,
      // ⚠️ `onSubmit: () { if (_classId == null) return; }` ne faisait RIEN :
      // le bouton restait actif, l'agent cliquait, la fenêtre ne bougeait pas
      // et rien n'expliquait pourquoi. Un bouton désactivé dit la même chose,
      // mais avant le clic.
      onSubmit: _classId == null ? null : () => Navigator.pop(context, _classId),
      body: classesAsync.when(
        loading: () => const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Text(messageErreur(e), style: TextStyle(color: kRed)),
        data: (classes) {
          if (classes.isEmpty) {
            return Text('Aucune classe disponible.',
                style: TextStyle(color: kTextMuted, fontSize: 13));
          }
          return CycleLevelClassPicker(
            entries: [for (final c in classes) _entry(c)],
            classId: _classId,
            onChanged: (v) => setState(() => _classId = v),
          );
        },
      ),
    );
  }
}
