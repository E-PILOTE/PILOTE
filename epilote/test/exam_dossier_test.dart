import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:epilote/features/examens/models/exam_dossier_piece.dart';
import 'package:epilote/features/examens/providers/exam_dossier_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Pièces du dossier d'examen — la note officielle METP (migration 0052).
//
//  Ce fichier verrouille surtout UNE régression : une pièce conditionnelle ne
//  doit JAMAIS bloquer la complétude. Le modèle plat d'origine copiait toutes
//  les pièces requises dans `missing_documents` — avec le certificat médical
//  d'inaptitude, plus AUCUN dossier de bac n'aurait jamais pu être complet.
// ════════════════════════════════════════════════════════════════════════════

/// Le dossier réel du BAC_T tel que la migration 0052 l'écrit en base.
const _bacT = '''[
  {"code":"acte_naissance","label":"Photocopie d'acte de naissance","copies":2,"nature":"fichier","source":"eleve"},
  {"code":"diplome_anterieur","label":"Copie légalisée du diplôme","copies":2,"nature":"fichier","source":"eleve","legalise":true},
  {"code":"photos","label":"Photos d'identité couleur","copies":4,"nature":"fichier","source":"eleve"},
  {"code":"attestation_stage","label":"Attestation de fin de stage","copies":1,"nature":"fichier","source":"candidature"},
  {"code":"certificat_medical","label":"Certificat médical d'inaptitude","copies":1,"nature":"fichier","source":"candidature","condition":"si_inapte_eps"},
  {"code":"chemise","label":"Chemise cartonnée","copies":1,"nature":"physique"},
  {"code":"enveloppe","label":"Enveloppe kaki format A4","copies":1,"nature":"physique"},
  {"code":"frais","label":"Frais d'inscription","copies":1,"nature":"financiere","source":"candidature"}
]''';

CandidateDossier _dossier(List<ExamDossierPiece> required, Set<String> missing) =>
    CandidateDossier(
      candidateId: 'c1',
      studentId: 's1',
      groupId: 'g1',
      schoolId: 'e1',
      fullName: 'Élève Test',
      examShortName: 'Bac T',
      status: 'incomplet',
      pieces: [
        for (final p in required)
          DossierPieceState(
            piece: p,
            provided: p.isConditional ? false : !missing.contains(p.code),
          ),
      ],
    );

