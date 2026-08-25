import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  UNE PIÈCE DU DOSSIER SE DÉPOSE HORS LIGNE — PAR UN SEUL CHEMIN.
//
//  ── CE QUE CE TEST GARDE ───────────────────────────────────────────────────
//  `student_document_upload.dart` s'annonce depuis son écriture comme « le
//  chemin unique, offline-first » vers `student_documents`. Il l'était pour
//  Examens et pour Stages. Le module qui POSSÈDE la table — l'assistant
//  d'inscription et la page Documents — ne l'empruntait pas : il envoyait à
//  Supabase Storage en direct et répondait « Téléversement impossible
//  (connexion requise) » dès qu'il n'y avait pas de réseau.
//
//  Sur une plateforme offline-first destinée aux écoles congolaises, cela
//  voulait dire : on inscrit l'élève sans connexion, mais on ne peut joindre
//  ni son acte de naissance, ni sa photo d'identité, ni son certificat
//  médical — les trois pièces qui font justement qu'un dossier est complet.
//  Il fallait revenir, avec du réseau, refaire le geste.
//
//  ── LES DEUX MOITIÉS, ET POURQUOI ELLES SONT DEUX ──────────────────────────
//  `attachStudentDocumentOffline` met les octets en file ET écrit la ligne :
//  c'est le geste normal, quand l'élève existe déjà.
//
//  `queueStudentDocumentFile` ne met que les octets. L'assistant s'en sert à
//  l'étape 4 parce que l'élève n'est créé qu'à l'enregistrement : écrire la
//  ligne plus tôt la placerait dans la file PowerSync AVANT l'insertion de
//  `students`, le serveur refuserait sur la clé étrangère (`23503`), et le
//  connecteur tenant ce code pour fatal abandonnerait le LOT ENTIER — l'élève,
//  ses tuteurs et son inscription avec, sans un message.
//
//  ── POURQUOI SUR LE TEXTE SOURCE ───────────────────────────────────────────
//  Le défaut ne se voit qu'en coupant le réseau d'un vrai poste, avec une base
//  PowerSync vivante. Aucun test unitaire ne l'attrape ; ce qui se garde, c'est
//  la FORME. Même parti pris que `offline_booleen_test.dart` et
//  `perimetre_scolarite_test.dart`.
// ════════════════════════════════════════════════════════════════════════════

const _kService = 'lib/services/powersync/student_document_upload.dart';
const _kAssistant = 'lib/features/students/screens/add_inscription_steps_3_5.dart';
const _kDetailDossier = 'lib/features/students/screens/documents_detail.dart';
const _kAvatar = 'lib/services/powersync/avatar_upload.dart';
const _kEditRegistre = 'lib/features/students/screens/eleves_edit.dart';
const _kEditGuichet = 'lib/features/students/screens/inscriptions_edit.dart';

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) {
    fail('$chemin introuvable — le test tourne-t-il depuis `epilote/` ? '
        'Si le fichier a été déplacé, mettre ce test à jour dans le même '
        'geste : c\'est lui qui dit où se dépose une pièce.');
  }
  return f.readAsStringSync();
}

List<File> _dartsSous(String chemin) => Directory(chemin)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList()
  ..sort((a, b) => a.path.compareTo(b.path));

