import 'package:flutter/material.dart';

import '../../providers/subscriptions_provider.dart';
import 'subs_style.dart';

// ─── Champs partagés du formulaire ───────────────────────────────────
//  ⚠️ `SubFormSectionTitle` (gris, petit) et `SubDetailSectionTitle` (marine,
//  gras) sont DEUX titres différents. Ils s'appelaient `_SectionTitle` et
//  `_SubSectionTitle` : un caractère d'écart pour deux styles opposés.

class SubFormSectionTitle extends StatelessWidget {
  const SubFormSectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
          color: kSubMuted, letterSpacing: 0.5));
}

class SubFormField extends StatelessWidget {
  const SubFormField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.validator,
  });
  final TextEditingController controller;
  final String                label;
  final IconData              icon;
  final TextInputType?        keyboardType;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller:   controller,
    keyboardType: keyboardType,
    style: TextStyle(fontSize: 13, color: kSubText),
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 16, color: kSubMuted),
      filled: true,
      fillColor: kSubSurface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: kSubBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: kSubNavy, width: 1.5),
      ),
      contentPadding: const EdgeInsets.all(12),
    ),
    validator: validator,
  );
}

class SubFormDropdown<T> extends StatelessWidget {
  const SubFormDropdown({
    super.key,
    required this.value,
    required this.icon,
    required this.items,
    required this.onChanged,
    this.iconColor,
  });
  final T value;
  final IconData icon;
  final Color? iconColor;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: kSubSurface,
      border: Border.all(color: kSubBorder),
      borderRadius: BorderRadius.circular(8),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        icon: Icon(Icons.expand_more_rounded, size: 18, color: kSubMuted),
        style: TextStyle(color: kSubText, fontSize: 13),
        items: items.entries.map((e) => DropdownMenuItem<T>(
          value: e.key,
          child: Row(children: [
            Icon(icon, size: 14, color: iconColor ?? kSubNavy),
            const SizedBox(width: 8),
            Text(e.value),
          ]),
        )).toList(),
        onChanged: (v) { if (v != null) onChanged(v); },
      ),
    ),
  );
}

class SubPlanDropdown extends StatelessWidget {
  const SubPlanDropdown({
    super.key,
    required this.plans,
    required this.value,
    required this.onChanged,
  });
  final List<PlanOption> plans;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: kSubSurface,
      border: Border.all(color: kSubBorder),
      borderRadius: BorderRadius.circular(8),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String?>(
        value: value,
        isExpanded: true,
        icon: Icon(Icons.expand_more_rounded, size: 18, color: kSubMuted),
        style: TextStyle(color: kSubText, fontSize: 13),
        hint: Text('Sélectionner un plan', style: TextStyle(color: kSubMuted, fontSize: 13)),
        items: [
          DropdownMenuItem<String?>(
            value: null,
            child: Row(children: [
              Icon(Icons.block_rounded, size: 14, color: kSubMuted),
              const SizedBox(width: 8),
              const Text('Aucun plan'),
            ]),
          ),
          ...plans.map((p) => DropdownMenuItem<String?>(
            value: p.id,
            child: Row(children: [
              const Icon(Icons.workspace_premium_rounded, size: 14, color: kSubPurple),
              const SizedBox(width: 8),
              Flexible(child: Text(
                '${p.name} · ${p.priceLabel}',
                overflow: TextOverflow.ellipsis,
              )),
            ]),
          )),
        ],
        onChanged: onChanged,
      ),
    ),
  );
}

class SubDateField extends StatelessWidget {
  const SubDateField({super.key, required this.label, required this.value, required this.onTap});
  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: kSubSurface,
          border: Border.all(color: kSubBorder),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today_rounded, size: 15, color: kSubMuted),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: kSubMuted, fontSize: 10)),
            Text(subDate(value), style: TextStyle(
                color: kSubText, fontSize: 12.5, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ])),
        ]),
      ),
    ),
  );
}
