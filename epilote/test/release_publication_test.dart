// Mille postes interrogent `derniere_version()` à chaque ouverture. Une ligne
// fausse publiée ici ne se rattrape pas : au moment où on s'en aperçoit, le
// parc l'a déjà lue. Ces tests gardent les refus.

import 'package:epilote/features/super_admin/providers/releases_provider.dart';
import 'package:flutter_test/flutter_test.dart';

const _sha =
    'a3f1b2c4d5e6f708192a3b4c5d6e7f8091a2b3c4d5e6f708192a3b4c5d6e7f80';

ReleasePubliee _publiee(int build,
        {String platform = 'windows', String channel = 'stable'}) =>
    ReleasePubliee(
      id: 'r$build',
      version: '3.$build.0',
      buildNumber: build,
      platform: platform,
      channel: channel,
      downloadUrl: 'https://exemple.cg/e.exe',
      sha256: _sha,
      isMandatory: false,
    );

ControleRelease? _verifier({
  String version = '3.2.0',
  String build = '42',
  String url = 'https://exemple.cg/EPILOTE-3.2.0.exe',
  String sha = _sha,
  String? minBuild,
  List<ReleasePubliee> deja = const [],
  String platform = 'windows',
  String channel = 'stable',
}) =>
    ControleRelease.verifier(
      version: version,
      build: build,
      url: url,
      sha: sha,
      minBuild: minBuild,
      deja: deja,
      platform: platform,
      channel: channel,
    );

void main() {
  test('une déclaration complète et cohérente passe', () {
    expect(_verifier(), isNull);
    expect(_verifier(deja: [_publiee(41)]), isNull);
    expect(_verifier(minBuild: '30'), isNull);
  });

  group('Le numéro de build', () {
    test('ne peut pas reculer', () {
      // Le poste compare des ENTIERS : un build inférieur ne serait jamais
      // proposé, et la correction n'atteindrait aucune école — en silence.
      final f = _verifier(build: '40', deja: [_publiee(42)]);
      expect(f, isNotNull);
      expect(f!.champ, 'build');
      expect(f.message, contains('INFÉRIEUR'));
      expect(f.message, contains('42'));
    });

    test('ne peut pas se répéter', () {
      final f = _verifier(build: '42', deja: [_publiee(42)]);
      expect(f?.champ, 'build');
      expect(f!.message.toLowerCase(), contains('déjà publié'));
    });

    test('doit être un entier positif', () {
      expect(_verifier(build: '3.2.0')?.champ, 'build');
      expect(_verifier(build: '0')?.champ, 'build');
      expect(_verifier(build: '')?.champ, 'build');
    });

    test('ne se compare qu\'à SA plateforme et SON canal', () {
      // Le build 42 de Windows n'interdit rien à macOS, ni au canal bêta :
      // ce sont trois files indépendantes côté serveur.
      expect(_verifier(build: '10', deja: [_publiee(42, platform: 'macos')]),
          isNull);
      expect(_verifier(build: '10', deja: [_publiee(42, channel: 'beta')]),
          isNull);
    });
  });

  group('L\'empreinte SHA-256', () {
    test('doit faire 64 caractères hexadécimaux', () {
      expect(_verifier(sha: 'abc')?.champ, 'sha');
      expect(_verifier(sha: '${_sha}ff')?.champ, 'sha');
      // 'g' n'est pas hexadécimal — faute de frappe classique.
      expect(_verifier(sha: _sha.replaceFirst('a', 'g'))?.champ, 'sha');
    });

    test('les majuscules sont acceptées', () {
      // Certains outils la sortent en capitales ; refuser ferait retaper, et
      // une empreinte retapée est fausse une fois sur deux.
      expect(_verifier(sha: _sha.toUpperCase()), isNull);
    });

    test('le message dit où la reprendre', () {
      expect(_verifier(sha: 'trop court')!.message, contains('manifest.json'));
    });
  });

  test('l\'adresse doit être en https', () {
    // Un installateur téléchargé en clair peut être remplacé en chemin.
    expect(_verifier(url: 'http://exemple.cg/e.exe')?.champ, 'url');
    expect(_verifier(url: 'exemple.cg/e.exe')?.champ, 'url');
  });

  group('Le build minimum', () {
    test('ne peut pas dépasser celui qu\'on publie', () {
      // Sinon les postes sont sommés de passer à une version qui n'existe
      // pas : bloqués, sans issue.
      final f = _verifier(build: '42', minBuild: '50');
      expect(f?.champ, 'minBuild');
      expect(f!.message.toLowerCase(), contains('n\'existe pas'));
    });

    test('vide ou absent ne bloque rien', () {
      expect(_verifier(minBuild: null), isNull);
      expect(_verifier(minBuild: '   '), isNull);
    });
  });

  test('la version doit être nommée', () {
    expect(_verifier(version: '  ')?.champ, 'version');
  });
}
