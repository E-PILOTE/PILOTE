import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/widgets/admin_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/license_phase.dart';
import 'license_providers.dart';

// Ambre (grâce) / rouge (lecture seule).
Color get _kWarnBg => kAccent.withValues(alpha: 0.12);
Color get _kWarnBorder => kAccent.withValues(alpha: 0.45);
const _kWarnFg = Color(0xFF92400E);
const _kWarnIcon = Color(0xFFD97706);
Color get _kStopBg => kRed.withValues(alpha: 0.12);
const _kStopBorder = Color(0xFFFECACA);
const _kStopFg = Color(0xFF991B1B);
Color get _kStopIcon => kRed;

/// Bandeau licence côté PERSONNEL (offline). Rend visible la phase dérivée de la
/// licence (grâce / lecture seule). À la différence du bandeau admin_groupe, le
/// personnel ne peut pas renouveler → on l'oriente vers son administration.
///
/// Invisible quand : pas de licence (dormant), en chargement, ou phase active.
/// Ne gate JAMAIS la synchro (C4) : purement informatif + signal de lecture seule.
///
/// **Ré-évaluation (Vague 3 « tick 1×/jour + premier plan »)** : la phase se
/// dérive de `now`, mais l'`Entitlement` en mémoire ne change pas sur une session
/// longue **hors ligne** (cœur de cible rural, appareil laissé allumé). Ce widget
/// se re-rend donc à chaque retour au premier plan (`resumed`) ET sur un timer
/// périodique, pour que la bascule grâce→lecture-seule s'affiche sans redémarrage.
class LicenseBanner extends ConsumerStatefulWidget {
  const LicenseBanner({super.key});

  @override
  ConsumerState<LicenseBanner> createState() => _LicenseBannerState();
}

class _LicenseBannerState extends ConsumerState<LicenseBanner>
    with WidgetsBindingObserver {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Grain 6 h : garantit la bascule au passage d'un jour dans les 6 h même
    // sans interaction ; le retour au premier plan rafraîchit immédiatement.
    _tick = Timer.periodic(const Duration(hours: 6), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ent = ref.watch(entitlementProvider).valueOrNull;
    if (ent == null || !ent.isEnforced) return const SizedBox.shrink();

    final now = DateTime.now().toUtc();
    final phase = ent.phaseAt(now);

    // Priorité d'affichage : hardLock > readOnly > grace > rien. Le compte à
    // rebours d'avant-échéance appartient à `SchoolSubscriptionBanner`.
    final (Color bg, Color border, Color fg, IconData icon, Color iconColor, String message) info;
    switch (phase) {
      case LicensePhase.hardLock:
        info = (
          _kStopBg, _kStopBorder, _kStopFg, Icons.lock_clock_rounded, _kStopIcon,
          "Accès aux modules suspendu — abonnement de l'établissement à renouveler "
              'auprès de votre administration.',
        );
      case LicensePhase.readOnly:
        info = (
          _kStopBg, _kStopBorder, _kStopFg, Icons.lock_clock_rounded, _kStopIcon,
          "Abonnement de l'établissement expiré — application en lecture seule. "
              'Rapprochez-vous de votre administration.',
        );
      case LicensePhase.grace:
        info = (
          _kWarnBg, _kWarnBorder, _kWarnFg, Icons.warning_amber_rounded, _kWarnIcon,
          "Abonnement de l'établissement échu — régularisation requise auprès "
              'de votre administration.',
        );
      case LicensePhase.active:
        // Le compte à rebours AVANT échéance a quitté ce bandeau : il dépendait
        // de `license.validTo`, donc d'une licence émise — que la plupart des
        // groupes n'ont pas (`LICENSE_PILOT_GROUP_IDS`). Il vit désormais dans
        // `SchoolSubscriptionBanner`, alimenté par la date synchronisée du
        // groupe, sur le seuil réglé par le super_admin. Ici, phase active =
        // rien à signaler.
        return const SizedBox.shrink();
    }
    final (bg, border, fg, icon, iconColor, message) = info;

    return Material(
      color: bg,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: border))),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: _kStopIcon,
      content: const Text('Abonnement expiré — application en lecture seule. '
          'Modification impossible pour le moment.'),
    ));
    return false;
  }
  return true;
}
