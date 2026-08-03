import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  OÙ VIVENT LA BASE HORS LIGNE ET LA FILE D'ATTENTE DE FICHIERS
//
//  Jusqu'ici : `getApplicationDocumentsDirectory()`. Sous Linux, en
//  développement, c'est sans conséquence. Sous Windows — la plateforme de
//  déploiement — c'est le dossier « Documents » de l'agent, et cela pose deux
//  problèmes qui font perdre du travail :
//
//   1. L'agent VOIT `epilote_v3.db` au milieu de ses fichiers. Un fichier
//      inconnu, au nom technique, dans son dossier personnel : tôt ou tard il
//      le supprime. Avec lui part tout ce que la synchronisation n'a pas
//      encore remonté.
//
//   2. « Documents » est très fréquemment redirigé vers OneDrive. Une base
//      SQLite dans un dossier synchronisé est une cause classique de
//      corruption : le client verrouille et téléverse le fichier pendant que
//      la base écrit son journal, et la base et son `-wal` se désynchronisent.
//
//  On écrit donc dans le dossier de support applicatif — `%APPDATA%\...` sous
//  Windows, `~/.local/share/...` sous Linux. Invisible, non synchronisé, et
//  propre à chaque utilisateur du poste, ce qui reste exactement ce qu'il faut
//  pour un poste partagé d'établissement.
//
//  ── LA REPRISE DE L'EXISTANT ───────────────────────────────────────────────
//  Un poste qui tournait déjà a sa base dans l'ancien emplacement. On la
//  DÉPLACE au premier démarrage. En cas d'échec du déplacement, on continue
//  sur l'ANCIEN emplacement : mieux vaut un fichier mal placé qu'une base
//  vide et un trimestre de saisie envolé.
// ════════════════════════════════════════════════════════════════════════════

/// Préfixe des fichiers de la base locale — `epilote_v3.db`, plus les fichiers
/// annexes que SQLite tient à côté (`-wal`, `-shm`, `-journal`).
const String kLocalDbName = 'epilote_v3.db';

/// Nom du dossier de la file d'attente d'envoi de fichiers.
const String kOutboxDirName = 'upload_outbox';

Directory? _resolved;

/// Dossier de travail local, résolu une fois pour toutes.
///
/// [supportDir] et [documentsDir] n'existent que pour les tests ; en
/// production ils viennent de `path_provider`.
Future<Directory> localDataDir({
  Directory? supportDir,
  Directory? documentsDir,
  bool forceResolve = false,
}) async {
  if (_resolved != null && !forceResolve) return _resolved!;

  final target = supportDir ?? await getApplicationSupportDirectory();
  if (!target.existsSync()) target.createSync(recursive: true);

  final legacy = documentsDir ?? await getApplicationDocumentsDirectory();
  _resolved = _migrateIfNeeded(legacy: legacy, target: target);
  return _resolved!;
}

/// Chemin complet de la base locale.
Future<String> localDbPath() async => p.join((await localDataDir()).path, kLocalDbName);

/// Dossier de la file d'attente d'envoi, créé s'il manque.
Future<Directory> outboxDir() async {
  final dir = Directory(p.join((await localDataDir()).path, kOutboxDirName));
  if (!dir.existsSync()) dir.createSync(recursive: true);
  return dir;
}

/// Déplace, si besoin, la base et la file d'attente de [legacy] vers [target].
///
/// Renvoie le dossier à utiliser réellement : [target] en temps normal,
/// [legacy] si un déplacement a échoué — on ne laisse jamais l'application
/// ouvrir une base vide à côté d'une base pleine.
Directory _migrateIfNeeded({
  required Directory legacy,
  required Directory target,
}) {
  // Même dossier (certaines plateformes les confondent) : rien à faire.
  if (p.equals(legacy.path, target.path)) return target;

  final legacyDb = File(p.join(legacy.path, kLocalDbName));
  final targetDb = File(p.join(target.path, kLocalDbName));

  // Le nouvel emplacement fait foi dès qu'il porte une base : soit
  // l'installation est neuve, soit la reprise a déjà eu lieu.
  if (targetDb.existsSync()) return target;
  if (!legacyDb.existsSync()) return target;

  try {
    // La base ET ses fichiers annexes. Déplacer `epilote_v3.db` sans son
    // `-wal` perdrait les dernières transactions, qui n'y sont pas encore
    // reportées — exactement le travail hors ligne le plus récent.
    for (final entity in legacy.listSync()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (!name.startsWith(kLocalDbName)) continue;
      entity.renameSync(p.join(target.path, name));
    }

    final legacyOutbox = Directory(p.join(legacy.path, kOutboxDirName));
    if (legacyOutbox.existsSync()) {
      final targetOutbox = Directory(p.join(target.path, kOutboxDirName));
      if (!targetOutbox.existsSync()) targetOutbox.createSync(recursive: true);
      for (final entity in legacyOutbox.listSync()) {
        if (entity is! File) continue;
        entity.renameSync(p.join(targetOutbox.path, p.basename(entity.path)));
      }
      // Le dossier vide part aussi ; s'il ne l'est pas, on le laisse plutôt
      // que de supprimer un fichier qu'on n'a pas su déplacer.
      try {
        legacyOutbox.deleteSync();
      } catch (_) {/* reste non vide : on n'insiste pas */}
    }
    return target;
  } catch (_) {
    // ⚠️ Repli délibéré sur l'ancien emplacement. Un déplacement partiel
    // laisserait la base d'un côté et son journal de l'autre ; rouvrir
    // l'ancien dossier est le seul choix qui ne perd rien.
    return legacy;
  }
}

/// Réinitialise la résolution — réservé aux tests.
void resetLocalDataDirForTest() => _resolved = null;
