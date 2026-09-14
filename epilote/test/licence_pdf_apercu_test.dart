import 'dart:io';

import 'package:epilote/core/services/licence_pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA FICHE DE LICENCE SE CONSTRUIT VRAIMENT — et on peut la regarder
//
//  ── POURQUOI UN TEST QUI ÉCRIT UN FICHIER ─────────────────────────────────
//  Un PDF est le seul livrable de cette application qu'aucune sonde de source
//  ne peut juger : il se compose de widgets `pw.*` qui ne rendent rien avant
//  `doc.save()`. Une police manquante, un `Expanded` hors `Row`, un
//  `FractionallySizedBox` qui n'existe pas dans le paquet `pdf` — tout cela
//  compile et casse À L'IMPRESSION, devant le client.
//
//  Ce test construit le document avec de vraies données et l'écrit sous
//  `build/apercu/`. Il échoue si la construction lève, si le fichier est vide,
//  ou s'il ne commence pas par la signature `%PDF`.
//
//  ⚠️ Le fichier produit N'EST PAS un artefact de test à conserver : il vit
//  dans `build/`, que git ignore. Il sert à REGARDER la fiche pendant qu'on la
//  met au point — la seule façon honnête de vérifier une mise en page.
// ════════════════════════════════════════════════════════════════════════════

void main() {
  // `loadFonts()` lit les polices embarquées via rootBundle.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('la fiche d’une licence de tutelle se construit et s’ouvre', () async {
    final l = LicenceAImprimer(
      ministere: "Ministère de l'Enseignement Technique et Professionnel",
      sigleTutelle: 'METP',
      intitule: 'Licence annuelle de tutelle 2026',
      statut: 'active',
      statutLabel: 'Active',
      dateDebut: DateTime(2026, 1, 1),
      dateFin: DateTime(2026, 12, 31),
      montantXaf: 40000000,
      avanceXaf: 0,
      montantRegleXaf: 0,
      nbEtablissements: 12,
      nbEleves: 1776,
      notes: 'Reference de marche, signataire et echeancier restent a saisir.',
    );

    // ⚠️ Le montant annuel d'un marché annuel EST son montant. 364 jours du
    // 01/01 au 31/12 : la règle de trois affichait 40 109 890.
    expect(l.annuelXaf, 40000000);
    expect(l.moisCouverts, 12);
    expect(l.mensuelXaf, 3333333);

    final octets = await LicencePdfService.buildPdf(l);

    expect(octets.length, greaterThan(2000),
        reason: 'Le document fait ${octets.length} octets : il est vide ou '
            'tronqué.');
    expect(String.fromCharCodes(octets.take(4)), '%PDF',
        reason: 'Ce ne sont pas des octets PDF.');

    final dossier = Directory('build/apercu')..createSync(recursive: true);
    final f = File('${dossier.path}/licence_metp_2026.pdf')
      ..writeAsBytesSync(octets);
    // ignore: avoid_print
    print('Fiche écrite : ${f.absolute.path} (${octets.length} octets)');
  });

  test('un marché pluriannuel, lui, se ramène bien à l’année', () {
    final triennal = LicenceAImprimer(
      ministere: 'Ministère X',
      intitule: 'Licence triennale',
      statut: 'active',
      statutLabel: 'Active',
      dateDebut: DateTime(2026, 1, 1),
      dateFin: DateTime(2028, 12, 31),
      montantXaf: 40000000,
      avanceXaf: 0,
      montantRegleXaf: 0,
    );
    // ⚠️ 40 M sur trois ans ne font PAS 40 M par an — c'est le piège que la
    // tolérance ne doit pas avaler.
    expect(triennal.annuelXaf, closeTo(13333333, 100000));
    expect(triennal.moisCouverts, greaterThan(30));
  });
}