void main() {
  group('ExamDossierPiece.parseList', () {
    test('lit le dossier réel du BAC_T (8 pièces)', () {
      expect(ExamDossierPiece.parseList(_bacT).length, 8);
    });

    test('accepte une liste déjà décodée autant qu\'une chaîne jsonb', () {
      final asString = ExamDossierPiece.parseList(_bacT);
      final asList = ExamDossierPiece.parseList(jsonDecode(_bacT));
      expect(asList.map((p) => p.code), asString.map((p) => p.code));
    });

    test('ne plante jamais sur une donnée molle', () {
      for (final raw in [null, '', '   ', '[]', 'null', 42, {'x': 1}]) {
        expect(ExamDossierPiece.parseList(raw), isEmpty, reason: 'raw=$raw');
      }
    });

    test('écarte les entrées sans code plutôt que de créer des pièces vides', () {
      final p = ExamDossierPiece.parseList('[{"label":"orpheline"},{"code":"ok"}]');
      expect(p.map((e) => e.code), ['ok']);
    });

    test('défauts rétrocompatibles : sessions MEPSA sans nature ni source', () {
      // CEPE/BEPC/BAC_G n'ont pas été retouchés faute de source.
      final p = ExamDossierPiece.parseList(
          '[{"code":"acte_naissance","label":"Acte de naissance","copies":1}]').single;
      expect(p.nature, PieceNature.fichier);
      expect(p.source, PieceSource.eleve);
      expect(p.legalise, isFalse);
      expect(p.isConditional, isFalse);
    });

    test('nature, source, légalisation et condition sont lues', () {
      final byCode = {
        for (final p in ExamDossierPiece.parseList(_bacT)) p.code: p,
      };
      expect(byCode['chemise']!.nature, PieceNature.physique);
      expect(byCode['frais']!.nature, PieceNature.financiere);
      expect(byCode['attestation_stage']!.source, PieceSource.candidature);
      expect(byCode['diplome_anterieur']!.legalise, isTrue);
      expect(byCode['acte_naissance']!.legalise, isFalse);
      expect(byCode['certificat_medical']!.isConditional, isTrue);
      expect(byCode['acte_naissance']!.isConditional, isFalse);
    });

    test('aller-retour encode/parse conservateur', () {
      final origin = ExamDossierPiece.parseList(_bacT);
      final back = ExamDossierPiece.parseList(
          ExamDossierPiece.encodeList(origin));
      expect(back.map((p) => p.code), origin.map((p) => p.code));
      expect(back.firstWhere((p) => p.code == 'certificat_medical').condition,
          'si_inapte_eps');
      expect(
          back.firstWhere((p) => p.code == 'chemise').nature, PieceNature.physique);
    });
  });

  group('CandidateDossier — la complétude', () {
    final required = ExamDossierPiece.parseList(_bacT);

    test('RÉGRESSION : une pièce conditionnelle ne bloque jamais la complétude',
        () {
      // Toutes les pièces dues sont là ; le certificat médical, lui, n'est pas
      // fourni — et ne doit rien empêcher. C'est le bug que le modèle plat
      // aurait créé : aucun dossier de bac jamais complet dans tout le pays.
      final d = _dossier(required, {});
      expect(d.missingCount, 0);
      expect(d.isComplete, isTrue);
    });

    test('les conditionnelles sont écartées des pièces qui décident', () {
      final d = _dossier(required, {});
      expect(d.mandatory.length, 7);
      expect(d.conditional.map((p) => p.piece.code), ['certificat_medical']);
    });

    test('une pièce due manquante rend le dossier incomplet', () {
      final d = _dossier(required, {'attestation_stage'});
      expect(d.missingCount, 1);
      expect(d.isComplete, isFalse);
    });

    test('une pièce PHYSIQUE compte comme les autres (chemise, enveloppe)', () {
      // Elles ne seront jamais un fichier : seule la déclaration les fournit.
      final d = _dossier(required, {'chemise', 'enveloppe'});
      expect(d.missingCount, 2);
    });

    test('une conditionnelle n\'est jamais présentée comme fournie', () {
      // La déduire « fournie » de son absence de `missing` serait un mensonge
      // par construction : elle n'a pas d'état.
      final d = _dossier(required, {});
      expect(d.conditional.single.provided, isFalse);
    });

    test('un dossier déposé est reconnu comme tel (retrait interdit)', () {
      for (final s in ['depose', 'valide']) {
        final d = CandidateDossier(
            candidateId: 'c', studentId: 's', groupId: 'g', schoolId: 'e',
            fullName: 'X', examShortName: 'Bac T',
            status: s, pieces: const []);
        expect(d.isSubmitted, isTrue, reason: s);
      }
      final d = const CandidateDossier(
          candidateId: 'c', studentId: 's', groupId: 'g', schoolId: 'e',
          fullName: 'X', examShortName: 'Bac T',
          status: 'complet', pieces: []);
      expect(d.isSubmitted, isFalse);
    });

    test('BET : aucun diplôme antérieur n\'est dû (il suit la 3e technique)', () {
      final bet = ExamDossierPiece.parseList('''[
        {"code":"acte_naissance","label":"Acte","copies":2,"nature":"fichier"},
        {"code":"photos","label":"Photos","copies":4,"nature":"fichier"},
        {"code":"certificat_medical","label":"Certificat","copies":1,"condition":"si_inapte_eps"},
        {"code":"chemise","label":"Chemise","copies":1,"nature":"physique"},
        {"code":"enveloppe","label":"Enveloppe","copies":1,"nature":"physique"},
        {"code":"frais","label":"Frais","copies":1,"nature":"financiere"}
      ]''');
      expect(bet.any((p) => p.code == 'diplome_anterieur'), isFalse);
      expect(bet.any((p) => p.legalise), isFalse);
      expect(_dossier(bet, {}).isComplete, isTrue);
    });
  });
}
