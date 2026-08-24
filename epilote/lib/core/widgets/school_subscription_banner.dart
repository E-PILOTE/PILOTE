import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/navigation/providers/module_navigation_provider.dart';
import '../../licensing/domain/license_phase.dart';
import '../../licensing/presentation/license_providers.dart';
import '../utils/subscription_days.dart';
import 'admin_ui.dart';

// Ambre : même palette que les deux autres bandeaux d'échéance.
Color get _kWarnBg => kAccent.withValues(alpha: 0.12);
Color get _kWarnBorder => kAccent.withValues(alpha: 0.45);
const _kWarnFg = Color(0xFF92400E);
const _kWarnIcon = Color(0xFFD97706);

/// Compte à rebours d'échéance côté **personnel d'école** (offline).
///
/// ── Pourquoi ce widget existe ──────────────────────────────────────────────
/// Le personnel ne voyait un compte à rebours QUE si son groupe détenait une
/// licence signée ([LicenseBanner]) — or l'émission est bornée par
/// `LICENSE_PILOT_GROUP_IDS`, donc quasiment aucun groupe. L'école découvrait
/// l'échéance le jour de la coupure pendant que son admin de groupe, lui,
/// était prévenu depuis des jours.
///
/// Ce bandeau ne dépend d'aucune licence : il lit la date d'échéance déjà
/// synchronisée dans le SQLite local (`school_groups`, bucket `by_group`) et
/// la fenêtre d'alerte recopiée par la migration 0106 dans la même ligne.
/// Il fonctionne donc **hors ligne, pour tous les groupes**.
///
/// Architecture : lecture PowerSync pure (`currentSchoolGroupProvider`), jamais
/// `supabase.from()` — chemin personnel scolaire. Purement informatif : ne gate
/// rien et ne touche JAMAIS à la synchro (C4).
///
/// Audience : les agents de l'établissement. `app_shell` ne le monte pas pour
/// les familles (parent/élève) — la situation contractuelle de l'école ne les
/// regarde pas.
///
/// Re-rendu au retour au premier plan et toutes les 6 h : la phase dérive de
/// `now`, et un poste rural reste allumé des jours sans interaction.
class SchoolSubscriptionBanner extends ConsumerStatefulWidget {
  const SchoolSubscriptionBanner({super.key});

  @override
  ConsumerState<SchoolSubscriptionBanner> createState() =>
      _SchoolSubscriptionBannerState();
}

class _SchoolSubscriptionBannerState
    extends ConsumerState<SchoolSubscriptionBanner> with WidgetsBindingObserver {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    final group = ref.watch(currentSchoolGroupProvider).valueOrNull;
    if (group == null) return const SizedBox.shrink();

    final now = DateTime.now();

    // L'échéance est DÉPASSÉE ⇒ ce n'est plus un compte à rebours : les phases
    // grâce / lecture seule / hard-lock parlent, via LicenseBanner. On se tait
    // pour ne pas empiler deux bandeaux qui disent la même chose.
    final ent = ref.watch(entitlementProvider).valueOrNull;
    if (ent != null &&
        ent.isEnforced &&
        ent.phaseAt(now.toUtc()) != LicensePhase.active) {
      return const SizedBox.shrink();
    }

    // Fenêtre réglée par le super_admin, arrivée jusqu'ici par la synchro.
    // `null` = groupe antérieur au trigger 0106 → filet compilé.
    final alertDays = group.subscriptionAlertDays ?? kSubscriptionAlertDays;
    final daysLeft = alertDaysLeft(
      group.subscriptionEnd,
      alertDays: alertDays,
      today: now,
    );
    if (daysLeft == null) return const SizedBox.shrink();

    return Material(
      color: _kWarnBg,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: _kWarnBorder)),
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule_rounded, size: 18, color: _kWarnIcon),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                schoolCountdownMessage(
                  daysLeft: daysLeft,
                  willSuspendModules: ent?.license?.hardLockable ?? false,
                ),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: _kWarnFg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Message affiché au personnel. Pur & testable.
///
/// Le personnel ne peut pas payer : on l'oriente vers son administration au
/// lieu de lui proposer un bouton « Renouveler » qu'il ne peut pas actionner.
///
/// [willSuspendModules] ne promet la suspension que lorsqu'elle va RÉELLEMENT
/// arriver — c'est-à-dire quand une licence à hard-lock est en place. Sans
/// licence, rien ne se ferme le lendemain de l'échéance : annoncer une coupure
/// qui ne vient pas apprend aux écoles à ignorer les avertissements suivants.
String schoolCountdownMessage({
  required int daysLeft,
  required bool willSuspendModules,
}) {
  final suite = willSuspendModules
      ? " ; au-delà, l'accès aux modules sera suspendu."
      : '. Prévenez votre administration pour éviter toute interruption.';
  if (daysLeft == 0) {
    return "L'abonnement de l'établissement expire aujourd'hui$suite";
  }
  return "L'abonnement de l'établissement expire dans $daysLeft jour"
      "${daysLeft > 1 ? 's' : ''}$suite";
}
