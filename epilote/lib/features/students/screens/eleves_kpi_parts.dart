part of 'eleves_screen.dart';

// ─── KPIs (démographie de l'effectif) ────────────────────────────────────────
//
//  Chaque carte est une PORTE, pas seulement un chiffre : « Internes : 42 »
//  s'ouvrait sur rien, et la liste des quarante-deux — celle du dortoir, de la
//  cantine, du dossier de bourse — n'était accessible par aucun chemin.
class _Kpis extends StatelessWidget {
  const _Kpis({
    required this.students,
    required this.active,
    required this.onSelect,
  });
  final List<StudentRow> students;

  /// La particularité actuellement filtrée, pour surligner sa carte.
  final String? active;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final filles = students.where((s) => s.gender == 'F').length;
    final garcons = students.where((s) => s.gender == 'M').length;
    final internes = students.where((s) => s.isBoarder).length;
    final boursiers =
        students.where((s) => s.hasScholarship || s.hasSocialAid).length;
    // (icône, libellé, valeur, couleur, sous-titre, code de particularité)
    final items = <(IconData, String, String, Color, String?, String?)>[
      (Icons.groups_rounded, 'Effectif', '${students.length}', kNavy,
          'élèves validés', null),
      (Icons.female_rounded, 'Filles', '$filles', const Color(0xFFEC4899),
          null, null),
      (Icons.male_rounded, 'Garçons', '$garcons', const Color(0xFF0EA5E9),
          null, null),
      (Icons.night_shelter_outlined, 'Internes', '$internes',
          const Color(0xFF8B5CF6), 'voir la liste', 'interne'),
      (Icons.volunteer_activism_outlined, 'Boursiers / aidés', '$boursiers',
          const Color(0xFFF59E0B), 'voir la liste', 'boursier_ou_aide'),
    ];
    return LayoutBuilder(builder: (ctx, cns) {
      final w = cns.maxWidth;
      final cols = w >= 1100 ? 5 : (w >= 720 ? 3 : (w >= 460 ? 2 : 1));
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 176,
        ),
        itemCount: items.length,
        itemBuilder: (ctx, i) {
          final (icon, label, value, color, sub, code) = items[i];
          return AdminStatCard(
            label: label,
            value: value,
            icon: icon,
            color: color,
            subtitle: code != null && code == active ? 'filtre actif' : sub,
            onTap: code == null ? null : () => onSelect(code),
          );
        },
      );
    });
  }
}
