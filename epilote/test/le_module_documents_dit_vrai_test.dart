import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE MODULE DOCUMENTS DIT CE QU'IL FAIT
//
//  Cinq défauts, tous invisibles à l'écran : les papiers sortaient, les listes
//  s'affichaient, les suppressions semblaient aboutir. Ce qui manquait ne se
//  voyait qu'AILLEURS — chez le destinataire du PDF, à la page 2 d'un registre
//  imprimé, dans un Storage que personne n'ouvre, ou six mois plus tard quand
//  une famille revient chercher un certificat.
//
//  C'est la forme de défaut que seul un test de SOURCE attrape : il n'y a rien
//  à calculer, juste un appel qui doit exister.
// ════════════════════════════════════════════════════════════════════════════

String _lire(String chemin) =>
    File(chemin).readAsStringSync().replaceAll('\r\n', '\n');

void main() {
  group('Un export dit ce qui est à l’écran', () {
    test('chaque vue de Documents exporte la sienne', () {
      final src = _lire('lib/features/students/screens/documents_screen.dart');
      // En vue « Registre », l'en-tête comptait des PIÈCES et le bouton PDF
      // sortait la liste des DOSSIERS par élève, titrée « Dossiers
      // documentaires ». L'agent croyait imprimer ce qu'il voyait.
      expect(src, contains('onExportPdf: _byStudent'),
          reason: 'L’export ne suit pas la vue affichée.');
      expect(src, contains('_previewRegistrePdf(filteredDocs)'));
    });

    test('le registre des pièces a son propre document', () {
      expect(_lire('lib/features/students/services/documents_pdf_service.dart'),
          contains('buildRegistrePdf'));
    });

    test('un extrait filtré s’annonce comme tel', () {
      // Sans cette ligne, « cartes scolaires, nom contenant Bakala » se
      // présente exactement comme le registre entier — et c'est sur ce papier
      // que quelqu'un conclura qu'un document n'a jamais été délivré.
      final src = _lire('lib/features/students/screens/registre_screen.dart');
      expect(src, contains('Extrait filtré'));
    });
  });

  group('Les trois documents réglementaires savent sortir', () {
    test('le registre des délivrances s’imprime', () {
      // C'était le seul des trois sans sortie — et c'est celui qu'on réclame de
      // l'extérieur : « qui a délivré ce papier, et quand ? »
      expect(_lire('lib/features/students/screens/registre_screen.dart'),
          contains('showPdfPreviewDialog'));
      expect(
          File('lib/features/students/services/'
                  'registre_documents_pdf_service.dart')
              .existsSync(),
          isTrue);
    });

    test('le registre matricule répète ses en-têtes page après page', () {
      // Treize colonnes, 800 élèves, ~20 pages : une seule portait les
      // intitulés. « Cette date, c'est l'entrée ou la sortie ? », sur une pièce
      // réglementaire qu'on ne peut pas annoter pour rattraper.
      final src = _lire('lib/features/students/services/'
          'registre_matricule_pdf_service.dart');
      expect(src, contains('repeat: true'),
          reason: 'L’en-tête du grand livre ne se répète pas.');
    });
  });

  group('Ce qu’on retire du dossier disparaît vraiment', () {
    test('supprimer une pièce met son fichier en file de suppression', () {
      // La ligne partait, le fichier restait — un acte de naissance, un
      // certificat médical, la photo d'un enfant — servi à qui détenait encore
      // une URL signée, pendant que l'école se croyait quitte.
      final src =
          _lire('lib/features/students/providers/documents_provider.dart');
      expect(src, contains('enqueueStorageDeletion'));
      expect(src.contains('le fichier Storage reste orphelin'), isFalse,
          reason: 'Le commentaire décrivant le défaut est encore là.');
    });

    test('la file de suppression se vide au retour du réseau', () {
      expect(_lire('lib/services/powersync/powersync_service.dart'),
          contains('flushStorageDeletions'),
          reason: 'Une file qu’aucun retour de réseau ne draine ne sert à '
              'rien : le fichier resterait au Storage.');
    });

    test('un fichier jamais parti n’est pas téléversé pour être supprimé', () {
      // Sur un réseau congolais parfois facturé au mégaoctet, faire voyager un
      // fichier dont personne ne veut plus serait une faute.
      expect(_lire('lib/services/powersync/upload_outbox.dart'),
          contains('DELETE FROM upload_outbox WHERE id = ?'));
    });
  });

  group('Le certificat de radiation se réémet', () {
    test('le geste existe hors du moment de la sortie', () {
      // `delivrerCertificatRadiation` n'avait qu'UN appelant : `sortirEleve`.
      // Passé ce moment, une famille qui revient — bourse, inscription
      // ailleurs, équivalence — repartait les mains vides.
      expect(
          _lire('lib/features/students/services/eleve_cycle_actions.dart'),
          contains('Future<void> certificatRadiationEleve'));
    });

    test('le menu ne l’offre qu’à un élève sorti', () {
      expect(_lire('lib/features/students/widgets/eleve_actions_menu.dart'),
          contains('peutReclamerRadiation(cible)'));
    });

    test('le motif et la date se relisent, ils ne se redemandent pas', () {
      // Les ressaisir ferait diverger deux exemplaires du même certificat — et
      // c'est l'école d'accueil qui lirait deux vérités.
      final src =
          _lire('lib/features/students/services/eleve_cycle_actions.dart');
      expect(src, contains("row['withdrawal_motif']"));
      expect(src, contains("row['withdrawal_date']"));
    });
  });
}
