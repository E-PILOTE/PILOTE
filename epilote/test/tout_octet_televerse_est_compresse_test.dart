import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  AUCUN OCTET NE PART SANS ÊTRE PASSÉ PAR LA COMPRESSION
//
//  ── CE QUE COÛTE UN OUBLI ──────────────────────────────────────────────────
//  Une photo sortie d'un téléphone pèse 4 à 8 Mo. L'application l'affiche dans
//  une pastille de 38 px et l'imprime sur 22 mm. Sans compression, ces 8 Mo
//  traversent la liaison de l'école à la montée, PUIS redescendent sur chaque
//  poste qui synchronise, PUIS occupent le disque du poste à demeure.
//
//  Sur une école qui inscrit six cents élèves, c'est plusieurs gigaoctets — au
//  Congo, sur des liaisons facturées au volume et coupées la moitié du temps.
//  Et rien ne le signale : l'envoi réussit, il est seulement très lent, une
//  fois, chez quelqu'un d'autre.
//
//  ── POURQUOI UN TEST PLUTÔT QU'UNE CONSIGNE ────────────────────────────────
//  La compression ne peut pas vivre dans `enqueueUpload` : elle dépend de ce
//  qu'on envoie. Un avatar se réduit à 256 px, un logo à 512, une pièce de
//  dossier à 1600, et une archive d'examen ne se touche PAS. Le choix est
//  forcément chez l'appelant — donc oubliable.
//
//  Ce garde rend l'oubli visible : ajouter un `uploadBinary` sans compresser
//  fait échouer les tests, avec le nom du fichier fautif.
//
//  ⚠️ Il lit le CODE SOURCE, pas l'exécution. Il ne prouve pas que la
//  compression s'applique aux bons octets — il prouve qu'on y a pensé.
// ════════════════════════════════════════════════════════════════════════════

/// Les portes de sortie vers Supabase Storage.
const _kPortes = ['uploadBinary(', 'enqueueUpload('];

/// Les fonctions de `core/utils/media_compression.dart` qui réduisent.
const _kCompressions = [
  'compressAvatar(',
  'compressLogo(',
  'compressForUpload(',
  'compressImage(',
  'compressImageBytes(',
];

/// Les fichiers qui téléversent SANS compresser, et pourquoi c'est juste.
///
/// Toute entrée ici est une décision, pas une dispense : elle doit tenir en une
/// phrase qu'on puisse contredire.
const _kExceptions = <String, String>{
  'lib/services/powersync/upload_outbox.dart':
      'La file d’attente. Elle renvoie des octets DÉJÀ compressés au moment où '
          'ils y ont été déposés ; les recompresser au vol les dégraderait une '
          'seconde fois, sans rien gagner.',
  'lib/features/admin_groupe/providers/exam_archives_provider.dart':
      'Pièce opposable. L’empreinte SHA-256 est calculée sur les octets '
          'déposés : ré-encoder le scan d’un procès-verbal changerait '
          'l’empreinte, donc la seule chose qui prouve qu’on regarde bien le '
          'document déposé ce jour-là.',
  'lib/features/communication/providers/messages_provider.dart':
      'La compression a lieu en amont, dans `comm_attachments.dart`, AVANT le '
          'contrôle de taille — une photo de 8 Mo tombe à ~400 Ko et repasse '
          'sous la limite. Vérifié par un test dédié plus bas.',
};

List<File> _dartsSous(String chemin) => Directory(chemin)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList()
  ..sort((a, b) => a.path.compareTo(b.path));

String _relatif(File f) {
  final c = f.path.replaceAll(r'\', '/');
  return c.substring(c.indexOf('lib/'));
}

void main() {
  group('Aucun téléversement n’échappe à la compression', () {
    final dossier = Directory('lib');
    if (!dossier.existsSync()) {
      fail('`lib/` introuvable — lancer les tests depuis `epilote/`.');
    }

    final televersent = <String, String>{}; // chemin → source
    for (final f in _dartsSous('lib')) {
      final src = f.readAsStringSync().replaceAll('\r\n', '\n');
      if (_kPortes.any(src.contains)) televersent[_relatif(f)] = src;
    }

    test('le dépôt téléverse bien quelque part (le garde n’est pas creux)', () {
      expect(televersent, isNotEmpty,
          reason: 'Aucune porte trouvée : le nom des fonctions a changé et ce '
              'garde ne surveille plus rien.');
    });

    test('chaque fichier qui téléverse compresse, ou figure aux exceptions',
        () {
      final fautifs = <String>[];
      for (final e in televersent.entries) {
        if (_kExceptions.containsKey(e.key)) continue;
        if (_kCompressions.any(e.value.contains)) continue;
        fautifs.add(e.key);
      }

      expect(
        fautifs,
        isEmpty,
        reason: 'Ces fichiers envoient des octets sans les réduire :\n'
            '${fautifs.map((f) => '  • $f').join('\n')}\n\n'
            'Une photo de téléphone pèse 4 à 8 Mo ; l’application l’affiche '
            'sur 38 px et l’imprime sur 22 mm. Appelez `compressAvatar` '
            '(256 px), `compressLogo` (512 px) ou `compressForUpload` '
            '(1600 px) selon l’usage — ou inscrivez le fichier dans '
            '`_kExceptions` avec la raison écrite.',
      );
    });

    test('aucune exception n’est devenue inutile', () {
      final fantomes =
          _kExceptions.keys.where((k) => !televersent.containsKey(k)).toList();
      expect(fantomes, isEmpty,
          reason: 'Ces fichiers ne téléversent plus rien : '
              '${fantomes.join(', ')}. Une exception qui ne protège plus rien '
              'finit par couvrir autre chose.');
    });

    test('chaque exception porte une raison écrite, pas un mot', () {
      for (final e in _kExceptions.entries) {
        expect(e.value.length, greaterThan(60),
            reason: '« ${e.key} » a une justification trop courte pour être '
                'contredite.');
      }
    });
  });

  group('L’exception de la messagerie tient vraiment', () {
    const chemin = 'lib/features/communication/widgets/comm_attachments.dart';

    test('les pièces jointes sont compressées AVANT d’être envoyées', () {
      final src = File(chemin).readAsStringSync().replaceAll('\r\n', '\n');
      final iCompression = src.indexOf('compressForUpload(');
      final iEnvoi = src.indexOf('uploadMessageAttachment(');

      expect(iCompression, greaterThan(-1),
          reason: '$chemin ne compresse plus : l’exception accordée à '
              '`messages_provider.dart` ne repose alors sur rien.');
      expect(iEnvoi, greaterThan(-1),
          reason: '$chemin n’envoie plus par `uploadMessageAttachment` — la '
              'chaîne vérifiée ici n’est plus celle du code.');
      expect(iCompression, lessThan(iEnvoi),
          reason: 'La compression doit précéder l’envoi ET le contrôle de '
              'taille : c’est ce qui fait passer une photo de 8 Mo sous la '
              'limite au lieu de la refuser.');
    });
  });

  group('Les archives d’examen expliquent leur exception dans le code', () {
    test('la raison est écrite là où quelqu’un la lira', () {
      final src = File(
        'lib/features/admin_groupe/providers/exam_archives_provider.dart',
      ).readAsStringSync().replaceAll('\r\n', '\n');
      expect(src.contains('ON NE COMPRESSE PAS'), isTrue,
          reason: 'La seule exception permanente du dépôt doit se justifier '
              'sur place. Un lecteur qui trouve un envoi non compressé et '
              'aucune explication le « corrigera » — et cassera la valeur '
              'probante de l’archive.');
    });
  });
}
