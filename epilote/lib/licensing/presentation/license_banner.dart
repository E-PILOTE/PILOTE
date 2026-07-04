import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/license_phase.dart';
import 'license_providers.dart';

// Ambre (grâce) / rouge (lecture seule).
const _kWarnBg = Color(0xFFFFFBEB);
const _kWarnBorder = Color(0xFFFDE68A);
const _kWarnFg = Color(0xFF92400E);
const _kWarnIcon = Color(0xFFD97706);
const _kStopBg = Color(0xFFFEF2F2);
const _kStopBorder = Color(0xFFFECACA);
const _kStopFg = Color(0xFF991B1B);
const _kStopIcon = Color(0xFFDC2626);

/// Bandeau licence côté PERSONNEL (offline). Rend visible la phase dérivée de la
/// licence (grâce / lecture seule). À la différence du bandeau admin_groupe, le
/// personnel ne peut pas renouveler → on l'oriente vers son administration.
///
/// Invisible quand : pas de licence (dormant), en chargement, ou phase active.
/// Ne gate JAMAIS la synchro (C4) : purement informatif + signal de lecture seule.
class LicenseBanner extends ConsumerWidget {
  const LicenseBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ent = ref.watch(entitlementProvider).valueOrNull;
    if (ent == null || !ent.isEnforced) return const SizedBox.shrink();

    final phase = ent.phaseAt(DateTime.now().toUtc());
    if (phase == LicensePhase.active) return const SizedBox.shrink();

    final isStop = phase == LicensePhase.readOnly;
    final (bg, border, fg, icon, message) = isStop
        ? (
            _kStopBg,
            _kStopBorder,
            _kStopFg,
            _kStopIcon,
            "Abonnement de l'établissement expiré — application en lecture seule. "
                'Rapprochez-vous de votre administration.',
          )
        : (
            _kWarnBg,
            _kWarnBorder,
            _kWarnFg,
            _kWarnIcon,
            "Abonnement de l'établissement échu — régularisation requise auprès "
                'de votre administration.',
          );

    return Material(
      color: bg,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: border))),
        child: Row(
          children: [
            Icon(isStop ? Icons.lock_clock_rounded : Icons.warning_amber_rounded,
                size: 18, color: icon),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper d'expertise pour gater une mutation staff quand la licence est en
/// lecture seule. Fail-soft : au doute (pas de licence, chargement) → autorise.
/// À appeler en tête d'un handler de mutation côté personnel.
bool ensureLicenseWritable(WidgetRef ref, BuildContext context) {
  final ent = ref.read(entitlementProvider).valueOrNull;
  if (ent != null && ent.isEnforced && !ent.canWriteAt(DateTime.now().toUtc())) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      backgroundColor: _kStopIcon,
      content: Text('Abonnement expiré — application en lecture seule. '
          'Modification impossible pour le moment.'),
    ));
    return false;
  }
  return true;
}
