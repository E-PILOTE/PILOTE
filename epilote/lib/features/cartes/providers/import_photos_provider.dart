// ══════════════════════════════════════════════════════════════════════════════
//  IMPORTER LES PHOTOS — l'écriture, une fois que l'agent a vu le tableau
//
//  L'appariement (`services/appariement_photos.dart`) est pur et se teste ;
//  ici commence ce qui touche le disque et la base. Deux règles héritées de
//  l'import de listes, pour les mêmes raisons :
//
//   1. **On n'écrit RIEN avant que l'agent ait vu et validé le tableau.** Six
//      cents photos posées en silence puis découvertes fausses ne se défont
//      pas : il faudrait rouvrir six cents dossiers.
//   2. **Un échec isolé n'emporte pas le lot.** Un fichier corrompu au milieu
//      d'une classe ne doit pas annuler les trente-neuf autres. Chaque photo
//      vit et échoue seule, et le rapport final nomme celles qui ont manqué.
//
//  ── HORS LIGNE PAR CONSTRUCTION ────────────────────────────────────────────
//  `queueAvatarUpload` calcule l'URL publique définitive SANS réseau, pose les
//  octets sur le disque et les envoie au retour de la connexion. Une école qui
//  importe la rentrée un jour de coupure voit ses visages tout de suite ; ils
//  montent le lendemain.
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/powersync/avatar_upload.dart';
import '../../students/providers/students_provider.dart' show updateStudent;
import '../services/appariement_photos.dart';

/// Ce qu'est devenue une photo qu'on a essayé d'écrire.
class ResultatPhoto {
  const ResultatPhoto(this.eleve, this.fichier, {this.echec});
  final String eleve, fichier;

  /// `null` si la photo est passée.
  final String? echec;

  bool get reussi => echec == null;
}

class RapportImportPhotos {
  const RapportImportPhotos(this.resultats);
  final List<ResultatPhoto> resultats;

  int get reussis => resultats.where((r) => r.reussi).length;
  int get echoues => resultats.length - reussis;
  List<ResultatPhoto> get echecs =>
      resultats.where((r) => !r.reussi).toList();
}

/// Écrit les photos appariées : compression, mise en file, `students.photo_url`.
///
/// [onProgres] est appelée AVANT chaque photo, avec le rang (1-indexé) et le
/// nom de l'élève : un import de six cents fichiers dure des minutes, et une
/// barre qui n'avance pas se lit comme une application figée.
Future<RapportImportPhotos> ecrirePhotosImportees({
  required SupabaseClient client,
  required List<PhotoAppariee> apparies,
  void Function(int rang, int total, String eleve)? onProgres,
  bool Function()? interrompu,
}) async {
  final resultats = <ResultatPhoto>[];

  for (var i = 0; i < apparies.length; i++) {
    if (interrompu?.call() ?? false) break;

    final p = apparies[i];
    onProgres?.call(i + 1, apparies.length, p.eleve.fullName);

    try {
      final f = File(p.fichier.chemin);
      if (!f.existsSync()) {
        resultats.add(ResultatPhoto(p.eleve.fullName, p.fichier.nom,
            echec: 'Fichier introuvable'));
        continue;
      }

      final octets = await f.readAsBytes();
      if (octets.isEmpty) {
        resultats.add(ResultatPhoto(p.eleve.fullName, p.fichier.nom,
            echec: 'Fichier vide'));
        continue;
      }

      // `queueAvatarUpload` compresse AVANT la mise en file — hors ligne, ces
      // octets dorment sur le disque, parfois des jours.
      final url = await queueAvatarUpload(
        client: client,
        folder: 'students',
        ownerId: p.eleve.studentId,
        bytes: octets,
        ext: p.fichier.extension,
      );

      await updateStudent(studentId: p.eleve.studentId, photoUrl: url);
      resultats.add(ResultatPhoto(p.eleve.fullName, p.fichier.nom));
    } catch (e) {
      // Isolé : le fichier suivant a toutes ses chances.
      resultats.add(ResultatPhoto(p.eleve.fullName, p.fichier.nom,
          echec: e.toString()));
    }
  }

  return RapportImportPhotos(resultats);
}
