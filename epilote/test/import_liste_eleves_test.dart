// Une secrétaire de Kinkala a trois cents élèves dans un classeur Excel. Ce
// qu'elle exporte n'est pas du CSV de manuel : point-virgules, Windows-1252,
// dates à la française, colonnes nommées comme elle l'a décidé.
//
// Ces tests fixent ce que le lecteur doit encaisser, et surtout ce qu'il doit
// REFUSER : une ligne incomplète acceptée ici serait rejetée par le serveur à
// la synchronisation, et c'est le lot entier qui serait perdu.

import 'dart:convert';

import 'package:epilote/features/students/providers/import_eleves_provider.dart'
    show cleClasse;
import 'package:epilote/core/utils/write_identity.dart';
import 'package:epilote/features/students/services/import_liste_eleves.dart';
import 'package:flutter_test/flutter_test.dart';

List<int> _utf8(String s) => utf8.encode(s);
List<int> _windows(String s) => latin1.encode(s);

const _anneeRef = 2026;

LectureImport _lire(List<int> octets) =>
    lireFichierEleves(octets, anneeReference: _anneeRef);

void main() {
  group('Ce qu\'Excel produit vraiment', () {
    test('point-virgule et accents Windows-1252', () {
      // Le cas le plus fréquent du pays : Excel francophone sur Windows.
      // Décoder en UTF-8 sans repli rendrait « Prénom » illisible et le
      // séparateur virgule ne découperait rien du tout.
      final f = _lire(_windows(
        'Nom;Prénom;Date de naissance;Sexe\n'
        'NGOMA;Aïcha;12/03/2011;F\n',
      ));
      expect(f.separateur, ';');
      expect(f.retenues, hasLength(1));
      expect(f.retenues.single.prenom, 'Aïcha');
      expect(f.retenues.single.nom, 'NGOMA');
    });

    test('virgule et UTF-8 marchent aussi', () {
      final f = _lire(_utf8(
        'Nom,Prénom,Date de naissance,Sexe\n'
        'MBEMBA,Jean,2011-03-12,M\n',
      ));
      expect(f.separateur, ',');
      expect(f.retenues.single.dateNaissance, DateTime(2011, 3, 12));
    });

    test('le BOM que Windows ajoute ne devient pas un caractère du nom', () {
      final f = _lire([0xEF, 0xBB, 0xBF, ..._utf8('Nom;Sexe;Date de naissance\n'
          'OKEMBA;M;01/09/2012\n')]);
      expect(f.retenues.single.nom, 'OKEMBA');
    });

    test('une virgule dans un nom entre guillemets ne coupe pas la cellule', () {
      final f = _lire(_utf8(
        'Nom,Prénom,Date de naissance,Sexe\n'
        '"MBEMBA, dit LOUZOLO",Jean,12/03/2011,M\n',
      ));
      expect(f.retenues.single.nom, 'MBEMBA, dit LOUZOLO');
    });

    test('les lignes vides du bas de tableau sont ignorées', () {
      // Excel en produit systématiquement : elles ne doivent pas apparaître
      // comme trois cents rejets « nom manquant ».
      final f = _lire(_utf8(
        'Nom;Prénom;Date de naissance;Sexe\n'
        'NGOMA;Aïcha;12/03/2011;F\n'
        ';;;\n'
        '\n'
        '   \n',
      ));
      expect(f.lignes, hasLength(2)); // la ligne ';;;' reste, elle a des cellules
      expect(f.retenues, hasLength(1));
    });
  });

  group('Reconnaître les colonnes', () {
    test('quel que soit l\'habillage de l\'en-tête', () {
      expect(champPour('DATE DE NAISSANCE'), ChampImport.dateNaissance);
      expect(champPour('Date  de   naissance'), ChampImport.dateNaissance);
      expect(champPour('Né(e) le'), ChampImport.dateNaissance);
      expect(champPour('Prénom(s)'), ChampImport.prenom);
      expect(champPour('SEXE'), ChampImport.sexe);
      expect(champPour('Nom et prénoms'), ChampImport.nomComplet);
    });

    test('un en-tête ambigu n\'est PAS deviné', () {
      // « N° » désigne aussi bien un rang dans la liste qu'un matricule.
      // Deviner ferait entrer un numéro d'ordre dans un champ d'identité.
      expect(champPour('N°'), isNull);
      expect(champPour('Num'), isNull);
      expect(champPour('Observations'), isNull);
    });

    test('les colonnes non reprises sont NOMMÉES, pas oubliées', () {
      // Une colonne « Téléphone parent » abandonnée en silence fait croire à
      // l'école que les numéros sont entrés dans le système.
      final f = _lire(_utf8(
        'Nom;Prénom;Date de naissance;Sexe;Téléphone parent;Observations\n'
        'NGOMA;Aïcha;12/03/2011;F;066112233;RAS\n',
      ));
      expect(f.colonnesIgnorees, contains('Téléphone parent'));
      expect(f.colonnesIgnorees, contains('Observations'));
      expect(f.colonnesReconnues.values, contains(ChampImport.sexe));
    });

    test('une seconde colonne pour le même champ est signalée', () {
      final f = _lire(_utf8(
        'Nom;Nom de famille;Date de naissance;Sexe\n'
        'NGOMA;AUTRE;12/03/2011;F\n',
      ));
      expect(f.retenues.single.nom, 'NGOMA');
      expect(f.colonnesIgnorees.join(), contains('déjà lu'));
    });

    test('sans colonne de nom, on n\'affiche aucun tableau', () {
      expect(
        () => _lire(_utf8('Classe;Sexe\n6e A;M\n')),
        throwsA(isA<FichierIllisible>()),
      );
    });
  });

  group('Les dates', () {
    test('jour d\'abord dans les formats à barres', () {
      // 12/03/2011 est le 12 mars, jamais le 3 décembre.
      expect(lireDate('12/03/2011'), DateTime(2011, 3, 12));
      expect(lireDate('12-03-2011'), DateTime(2011, 3, 12));
      expect(lireDate('12.03.2011'), DateTime(2011, 3, 12));
      expect(lireDate('2011-03-12'), DateTime(2011, 3, 12));
    });

    test('une année sur deux chiffres est REFUSÉE', () {
      // « 12/03/11 » vaut 2011 ou 1911. Un élève né en 1911 entrerait sans
      // bruit dans le registre national.
      expect(lireDate('12/03/11'), isNull);
    });

    test('une date qui n\'existe pas est refusée, pas décalée', () {
      // DateTime(2011, 2, 31) donne le 3 mars sans se plaindre : on
      // inscrirait une date que personne n'a écrite.
      expect(lireDate('31/02/2011'), isNull);
      expect(lireDate('32/01/2011'), isNull);
      expect(lireDate('12/13/2011'), isNull);
    });

    test('une date invraisemblable est rejetée avec son année', () {
      final f = _lire(_utf8(
        'Nom;Date de naissance;Sexe\n'
        'NGOMA;12/03/2030;F\n'
        'MBEMBA;12/03/1960;M\n',
      ));
      expect(f.retenues, isEmpty);
      expect(f.rejetees.first.rejets.join(), contains('2030'));
      expect(f.rejetees.last.rejets.join(), contains('1960'));
    });
  });

  group('Le sexe', () {
    test('accepte ce que les gens écrivent réellement', () {
      for (final v in ['M', 'm', 'G', 'Masculin', 'garçon', 'HOMME']) {
        expect(lireSexe(v), 'M', reason: v);
      }
      for (final v in ['F', 'f', 'Féminin', 'fille', 'FEMME']) {
        expect(lireSexe(v), 'F', reason: v);
      }
    });

    test('n\'invente rien sur une valeur inconnue', () {
      expect(lireSexe('?'), isNull);
      expect(lireSexe(''), isNull);
      expect(lireSexe('X'), isNull);
    });
  });

  group('Ce qui est obligatoire l\'est vraiment', () {
    test('date et sexe manquants bloquent la ligne', () {
      // `date_of_birth` et `gender` sont NOT NULL en base. Laisser passer la
      // ligne ici, c'est faire refuser la transaction PowerSync par le serveur
      // — et une transaction refusée emporte TOUT LE LOT, pas cette seule
      // ligne. Le refus doit tomber avant l'écriture.
      final f = _lire(_utf8(
        'Nom;Prénom;Date de naissance;Sexe\n'
        'NGOMA;Aïcha;;F\n'
        'MBEMBA;Jean;12/03/2011;\n'
        'OKEMBA;Paul;12/03/2011;M\n',
      ));
      expect(f.retenues, hasLength(1));
      expect(f.retenues.single.nom, 'OKEMBA');
      expect(f.rejetees.first.rejets.join(), contains('Date de naissance'));
      expect(f.rejetees.last.rejets.join(), contains('Sexe'));
    });

    test('le motif de rejet dit le format attendu', () {
      // « Date illisible » n'aide personne. « attendu 12/03/2011 » se corrige.
      final f = _lire(_utf8(
        'Nom;Date de naissance;Sexe\nNGOMA;le 12 mars;F\n',
      ));
      expect(f.rejetees.single.rejets.join(), contains('12/03/2011'));
    });

    test('le numéro de rejet est celui qu\'Excel affiche', () {
      // La secrétaire corrige dans son tableur : si on annonce « ligne 1 »
      // pour la deuxième ligne de données, elle cherche au mauvais endroit.
      final f = _lire(_utf8(
        'Nom;Date de naissance;Sexe\n'
        'NGOMA;12/03/2011;F\n'
        'MBEMBA;;M\n',
      ));
      expect(f.rejetees.single.numero, 3);
    });
  });

  group('Nom et prénom dans une seule colonne', () {
    test('les capitales désignent le nom de famille', () {
      final s = separerNomComplet('MAKAYA Jean Pierre');
      expect(s.nom, 'MAKAYA');
      expect(s.prenom, 'Jean Pierre');
      expect(s.devine, isFalse);

      final d = separerNomComplet('NGOMA MBEMBA Aïcha');
      expect(d.nom, 'NGOMA MBEMBA');
      expect(d.prenom, 'Aïcha');
    });

    test('sans capitales, la coupe est signalée comme devinée', () {
      // « Makaya Jean Pierre » : impossible de savoir où s'arrête le nom.
      // On coupe, mais l'écran doit dire que c'est la machine qui a tranché.
      final s = separerNomComplet('Makaya Jean Pierre');
      expect(s.nom, 'Makaya');
      expect(s.prenom, 'Jean Pierre');
      expect(s.devine, isTrue);
    });

    test('la colonne « Nom et prénom » alimente les deux champs', () {
      final f = _lire(_utf8(
        'Nom et prénoms;Date de naissance;Sexe\n'
        'MAKAYA Jean;12/03/2011;M\n',
      ));
      expect(f.retenues.single.nom, 'MAKAYA');
      expect(f.retenues.single.prenom, 'Jean');
    });

    test('« Nom » séparé l\'emporte sur « Nom et prénom »', () {
      final f = _lire(_utf8(
        'Nom;Prénom;Nom et prénoms;Date de naissance;Sexe\n'
        'NGOMA;Aïcha;PEU IMPORTE;12/03/2011;F\n',
      ));
      expect(f.retenues.single.nom, 'NGOMA');
      expect(f.retenues.single.prenom, 'Aïcha');
    });
  });

  group('Doublons à l\'intérieur du fichier', () {
    test('la même personne deux fois : la seconde est rejetée', () {
      // Arrive quand deux classes sont collées dans le même tableau.
      final f = _lire(_utf8(
        'Nom;Prénom;Date de naissance;Sexe\n'
        'NGOMA;Aïcha;12/03/2011;F\n'
        'MBEMBA;Jean;01/09/2012;M\n'
        'ngoma;aïcha;12/03/2011;F\n',
      ));
      marquerDoublonsInternes(f.lignes);
      expect(f.retenues, hasLength(2));
      expect(f.rejetees.single.numero, 4);
      expect(f.rejetees.single.rejets.join(), contains('ligne 2'));
    });

    test('deux homonymes nés des jours différents restent deux élèves', () {
      final f = _lire(_utf8(
        'Nom;Prénom;Date de naissance;Sexe\n'
        'NGOMA;Jean;12/03/2011;M\n'
        'NGOMA;Jean;05/07/2012;M\n',
      ));
      marquerDoublonsInternes(f.lignes);
      expect(f.retenues, hasLength(2));
    });
  });

  group('Refus de lecture', () {
    test('fichier vide', () {
      expect(() => _lire(_utf8('   ')), throwsA(isA<FichierIllisible>()));
    });

    test('en-tête seule, sans élève', () {
      expect(
        () => _lire(_utf8('Nom;Prénom;Date de naissance;Sexe\n')),
        throwsA(isA<FichierIllisible>()),
      );
    });
  });
  group('Rapprocher les noms de classe', () {
    test('les habillages d\'ordinal se rejoignent', () {
      // Le fichier écrit « 6ème A », la base « 6e A ». C'est la même classe.
      expect(cleClasse('6ème A'), cleClasse('6e A'));
      expect(cleClasse('6EME A'), cleClasse('6e A'));
      expect(cleClasse('2nde C'), cleClasse('2e C'));
      expect(cleClasse('1ère S'), cleClasse('1e S'));
      expect(cleClasse('CM2 A'), cleClasse('cm2  a'));
    });

    test('deux sections différentes NE se rejoignent PAS', () {
      // C'est l'erreur qu'on ne veut jamais commettre.
      expect(cleClasse('6e A') == cleClasse('6e B'), isFalse);
      expect(cleClasse('CM1') == cleClasse('CM2'), isFalse);
      expect(cleClasse('6e') == cleClasse('5e'), isFalse);
    });

    test('la lettre de section n\'est pas prise pour un ordinal', () {
      // « 6 E » désigne la section E, pas « sixième ». L'effacer la
      // confondrait avec toutes les autres sixièmes.
      expect(cleClasse('6 E') == cleClasse('6 A'), isFalse);
    });
  });
  group('Le garde-fou d\'écriture', () {
    test('une identité incomplète est une ABSENCE, jamais une chaîne vide', () {
      // `group_id` et `school_id` sont uuid NOT NULL côté serveur. Écrire ''
      // passe en SQLite, l'écran annonce « 300 élèves inscrits », puis
      // PostgreSQL répond 22P02 à la remontée — et un refus abandonne le LOT
      // PowerSync ENTIER : les notes et les paiements de la même fenêtre
      // partent avec, sans message.
      expect(isUsableId(''), isFalse);
      expect(isUsableId('   '), isFalse);
      expect(isUsableId(null), isFalse);
      expect(isUsableId('a6000000-0000-0000-0000-000000000006'), isTrue);
    });

    test('le message nomme ce qui manque, pas « erreur »', () {
      // « Erreur d'enregistrement » n'aide personne. La secrétaire doit savoir
      // que son compte n'est rattaché à aucune école, et la direction quoi
      // corriger.
      final m = missingWriteIds(groupId: null, schoolId: 'x', actorId: 'y');
      expect(m, ['groupe']);
      final msg = writeIdentityMessage(m);
      expect(msg, contains('groupe'));
      expect(msg.toLowerCase(), contains('perdue'));
    });

    test('une identité complète ne bloque rien', () {
      expect(
        buildWriteIdentity(groupId: 'g', schoolId: 's', actorId: 'a'),
        isNotNull,
      );
      expect(
        buildWriteIdentity(groupId: 'g', schoolId: '', actorId: 'a'),
        isNull,
      );
    });
  });
}
