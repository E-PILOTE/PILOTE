import 'dart:io';

import 'package:epilote/features/admin_groupe/screens/admin_licence_territoire.dart';
import 'package:epilote/features/tutelle/providers/tutelle_reseau_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  ON REGARDE AVANT D'IMPRIMER — et un département mène quelque part
//
//  ── LES DEUX DEMANDES ─────────────────────────────────────────────────────
//  « Je voudrais d'abord que tu mettes le preview avant impression qu'on voit
//    d'abord ce que c'est. Après on imprime comme tu as fait pour les autres. »
//  « Quand je clique sur département, je veux plus de détails, ensuite le
//    moyen d'imprimer ça. »
//
//  ── ⚠️ POURQUOI UNE SONDE DE SOURCE POUR LE PREMIER POINT ─────────────────
//  `Printing.layoutPdf` ouvre la boîte d'impression du système. Rien ne
//  distingue, à l'exécution d'un test, un document qu'on a vu d'un document
//  parti droit à l'imprimante : la différence est dans l'appel. Le seul moyen
//  de garantir que le raccourci ne revienne pas est de vérifier qu'il n'existe
//  plus dans le fichier — et que `printing` n'y est même plus importé.
// ════════════════════════════════════════════════════════════════════════════

const _service = 'lib/core/services/licence_pdf_service.dart';
const _carteMinistere =
    'lib/features/admin_groupe/screens/admin_licence_card.dart';
const _ficheFondateur =
    'lib/features/super_admin/screens/economie/licence_detail.dart';
const _modales = 'lib/features/admin_groupe/screens/admin_licence_modales.dart';
const _couverture =
    'lib/features/admin_groupe/screens/admin_licence_couverture.dart';
const _territoire =
    'lib/features/admin_groupe/screens/admin_licence_territoire.dart';
const _kpiFondateur =
    'lib/features/super_admin/screens/economie/economie_kpi_detail.dart';

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('Fichier introuvable : $chemin — sonde aveugle.');
  return f.readAsStringSync();
}

TutelleEcole _ecole(
  String nom, {
  String? departement,
  int eleves = 100,
  String groupe = 'Groupe A',
}) =>
    TutelleEcole(
      id: nom,
      groupId: groupe,
      groupeNom: groupe,
      nom: nom,
      secteur: 'public',
      departement: departement,
      nbEleves: eleves,
      nbFilles: eleves ~/ 2,
      nbPersonnel: 10,
      nbClasses: 5,
    );

