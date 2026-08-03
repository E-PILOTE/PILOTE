import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:epilote/services/powersync/local_storage_dir.dart';

// ════════════════════════════════════════════════════════════════════════════
//  La base hors ligne quitte « Documents » pour le dossier de support
//  applicatif. Ce déplacement porte du travail que la synchronisation n'a pas
//  encore remonté : s'il se passe mal, une école perd sa saisie. D'où ces
//  tests, qui couvrent surtout les cas où l'on NE doit PAS déplacer.
// ════════════════════════════════════════════════════════════════════════════

void main() {
  late Directory root, legacy, target;

  setUp(() {
    resetLocalDataDirForTest();
    root = Directory.systemTemp.createTempSync('epilote_storage_test');
    legacy = Directory(p.join(root.path, 'Documents'))..createSync();
    target = Directory(p.join(root.path, 'AppData'))..createSync();
  });

  tearDown(() => root.deleteSync(recursive: true));

  Future<Directory> resolve() =>
      localDataDir(supportDir: target, documentsDir: legacy, forceResolve: true);

  void writeDb(Directory dir, String contents) {
    File(p.join(dir.path, kLocalDbName)).writeAsStringSync(contents);
  }

  test('installation neuve : rien à reprendre, on écrit dans le support', () async {
    final dir = await resolve();
    expect(p.equals(dir.path, target.path), isTrue);
  });

  test('reprise : la base ET ses fichiers annexes suivent', () async {
    writeDb(legacy, 'base');
    // Le `-wal` porte les dernières transactions, non encore reportées dans
    // le fichier principal : le laisser derrière perdrait la saisie la plus
    // récente, c'est-à-dire précisément celle qui n'est pas synchronisée.
    File(p.join(legacy.path, '$kLocalDbName-wal')).writeAsStringSync('journal');
    File(p.join(legacy.path, '$kLocalDbName-shm')).writeAsStringSync('memoire');

    final dir = await resolve();

    expect(p.equals(dir.path, target.path), isTrue);
    expect(File(p.join(target.path, kLocalDbName)).readAsStringSync(), 'base');
    expect(File(p.join(target.path, '$kLocalDbName-wal')).existsSync(), isTrue);
    expect(File(p.join(target.path, '$kLocalDbName-shm')).existsSync(), isTrue);
    expect(File(p.join(legacy.path, kLocalDbName)).existsSync(), isFalse);
  });

  test('la file d\'attente de fichiers suit la base', () async {
    writeDb(legacy, 'base');
    final outbox = Directory(p.join(legacy.path, kOutboxDirName))..createSync();
    File(p.join(outbox.path, 'photo.jpg')).writeAsStringSync('octets');

    await resolve();

    expect(File(p.join(target.path, kOutboxDirName, 'photo.jpg')).existsSync(),
        isTrue);
  });

  test('une base déjà en place ne se fait jamais écraser', () async {
    writeDb(legacy, 'ancienne');
    writeDb(target, 'courante');

    final dir = await resolve();

    expect(p.equals(dir.path, target.path), isTrue);
    expect(File(p.join(target.path, kLocalDbName)).readAsStringSync(),
        'courante');
    // L'ancienne reste où elle est : on ne supprime pas une base qu'on n'a
    // pas lue, même si on croit ne plus en avoir besoin.
    expect(File(p.join(legacy.path, kLocalDbName)).readAsStringSync(),
        'ancienne');
  });

  test('les fichiers étrangers de Documents ne sont pas emportés', () async {
    writeDb(legacy, 'base');
    File(p.join(legacy.path, 'Bulletin de Kimbembé.pdf'))
        .writeAsStringSync('document personnel');

    await resolve();

    expect(File(p.join(legacy.path, 'Bulletin de Kimbembé.pdf')).existsSync(),
        isTrue);
    expect(
        File(p.join(target.path, 'Bulletin de Kimbembé.pdf')).existsSync(),
        isFalse);
  });

  test('même dossier des deux côtés : aucun déplacement', () async {
    writeDb(legacy, 'base');
    final dir = await localDataDir(
        supportDir: legacy, documentsDir: legacy, forceResolve: true);
    expect(File(p.join(dir.path, kLocalDbName)).readAsStringSync(), 'base');
  });

  test('le résultat est mémorisé : pas de reprise à chaque appel', () async {
    writeDb(legacy, 'base');
    await resolve();
    // Une base réapparue dans l'ancien dossier après coup ne doit pas
    // déclencher un second déplacement au milieu d'une session.
    writeDb(legacy, 'intrus');
    final dir = await localDataDir(supportDir: target, documentsDir: legacy);
    expect(p.equals(dir.path, target.path), isTrue);
    expect(File(p.join(legacy.path, kLocalDbName)).readAsStringSync(), 'intrus');
  });
}
