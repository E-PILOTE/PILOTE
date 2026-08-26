import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:epilote/features/user/providers/rapports_provider.dart';
import 'package:epilote/features/user/services/rapport_effectifs.dart';
import 'package:epilote/features/user/services/rapport_pdf_service.dart';
import 'package:epilote/features/user/services/rapport_personnel.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LES ÉTATS OFFICIELS DOIVENT SORTIR — Y COMPRIS POUR UN GRAND LYCÉE
//
//  `official_pdf_kit.dart` documente le piège : un contenu qui ne sait pas se
//  scinder fait boucler `MultiPage` jusqu'à `TooManyPagesException`. Le
//  document ne sort alors PAS DU TOUT — pas tronqué : rien. Et ces deux états
//  grandissent avec l'école, donc le seuil se franchit chez le plus gros
//  établissement du réseau, en pleine transmission à la direction
//  départementale, jamais en démonstration.
//
//  Un lycée congolais de 1 800 élèves compte couramment une quarantaine de
//  classes sur trois cycles. C'est la charge testée ici : la normale.
// ════════════════════════════════════════════════════════════════════════════

EleveCompte _e({
  required String classe,
  required String cycle,
  required int ordre,
  String? sexe = 'M',
  bool interne = false,
  bool boursier = false,
  String? statut = kStatutInscrit,
}) =>
    (
      classId: 'id-$classe',
      className: classe,
      cycleCode: cycle,
      levelOrder: ordre,
      statut: statut,
      sexe: sexe,
      interne: interne,
      boursier: boursier,
    );

/// Un établissement de [classes] classes réparties sur trois cycles, chacune
/// à [parClasse] élèves.
EtatEffectifs _etablissement({int classes = 40, int parClasse = 45}) {
  const cycles = ['PRIMAIRE', 'COLLEGE', 'LYCEE'];
  final eleves = <EleveCompte>[];
  for (var c = 0; c < classes; c++) {
    for (var i = 0; i < parClasse; i++) {
      eleves.add(_e(
        classe: 'Classe ${c + 1}',
        cycle: cycles[c % cycles.length],
        ordre: c * 10,
        sexe: i % 3 == 0 ? 'F' : (i % 7 == 0 ? null : 'M'),
        interne: i % 9 == 0,
        boursier: i % 11 == 0,
      ));
    }
  }
  final lignes = effectifsParClasse(eleves);
  return (
    classes: lignes,
    blocs: blocsParCycle(lignes),
    total: cumul('TOTAL ÉTABLISSEMENT', lignes),
  );
}

