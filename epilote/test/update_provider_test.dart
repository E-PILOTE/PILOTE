// La mise à jour du parc est ce qui transforme une livraison unique en une
// livraison rattrapable. Ces tests gardent les décisions qui, si elles
// cédaient, feraient soit réclamer une mise à jour en boucle, soit taire une
// correction que mille écoles attendent.

import 'package:epilote/features/updates/providers/update_provider.dart';
import 'package:epilote/features/updates/services/update_installer.dart';
import 'package:flutter_test/flutter_test.dart';

AppRelease _release({int build = 20, bool obligatoire = false, int? minBuild}) =>
    AppRelease(
      version: '3.2.0',
      buildNumber: build,
      downloadUrl: 'https://example.invalid/E-PILOTE.exe',
      sha256: 'a' * 64,
      sizeBytes: 35 * 1024 * 1024,
      isMandatory: obligatoire,
      minBuild: minBuild,
    );

void main() {
  group('Comparer les versions', () {
    test('un build plus élevé signale un retard', () {
      const installe = 18;
      final e = EtatMiseAJour(
        buildInstalle: installe,
        versionInstallee: '3.1.7 (build 18)',
        disponible: _release(build: 20),
      );
      expect(e.enRetard, isTrue);
      expect(e.aJour, isFalse);
    });

    test('le même build est à jour', () {
      final e = EtatMiseAJour(
        buildInstalle: 20,
        versionInstallee: '3.2.0 (build 20)',
        disponible: _release(build: 20),
      );
      expect(e.aJour, isTrue);
    });

    test('un build publié PLUS ANCIEN ne propose rien', () {
      // Cas réel : un poste recetté sur une version de test devancerait le
      // canal stable. Lui proposer de « revenir en arrière » serait absurde.
      final e = EtatMiseAJour(
        buildInstalle: 25,
        versionInstallee: '3.3.0 (build 25)',
        disponible: _release(build: 20),
      );
      expect(e.aJour, isTrue);
    });

    test('rien de disponible = à jour, jamais une erreur', () {
      // Hors ligne, table vide, serveur muet : indistinguable à dessein.
      const e = EtatMiseAJour(
          buildInstalle: 18, versionInstallee: '3.1.7 (build 18)');
      expect(e.aJour, isTrue);
      expect(e.enRetard, isFalse);
      expect(e.tropAncienne, isFalse);
    });

    test('un build inconnu ne déclenche pas de retard', () {
      // `buildInstalle` à 0 rendrait TOUTE version publiée plus récente, et
      // l'écran réclamerait une mise à jour en boucle. Le provider se tait ;
      // ici on vérifie qu'aucune version n'est portée dans ce cas.
      expect(EtatMiseAJour.inconnu.buildInstalle, 0);
      expect(EtatMiseAJour.inconnu.disponible, isNull);
      expect(EtatMiseAJour.inconnu.aJour, isTrue);
    });
  });

  group('Version devenue trop ancienne', () {
    test('le serveur peut la déclarer obligatoire', () {
      final e = EtatMiseAJour(
        buildInstalle: 18,
        versionInstallee: '3.1.7 (build 18)',
        disponible: _release(build: 20, obligatoire: true),
      );
      expect(e.tropAncienne, isTrue);
    });

    test('un plancher de build la déclare aussi', () {
      final e = EtatMiseAJour(
        buildInstalle: 12,
        versionInstallee: '3.0.2 (build 12)',
        disponible: _release(build: 20, minBuild: 15),
      );
      expect(e.tropAncienne, isTrue);
    });

    test('au-dessus du plancher, la mise à jour reste facultative', () {
      final e = EtatMiseAJour(
        buildInstalle: 18,
        versionInstallee: '3.1.7 (build 18)',
        disponible: _release(build: 20, minBuild: 15),
      );
      expect(e.enRetard, isTrue);
      expect(e.tropAncienne, isFalse); // on n'interrompt pas une saisie
    });
  });

  group('Lecture du serveur', () {
    test('l\'empreinte est ramenée en minuscules', () {
      // Une empreinte copiée depuis PowerShell arrive en MAJUSCULES ; comparée
      // telle quelle à celle calculée en Dart, elle ne correspondrait jamais
      // et aucune mise à jour ne pourrait plus s'installer.
      final r = AppRelease.fromMap({
        'version': '3.2.0',
        'build_number': 20,
        'download_url': 'https://example.invalid/x.exe',
        'sha256': 'ABCDEF0123456789' * 4,
      });
      expect(r.sha256, 'abcdef0123456789' * 4);
    });

    test('un enregistrement incomplet ne fait pas tomber l\'application', () {
      final r = AppRelease.fromMap(const {});
      expect(r.buildNumber, 0);
      expect(r.version, '');
      expect(r.isMandatory, isFalse);
    });

    test('la taille se lit en mégaoctets, ou pas du tout', () {
      expect(_release().tailleLisible, '35.0 Mo');
      final sansTaille = AppRelease.fromMap(const {
        'version': '3.2.0',
        'build_number': 20,
        'download_url': 'u',
        'sha256': 'b',
      });
      expect(sansTaille.tailleLisible, isEmpty);
    });
  });

  group('Progression du téléchargement', () {
    test('sans taille annoncée, aucun pourcentage n\'est inventé', () {
      const p = ProgressionTelechargement(1024, null);
      expect(p.fraction, isNull);
    });

    test('la fraction ne dépasse jamais 1', () {
      // Un serveur qui annonce une taille plus petite que ce qu'il envoie
      // ferait afficher « 120 % ».
      const p = ProgressionTelechargement(200, 100);
      expect(p.fraction, 1.0);
    });
  });
}
