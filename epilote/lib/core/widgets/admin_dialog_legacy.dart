import 'package:flutter/material.dart';

import 'admin_tokens.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CHROME HISTORIQUE (bandeau navy plein) — encore utilisé par une vingtaine
//  d'écrans. Ne PAS l'employer pour du neuf : `AdminFormDialog`,
//  `AdminSidePanel` et `showAdminConfirm` sont la famille de référence.
// ════════════════════════════════════════════════════════════════════════════
class AdminDialogHeader extends StatelessWidget {
  const AdminDialogHeader(
      {super.key, required this.title, required this.icon, this.subtitle});
  final String title;
  final IconData icon;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [kNavyDark, kNavy]),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded,
                color: Colors.white70, size: 20),
          ),
        ],
      ),
    );
  }
}

class AdminDialogFooter extends StatelessWidget {
  AdminDialogFooter({
    super.key,
    required this.saving,
    required this.submitLabel,
    required this.onCancel,
    required this.onSubmit,
    Color? submitColor,
    this.submitIcon,
  }) : submitColor = submitColor ?? kNavy;
  final bool saving;
  final String submitLabel;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;
  final Color submitColor;
  final IconData? submitIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: kBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: saving ? null : onCancel,
            child: Text('Annuler', style: TextStyle(color: kTextMuted)),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: saving ? null : onSubmit,
            icon: saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Icon(submitIcon ?? Icons.check_rounded, size: 18),
            label: Text(submitLabel),
            style: FilledButton.styleFrom(
              backgroundColor: submitColor,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}
