import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';

// ════════════════════════════════════════════════════════════════════════════
//  KIT DE FORMULAIRE « DOSSIER ÉLÈVE » — briques partagées par les 3 modals :
//  Nouvelle inscription · Modification · Détail. Une SEULE source de vérité
//  pour l'habillage (cadre, en-tête, indicateur d'étapes, barre de navigation)
//  et les champs (texte, liste, case, date) + la carte récap. → cohérence
//  parfaite, zéro duplication.
// ════════════════════════════════════════════════════════════════════════════

const _kIconGradStart = Color(0xFF1A2F5A);
const _kPanelBg = Color(0xFFF8FAFC);

// ─── Cadre du modal (carte blanche centrée, ombre, radius 18) ─────────────────
class InscriptionModalFrame extends StatelessWidget {
  const InscriptionModalFrame({
    super.key,
    required this.child,
    this.width = 720,
    this.maxHeight = 780,
  });
  final Widget child;
  final double width, maxHeight;

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final w = sw < width + 40 ? sw - 32 : width;
    return Center(
      child: Container(
        width: w,
        constraints: BoxConstraints(maxHeight: maxHeight),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 40,
                offset: const Offset(0, 10)),
          ],
        ),
        // Material requis pour les InkWell internes (en-tête, cases, menus)
        // quand le cadre est affiché sans wrapper Dialog (détail / édition).
        child: Material(type: MaterialType.transparency, child: child),
      ),
    );
  }
}

// ─── En-tête (icône en dégradé + titre + sous-titre + bouton fermer carré) ────
class InscriptionHeader extends StatelessWidget {
  const InscriptionHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onClose,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 16, 14, 14),
      decoration: BoxDecoration(
        color: kCardBg,
        border: Border(bottom: BorderSide(color: kBorder)),
      ),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_kIconGradStart, kNavy],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                  color: kNavy.withValues(alpha: 0.30),
                  blurRadius: 8,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 19),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary)),
              const SizedBox(height: 2),
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: kTextMuted)),
            ],
          ),
        ),
        InkWell(
          onTap: onClose ?? () => Navigator.of(context).pop(),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4F8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kBorder),
            ),
            child: Icon(Icons.close_rounded, size: 16, color: kTextMuted),
          ),
        ),
      ]),
    );
  }
}

// ─── Indicateur d'étapes (segments verts) ────────────────────────────────────
class InscriptionStepIndicator extends StatelessWidget {
  const InscriptionStepIndicator(
      {super.key, required this.current, required this.steps});
  final int current;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kPanelBg,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: List.generate(steps.length, (i) {
          final active = i == current;
          final done = i < current;
          final accent = done || active ? kGreen : kBorder;
          final dotColor = active ? kNavy : (done ? kGreen : Colors.white);
          final txtColor = active ? kNavy : (done ? kGreen : kTextMuted);
          return Expanded(
            child: Row(children: [
              if (i > 0)
                Expanded(
                    child:
                        Container(height: 2, color: done ? kGreen : kBorder)),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: accent, width: 1.5),
                  ),
                  child: Center(
                    child: done
                        ? const Icon(Icons.check_rounded,
                            size: 15, color: Colors.white)
                        : Text('${i + 1}',
                            style: TextStyle(
                                color: active ? Colors.white : kTextMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 4),
                Text(steps[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: txtColor,
                        fontSize: 10.5,
                        fontWeight:
                            active ? FontWeight.w800 : FontWeight.w500)),
              ]),
              if (i < steps.length - 1)
                Expanded(
                    child: Container(
                        height: 2, color: i < current ? kGreen : kBorder)),
            ]),
          );
        }),
      ),
    );
  }
}

// ─── Barre de navigation (Retour/Annuler · Suivant/Action finale) ────────────
class InscriptionNavBar extends StatelessWidget {
  InscriptionNavBar({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.submitting,
    required this.onBack,
    required this.onNext,
    required this.onSubmit,
    this.lastLabel = 'Enregistrer',
    this.lastIcon = Icons.check_rounded,
    Color? lastColor,
  }) : lastColor = lastColor ?? kGreen;
  final int currentStep, totalSteps;
  final bool submitting;
  final VoidCallback onBack, onNext, onSubmit;
  final String lastLabel;
  final IconData lastIcon;
  final Color lastColor;

  @override
  Widget build(BuildContext context) {
    final isLast = currentStep == totalSteps - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
      decoration: BoxDecoration(
        color: kCardBg,
        border: Border(top: BorderSide(color: kBorder)),
      ),
      child: Row(children: [
        if (currentStep > 0)
          TextButton.icon(
            onPressed: submitting ? null : onBack,
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: const Text('Retour'),
            style: TextButton.styleFrom(foregroundColor: kTextMuted),
          )
        else
          TextButton.icon(
            onPressed: submitting ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('Annuler'),
            style: TextButton.styleFrom(foregroundColor: kTextMuted),
          ),
        const Spacer(),
        AdminPrimaryButton(
          label: isLast ? lastLabel : 'Suivant',
          icon: isLast ? lastIcon : Icons.arrow_forward_rounded,
          color: isLast ? lastColor : kNavy,
          saving: submitting,
          onTap: submitting ? () {} : (isLast ? onSubmit : onNext),
        ),
      ]),
    );
  }
}

