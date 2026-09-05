import 'dart:io';

import 'package:epilote/features/students/services/registre_documents.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE REGISTRE DES DOCUMENTS DÉLIVRÉS
//
//  Ce registre a une propriété rare et fragile : **son défaut est le silence**.
//  Un document qui n'est pas noté ne produit aucune erreur, aucune ligne rouge,
//  rien à l'écran. On ne s'en aperçoit que le jour où l'on cherche la trace
//  d'un certificat contesté — et ce jour-là, il est trop tard pour la créer.
//
//  Les tests ci-dessous surveillent donc surtout des ABSENCES :
//   • une porte de délivrance qui ne noterait pas ;
//   • une colonne déclarée d'un côté et pas de l'autre ;
//   • une table absente des sync-rules, qui rendrait l'écran vide pour
//     toujours alors que la donnée existe côté serveur.
// ════════════════════════════════════════════════════════════════════════════

String _lire(String chemin) => File(chemin).readAsStringSync().replaceAll('\r\n', '\n');

/// Le corps d'un bloc `Table('nom', [ ... ])` du schéma PowerSync local.
String _blocSchema(String src, String table) {
  final debut = src.indexOf("Table('$table'");
  expect(debut, greaterThan(-1), reason: '`$table` absente du schéma local.');
  final fin = src.indexOf('  ]),', debut);
  expect(fin, greaterThan(debut));
  return src.substring(debut, fin);
}

