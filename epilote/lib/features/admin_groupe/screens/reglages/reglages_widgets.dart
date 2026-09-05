part of '../admin_settings_screen.dart';

// Briques communes : barre d’enregistrement, bascules, compteurs.

class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.saving, required this.onSave, this.error});
  final bool saving;
  final VoidCallback onSave;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null) ...[
          AdminErrorBanner(message: error!),
          const SizedBox(height: 14),
        ],
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: saving ? null : onSave,
            icon: saving
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_rounded, size: 18),
            label: Text(saving ? 'Enregistrement…' : 'Enregistrer'),
            style: FilledButton.styleFrom(
              backgroundColor: kNavy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

void _toast(BuildContext context, String message, {bool ok = true}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    backgroundColor: ok ? kGreen : kRed,
    behavior: SnackBarBehavior.floating,
    content: Text(message),
  ));
}

// ─── Ligne de switch compacte ────────────────────────────────────────────────
class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      activeThumbColor: kNavy,
      value: value,
      onChanged: onChanged,
      secondary: Icon(icon, color: kNavy, size: 21),
      title: Text(title,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTextPrimary)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: kTextMuted)),
    );
  }
}

// ─── Stepper numérique (min/max) ─────────────────────────────────────────────
class _NumberStepper extends StatelessWidget {
  const _NumberStepper({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.suffix,
    this.step = 1,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final int value;
  final int min;
  final int max;
  final int step;
  final String? suffix;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: kNavy, size: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTextPrimary)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: kTextMuted)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: value > min ? () => onChanged(value - step) : null,
                  icon: Icon(Icons.remove_rounded, size: 18, color: kNavy),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 56),
                  child: Text(
                    suffix == null ? '$value' : '$value $suffix',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: kTextPrimary),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: value < max ? () => onChanged(value + step) : null,
                  icon: Icon(Icons.add_rounded, size: 18, color: kNavy),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Dropdown intégré au design ──────────────────────────────────────────────
class _SettingDropdown<T> extends StatelessWidget {
  const _SettingDropdown({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String label;
  final IconData icon;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        decoration: adminInputDecoration(label, icon: icon),
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ONGLET 1 — GÉNÉRAL  (infos groupe en lecture seule + préférences group_settings)
// ═════════════════════════════════════════════════════════════════════════════
