part of '../plans_screen.dart';

// Interrupteur et sélecteur de modules du formulaire.

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.sub,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String label, sub;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Icon(icon, size: 16, color: value ? _kGreen : _kMuted),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(
            color: _kText, fontSize: 13, fontWeight: FontWeight.w600)),
        Text(sub, style: TextStyle(color: _kMuted, fontSize: 11)),
      ])),
      Switch(
        value: value,
        activeThumbColor: _kGreen,
        onChanged: onChanged,
      ),
    ]),
  );
}

class _ModulePickerBox extends StatelessWidget {
  const _ModulePickerBox({
    required this.modules,
    required this.selected,
    required this.loading,
    required this.onToggle,
  });
  final List<ModulePick> modules;
  final Set<String> selected;
  final bool loading;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Container(
        height: 80,
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kBorder),
        ),
        child: Center(child: SizedBox(width: 22, height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: _kNavy))),
      );
    }
    if (modules.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kBorder),
        ),
        child: Text('Aucun module disponible.',
            style: TextStyle(color: _kMuted, fontSize: 12)),
      );
    }
    return Container(
      padding: const EdgeInsets.all(10),
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kBorder),
      ),
      child: SingleChildScrollView(
        child: Wrap(spacing: 8, runSpacing: 8, children: modules.map((m) {
          final on = selected.contains(m.id);
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => onToggle(m.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: on ? _kNavy : _kBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: on ? _kNavy : _kBorder),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(on ? Icons.check_rounded : Icons.add_rounded,
                      size: 13, color: on ? Colors.white : _kMuted),
                  const SizedBox(width: 5),
                  Text(m.name, style: TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w600,
                      color: on ? Colors.white : _kText)),
                ]),
              ),
            ),
          );
        }).toList()),
      ),
    );
  }
}

// ─── Modal détails ────────────────────────────────────────────────────────────
