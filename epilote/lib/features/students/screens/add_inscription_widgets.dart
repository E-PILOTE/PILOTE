part of 'add_inscription_screen.dart';

// ─── Indicateur d'étapes (clair, style plateforme) ───────────────────────────
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current, required this.steps});
  final int current;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: List.generate(steps.length, (i) {
          final active = i == current;
          final done = i < current;
          final accent = done || active ? _kGreen : _kBorder;
          final dotColor = active ? _kNavy : (done ? _kGreen : Colors.white);
          final txtColor = active ? _kNavy : (done ? _kGreen : _kMuted);
          return Expanded(
            child: Row(children: [
              if (i > 0)
                Expanded(
                  child: Container(height: 2, color: done ? _kGreen : _kBorder),
                ),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: accent, width: 1.5),
                  ),
                  child: Center(
                    child: done
                        ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                        : Text('${i + 1}',
                            style: TextStyle(
                                color: active ? Colors.white : _kMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 4),
                Text(steps[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: txtColor,
                        fontSize: 10.5,
                        fontWeight: active ? FontWeight.w800 : FontWeight.w500)),
              ]),
              if (i < steps.length - 1)
                Expanded(
                  child: Container(height: 2, color: i < current ? _kGreen : _kBorder),
                ),
            ]),
          );
        }),
      ),
    );
  }
}

// ─── Barre de navigation (boutons plateforme) ────────────────────────────────
class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.currentStep,
    required this.totalSteps,
    required this.submitting,
    required this.onBack,
    required this.onNext,
    required this.onSubmit,
  });
  final int currentStep, totalSteps;
  final bool submitting;
  final VoidCallback onBack, onNext, onSubmit;

  @override
  Widget build(BuildContext context) {
    final isLast = currentStep == totalSteps - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _kBorder)),
      ),
      child: Row(children: [
        if (currentStep > 0)
          TextButton.icon(
            onPressed: submitting ? null : onBack,
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: const Text('Retour'),
            style: TextButton.styleFrom(foregroundColor: _kMuted),
          )
        else
          TextButton.icon(
            onPressed: submitting ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('Annuler'),
            style: TextButton.styleFrom(foregroundColor: _kMuted),
          ),
        const Spacer(),
        AdminPrimaryButton(
          label: isLast ? 'Enregistrer l\'inscription' : 'Suivant',
          icon: isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
          color: isLast ? _kGreen : _kNavy,
          saving: submitting,
          onTap: submitting ? () {} : (isLast ? onSubmit : onNext),
        ),
      ]),
    );
  }
}

// ─── Libellé de section (barre navy + majuscules) ────────────────────────────
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Container(
            width: 3,
            height: 13,
            decoration:
                BoxDecoration(color: _kNavy, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 8),
          Text(text.toUpperCase(),
              style: const TextStyle(
                  color: _kNavy,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1)),
        ]),
      );
}

// ─── Petit libellé de champ ──────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 5, left: 2),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11.5, color: _kMuted, fontWeight: FontWeight.w600)),
      );
}

// ─── Champ texte (label au-dessus + input plein, style plateforme) ───────────
class _Field extends StatelessWidget {
  const _Field({
    required this.ctrl,
    required this.label,
    required this.onChanged,
    this.keyboardType,
    this.maxLines = 1,
  });
  final TextEditingController ctrl;
  final String label;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _FieldLabel(label),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          maxLines: maxLines,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 13.5, color: _kText),
          decoration: adminFilledInput(''),
        ),
      ]),
    );
  }
}

// ─── Liste déroulante (label au-dessus + input plein) ────────────────────────
class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String label;
  final T? value;
  final Map<T, String> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _FieldLabel(label),
        DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          style: const TextStyle(fontSize: 13.5, color: _kText),
          icon: const Icon(Icons.expand_more_rounded, size: 18, color: _kMuted),
          decoration: adminFilledInput('Sélectionner'),
          items: items.entries
              .map((e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: onChanged,
        ),
      ]),
    );
  }
}

// ─── Case à cocher (tuile bordée, style plateforme) ──────────────────────────
class _CheckTile extends StatelessWidget {
  const _CheckTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: value ? _kGreen.withValues(alpha: 0.06) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: value ? _kGreen.withValues(alpha: 0.4) : _kBorder),
          ),
          child: Row(children: [
            Icon(
                value
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: 20,
                color: value ? _kGreen : _kMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: const TextStyle(fontSize: 13, color: _kText)),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── Champ date (label au-dessus + input plein cliquable) ────────────────────
class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _FieldLabel(label),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value != null
                  ? DateTime.tryParse(value!) ?? DateTime(2010)
                  : DateTime(2010),
              firstDate: DateTime(1990),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              onChanged(picked.toIso8601String().substring(0, 10));
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: InputDecorator(
            decoration: adminFilledInput('Sélectionner',
                icon: Icons.calendar_today_rounded),
            child: Text(value ?? 'Sélectionner',
                style: TextStyle(
                    color: value != null ? _kText : _kMuted, fontSize: 13.5)),
          ),
        ),
      ]),
    );
  }
}