// ─── Libellé de section (barre navy + majuscules) ────────────────────────────
class FormSectionTitle extends StatelessWidget {
  const FormSectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Container(
            width: 3,
            height: 13,
            decoration: BoxDecoration(
                color: kNavy, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 8),
          Text(text.toUpperCase(),
              style: TextStyle(
                  color: kNavy,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1)),
        ]),
      );
}

class FormFieldLabel extends StatelessWidget {
  const FormFieldLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 5, left: 2),
        child: Text(text,
            style: TextStyle(
                fontSize: 11.5,
                color: kTextMuted,
                fontWeight: FontWeight.w600)),
      );
}

// ─── Champ texte (label au-dessus + input plein) ─────────────────────────────
class FormTextField extends StatelessWidget {
  const FormTextField({
    super.key,
    required this.controller,
    required this.label,
    this.onChanged,
    this.keyboardType,
    this.maxLines = 1,
    this.icon,
  });
  final TextEditingController controller;
  final String label;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final int maxLines;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FormFieldLabel(label),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          onChanged: onChanged,
          style: TextStyle(fontSize: 13.5, color: kTextPrimary),
          decoration: adminFilledInput('', icon: icon),
        ),
      ]),
    );
  }
}

// ─── Liste déroulante (label au-dessus) ──────────────────────────────────────
class FormDropdown<T> extends StatelessWidget {
  const FormDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String label;
  final T? value;
  final Map<T, String> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FormFieldLabel(label),
        DropdownButtonFormField<T>(
          initialValue: items.containsKey(value) ? value : null,
          isExpanded: true,
          style: TextStyle(fontSize: 13.5, color: kTextPrimary),
          icon: Icon(Icons.expand_more_rounded,
              size: 18, color: kTextMuted),
          decoration: adminFilledInput('Sélectionner'),
          items: items.entries
              .map((e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: onChanged,
        ),
      ]),
    );
  }
}

// ─── Case à cocher (tuile bordée) ────────────────────────────────────────────
class FormCheckTile extends StatelessWidget {
  const FormCheckTile({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: value ? kGreen.withValues(alpha: 0.06) : _kPanelBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: value ? kGreen.withValues(alpha: 0.4) : kBorder),
          ),
          child: Row(children: [
            Icon(
                value
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: 20,
                color: value ? kGreen : kTextMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style:
                      TextStyle(fontSize: 13, color: kTextPrimary)),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── Champ date (input plein cliquable) ──────────────────────────────────────
class FormDateField extends StatelessWidget {
  const FormDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final String? value; // ISO yyyy-MM-dd
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FormFieldLabel(label),
        InkWell(
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: value != null
                  ? DateTime.tryParse(value!) ?? DateTime(now.year - 12)
                  : DateTime(now.year - 12),
              firstDate: DateTime(now.year - 40),
              lastDate: now,
            );
            if (picked != null) {
              onChanged(picked.toIso8601String().substring(0, 10));
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: InputDecorator(
            decoration: adminFilledInput('Sélectionner',
                icon: Icons.calendar_today_rounded),
            child: Text(value ?? 'Sélectionner',
                style: TextStyle(
                    color: value != null ? kTextPrimary : kTextMuted,
                    fontSize: 13.5)),
          ),
        ),
      ]),
    );
  }
}

// ─── Carte récapitulative (titre+icône navy, lignes label/valeur) ────────────
class ResumeCard extends StatelessWidget {
  const ResumeCard({
    super.key,
    required this.title,
    required this.icon,
    required this.rows,
    this.trailing,
  });
  final String title;
  final IconData icon;
  final List<(String, String)> rows;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 16, color: kNavy),
            const SizedBox(width: 8),
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: kNavy,
                    fontSize: 14)),
            if (trailing != null) ...[const Spacer(), trailing!],
          ]),
          Divider(height: 14, color: kBorder),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 150,
                        child: Text(r.$1,
                            style: TextStyle(
                                color: kTextMuted, fontSize: 13)),
                      ),
                      Expanded(
                        child: Text(r.$2.isEmpty ? '—' : r.$2,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500)),
                      ),
                    ]),
              )),
        ]),
      ),
    );
  }
}

