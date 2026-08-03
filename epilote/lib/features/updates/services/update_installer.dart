// ════════════════════════════════════════════════════════════════════════════
//  TÉLÉCHARGER, VÉRIFIER, PUIS SEULEMENT INSTALLER
//
//  ── LA VÉRIFICATION N'EST PAS UNE PRÉCAUTION, C'EST LA FONCTION ────────────
//  Une application qui télécharge un exécutable et le lance sans contrôler ce
//  qu'elle a reçu offre à quiconque intercepte la liaison le droit d'installer
//  ce qu'il veut sur mille postes de l'administration congolaise. L'empreinte
//  SHA-256 est comparée AVANT tout lancement, et un écart fait échouer la mise
//  à jour — jamais un avertissement qu'on peut ignorer.
//
//  ── LE FICHIER NE VA PAS DANS DOCUMENTS ────────────────────────────────────
//  Même raison que la base hors ligne : sous Windows, `Documents` est
//  fréquemment redirigé vers OneDrive, qui synchronise pendant l'écriture. On
//  écrit dans le dossier de support de l'application.
//
//  ── L'INSTALLATION FERME L'APPLICATION ─────────────────────────────────────
//  L'installateur remplace l'exécutable en cours d'exécution : il faut fermer.
//  D'où l'avertissement explicite avant de lancer — un secrétariat en pleine
//  saisie de rentrée doit pouvoir dire non.
// ════════════════════════════════════════════════════════════════════════════

import 'dart:io';

import 'package:convert/convert.dart' show AccumulatorSink;
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../../services/powersync/local_storage_dir.dart';
import '../providers/update_provider.dart';

/// Où en est le téléchargement, pour l'afficher sans mentir.
class ProgressionTelechargement {
  const ProgressionTelechargement(this.recus, this.total);
  final int recus;

  /// `null` quand le serveur n'annonce pas la taille : on montre alors une
  /// barre indéterminée plutôt qu'un pourcentage inventé.
  final int? total;

  double? get fraction =>
      (total == null || total! <= 0) ? null : (recus / total!).clamp(0.0, 1.0);
}

/// Ce qui peut mal se passer, dit en français à celui qui le lit.
class EchecMiseAJour implements Exception {
  const EchecMiseAJour(this.message);
  final String message;
  @override
  String toString() => message;
}

class UpdateInstaller {
  /// Dossier des téléchargements, à côté de la base — jamais dans Documents.
  static Future<Directory> dossier() async {
    final base = await localDataDir();
    final d = Directory(p.join(base.path, 'mises_a_jour'));
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  /// Télécharge l'installateur et rend son chemin, l'empreinte VÉRIFIÉE.
  ///
  /// Un fichier déjà présent et conforme n'est pas retéléchargé : sur une
  /// liaison congolaise, reprendre 34 Mo parce que l'application a été relancée
  /// est une punition.
  static Future<File> telecharger(
    AppRelease release, {
    void Function(ProgressionTelechargement)? onProgress,
    http.Client? client,
  }) async {
    final dir = await dossier();
    final cible = File(p.join(dir.path,
        'E-PILOTE-${release.version}-installateur.exe'));

    if (cible.existsSync() &&
        await _empreinte(cible) == release.sha256) {
      return cible;
    }

    final c = client ?? http.Client();
    final partiel = File('${cible.path}.part');
    try {
      final requete = http.Request('GET', Uri.parse(release.downloadUrl));
      final reponse = await c.send(requete);
      if (reponse.statusCode != 200) {
        throw EchecMiseAJour(
            'Le serveur a répondu ${reponse.statusCode}. Réessayez plus tard.');
      }

      final total = reponse.contentLength ?? release.sizeBytes;
      var recus = 0;
      final sortie = partiel.openWrite();
      try {
        await for (final morceau in reponse.stream) {
          sortie.add(morceau);
          recus += morceau.length;
          onProgress?.call(ProgressionTelechargement(recus, total));
        }
      } finally {
        await sortie.close();
      }

      // ⚠️ On vérifie AVANT de donner au fichier son nom définitif. Un
      // téléchargement interrompu ne doit jamais pouvoir passer pour complet.
      final empreinte = await _empreinte(partiel);
      if (empreinte != release.sha256) {
        await partiel.delete();
        throw const EchecMiseAJour(
            'Le fichier reçu ne correspond pas à celui qui a été publié. '
            'L’installation est annulée par sécurité.');
      }

      if (cible.existsSync()) await cible.delete();
      await partiel.rename(cible.path);
      return cible;
    } on EchecMiseAJour {
      rethrow;
    } catch (e) {
      if (partiel.existsSync()) {
        try {
          await partiel.delete();
        } catch (_) {/* le ménage n'est pas la priorité */}
      }
      throw EchecMiseAJour('Téléchargement impossible : $e');
    } finally {
      if (client == null) c.close();
    }
  }

  /// Lance l'installateur et rend la main. L'appelant ferme l'application.
  ///
  /// Aucun mode silencieux : l'agent doit voir ce qui s'installe sur son poste.
  /// Le déploiement en masse par la DSIC, lui, garde `/VERYSILENT` — mais il
  /// passe par le fichier, pas par ce chemin.
  static Future<void> lancer(File installateur) async {
    if (!Platform.isWindows) {
      throw const EchecMiseAJour(
          'L’installation automatique n’existe que sous Windows.');
    }
    if (!installateur.existsSync()) {
      throw const EchecMiseAJour('L’installateur téléchargé est introuvable.');
    }
    await Process.start(
      installateur.path,
      const ['/NORESTART'],
      mode: ProcessStartMode.detached,
    );
  }

  static Future<String> _empreinte(File f) async {
    // En flux : l'installateur pèse plus de 30 Mo, le charger entier en mémoire
    // sur un poste d'école à 4 Go est une mauvaise idée gratuite.
    final sortie = AccumulatorSink<Digest>();
    final entree = sha256.startChunkedConversion(sortie);
    await for (final morceau in f.openRead()) {
      entree.add(morceau);
    }
    entree.close();
    return sortie.events.single.toString();
  }
}