void main() {
  group('L’aperçu vient avant l’impression', () {
    test('le service n’ouvre plus la boîte d’impression du système', () {
      final src = _lire(_service);
      // ⚠️ Avec la parenthèse : le commentaire du fichier NOMME l'appel
      // supprimé pour expliquer pourquoi il l'est. Une sonde qui cherche le
      // nom seul se déclencherait sur sa propre explication.
      expect(src.contains('Printing.layoutPdf('), isFalse,
          reason: 'La fiche repart directement à l’imprimante : sur un poste '
              'où l’imprimante par défaut est « Microsoft Print to PDF », le '
              'geste produit un fichier que personne n’a vu.');
      expect(src.contains("package:printing/printing.dart"), isFalse,
          reason: 'Le raccourci est encore à portée d’import.');
      expect(src.contains('showPdfPreviewDialog'), isTrue);
      expect(src.contains('Future<void> apercuFicheLicence'), isTrue);
    });

    test('les deux espaces passent par le même aperçu', () {
      // Le ministère et le fondateur impriment LA MÊME fiche. Deux chemins
      // différents finiraient par produire deux documents différents.
      expect(
          _lire(_carteMinistere)
              .contains('apercuFicheLicence(context, ficheAImprimer(l))'),
          isTrue);
      expect(
          _lire(_ficheFondateur)
              .contains('apercuFicheLicence(context, _fiche(l!))'),
          isTrue);
    });
  });

  group('Un département mène à ses établissements', () {
    test('le regroupement somme et classe par effectif', () {
      final reseau = ReseauSupervise(
        groupes: const [],
        ecoles: [
          _ecole('A', departement: 'Kouilou', eleves: 100),
          _ecole('B', departement: 'Kouilou', eleves: 250),
          _ecole('C', departement: 'Likouala', eleves: 900),
        ],
        nbEcolesPropres: 0,
      );
      final deps = departementsCouverts(reseau);
      expect(deps.length, 2);
      // Du plus peuplé au moins peuplé : c'est l'ordre dans lequel un
      // ministère lit son territoire.
      expect(deps.first.nom, 'Likouala');
      expect(deps.last.nom, 'Kouilou');
      expect(deps.last.eleves, 350);
      expect(deps.last.nbEcoles, 2);
      expect(deps.last.classes, 10);
    });

    test('⚠️ une école sans département ne disparaît pas du décompte', () {
      // Le piège : filtrer les `null` donne un total territorial inférieur au
      // total du KPI, et l'écart n'est expliqué nulle part.
      final reseau = ReseauSupervise(
        groupes: const [],
        ecoles: [
          _ecole('A', departement: 'Niari', eleves: 10),
          _ecole('B', eleves: 20),
          _ecole('C', departement: '   ', eleves: 30),
        ],
        nbEcolesPropres: 0,
      );
      final deps = departementsCouverts(reseau);
      expect(deps.map((d) => d.nom), contains(kDepartementNonRenseigne));
      final inconnu =
          deps.firstWhere((d) => d.nom == kDepartementNonRenseigne);
      expect(inconnu.nbEcoles, 2);
      expect(inconnu.renseigne, isFalse);
      // Tous les élèves sont comptés quelque part.
      expect(deps.fold(0, (s, d) => s + d.eleves), 60);
    });

    test('le nom de fichier ne fabrique pas un chemin', () {
      // « Pointe-Noire » ou « Bouenza / Nkayi » ne doivent créer ni dossier ni
      // fichier illisible au moment de l'enregistrement du PDF.
      final src = _lire(_territoire);
      expect(src.contains(r"RegExp(r'[^A-Za-z0-9]+')"), isTrue);
    });
  });

  group('Les fiches descendent, et rien n’est tronqué', () {
    test('le département est cliquable depuis la fiche ET depuis le graphe',
        () {
      expect(_lire(_modales).contains('ouvrirFicheDepartement(ctx, d)'), isTrue,
          reason: 'La ligne « Kouilou · 7 » est redevenue un cul-de-sac.');
      final graphe = _lire(_couverture);
      expect(graphe.contains('onPointTap'), isTrue);
      expect(graphe.contains('ouvrirFicheDepartement(context, visibles[i])'),
          isTrue);
      expect(graphe.contains('ouvrirFicheDepartements(context, reseau)'),
          isTrue);
    });

    test('plus aucune liste tronquée dans les fiches', () {
      // « 12 plus gros établissements sur 25 » : une troncature d'affichage
      // devient un chiffre faux dès qu'on la recopie.
      final src = _lire(_modales);
      expect(src.contains('.take('), isFalse);
      // La liste des établissements part de la collection ENTIÈRE.
      expect(src.contains('for (final e in ecoles)'), isTrue);
    });

    test('un seul découpage territorial dans toute la page', () {
      // Le graphe comptait ses départements dans son coin. Deux comptages du
      // même réseau finissent toujours par diverger — et c'est le graphe
      // qu'on croit.
      final graphe = _lire(_couverture);
      expect(graphe.contains('departementsCouverts(reseau)'), isTrue);
      expect(graphe.contains("'Non renseigné'"), isFalse,
          reason: 'Le libellé est redéclaré ici au lieu de venir de '
              '`kDepartementNonRenseigne`.');
    });

    test('les quatre fiches du fondateur s’impriment aussi', () {
      final src = _lire(_kpiFondateur);
      expect('ouvrirFicheDetail('.allMatches(src).length, 4);
      // ⚠️ Le revenu des abonnements ne montrait AUCUN groupe : il expliquait
      // son calcul sans nommer un seul payeur.
      expect(src.contains('for (final a in d.abonnements)'), isTrue);
    });
  });
}
