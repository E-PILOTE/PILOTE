import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'admin_tokens.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CHAMP DATE — un seul, partagé.
//
//  Il existait en deux exemplaires identiques (`admin_year_dialogs.dart` et
//  `admin_year_calendar_dialog.dart`), ce qui garantissait qu'une correction
//  n'en toucherait qu'un.
//
//  [first] / [last] bornent le sélecteur : quand on saisit un trimestre, rien
//  ne justifie de pouvoir pointer une date hors de l'année scolaire. Interdire
//  la saisie fautive vaut mieux que la refuser après coup.
// ════════════════════════════════════════════════════════════════════════════
class AdminDateField extends StatelessWidget {
  const AdminDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onPick,
    this.first,
    this.last,
    this.helper,
    this.enabled = true,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPick;
  final DateTime? first;
  final DateTime? last;
  final String? helper;
  final bool enabled;

  static final _fmt = DateFormat('d MMM yyyy', 'fr_FR');

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final borneMin = first ?? DateTime(now.year - 2);
    final borneMax = last ?? DateTime(now.year + 4);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: enabled ? kNavy : kTextMuted)),
      const SizedBox(height: 6),
      InkWell(
        onTap: !enabled
            ? null
            : () async {
                // `initialDate` doit tomber dans [first, last], sinon le
                // sélecteur Material lève une assertion.
                var initial = value ?? now;
                if (initial.isBefore(borneMin)) initial = borneMin;
                if (initial.isAfter(borneMax)) initial = borneMax;

                final picked = await showDatePicker(
                  context: context,
                  initialDate: initial,
                  firstDate: borneMin,
                  lastDate: borneMax,
                  locale: const Locale('fr', 'FR'),
                );
                if (picked != null) onPick(picked);
              },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            color: enabled ? kSurface : kSurface.withValues(alpha: .5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kBorder),
          ),
          child: Row(children: [
            Icon(Icons.calendar_today_rounded, size: 15, color: kTextMuted),
            const SizedBox(width: 8),
            Text(value != null ? _fmt.format(value!) : 'Choisir…',
                style: TextStyle(
                    fontSize: 13,
                    color: value != null && enabled ? kNavy : kTextMuted)),
          ]),
        ),
      ),
      if (helper != null) ...[
        const SizedBox(height: 5),
        Text(helper!, style: TextStyle(fontSize: 10.5, color: kTextMuted)),
      ],
    ]);
  }
}
