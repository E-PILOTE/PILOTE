part of '../plans_screen.dart';

// Titre de section et champ de formulaire.

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
          color: _kMuted, letterSpacing: 0.5));
}

class _FormField extends StatelessWidget {
  const _FormField({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.keyboardType,
    this.maxLines = 1,
    this.onChanged,
    this.validator,
  });
  final TextEditingController controller;
  final String                label;
  final IconData              icon;
  final String?               hint;
  final TextInputType?        keyboardType;
  final int                   maxLines;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller:   controller,
    keyboardType: keyboardType,
    maxLines:     maxLines,
    onChanged:    onChanged,
    style: TextStyle(fontSize: 13, color: _kText),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 16, color: _kMuted),
      filled: true,
      fillColor: _kSurface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: _kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: _kNavy, width: 1.5),
      ),
      contentPadding: const EdgeInsets.all(12),
    ),
    validator: validator,
  );
}

// ─── Modal création / édition ─────────────────────────────────────────────────