void main() {
  group('Le dépôt d\'une pièce ne demande pas le réseau', () {
    test('l\'assistant met les OCTETS en file, jamais la ligne', () {
      final src = _lire(_kAssistant);
      expect(src.contains('queueStudentDocumentFile('), isTrue,
          reason: 'L\'étape 4 doit passer par `queueStudentDocumentFile` : '
              'sans réseau, la famille repart sans avoir pu déposer une seule '
              'pièce.');
      expect(src.contains('insertStudentDocumentRow('), isFalse,
          reason: 'La ligne `student_documents` ne doit PAS s\'écrire à '
              'l\'étape 4 : l\'élève n\'existe pas encore, le serveur '
              'refuserait sur la clé étrangère et PowerSync abandonnerait le '
              'lot entier — l\'élève compris.');
    });

    test('la page Documents dépose d\'un seul geste', () {
      final src = _lire(_kDetailDossier);
      expect(src.contains('attachStudentDocumentOffline('), isTrue,
          reason: 'Ici l\'élève existe : les octets et la ligne partent '
              'ensemble.');
    });

    test('la consultation retombe sur le fichier local tant qu\'il attend', () {
      final src = _lire(_kDetailDossier);
      expect(src.contains('pendingFileFor('), isTrue,
          reason: 'Une pièce déposée hors ligne n\'a pas encore d\'URL signée, '
              'mais elle est sur le poste — c\'est l\'agent qui vient de la '
              'déposer. Lui répondre « aperçu indisponible » serait absurde.');
    });
  });

  group('La photo de l\'élève se prend hors ligne', () {
    // C'était le dernier fichier du module à exiger le réseau. Tout le reste
    // de la fiche s'enregistrait très bien sans connexion ; seule la photo
    // répondait « reprenez-la plus tard » — donc, en pratique, jamais.
    test('les deux éditeurs passent par la file', () {
      for (final chemin in [_kEditRegistre, _kEditGuichet]) {
        final src = _lire(chemin);
        expect(src.contains('queueAvatarUpload('), isTrue,
            reason: '$chemin doit mettre la photo en file, pas l\'envoyer.');
        expect(src.contains('uploadStudentPhoto('), isFalse,
            reason: '$chemin ne doit plus appeler l\'ancien chemin en ligne.');
      }
    });

    test('l\'URL publique se calcule SANS réseau', () {
      // `getPublicUrl` est une simple concaténation : c'est ce qui permet
      // d'écrire l'URL DÉFINITIVE dans `students.photo_url` avant même que le
      // fichier n'existe, puis de laisser la file le poser à ce chemin exact.
      // Un `await` sur le client Storage trahirait un aller-retour réseau, et
      // toute la mécanique tomberait avec lui.
      final src = _lire(_kAvatar);
      expect(src.contains('await client.storage'), isFalse,
          reason: 'Aucune attente réseau ne doit s\'intercaler : l\'URL doit '
              'rester calculable hors ligne.');
      expect(src.contains('getPublicUrl('), isTrue);
      expect(src.contains('enqueueUpload('), isTrue);
    });

    test('la pastille montre le fichier local tant qu\'il attend', () {
      // Sans cela, l'agent qui vient de prendre la photo verrait un avatar
      // cassé — l'URL publique désigne un objet pas encore téléversé — et
      // conclurait que son geste a échoué.
      final src = _lire('lib/core/widgets/photo_avatar.dart');
      expect(src.contains('FileImage('), isTrue);
      expect(src.contains('fichierLocalEnAttente('), isTrue);
      // ⚠️ ET la file se lit en UNE fois. Chercher par pastille ferait deux
      // cents requêtes sur une liste de personnel, et autant à chaque
      // reconstruction — c'est pourquoi la variante par-appel a été retirée.
      expect(src.contains('pendingUploadPathsProvider'), isTrue);
    });

    test('l\'ancien chemin en ligne de la photo a disparu', () {
      final fautes = <String>[];
      for (final f in _dartsSous('lib')) {
        final lignes = f.readAsLinesSync();
        for (var i = 0; i < lignes.length; i++) {
          final nu = lignes[i].trimLeft();
          if (nu.startsWith('//') || nu.startsWith('*')) continue;
          if (lignes[i].contains('uploadStudentPhoto')) {
            fautes.add('${f.path}:${i + 1}');
          }
        }
      }
      expect(fautes, isEmpty,
          reason: 'Ne pas réintroduire `uploadStudentPhoto` : il envoyait à '
              'Storage en direct.\n\n${fautes.join('\n')}');
    });
  });

  group('Ce qui peut être compressé l\'est', () {
    test('la note vocale s\'encode en mono, à débit parlé', () {
      // Seul fichier qu'aucun compresseur ne peut reprendre après coup :
      // `compressForUpload` ne traite que ce qu'il sait décoder — images et
      // vidéo. Un AAC déjà encodé lui passe entre les doigts. Le levier est
      // donc à l'encodage, et nulle part ailleurs.
      final src = _lire('lib/features/communication/widgets/audio_recorder_button.dart');
      expect(src.contains('numChannels: 1'), isTrue,
          reason: 'Une voix en stéréo, c\'est deux fois le même canal.');
      expect(RegExp(r'bitRate:\s*(\d+)').firstMatch(src), isNotNull);
      final debit = int.parse(
          RegExp(r'bitRate:\s*(\d+)').firstMatch(src)!.group(1)!);
      expect(debit, lessThanOrEqualTo(48000),
          reason: 'Au-delà de 48 kbps on encode de la musique, pas de la '
              'parole — et la file d\'envoi dort parfois des jours sur le '
              'disque d\'un poste partagé.');
    });

    test('l\'archive d\'examen n\'est PAS compressée', () {
      // L'exception, et elle est délibérée : son empreinte SHA-256 est ce qui
      // prouve, des années plus tard, que la pièce opposable n'a pas bougé.
      // Ré-encoder changerait les octets, donc l'empreinte, donc la valeur
      // probante. Ce test existe pour qu'un futur « on compresse tout » ne
      // l'emporte pas par mégarde.
      final src = _lire(
          'lib/features/admin_groupe/providers/exam_archives_provider.dart');
      expect(src.contains('sha256.convert(bytes)'), isTrue,
          reason: 'L\'empreinte doit porter sur les octets DÉPOSÉS.');
      expect(src.contains('compressForUpload('), isFalse,
          reason: 'Compresser ici détruirait la valeur probante de l\'archive.');
    });
  });

  group('Un seul chemin, et il est unique', () {
    test('le chemin Storage se calcule à un seul endroit', () {
      final src = _lire(_kService);
      final gabarit = RegExp(r'\$schoolId/\$studentId/');
      expect(gabarit.allMatches(src).length, 1,
          reason: 'Un second endroit qui compose le chemin, c\'est un fichier '
              'et sa ligne qui finissent par ne plus se retrouver.');
      expect(src.contains('await queueStudentDocumentFile('), isTrue,
          reason: '`attachStudentDocumentOffline` doit déléguer la mise en '
              'file, pas la recopier.');
    });

    test('rien n\'envoie une pièce à Storage en direct', () {
      // `avatars` (photo de profil, bucket PUBLIC) n'est pas concerné : ce
      // n'est pas une pièce du dossier, et son échec est déjà non bloquant.
      // Seul le bucket privé des pièces est verrouillé ici, et seule
      // `upload_outbox` a le droit d'y écrire.
      final fautes = <String>[];
      for (final f in _dartsSous('lib/features/students')) {
        final lignes = f.readAsLinesSync();
        for (var i = 0; i < lignes.length; i++) {
          final l = lignes[i];
          if (l.contains('uploadBinary') && !l.contains("'avatars'")) {
            fautes.add('${f.path}:${i + 1}  ${l.trim()}');
          }
        }
      }
      expect(fautes, isEmpty,
          reason: 'Une pièce du dossier se dépose par '
              '`attachStudentDocumentOffline` / `queueStudentDocumentFile`, '
              'qui passent par `upload_outbox`. Un envoi direct rend le geste '
              'impossible hors réseau.\n\n${fautes.join('\n')}');
    });

    test('l\'ancien chemin en ligne n\'existe plus nulle part', () {
      // Il a été RETIRÉ, pas laissé de côté : une fonction publique qui fait
      // presque la bonne chose est un piège dormant, et c'est par elle que ce
      // module était devenu le seul des trois à ne pas savoir travailler hors
      // ligne.
      //
      // ⚠️ On vise le CODE, pas les commentaires : le nom doit rester
      // prononçable dans l'explication qui dit pourquoi il a disparu. Une
      // règle qui interdit d'écrire son propre motif se fait contourner en
      // effaçant le motif.
      final fautes = <String>[];
      for (final f in _dartsSous('lib')) {
        final lignes = f.readAsLinesSync();
        for (var i = 0; i < lignes.length; i++) {
          final l = lignes[i];
          final nu = l.trimLeft();
          if (nu.startsWith('//') || nu.startsWith('*')) continue;
          if (l.contains('uploadStudentDocumentFile')) {
            fautes.add('${f.path}:${i + 1}  ${l.trim()}');
          }
        }
      }
      expect(fautes, isEmpty,
          reason: 'Ne pas réintroduire `uploadStudentDocumentFile` : il '
              'envoyait à Storage en direct.\n\n${fautes.join('\n')}');
    });
  });
}
