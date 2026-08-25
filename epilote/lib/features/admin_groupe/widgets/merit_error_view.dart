import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Vue d'erreur partagée par les deux bases du palmarès.
// ════════════════════════════════════════════════════════════════════════════
// ─── Erreur ─────────────────────────────────────────────────────────────────
class MeritErrorView extends StatelessWidget {
  const MeritErrorView({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.error_outline_rounded, size: 40, color: kRed),
            const SizedBox(height: 12),
            Text('Palmarès indisponible',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: kTextMuted)),
            const SizedBox(height: 16),
            AdminActionButton(
              label: 'Réessayer',
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
          ]),
        ),
      );
}
