part of '../admin_schools_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Champ « Ville / Village » — cascade géographique du formulaire école.
//
//  Choisir une localité pose automatiquement le repère APPROXIMATIF sur la
//  carte (via [SchoolLocationController]) ; le champ reste libre, car tous les
//  villages du Congo ne sont pas au référentiel. La liste est filtrée par le
//  département (rattachement point-dans-polygone sur les contours ADM1).
// ════════════════════════════════════════════════════════════════════════════

class SchoolLocalityField extends ConsumerWidget {
  const SchoolLocalityField({
    super.key,
    required this.department,
    required this.city,
    required this.cityFocus,
    required this.location,
  });

  /// Département sélectionné — filtre la liste des localités.
  final String? department;
  final TextEditingController city;
  final FocusNode cityFocus;

  /// Pont vers la carte : la localité choisie y pose le repère approximatif.
  final SchoolLocationController location;

  // ── Cascade : Ville/Village recherchable, filtré par le département choisi ──
  // Sélectionner une localité pose automatiquement le repère approximatif sur
  // la carte (via le contrôleur) ; le champ reste libre (village hors référentiel).
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final places = ref.watch(localitiesInDeptProvider(department));
    return RawAutocomplete<GeoPlace>(
      textEditingController: city,
      focusNode: cityFocus,
      displayStringForOption: (p) => p.name,
      optionsBuilder: (value) {
        final q = normalizePlaceName(value.text);
        final base = q.isEmpty
            ? places
            : places.where((p) => normalizePlaceName(p.name).contains(q));
        return base.take(40);
      },
      onSelected: (p) {
        city.text = p.name;
        location.requestApprox(p.coords);
        cityFocus.unfocus();
      },
      fieldViewBuilder: (context, controller, focusNode, _) => TextFormField(
        controller: controller,
        focusNode: focusNode,
        decoration: schoolInputDec(department == null
            ? 'Ville / Village'
            : 'Ville / Village ($department)'),
      ),
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240, maxWidth: 340),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (_, i) {
                final p = options.elementAt(i);
                return InkWell(
                  onTap: () => onSelected(p),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    child: Row(children: [
                      Icon(_placeIcon(p.type), size: 15, color: kTextMuted),
                      const SizedBox(width: 8),
                      Expanded(child: Text(p.name,
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis)),
                      Text(_placeLabel(p.type),
                          style: const TextStyle(fontSize: 10.5, color: kTextMuted)),
                    ]),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  IconData _placeIcon(String type) => switch (type) {
        'city' => Icons.location_city_rounded,
        'town' => Icons.apartment_rounded,
        'suburb' || 'neighbourhood' || 'quarter' => Icons.holiday_village_rounded,
        _ => Icons.cottage_rounded,
      };

  String _placeLabel(String type) => switch (type) {
        'city' => 'Ville',
        'town' => 'Bourg',
        'village' => 'Village',
        'hamlet' || 'isolated_dwelling' => 'Hameau',
        'locality' => 'Localité',
        'suburb' || 'neighbourhood' || 'quarter' => 'Quartier',
        _ => 'Lieu',
      };
}
