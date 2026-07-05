import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/routes.dart';
import '../../../core/widgets/app_shell.dart';

/// Mur de renouvellement (hard-lock impayé, plan privé au-delà de la grâce).
///
/// Affiché quand un membre du personnel tente d'ouvrir un module alors que
/// l'abonnement de l'école est en phase `hardLock` (voir `LicensePhase`). Les
/// modules deviennent inaccessibles ; seuls Dashboard / Profil / Paramètres et
/// les pages natives (hors abonnement) restent. La SYNCHRO n'est jamais coupée
/// (ADR-0006) : aucune donnée n'est perdue, tout est restauré au paiement.
///
/// Écran volontairement NEUTRE : ne lit aucune donnée PowerSync (le personnel
/// n'a pas à dépendre de la synchro pour voir ce mur).
class RenewalWallScreen extends ConsumerWidget {
  const RenewalWallScreen({super.key});

  static const _kNavy  = Color(0xFF1E3A5F);
  static const _kGreen = Color(0xFF009A44);
  static const _kAmber = Color(0xFFB45309);
  static const _kMuted = Color(0xFF64748B);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppShell(
      title: 'Renouvellement requis',
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: _kAmber.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_clock_rounded,
                      size: 42, color: _kAmber),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Abonnement à renouveler',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800, color: _kNavy),
                ),
                const SizedBox(height: 12),
                const Text(
                  'L\'abonnement de votre établissement est arrivé à échéance. '
                  'Les modules sont temporairement suspendus le temps du '
                  'renouvellement.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: _kMuted, height: 1.6),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _kGreen.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kGreen.withValues(alpha: 0.25)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.shield_outlined, color: _kGreen, size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Vos données sont intactes et en sécurité. Elles seront '
                          'immédiatement restaurées dès la régularisation, sans '
                          'aucune perte.',
                          style: TextStyle(
                              fontSize: 13, color: _kNavy, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Contactez l\'administrateur de votre groupe scolaire pour '
                  'procéder au renouvellement.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: _kMuted, height: 1.5),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => context.go(Routes.userDashboard),
                  style: FilledButton.styleFrom(
                    backgroundColor: _kNavy,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                  ),
                  icon: const Icon(Icons.dashboard_rounded, size: 18),
                  label: const Text('Retour au tableau de bord'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