LigneRecouvrement _r(int i) => (
      className: 'Classe ${i + 1}',
      effectif: 45,
      aJour: 30,
      du: 1350000,
      encaisse: 900000,
      reste: 450000,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('fr'));

  group('état des effectifs', () {
    test('un lycée de 40 classes produit un document', () async {
      final etat = _etablissement();
      expect(etat.total.total, 1800, reason: 'la charge testée est bien réelle');
      final bytes = await RapportPdfService.etatEffectifs(
          etat: etat, anneeLabel: '2025-2026');
      expect(bytes.length, greaterThan(1000));
    });

    test('un très grand établissement — 60 classes — sort aussi', () async {
      final bytes = await RapportPdfService.etatEffectifs(
          etat: _etablissement(classes: 60, parClasse: 60),
          anneeLabel: '2025-2026');
      expect(bytes.length, greaterThan(1000));
    });

    test('une école sans aucun élève produit quand même son état', () async {
      // Une école qui n'a encore inscrit personne doit pouvoir éditer un état
      // vide : c'est la pièce qui prouve qu'elle a ouvert.
      const vide = (
        classes: <LigneEffectif>[],
        blocs: <BlocCycle>[],
        total: (
          classId: '',
          className: 'TOTAL ÉTABLISSEMENT',
          cycleCode: null,
          levelOrder: 0,
          total: 0,
          filles: 0,
          garcons: 0,
          sexeInconnu: 0,
          internes: 0,
          boursiers: 0,
        ),
      );
      final bytes =
          await RapportPdfService.etatEffectifs(etat: vide, anneeLabel: null);
      expect(bytes.length, greaterThan(1000));
    });

    test('une année non renseignée ne fait pas échouer l\'édition', () async {
      final bytes = await RapportPdfService.etatEffectifs(
          etat: _etablissement(classes: 3, parClasse: 10), anneeLabel: null);
      expect(bytes.length, greaterThan(1000));
    });
  });

  group('état de recouvrement', () {
    test('40 classes produisent un document', () async {
      final bytes = await RapportPdfService.etatRecouvrement(
        lignes: [for (var i = 0; i < 40; i++) _r(i)],
        anneeLabel: '2025-2026',
        sansBareme: false,
      );
      expect(bytes.length, greaterThan(1000));
    });

    test('sans barème publié, le document sort avec son avertissement',
        () async {
      // ⚠️ Le cas des ~30 écoles publiques sans tarif posé : le document doit
      // exister et DIRE que le dû n'est pas établi, plutôt que d'afficher des
      // zéros qui se liraient « tout est réglé ».
      final bytes = await RapportPdfService.etatRecouvrement(
        lignes: [
          for (var i = 0; i < 12; i++)
            (
              className: 'Classe ${i + 1}',
              effectif: 40,
              aJour: 0,
              du: 0,
              encaisse: 0,
              reste: 0,
            ),
        ],
        anneeLabel: '2025-2026',
        sansBareme: true,
      );
      expect(bytes.length, greaterThan(1000));
    });

    test('aucune classe : l\'édition ne casse pas', () async {
      final bytes = await RapportPdfService.etatRecouvrement(
          lignes: const [], anneeLabel: '2025-2026', sansBareme: true);
      expect(bytes.length, greaterThan(1000));
    });
  });

  group('état du personnel', () {
    EtatPersonnel etat(List<AgentCompte> agents) {
      final categories = personnelParCategorie(agents);
      return (
        categories: categories,
        statuts: personnelParStatut(agents),
        total: cumulPersonnel('TOTAL ÉTABLISSEMENT', categories),
        directionEnPoste: aUneDirectionEnPoste(agents),
      );
    }

    test('un grand établissement — 180 agents — produit un document', () async {
      const roles = [
        'directeur',
        'secretaire',
        'comptable',
        'enseignant',
        'cpe',
        'surveillant',
        'infirmier',
      ];
      const statuts = ['fonctionnaire', 'volontaire', 'prestataire', null];
      final agents = [
        for (var i = 0; i < 180; i++)
          (
            role: roles[i % roles.length],
            actif: i % 17 != 0,
            statutEmploi: statuts[i % statuts.length],
          ),
      ];
      final bytes = await RapportPdfService.etatPersonnel(
          etat: etat(agents), anneeLabel: '2025-2026');
      expect(bytes.length, greaterThan(1000));
    });

    test('sans direction en poste, le document sort avec son avertissement',
        () async {
      // ⚠️ Il doit exister ET le dire : un état du personnel qui ne signale
      // pas l'absence de direction se fait signer par personne.
      final e = etat(const [
        (role: 'enseignant', actif: true, statutEmploi: 'fonctionnaire'),
        (role: 'directeur', actif: false, statutEmploi: 'fonctionnaire'),
      ]);
      expect(e.directionEnPoste, isFalse);
      final bytes = await RapportPdfService.etatPersonnel(
          etat: e, anneeLabel: '2025-2026');
      expect(bytes.length, greaterThan(1000));
    });

    test('une école sans aucun agent n\'empêche pas l\'édition', () async {
      final bytes = await RapportPdfService.etatPersonnel(
          etat: etat(const []), anneeLabel: null);
      expect(bytes.length, greaterThan(1000));
    });
  });

  group('le reste dû par classe', () {
    test('le document PORTE le reste, il ne le recalcule pas', () {
      expect(resteDe(_r(0)), 450000);
    });

    test('une classe peut devoir de l\'argent alors qu\'elle a trop encaissé',
        () {
      // ⚠️ LE DÉFAUT QUI A MOTIVÉ CE CHANGEMENT.
      //
      // Le reste valait `(du − encaisse).clamp(0, du)`. Sur une classe où une
      // famille règle l'année d'avance — cas courant quand la récolte tombe —
      // cette soustraction efface la dette des autres.
      //
      // Ici : douze familles doivent 100 000 F en tout ; l'une a versé
      // 250 000 F d'avance, les onze autres n'ont rien versé. L'école est bel
      // et bien impayée, et l'ancienne formule imprimait « Reste dû : 0 » sur
      // un document destiné à la direction départementale.
      const avance = (
        className: '6e A',
        effectif: 12,
        aJour: 1,
        du: 100000,
        encaisse: 250000,
        reste: 92000,
      );
      expect(resteDe(avance), 92000,
          reason: 'Le reste se compte élève par élève, en amont — jamais en '
              'soustrayant deux sommes.');
    });

    test('il ne passe jamais sous zéro', () {
      // Garanti à la source : `(r.du - verse).clamp(0, r.du)` par élève.
      const solde = (
        className: '5e B',
        effectif: 10,
        aJour: 10,
        du: 100000,
        encaisse: 250000,
        reste: 0,
      );
      expect(resteDe(solde), 0);
    });
  });
}
