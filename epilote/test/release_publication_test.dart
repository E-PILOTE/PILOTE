// Mille postes interrogent `derniere_version()` à chaque ouverture. Une ligne
// fausse publiée ici ne se rattrape pas : au moment où on s'en aperçoit, le
// parc l'a déjà lue. Ces tests gardent les refus.

import 'dart:async';

import 'package:epilote/features/super_admin/providers/releases_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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

  // ══════════════════════════════════════════════════════════════════════════
  //  L'ADRESSE RÉPOND-ELLE À QUI N'A AUCUN IDENTIFIANT ?
  //
  //  Écrit APRÈS le défaut, pas avant. La 3.3.0 est partie vers le dépôt
  //  GitHub privé du projet : empreinte juste, taille juste, https juste — et
  //  `404` pour chaque poste, parce que les pièces d'une release privée
  //  exigent un jeton. Tous les contrôles avaient été faits depuis des postes
  //  authentifiés, où l'adresse répondait parfaitement.
  //
  //  Les douze contrôles ci-dessus ne lisent que du texte. Aucun n'aurait pu
  //  voir cela.
  // ══════════════════════════════════════════════════════════════════════════
  group('L\'adresse doit répondre à qui n\'a AUCUN identifiant', () {
    const url = 'https://exemple.cg/E-PILOTE-3.2.0-installateur.exe';

    Future<ControleRelease?> sonde(
      Future<http.Response> Function(http.Request r) repond, {
      int? tailleAttendue,
      Duration delai = const Duration(seconds: 20),
    }) =>
        ControleRelease.verifierAdresse(url,
            tailleAttendue: tailleAttendue,
            client: MockClient(repond),
            delai: delai);

    http.Response ok({int? taille}) => http.Response('', 200,
        headers: taille == null ? const {} : {'content-length': '$taille'});

    test('une adresse publique qui répond 200 passe', () async {
      expect(await sonde((_) async => ok()), isNull);
      expect(await sonde((_) async => ok(taille: 42), tailleAttendue: 42),
          isNull);
    });

    test('la requête ne porte NI jeton NI cookie', () async {
      // ⚠️ LE test de ce groupe. Se servir du client de l'application — qui
      // porte le jeton Supabase — ferait passer le contrôle et échouer le
      // parc : exactement le défaut d'origine, reproduit par son remède.
      http.Request? vue;
      await sonde((r) async {
        vue = r;
        return ok();
      });
      expect(vue, isNotNull);
      expect(vue!.method, 'HEAD');
      for (final entete in ['authorization', 'cookie', 'apikey', 'x-client-info']) {
        expect(vue!.headers[entete], isNull,
            reason: 'Un en-tête « $entete » rendrait ce contrôle menteur : il '
                'passerait ici et échouerait sur chaque poste du parc.');
      }
    });

    test('un 404 bloque, et le message dit ce que verrait le parc', () async {
      final f = await sonde((_) async => http.Response('', 404));
      expect(f?.champ, 'url');
      expect(f!.message, contains('404'));
      expect(f.message, contains('sans identifiants'));
    });

    test('un 403 bloque en nommant l\'authentification', () async {
      // Le cas exact d'un dépôt privé.
      final f = await sonde((_) async => http.Response('', 403));
      expect(f?.champ, 'url');
      expect(f!.message, contains('authentification'));
      expect(f.message, contains('public'));
    });

    test('un hébergeur qui refuse HEAD est réessayé en GET d\'un octet',
        () async {
      final methodes = <String>[];
      final f = await sonde((r) async {
        methodes.add(r.method);
        return r.method == 'HEAD'
            ? http.Response('', 405)
            : http.Response('x', 206);
      });
      expect(f, isNull, reason: 'Un 405 ne dit rien du fichier, seulement de '
          'la méthode : il ne doit pas bloquer une version valable.');
      expect(methodes, ['HEAD', 'GET']);
    });

    test('une taille annoncée différente bloque', () async {
      // L'adresse répond, mais elle ne désigne pas le fichier déclaré. Sans
      // cela, l'écart n'apparaîtrait qu'à l'empreinte, sur chaque poste,
      // après trente-cinq mégaoctets téléchargés pour rien.
      final f = await sonde((_) async => ok(taille: 12), tailleAttendue: 99);
      expect(f?.champ, 'url');
      expect(f!.message, contains('12'));
      expect(f.message, contains('99'));
    });

    test('une taille non annoncée ne bloque pas', () async {
      expect(await sonde((_) async => ok(), tailleAttendue: 99), isNull);
    });

    test('un réseau muet bloque : on ne publie pas ce qu\'on n\'a pas joint',
        () async {
      final f = await sonde((_) async => throw http.ClientException('coupé'));
      expect(f?.champ, 'url');
      expect(f!.message, contains('réessayez'));
    });

    test('un délai dépassé bloque', () async {
      final f = await sonde((_) => Completer<http.Response>().future,
          delai: const Duration(milliseconds: 30));
      expect(f?.champ, 'url');
      expect(f!.message, contains('réessayez'));
    });

    test('une adresse qui n\'est pas https est refusée sans toucher au réseau',
        () async {
      var appele = false;
      final f = await ControleRelease.verifierAdresse('http://exemple.cg/e.exe',
          client: MockClient((_) async {
        appele = true;
        return ok();
      }));
      expect(f?.champ, 'url');
      expect(appele, isFalse);
    });
  });
}
