import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/subscription_days.dart';
import '../../../core/widgets/admin_ui.dart';

/// Bloc « Cycle d'abonnement » de l'écran Paramètres super_admin.
///
/// ── Pourquoi ce regroupement ───────────────────────────────────────────────
/// Les quatre réglages d'un même cycle de vie vivaient dans deux onglets
/// différents : la fenêtre d'alerte et le délai de grâce sous « Facturation »,
/// les seuils de rappel sous « Notifications ». On réglait donc l'un sans voir
/// l'autre — et c'est exactement comme ça qu'on obtient une cloche qui sonne à
/// J-30 pendant qu'aucun bandeau ne s'allume avant J-7.
///
/// Ici les quatre curseurs sont côte à côte, sous une frise qui montre en une
/// ligne ce que l'admin de groupe va réellement vivre, et sous un contrôle de
/// cohérence qui prévient quand l'échelle se troue.
class SubscriptionCycleSection extends StatefulWidget {
  const SubscriptionCycleSection({
    super.key,
    required this.alertCtrl,
    required this.reminderCtrl,
    required this.graceCtrl,
    required this.trialCtrl,
  });

  /// Jours AVANT échéance où le bandeau s'allume (`subscription_alert_days`).
  final TextEditingController alertCtrl;

  /// Seuils de rappel CSV (`notif_reminder_days`).
  final TextEditingController reminderCtrl;

  /// Jours APRÈS échéance avant la lecture seule (`grace_days`).
  final TextEditingController graceCtrl;

  /// Durée d'essai des nouveaux groupes (`trial_days`).
  final TextEditingController trialCtrl;

  @override
  State<SubscriptionCycleSection> createState() =>
      _SubscriptionCycleSectionState();
}

class _SubscriptionCycleSectionState extends State<SubscriptionCycleSection> {
  @override
  void initState() {
    super.initState();
    // La frise et l'avertissement de cohérence se recalculent à la frappe :
    // le réglage se juge en le voyant, pas après avoir enregistré.
    widget.alertCtrl.addListener(_refresh);
    widget.reminderCtrl.addListener(_refresh);
    widget.graceCtrl.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.alertCtrl.removeListener(_refresh);
    widget.reminderCtrl.removeListener(_refresh);
    widget.graceCtrl.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  int get _alertDays =>
      int.tryParse(widget.alertCtrl.text.trim()) ?? kSubscriptionAlertDays;
  int get _graceDays => int.tryParse(widget.graceCtrl.text.trim()) ?? 15;
  List<int> get _reminders => parseReminderDays(widget.reminderCtrl.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Text(
              "Cycle d'abonnement",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: kNavy,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              'Ce que le groupe voit avant, pendant et après son échéance. '
              'Les quatre réglages se lisent ensemble.',
              style: TextStyle(fontSize: 11, color: kTextMuted),
            ),
          ),
          Divider(
              height: 16,
              thickness: 1,
              indent: 16,
              endIndent: 16,
              color: kBorder),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _NumField(
                        label: '🔔 Rappels (cloche)',
                        ctrl: widget.reminderCtrl,
                        csv: true,
                        hint: '30, 15, 7, 1, 0',
                        suffix: 'jours avant, séparés par des virgules',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _NumField(
                        label: '🟠 Alerte (bandeau)',
                        ctrl: widget.alertCtrl,
                        hint: '$kSubscriptionAlertDays',
                        suffix: "jours avant l'échéance",
                      ),
                    ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _NumField(
                        label: '🔴 Délai de grâce',
                        ctrl: widget.graceCtrl,
                        hint: '15',
                        suffix: "jours après l'échéance",
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _NumField(
                        label: "Durée d'essai",
                        ctrl: widget.trialCtrl,
                        hint: '3',
                        suffix: 'jours (nouveaux groupes)',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _Frise(
                  reminders: _reminders,
                  alertDays: _alertDays,
                  graceDays: _graceDays,
                ),
                if (!remindersCoverAlertWindow(
                  reminderDays: _reminders,
                  alertDays: _alertDays,
                ))
                  const _Coherence(
                    'Aucun rappel ne tombe dans la fenêtre du bandeau : la '
                    "cloche se taira pendant les derniers jours, ceux où l'on "
                    'décide de payer. Ajoutez un seuil ≤ à la fenêtre d’alerte '
                    '(par exemple 1 et 0).',
                  )
                else if (!_reminders.contains(0))
                  const _Coherence(
                    'Aucun rappel le jour même : ajoutez 0 à la liste pour que '
                    "l'admin soit prévenu le jour de l'échéance.",
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Frise de l'échelle d'escalade, reconstruite à partir des valeurs saisies.
/// Elle rend visible ce qu'aucun champ isolé ne montre : l'ORDRE des signaux.
class _Frise extends StatelessWidget {
  const _Frise({
    required this.reminders,
    required this.alertDays,
    required this.graceDays,
  });

  final List<int> reminders;
  final int alertDays;
  final int graceDays;

  @override
  Widget build(BuildContext context) {
    // Ordre chronologique vécu : les rappels lointains d'abord, puis le
    // bandeau, l'échéance, et enfin la lecture seule.
    final steps = <(String, Color)>[
      for (final d in reminders.where((d) => d > alertDays))
        ('J-$d 🔔', kNavy),
      ('J-$alertDays 🟠 bandeau', const Color(0xFFD97706)),
      for (final d in reminders.where((d) => d <= alertDays && d > 0))
        ('J-$d 🔔', kNavy),
      // Le jour de l'échéance porte l'éventuel dernier rappel : une seule
      // pastille, sinon la frise affiche deux fois « J0 ».
      (reminders.contains(0) ? 'J0 🔔 échéance' : 'J0 échéance', kTextMuted),
      ('J+$graceDays 🔴 lecture seule', kRed),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final (label, color) in steps)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color.withValues(alpha: 0.35)),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Avertissement de cohérence entre deux réglages qui doivent s'accorder.
class _Coherence extends StatelessWidget {
  const _Coherence(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: kAccent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kAccent.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 16, color: Color(0xFFD97706)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: Color(0xFF92400E),
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}

/// Champ numérique (ou liste CSV de nombres) — même habillage que le reste de
/// l'écran Paramètres.
class _NumField extends StatelessWidget {
  const _NumField({
    required this.label,
    required this.ctrl,
    this.hint = '',
    this.suffix,
    this.csv = false,
  });

  final String label;
  final TextEditingController ctrl;
  final String hint;
  final String? suffix;
  final bool csv;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary)),
            const SizedBox(height: 4),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                if (csv)
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9, ]'))
                else
                  FilteringTextInputFormatter.digitsOnly,
              ],
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: hint,
                suffixText: suffix,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: kBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: kBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: kNavy, width: 1.5),
                ),
              ),
            ),
          ],
        ),
      );
}
