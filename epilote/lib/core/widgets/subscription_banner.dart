import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/widgets/admin_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/routes.dart';
import '../../features/admin_groupe/providers/subscription_access_provider.dart';

// Ambre (alerte douce : grâce / fin proche)
const _kWarnBg = Color(0xFFFFFBEB);
const _kWarnBorder = Color(0xFFFDE68A);
const _kWarnFg = Color(0xFF92400E);
const _kWarnIcon = Color(0xFFD97706);
// Rouge (lecture seule : échu au-delà de la grâce / suspendu / résilié)
const _kStopBg = Color(0xFFFEF2F2);
const _kStopBorder = Color(0xFFFECACA);
const _kStopFg = Color(0xFF991B1B);
Color get _kStopIcon => kRed;

/// Bandeau d'abonnement affiché en haut du shell **admin_groupe uniquement**.
/// Rend l'expiration VISIBLE et pousse au renouvellement (soft-gate — cf.
/// docs/ABONNEMENT_LICENCE_ARCHITECTURE.md, cascade grâce→lecture seule).
/// Ne s'affiche pas quand l'abonnement est actif et loin de l'échéance.
///
/// **Ré-évaluation (Vague 3 « tick 1×/jour + premier plan »)** : la phase se
/// dérive de `now` dans `subscriptionAccessProvider`. Pour que la bascule
/// grâce→lecture-seule apparaisse sans redémarrage sur une session longue, on
/// invalide le provider au retour au premier plan et sur un timer périodique
/// (online → refetch peu coûteux). Miroir du tick staff, pour l'uniformité.
class SubscriptionBanner extends ConsumerStatefulWidget {
  const SubscriptionBanner({super.key});

  @override
  ConsumerState<SubscriptionBanner> createState() => _SubscriptionBannerState();
}

class _SubscriptionBannerState extends ConsumerState<SubscriptionBanner>
    with WidgetsBindingObserver {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tick = Timer.periodic(const Duration(hours: 6), (_) {
      if (mounted) ref.invalidate(subscriptionAccessProvider);
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
    if (state == AppLifecycleState.resumed && mounted) {
      ref.invalidate(subscriptionAccessProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(subscriptionAccessProvider).valueOrNull;
    if (access == null) return const SizedBox.shrink();

    final isStop = access.phase == SubscriptionPhase.readOnly;
    final isGrace = access.phase == SubscriptionPhase.grace;
    final isSoon = access.expiresSoon;
    if (!isStop && !isGrace && !isSoon) return const SizedBox.shrink();

    final (bg, border, fg, icon, iconColor, message) = switch (access.phase) {
      SubscriptionPhase.readOnly => (
          _kStopBg,
          _kStopBorder,
          _kStopFg,
          Icons.lock_clock_rounded,
          _kStopIcon,
          "Abonnement expiré — création d'écoles et d'utilisateurs suspendue. "
              'Renouvelez pour rétablir. La gestion et les exports restent accessibles.',
        ),
      SubscriptionPhase.grace => (
          _kWarnBg,
          _kWarnBorder,
          _kWarnFg,
          Icons.warning_amber_rounded,
          _kWarnIcon,
          _graceMessage(access.daysLeft),
        ),
      SubscriptionPhase.active => (
          _kWarnBg,
          _kWarnBorder,
          _kWarnFg,
          Icons.schedule_rounded,
          _kWarnIcon,
          'Votre abonnement expire dans ${access.daysLeft} jour'
              "${(access.daysLeft ?? 0) > 1 ? 's' : ''}.",
        ),
    };

    return Material(
      color: bg,
      child: InkWell(
        onTap: () => context.go(Routes.adminAbonnement),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: border)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () => context.go(Routes.adminAbonnement),
                style: TextButton.styleFrom(
                  foregroundColor: iconColor,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Renouveler',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _graceMessage(int? daysLeft) {
    final overdue = daysLeft == null ? null : -daysLeft;
    if (overdue == null) return 'Abonnement expiré — pensez à renouveler.';
    if (overdue == 0) return "Votre abonnement expire aujourd'hui — renouvelez.";
    return "Abonnement expiré depuis $overdue jour${overdue > 1 ? 's' : ''} — "
        'renouvelez pour éviter le passage en lecture seule.';
  }
}
