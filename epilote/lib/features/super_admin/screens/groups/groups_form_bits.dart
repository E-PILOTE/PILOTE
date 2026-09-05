part of '../school_groups_screen.dart';

// Libellés, séparateurs, liste déroulante, pastille carrée.

class _FormLabel extends StatelessWidget {
  const _FormLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      Container(
        width: 3, height: 13,
        decoration: BoxDecoration(
          color: _kNavy,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(text, style: TextStyle(
          color: _kNavy, fontSize: 10.5, fontWeight: FontWeight.w800,
          letterSpacing: 1.1)),
    ]),
  );
}

// Séparateur de section dans le formulaire
class _FormDivider extends StatelessWidget {
  const _FormDivider();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Divider(color: _kBorder, height: 1),
  );
}

// Widget dropdown filtre compact
class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.icon,
    required this.label,
    required this.items,
    required this.value,
    required this.onChanged,
    this.active = false,
  });
  final IconData icon;
  final String label;
  final Map<String, String> items;
  final String value;
  final ValueChanged<String> onChanged;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: active ? _kNavy.withValues(alpha: 0.06) : _kSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: active ? _kNavy.withValues(alpha: 0.4) : _kBorder,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded, size: 16,
              color: active ? _kNavy : _kMuted),
          style: TextStyle(
            color: active ? _kNavy : _kMuted,
            fontSize: 12.5, fontWeight: FontWeight.w600,
          ),
          items: items.entries.map((e) => DropdownMenuItem(
            value: e.key,
            child: Text(e.value),
          )).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ),
    );
  }
}

// Initiales carrées pour le header du modal
class _SquareInitials extends StatelessWidget {
  const _SquareInitials({required this.name, required this.size});
  final String name;
  final double size;

  static List<Color> get _colors => [_kNavy, _kGreen, _kPurple, _kOrange,
      const Color(0xFF0EA5E9)];

  String get _initials => initialesEtablissement(name);

  Color get _color =>
      name.isNotEmpty ? _colors[name.codeUnitAt(0) % _colors.length] : _kNavy;

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    color: _color.withValues(alpha: 0.12),
    child: Center(child: Text(_initials, style: TextStyle(
      color: _color, fontSize: size * 0.3, fontWeight: FontWeight.w900,
    ))),
  );
}

// Bouton icône compact pour le header modal