// ─── Cascade Cycle → Niveau → Classe (partagée inscription + modification) ────
/// Une entrée = une classe inscriptible, déjà résolue (cycle/niveau) côté data.
class ClassPickerEntry {
  const ClassPickerEntry({
    required this.id,
    required this.name,
    required this.cycleCode,
    required this.cycleLabel,
    required this.cycleOrder,
    required this.levelCode,
    required this.levelOrder,
    this.capacity,
    this.count,
  });
  final String id, name, cycleCode, cycleLabel, levelCode;
  final int cycleOrder, levelOrder;
  final int? capacity, count;

  String get levelLabel => levelCode.isEmpty ? 'Autres' : levelCode;
  String get classLabel =>
      capacity != null ? '$name  (${count ?? 0}/$capacity)' : name;
}

/// Sélecteur en cascade Cycle ▸ Niveau ▸ Classe. Tout est dérivé des classes
/// existantes (offline). Le cycle unique est présélectionné. Émet l'id de la
/// classe choisie (ou `null` si la sélection devient incohérente).
class CycleLevelClassPicker extends StatefulWidget {
  const CycleLevelClassPicker({
    super.key,
    required this.entries,
    required this.classId,
    required this.onChanged,
  });
  final List<ClassPickerEntry> entries;
  final String? classId;
  final ValueChanged<String?> onChanged;

  @override
  State<CycleLevelClassPicker> createState() => _CycleLevelClassPickerState();
}

class _CycleLevelClassPickerState extends State<CycleLevelClassPicker> {
  String? _cycleCode;
  String? _levelCode;

  ClassPickerEntry? get _selected {
    final id = widget.classId;
    if (id == null) return null;
    final m = widget.entries.where((e) => e.id == id);
    return m.isEmpty ? null : m.first;
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;
    if (entries.isEmpty) {
      return Text('Aucune classe disponible.',
          style: TextStyle(color: kTextMuted, fontSize: 13));
    }

    // Cycles (triés par ordre pédagogique).
    final cycleOrder = <String, ({String label, int order})>{};
    for (final e in entries) {
      cycleOrder[e.cycleCode] = (label: e.cycleLabel, order: e.cycleOrder);
    }
    final cycleCodes = cycleOrder.keys.toList()
      ..sort((a, b) => cycleOrder[a]!.order.compareTo(cycleOrder[b]!.order));
    final cycleItems = {for (final c in cycleCodes) c: cycleOrder[c]!.label};

    // Cycle effectif : sélection explicite, sinon celui de la classe choisie,
    // sinon l'unique cycle de l'école (présélection).
    final sel = _selected;
    final effCycle = (_cycleCode != null && cycleOrder.containsKey(_cycleCode))
        ? _cycleCode
        : sel?.cycleCode ?? (cycleCodes.length == 1 ? cycleCodes.first : null);

    // Niveaux du cycle.
    final levelOrder = <String, int>{};
    for (final e in entries.where((e) => e.cycleCode == effCycle)) {
      levelOrder[e.levelCode] = e.levelOrder;
    }
    final levelCodes = levelOrder.keys.toList()
      ..sort((a, b) {
        final d = levelOrder[a]!.compareTo(levelOrder[b]!);
        return d != 0 ? d : a.compareTo(b);
      });
    final levelItems = {
      for (final c in levelCodes) c: c.isEmpty ? 'Autres' : c,
    };

    final effLevel = (_levelCode != null && levelOrder.containsKey(_levelCode))
        ? _levelCode
        : sel?.levelCode;

    final inLevel = entries
        .where((e) => e.cycleCode == effCycle && e.levelCode == effLevel)
        .toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      FormDropdown<String>(
        label: 'Cycle *',
        value: effCycle,
        items: cycleItems,
        onChanged: (v) {
          setState(() {
            _cycleCode = v;
            _levelCode = null;
            if (sel != null && sel.cycleCode != v) widget.onChanged(null);
          });
        },
      ),
      FormDropdown<String>(
        key: ValueKey('level_$effCycle'),
        label: 'Niveau *',
        value: effLevel,
        items: levelItems,
        onChanged: (v) {
          setState(() {
            _levelCode = v;
            _cycleCode = effCycle;
            if (sel != null && sel.levelCode != v) widget.onChanged(null);
          });
        },
      ),
      FormDropdown<String>(
        key: ValueKey('class_${effCycle}_$effLevel'),
        label: 'Classe *',
        value: widget.classId,
        items: {for (final e in inLevel) e.id: e.classLabel},
        onChanged: (v) {
          final match = v == null
              ? const <ClassPickerEntry>[]
              : entries.where((e) => e.id == v);
          final picked = match.isEmpty ? null : match.first;
          setState(() {
            if (picked != null) {
              _cycleCode = picked.cycleCode;
              _levelCode = picked.levelCode;
            }
          });
          widget.onChanged(v);
        },
      ),
      if (effLevel != null && inLevel.isEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text('Aucune classe pour ce niveau.',
              style: TextStyle(color: kTextMuted, fontSize: 12.5)),
        ),
    ]);
  }
}
