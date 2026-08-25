import 'package:flutter_test/flutter_test.dart';

import 'package:epilote/features/examens/models/dossier_piece_state.dart';
import 'package:epilote/features/examens/models/exam_dossier_piece.dart';

// ════════════════════════════════════════════════════════════════════════════
//  DÉRIVATION DU DOSSIER — la règle qui décide si un élève compose.
//
//  Une erreur ici coûte une année scolaire : soit on déclare complet un dossier
//  qui sera rejeté au comptoir, soit on bloque un candidat dont le dossier est
//  en règle. D'où ces cas, écrits avant l'implémentation.
// ════════════════════════════════════════════════════════════════════════════

ExamDossierPiece _piece(
  String code, {
  PieceNature nature = PieceNature.fichier,
  String? condition,
}) =>
    ExamDossierPiece(
      code: code,
      label: code,
      copies: 1,
      nature: nature,
      source: PieceSource.eleve,
      legalise: false,
      condition: condition,
    );

Set<String> _missingCodes(List<ExamDossierPiece> pieces) =>
    pieces.map((p) => p.code).toSet();

void main() {
  group('deriveMissing', () {
    test('une pièce fichier attachée n\'est plus manquante', () {
      final missing = deriveMissing(
        required: [_piece('acte_naissance')],
        attachedCodes: {'acte_naissance'},
        declaredCodes: const {},
        stageIssued: false,
      );
      expect(missing, isEmpty);
    });

    test('une pièce fichier ni attachée ni déclarée est manquante', () {
      final missing = deriveMissing(
        required: [_piece('acte_naissance')],
        attachedCodes: const {},
        declaredCodes: const {},
        stageIssued: false,
      );
      expect(_missingCodes(missing), {'acte_naissance'});
    });

    // Rétrocompatibilité : les dossiers déjà cochés complets AVANT l'arrivée des
    // fichiers doivent le rester. Sinon on invaliderait d'un coup tous les
    // dossiers du pays.
    test('une pièce fichier seulement DÉCLARÉE reste non manquante', () {
      final missing = deriveMissing(
        required: [_piece('acte_naissance')],
        attachedCodes: const {},
        declaredCodes: {'acte_naissance'},
        stageIssued: false,
      );
      expect(missing, isEmpty);
    });

    test('une pièce physique cochée n\'est pas manquante, non cochée l\'est', () {
      final chemise = _piece('chemise', nature: PieceNature.physique);

      expect(
        deriveMissing(
          required: [chemise],
          attachedCodes: const {},
          declaredCodes: {'chemise'},
          stageIssued: false,
        ),
        isEmpty,
      );

      expect(
        _missingCodes(deriveMissing(
          required: [chemise],
          attachedCodes: const {},
          declaredCodes: const {},
          stageIssued: false,
        )),
        {'chemise'},
      );
    });

    // Nous ne savons pas qui est inapte à l'EPS. Exiger la pièce de tous rendrait
    // tout dossier éternellement incomplet ; la DEC tranche au comptoir.
    test('une pièce conditionnelle n\'est JAMAIS manquante', () {
      final missing = deriveMissing(
        required: [_piece('certificat_inaptitude', condition: 'si_inapte_eps')],
        attachedCodes: const {},
        declaredCodes: const {},
        stageIssued: false,
      );
      expect(missing, isEmpty);
    });

    test('attestation_stage émise par le module Stages n\'est pas manquante', () {
      final required = [_piece(kStagePieceCode)];

      expect(
        deriveMissing(
          required: required,
          attachedCodes: const {},
          declaredCodes: const {},
          stageIssued: true,
        ),
        isEmpty,
      );

      expect(
        _missingCodes(deriveMissing(
          required: required,
          attachedCodes: const {},
          declaredCodes: const {},
          stageIssued: false,
        )),
        {kStagePieceCode},
      );
    });

    test('aucune exigence → aucun manquant', () {
      expect(
        deriveMissing(
          required: const [],
          attachedCodes: const {},
          declaredCodes: const {},
          stageIssued: false,
        ),
        isEmpty,
      );
    });

    test('mélange réaliste : seules les pièces non couvertes remontent', () {
      final missing = deriveMissing(
        required: [
          _piece('acte_naissance'), // attachée
          _piece('diplome'), // rien → manquante
          _piece('enveloppe', nature: PieceNature.physique), // cochée
          _piece('frais', nature: PieceNature.financiere), // rien → manquante
          _piece('inaptitude', condition: 'si_inapte_eps'), // jamais
          _piece(kStagePieceCode), // via Stages
        ],
        attachedCodes: {'acte_naissance'},
        declaredCodes: {'enveloppe'},
        stageIssued: true,
      );
      expect(_missingCodes(missing), {'diplome', 'frais'});
    });
  });

  // Le vrai danger d'une recomposition : perdre en silence une case cochée
  // avant l'arrivée des fichiers. Ces tests verrouillent l'aller-retour.
  group('recoverDeclared ↔ deriveMissing (aller-retour)', () {
    test('une déclaration antérieure survit à une recomposition', () {
      final required = [_piece('acte_naissance'), _piece('diplome')];
      // État stocké : seul `diplome` manque → `acte_naissance` avait été coché.
      final declared = recoverDeclared(
        required: required,
        previousMissing: {'diplome'},
        attachedCodes: const {},
      );
      expect(declared, {'acte_naissance'});

      final missing = deriveMissing(
        required: required,
        attachedCodes: const {},
        declaredCodes: declared,
        stageIssued: false,
      );
      expect(_missingCodes(missing), {'diplome'},
          reason: 'la recomposition doit reproduire l\'état stocké');
    });

    test('recomposer plusieurs fois de suite est stable', () {
      final required = [
        _piece('acte_naissance'),
        _piece('diplome'),
        _piece('enveloppe', nature: PieceNature.physique),
      ];
      var missing = {'diplome'};

      for (var i = 0; i < 3; i++) {
        final declared = recoverDeclared(
          required: required,
          previousMissing: missing,
          attachedCodes: const {},
        );
        missing = _missingCodes(deriveMissing(
          required: required,
          attachedCodes: const {},
          declaredCodes: declared,
          stageIssued: false,
        ));
      }
      expect(missing, {'diplome'});
    });

    test('joindre un fichier ne fait pas perdre les autres déclarations', () {
      final required = [_piece('acte_naissance'), _piece('diplome')];
      // Avant : les deux étaient cochées (rien ne manque).
      final declared = recoverDeclared(
        required: required,
        previousMissing: const {},
        attachedCodes: {'acte_naissance'}, // on vient d'attacher celle-ci
      );
      // `diplome` reste déclarée ; `acte_naissance` est passée au fichier.
      expect(declared, {'diplome'});

      expect(
        deriveMissing(
          required: required,
          attachedCodes: {'acte_naissance'},
          declaredCodes: declared,
          stageIssued: false,
        ),
        isEmpty,
        reason: 'un dossier complet ne doit pas redevenir incomplet',
      );
    });

    test('une pièce conditionnelle n\'est jamais réputée déclarée', () {
      expect(
        recoverDeclared(
          required: [_piece('inaptitude', condition: 'si_inapte_eps')],
          previousMissing: const {},
          attachedCodes: const {},
        ),
        isEmpty,
      );
    });
  });

  group('PieceFileState', () {
    test('un fichier vérifié est vérifié, non vérifié est fourni', () {
      const attached = AttachedPiece(
        documentId: 'd1',
        code: 'acte_naissance',
        fileUrl: 'school/eleve/acte.pdf',
        fileName: 'acte.pdf',
        isVerified: false,
      );
      expect(attached.state, PieceFileState.fournie);
      expect(
        AttachedPiece(
          documentId: attached.documentId,
          code: attached.code,
          fileUrl: attached.fileUrl,
          fileName: attached.fileName,
          isVerified: true,
        ).state,
        PieceFileState.verifiee,
      );
    });

    test('pieceStateFor : absente, déclarée, fournie, vérifiée', () {
      const attached = AttachedPiece(
        documentId: 'd1',
        code: 'acte_naissance',
        fileUrl: 'u',
        fileName: 'f',
        isVerified: false,
      );

      expect(pieceStateFor(attached: null, declared: false),
          PieceFileState.absente);
      expect(pieceStateFor(attached: null, declared: true),
          PieceFileState.declaree);
      expect(pieceStateFor(attached: attached, declared: false),
          PieceFileState.fournie);
    });
  });
}