void main() {
  group('Les libellés ne mentent jamais', () {
    test('les quatre types connus ont un libellé lisible', () {
      for (final t in TypeDocument.tous) {
        final l = libelleTypeDocument(t);
        expect(l, isNotEmpty);
        expect(l, isNot(t),
            reason: 'Le type « $t » s’afficherait avec son code brut.');
      }
    });

    test('un code inconnu s’affiche tel quel, jamais « Autre »', () {
      // Le jour où un type est ajouté sans passer par cette table, le registre
      // doit rester lisible. « Autre » effacerait l'information restante.
      expect(libelleTypeDocument('registre_matricule'), 'registre_matricule');
    });

    test('les quatre codes sont distincts', () {
      expect(TypeDocument.tous.toSet().length, TypeDocument.tous.length);
    });
  });

  group('Toute porte de délivrance passe par le registre', () {
    // La liste est écrite à la main : chaque entrée est une décision, et un
    // fichier ajouté ici sans son appel fait échouer le test.
    const portes = {
      'lib/features/students/services/attestation_actions.dart':
          'certificats de scolarité et de radiation',
      'lib/features/cartes/services/cartes_actions.dart':
          'cartes scolaires (planche et duplicata)',
      'lib/features/staff/screens/personnel_dossier_sheet.dart':
          'attestation de travail',
    };

    for (final e in portes.entries) {
      test('${e.value} — noté', () {
        expect(_lire(e.key), contains('noterDocumentEmis('),
            reason: 'Ce fichier délivre un document officiel sans en laisser '
                'la moindre trace. Le défaut ne se verrait qu’au moment où '
                'quelqu’un vient demander qui l’a signé.');
      });
    }

    test('les deux gestes de la carte sont notés, pas seulement un', () {
      final src = _lire('lib/features/cartes/services/cartes_actions.dart');
      final appels = 'noterDocumentEmis('.allMatches(src).length;
      expect(appels, greaterThanOrEqualTo(2),
          reason: 'La planche de classe ET le duplicata au guichet sont deux '
              'délivrances distinctes.');
    });

    test('la planche note UN ÉLÈVE par ligne, pas une ligne par classe', () {
      final src = _lire('lib/features/cartes/services/cartes_actions.dart');
      expect(src.contains('for (final e in actifs)'), isTrue,
          reason: 'Une ligne « classe de 40 » ne répondrait pas à « combien de '
              'cartes cet enfant a-t-il reçues ? », qui est la question des '
              'duplicatas.');
    });
  });

  group('Le registre ne peut pas coûter la donnée qu’il observe', () {
    final src = _lire('lib/features/students/services/registre_documents.dart');

    test('l’écriture est entourée d’un try/catch — le document passe avant', () {
      expect(src.contains('} catch (_) {'), isTrue,
          reason: 'Une famille au guichet ne doit pas repartir sans son '
              'certificat parce que le registre a hoqueté.');
    });

    test('rien ne s’écrit sans identité complète', () {
      expect(src.contains('buildWriteIdentity('), isTrue);
      expect(src.contains('if (identite == null) return;'), isTrue,
          reason: 'Une chaîne vide dans une colonne uuid remonte en 22P02 — '
              'code FATAL : le lot entier en attente serait jeté.');
    });

    test('l’identifiant est aléatoire, jamais déterministe', () {
      expect(src.contains('_uuid.v4()'), isTrue);
      expect(src.contains('idDeterministe'), isFalse,
          reason: 'Deux certificats délivrés le même jour au même élève sont '
              'DEUX actes : un duplicata après une perte est précisément ce '
              'que le registre doit montrer.');
    });

    test('le client n’émet jamais d’UPDATE sur le registre', () {
      expect(src.toUpperCase().contains('UPDATE ISSUED_DOCUMENTS'), isFalse,
          reason: 'La table est immuable côté serveur (trigger RETURN OLD) : '
              'un UPDATE réussirait sans rien changer, ce qui est pire qu’un '
              'refus — l’écran annoncerait une correction qui n’a pas eu lieu.');
    });

    test('l’agent noté est celui AU CLAVIER, pas la session de l’appareil', () {
      expect(src.contains('activeAgentIdProvider'), isTrue,
          reason: 'Sur un poste partagé, noter le compte qui a ouvert la '
              'session rendrait le registre inutile — et injuste.');
    });
  });

  group('Les deux moitiés de la table disent la même chose', () {
    final schema = _lire('lib/services/powersync/powersync_schema.dart');
    final migration = _lire(
        '../database/migrations/0149_AVANT_LE_BUILD_le_registre_des_documents_delivres.sql');

    /// Colonnes déclarées dans le schéma SQLite local.
    Set<String> colonnesLocales() {
      final bloc = _blocSchema(schema, 'issued_documents');
      return {
        for (final m
            in RegExp(r"Column\.\w+\('(\w+)'\)").allMatches(bloc))
          m.group(1)!,
      };
    }

    /// Colonnes du CREATE TABLE de la migration.
    Set<String> colonnesServeur() {
      final debut = migration.indexOf('CREATE TABLE IF NOT EXISTS public.issued_documents');
      expect(debut, greaterThan(-1));
      final fin = migration.indexOf('COMMENT ON TABLE', debut);
      final corps = migration.substring(debut, fin);
      return {
        for (final l in corps.split('\n'))
          if (RegExp(r'^\s{2}\w+\s+(uuid|text|timestamptz)').hasMatch(l))
            l.trim().split(RegExp(r'\s+')).first,
      };
    }

    test('aucune colonne locale n’est absente du serveur', () {
      // ⚠️ C'EST LE PIÈGE 42703. Une colonne déclarée en local part dans chaque
      // upsert ; si le serveur ne l'a pas, PostgREST répond 42703 — que
      // `_fatalResponseCodes` ne reconnaît PAS. Le connecteur ne complète pas
      // la transaction : il rejoue le lot INDÉFINIMENT. Ce poste n'envoie plus
      // rien, jamais, sans un message à l'écran.
      final locales = colonnesLocales();
      final serveur = colonnesServeur();
      expect(locales.difference(serveur), isEmpty,
          reason: 'Colonnes déclarées en local et absentes en base : le poste '
              'rejouerait son lot sans fin.');
    });

    test('le serveur n’a pas de colonne obligatoire oubliée en local', () {
      final locales = colonnesLocales()..add('id');
      final serveur = colonnesServeur();
      expect(serveur.difference(locales), isEmpty,
          reason: 'Une colonne serveur absente du schéma local ne descend pas '
              'sur les postes : le registre afficherait une ligne amputée.');
    });
  });

  group('La table descend vraiment sur les postes', () {
    test('`issued_documents` figure dans le bucket by_school des sync-rules',
        () {
      final rules = _lire('../powersync/config/sync-rules.yaml');
      expect(
        rules.contains(
            'SELECT * FROM issued_documents WHERE school_id = bucket.sid'),
        isTrue,
        reason: 'Sans cette ligne, les écritures remontent bien vers Postgres '
            'mais n’appartiennent à aucun bucket : la copie locale disparaît '
            'au checkpoint suivant et le registre s’affiche VIDE alors que la '
            'donnée existe. Rien n’est perdu, mais l’écran ment.',
      );
    });

    test('elle est dans by_school, pas dans un bucket sensible', () {
      final rules = _lire('../powersync/config/sync-rules.yaml');
      final iBySchool = rules.indexOf('  by_school:');
      final iSensible = rules.indexOf('  sensitive_finance:');
      final iTable = rules.indexOf('FROM issued_documents');
      expect(iTable, greaterThan(iBySchool));
      expect(iTable, lessThan(iSensible),
          reason: 'Le registre n’est pas une donnée sensible à part : il suit '
              'l’école, comme les pièces du dossier.');
    });
  });
}
