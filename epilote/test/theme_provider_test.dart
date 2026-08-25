import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:epilote/core/theme/palette.dart';
import 'package:epilote/core/theme/theme_prefs.dart';
import 'package:epilote/core/widgets/admin_ui.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // L'état global fuit d'un test à l'autre — c'est le prix assumé des jetons
    // globaux (spec §2.3). On repart toujours de Clair.
    applyPalette(kPaletteClair);
  });

  group('préférence de thème', () {
    test('sans préférence enregistrée → Clair', () async {
      expect(await loadThemeFor('agent-1'), EpiloteThemeId.clair);
    });

    test('la préférence est persistée puis relue', () async {
      await saveThemeFor('agent-1', EpiloteThemeId.melack);
      expect(await loadThemeFor('agent-1'), EpiloteThemeId.melack);
    });

    // Le cœur de la décision produit : le thème suit l'AGENT, pas l'appareil.
    test('deux agents du même poste ont deux thèmes distincts', () async {
      await saveThemeFor('aline', EpiloteThemeId.melack);
      await saveThemeFor('casimir', EpiloteThemeId.sombre);
      expect(await loadThemeFor('aline'), EpiloteThemeId.melack);
      expect(await loadThemeFor('casimir'), EpiloteThemeId.sombre);
      // Un 3e agent n'hérite de personne.
      expect(await loadThemeFor('patrick'), EpiloteThemeId.clair);
    });

    test('agent inconnu (null) → Clair, sans planter', () async {
      expect(await loadThemeFor(null), EpiloteThemeId.clair);
      await saveThemeFor(null, EpiloteThemeId.sombre); // ne doit rien casser
      expect(await loadThemeFor(null), EpiloteThemeId.clair);
    });

    test('valeur corrompue en préférences → Clair (fail-soft)', () async {
      SharedPreferences.setMockInitialValues({'epilote_theme_x': 'turquoise'});
      expect(await loadThemeFor('x'), EpiloteThemeId.clair);
    });
  });

  group('applyPalette', () {
    test('bascule réellement les jetons globaux', () {
      expect(kSurface, kPaletteClair.surface);
      applyPalette(kPaletteMelack);
      expect(kSurface, kPaletteMelack.surface);
      expect(kCardBg, kPaletteMelack.cardBg);
      expect(kNavyDeep, kPaletteMelack.navyDeep);
      expect(activePalette.id, EpiloteThemeId.melack);
    });

    test('les 11 jetons suivent la palette, sans exception', () {
      applyPalette(kPaletteSombre);
      const p = kPaletteSombre;
      expect(
        [kNavyDeep, kNavyDark, kNavy, kGreen, kAccent, kRed, kSurface, kCardBg,
          kTextPrimary, kTextMuted, kBorder],
        [p.navyDeep, p.navyDark, p.navy, p.green, p.accent, p.red, p.surface,
          p.cardBg, p.textPrimary, p.textMuted, p.border],
      );
    });
  });
}
