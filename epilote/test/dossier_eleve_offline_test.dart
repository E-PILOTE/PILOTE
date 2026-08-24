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
