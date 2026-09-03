import 'package:epilote/features/tutelle/providers/tutelle_filtres.dart';
import 'package:epilote/features/tutelle/providers/tutelle_reseau_provider.dart';
import 'package:epilote/features/tutelle/services/tutelle_fiche_pdf_service.dart';
import 'package:epilote/features/tutelle/services/tutelle_pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Génération RÉELLE des trois documents de la tutelle.
///
/// Ce test existe parce qu'un défaut de mise en page n'y produit pas un rendu
/// approximatif : il produit `TooManyPagesException`, et le document ne sort
/// pas du tout. `OfficialPdfKit.frame()` enveloppe son contenu dans un
/// `Padding`, qui ne sait pas se scinder entre deux pages ; si un bloc de
/// lignes dépasse la hauteur utile, `MultiPage` boucle jusqu'à l'exception.
///
/// On construit donc vraiment les documents, jusqu'au cas le plus défavorable :
/// la cible nationale — mille établissements, quinze départements, des noms
/// congolais à rallonge — sur un état qui empile QUATRE tables.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => initializeDateFormatting('fr'));

  const departements = [
    'Brazzaville', 'Pointe-Noire', 'Kouilou', 'Niari', 'Bouenza',
    'Lékoumou', 'Pool', 'Plateaux', 'Cuvette', 'Cuvette-Ouest',
    'Sangha', 'Likouala', 'Cuvette Ouest', 'Île Mbamou', 'Djoué-Léfini',
  ];

  TutelleEcole ecole(int i, {bool long = false, bool sansDept = false}) =>
      TutelleEcole(
        id: 'E$i',
        groupId: 'G${i % 40}',
        groupeNom: long
            ? 'Réseau Scolaire Confessionnel Notre-Dame du Rosaire ${i % 40}'
            : 'Groupe ${i % 40}',
        nom: long
            ? 'Complexe Scolaire Départemental Étoile du Nord de Ouesso $i'
            : 'École $i',
        secteur: i.isEven ? 'prive' : 'public',
        code: 'ETB-${i.toString().padLeft(5, '0')}',
        typeEtablissement: 'Collège d’Enseignement Général',
        typeEtablissementCourt: 'CEG',
        departement: sansDept ? null : departements[i % departements.length],
        ville: long ? 'Kinkala-Centre, arrondissement 3' : 'Kinkala',
        arrondissement: 'Arrondissement 3',
        latitude: -4.2634 + i / 1000,
        longitude: 15.2429 + i / 1000,
        capacite: i % 5 == 0 ? null : 400,
        anneeCreation: 1978 + (i % 40),
        telephone: '+242 06 000 00 ${i % 100}',
        courriel: 'contact$i@ecole.cg',
        chefEtablissement: long
            ? 'Marie-Bénédicte Nkounkou Massamba Loemba $i'
            : 'Chef $i',
        agrementNumero: i % 3 == 0 ? 'AGR-2024-$i' : null,
        agrementType: i % 3 == 0 ? 'definitif' : null,
        agrementDate: i % 3 == 0 ? DateTime(2024, 3, 12) : null,
        actif: i % 17 != 0,
        nbEleves: 120 + i % 400,
        nbFilles: 60 + i % 180,
        nbPersonnel: 12 + i % 30,
        nbClasses: 6 + i % 12,
      );

  TutelleGroupe groupe(int i, {bool long = false}) => TutelleGroupe(
        id: 'G$i',
        nom: long
            ? 'Réseau Scolaire Confessionnel Notre-Dame du Rosaire $i'
            : 'Groupe $i',
        secteur: i.isEven ? 'prive' : 'public',
        departement: departements[i % departements.length],
        email: 'direction$i@groupe.cg',
        telephone: '+242 06 111 11 ${i % 100}',
        anneeCreation: 1985 + (i % 30),
        agrementNumero: i % 2 == 0 ? 'AGR-G-$i' : null,
        agrementType: i % 2 == 0 ? 'provisoire' : null,
        agrementDate: i % 2 == 0 ? DateTime(2023, 9, 1) : null,
        nbEcoles: 25,
        nbEcolesActives: 24,
        nbEleves: 6200,
        nbFilles: 3100,
        nbPersonnel: 400,
        nbClasses: 180,
        nbEcolesAgreees: 12,
      );

  Future<int> etat(List<TutelleEcole> ecoles, List<TutelleGroupe> groupes,
          {String? selection}) async =>
      (await TutelleReseauPdfService.buildReseau(
        groupes: groupes,
        ecoles: ecoles,
        bilan: BilanReseau.de(ecoles),
        tutelle: 'metp',
        selection: selection,
      ))
          .length;

  // ── L'état du réseau ──────────────────────────────────────────────────────
  group('État du réseau sous tutelle', () {
    test('un réseau vide produit quand même un document', () async {
      expect(await etat(const [], const []), greaterThan(0),
          reason: 'Un ministère dont aucune école ne passe les filtres doit '
              'obtenir une page qui le DIT, pas une erreur.');
    });

    test('le réseau réel du MEPSA (25 écoles) se génère', () async {
      expect(
        await etat([for (var i = 0; i < 25; i++) ecole(i)],
            [for (var i = 0; i < 6; i++) groupe(i)]),
        greaterThan(0),
      );
    });

    test('la cible nationale — 1 000 écoles, 40 groupes — se génère', () async {
      // Quatre tables empilées dans un seul `MultiPage` : secteurs,
      // départements, groupes (deux sections), établissements. C'est le
      // document le plus long de l'application.
      expect(
        await etat([for (var i = 0; i < 1000; i++) ecole(i, long: true)],
            [for (var i = 0; i < 40; i++) groupe(i, long: true)]),
        greaterThan(0),
      );
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('une école sans département ne fait pas échouer la répartition',
        () async {
      expect(
        await etat([
          for (var i = 0; i < 30; i++) ecole(i, sansDept: i % 4 == 0),
        ], [
          for (var i = 0; i < 6; i++) groupe(i)
        ]),
        greaterThan(0),
      );
    });

    test('un état filtré se génère AVEC sa phrase de sélection', () async {
      expect(
        await etat([for (var i = 0; i < 12; i++) ecole(i)],
            [for (var i = 0; i < 4; i++) groupe(i)],
            selection: descriptionDesFiltres(
                const FiltreReseau(secteur: 'prive', departement: 'Niari'))),
        greaterThan(0),
      );
    });

    test('un réseau entièrement privé ne produit qu’une section', () async {
      // `sectionsDuReseau` omet le pan vide : le document ne doit pas se
      // retrouver avec une table d'en-tête sans ligne.
      final prives = [
        for (var i = 0; i < 20; i++) ecole(i * 2), // i pair → privé
      ];
      expect(await etat(prives, [groupe(0), groupe(2), groupe(4)]),
          greaterThan(0));
    });
  });

  // ── Les deux fiches ───────────────────────────────────────────────────────
  group('Fiche d’établissement', () {
    test('une école complète se génère', () async {
      final bytes =
          await TutelleFichePdfService.buildEcole(ecole: ecole(3), tutelle: 'mepsa');
      expect(bytes.length, greaterThan(0));
    });

    test('une école aux champs vides se génère aussi', () async {
      // Le cas réel du premier jour : une école créée sans chef désigné, sans
      // capacité, sans agrément, sans coordonnées. Elle doit s'imprimer.
      const nue = TutelleEcole(
        id: 'X',
        groupId: 'G',
        groupeNom: 'Groupe',
        nom: 'École sans rien',
        secteur: 'prive',
        nbEleves: 0,
        nbFilles: 0,
        nbPersonnel: 0,
        nbClasses: 0,
      );
      expect((await TutelleFichePdfService.buildEcole(ecole: nue)).length,
          greaterThan(0));
    });

    test('un nom à rallonge ne casse pas la mise en page', () async {
      expect(
        (await TutelleFichePdfService.buildEcole(
                ecole: ecole(7, long: true), tutelle: 'metp'))
            .length,
        greaterThan(0),
      );
    });
  });

  group('Fiche de groupe scolaire', () {
    Future<int> fiche(int nbEcoles, {bool long = false}) async {
      final ecoles = [for (var i = 0; i < nbEcoles; i++) ecole(i, long: long)];
      return (await TutelleFichePdfService.buildGroupe(
        groupe: groupe(0, long: long),
        ecoles: ecoles,
        bilan: BilanReseau.de(ecoles),
        tutelle: 'mepsa',
      ))
          .length;
    }

    test('un groupe sans école dans la sélection se génère', () async {
      expect(await fiche(0), greaterThan(0));
    });

    test('un groupe privé congolais ordinaire (3 écoles)', () async {
      expect(await fiche(3), greaterThan(0));
    });

    test('un gros opérateur (120 écoles, noms longs) se pagine', () async {
      expect(await fiche(120, long: true), greaterThan(0));
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
