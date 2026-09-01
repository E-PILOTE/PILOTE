import 'dart:io';

import 'package:epilote/features/communication/providers/circulaires_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA CIRCULAIRE DESCEND JUSQU'À L'ÉCOLE (migration 0167)
//
//  Le chef d'établissement travaille HORS LIGNE. Pour qu'il reçoive la note de
//  sa tutelle, il fallait la faire descendre par PowerSync — et le plan que le
//  dépôt gardait en commentaire ne pouvait PAS marcher : il joignait deux
//  tables dans une requête de paramètres, ce que les Sync Rules interdisent.
//
//  Ces tests gardent les trois pièces de la solution : l'instantané côté base,
//  la règle de synchro sans JOIN, et la lecture locale côté Dart.
// ════════════════════════════════════════════════════════════════════════════

String _lire(String chemin) {
  final f = File(chemin);
  expect(f.existsSync(), isTrue, reason: 'Sonde aveugle : $chemin introuvable.');
  // ⚠️ CRLF sous Windows : sans normalisation, le `.` d'une regex
  // s'arrete sur le retour chariot et toute sonde multiligne devient aveugle.
  return f.readAsStringSync().replaceAll('\r\n', '\n');
}

String get _sql0167 => _lire('../database/migrations/'
    '0167_AVANT_LE_BUILD_la_circulaire_descend_a_lecole.sql');
String get _syncRules => _lire('../powersync/config/sync-rules.yaml');

/// Le YAML EFFECTIF, commentaires retires.
///
/// ⚠️ Une sonde qui lit les commentaires mesure la prose, pas la regle :
/// ce fichier explique longuement ce qu'il ne fait PAS, et ces phrases citent
/// justement les tables qu'on cherche a ne pas trouver.
String get _syncRulesEffectif => _syncRules
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('#'))
    .join('\n');
String get _schemaLocal =>
    _lire('lib/services/powersync/powersync_schema.dart');

void main() {
  group('La ligne locale porte tout ce qu\'il y a à lire', () {
    Map<String, dynamic> ligne({Object? accuseRequis = 1, String? lu}) => {
          'circulaire_id': 'c1',
          'school_id': 's1',
          'group_id': 'g1',
          'emetteur_group_id': 'min1',
          'emetteur_nom': 'MEPSA',
          'reference': 'REF-12',
          'objet': 'Rentrée scolaire',
          'corps': 'Le corps de la note.',
          'priorite': 'urgente',
          'accuse_requis': accuseRequis,
          'echeance': '2026-10-01',
          'publiee_le': '2026-09-01T08:00:00Z',
          'lu_le': lu,
          'created_at': '2026-09-01T08:00:00Z',
          'school_name': 'CEG Kinkala',
        };

    test('l\'identité de la circulaire vient de `circulaire_id`, pas de `id`',
        () {
      // ⚠️ `id` est celui de la LIGNE DESTINATAIRE. Le confondre avec celui de
      // la circulaire ferait qu'accuser réception viserait une circulaire
      // inexistante — la RPC lèverait 42501 et l'accusé serait impossible,
      // sans que l'écran sache pourquoi.
      final c = Circulaire.fromLigneLocale(ligne());
      expect(c.id, 'c1');
    });

    test('l\'instantané est lu en entier', () {
      final c = Circulaire.fromLigneLocale(ligne());
      expect(c.objet, 'Rentrée scolaire');
      expect(c.corps, 'Le corps de la note.');
      expect(c.emetteurNom, 'MEPSA');
      expect(c.reference, 'REF-12');
      expect(c.priorite, CirculairePriorite.urgente);
      expect(c.echeance, DateTime(2026, 10));
      expect(c.publiee, isTrue);
    });

    test('`accuse_requis` arrive en ENTIER depuis SQLite, pas en booléen', () {
      // PowerSync stocke les booléens en INTEGER. Un `as bool?` renverrait
      // null, donc `accuseRequis` tomberait à sa valeur par défaut et l'écran
      // cesserait de réclamer l'accusé — en silence.
      expect(Circulaire.fromLigneLocale(ligne(accuseRequis: 1)).accuseRequis,
          isTrue);
      expect(Circulaire.fromLigneLocale(ligne(accuseRequis: 0)).accuseRequis,
          isFalse);
    });

    test('une colonne ABSENTE vaut « accusé demandé », jamais le contraire',
        () {
      // ⚠️ Le défaut que ce test a manqué à sa première écriture.
      // `circulaires.accuse_requis` est NOT NULL DEFAULT TRUE : une valeur
      // absente signifie que rien ne dit le contraire, pas qu'aucun accusé
      // n'est demandé. Lu `== 1`, ce cas rendait « non » — et retirait à la
      // circulaire la seule chose qui lui donne une valeur administrative.
      // Forme sûre : `actifOffline` (`core/utils/booleen_offline.dart`).
      expect(Circulaire.fromLigneLocale(ligne(accuseRequis: null)).accuseRequis,
          isTrue);
    });

    test('une école, une ligne : l\'accusé reste par établissement', () {
      final c = Circulaire.fromLigneLocale(ligne());
      expect(c.mesEcoles, hasLength(1));
      expect(c.mesEcoles.single.schoolId, 's1');
      expect(c.mesEcoles.single.nom, 'CEG Kinkala');
      expect(c.mesEcoles.single.lue, isFalse);
      expect(c.toutesLues, isFalse);
    });

    test('accusée, elle est comptée comme lue', () {
      final c = Circulaire.fromLigneLocale(
          ligne(lu: '2026-09-02T10:00:00Z'));
      expect(c.mesEcoles.single.lue, isTrue);
      expect(c.toutesLues, isTrue);
      expect(c.nbMesEcolesLues, 1);
    });
  });

  group('La règle de synchro', () {
    test('AUCUNE requête de paramètres ne joint deux tables', () {
      // ⚠️ LE PIÈGE DE CE CHANTIER. Le dépôt gardait, en commentaire, un
      // bucket dont la requête de paramètres joignait `circulaire_destinataires`
      // à `profiles`. Les Sync Rules l'interdisent — « Not supported:
      // subqueries, JOINs, CTEs », une seule table par requête. La règle aurait
      // échoué à `validate`, ou serait passée sans rien faire descendre.
      final yaml = _syncRulesEffectif;
      final blocs = RegExp(
        r'parameters:\s*>-\s*\n((?:\s{6,}.*\n)+)',
      ).allMatches(yaml);
      expect(blocs, isNotEmpty,
          reason: 'Sonde aveugle : aucune requête de paramètres lue.');
      for (final m in blocs) {
        final q = m.group(1)!.toUpperCase();
        expect(q.contains(' JOIN '), isFalse,
            reason: 'Une requête de paramètres joint deux tables — interdit '
                'par les Sync Rules :\n${m.group(1)}');
        expect('SELECT'.allMatches(q).length, 1,
            reason: 'Sous-requête dans une requête de paramètres — interdit :'
                '\n${m.group(1)}');
      }
    });

    test('les circulaires descendent par un bucket SÉPARÉ', () {
      // Ajouter une table à `by_school` en changerait le contenu : les postes
      // resynchroniseraient élèves, inscriptions et candidatures pour une note
      // de deux pages. Un bucket neuf ne fait descendre que ce qu'il ajoute.
      final yaml = _syncRulesEffectif;
      expect(yaml.contains('circulaires_ecole:'), isTrue);

      final debutBucket = yaml.indexOf('circulaires_ecole:');
      final bySchool = yaml.indexOf('by_school:');
      final blocBySchool = yaml.substring(bySchool, debutBucket);
      expect(blocBySchool.contains('circulaire_destinataires'), isFalse,
          reason: 'circulaire_destinataires a été ajoutée à `by_school` : tout '
              'le bucket resynchroniserait sur chaque poste.');
    });

    test('l\'école ne reçoit QUE ce qui lui est adressé', () {
      // Le ciblage (`cible_secteur`, `cible_departement`) n'a de sens que si
      // une école exclue ne reçoit pas le texte quand même.
      final yaml = _syncRulesEffectif;
      final bloc = yaml.substring(yaml.indexOf('circulaires_ecole:'));
      expect(bloc.contains('WHERE school_id = bucket.sid'), isTrue);
      expect(bloc.contains('FROM circulaires '), isFalse,
          reason: 'La table `circulaires` descendrait entière : le ciblage '
              'deviendrait décoratif.');
    });
  });

  group('Le schéma local', () {
    test('déclare la table, sinon elle descend sans être lisible', () {
      final dart = _schemaLocal;
      expect(dart.contains("Table('circulaire_destinataires'"), isTrue);
    });

    test('déclare CHAQUE colonne de l\'instantané', () {
      // Une colonne oubliée ici ne lève rien : elle est simplement absente de
      // la vue locale, et l'écran affiche un vide sans expliquer pourquoi.
      final bloc = _schemaLocal.substring(
          _schemaLocal.indexOf("Table('circulaire_destinataires'"));
      for (final col in [
        'circulaire_id', 'school_id', 'group_id', 'emetteur_group_id',
        'emetteur_nom', 'reference', 'objet', 'corps', 'priorite',
        'accuse_requis', 'echeance', 'publiee_le', 'lu_le',
      ]) {
        expect(bloc.contains("'$col'"), isTrue,
            reason: '`$col` n\'est pas déclarée dans le schéma local.');
      }
    });
  });

  group('Ce que la migration 0167 doit tenir', () {
    test('l\'instantané est REFUSÉ à la modification, pas ignoré', () {
      // ⚠️ Un déclencheur qui LÈVE, pas une politique `USING`. La table est
      // synchronisée : un `USING` qui écarte l'écriture rend zéro ligne côté
      // serveur alors que le poste a DÉJÀ modifié sa copie locale. L'écran
      // dirait « enregistré », et la valeur d'origine reviendrait à la synchro
      // suivante.
      final sql = _sql0167;
      expect(sql.contains('RAISE EXCEPTION'), isTrue);
      expect(sql.contains("ERRCODE = '42501'"), isTrue);
      expect(sql.contains('BEFORE UPDATE ON public.circulaire_destinataires'),
          isTrue);
      expect(RegExp(r'CREATE POLICY\s+\w+\s+ON\s+public\.circulaire_destinataires'
              r'\s+FOR\s+UPDATE')
          .hasMatch(sql),
          isFalse,
          reason: 'Une politique d\'UPDATE rendrait le refus MUET.');
    });

    test('`lu_le` reste modifiable — c\'est la seule chose qui bouge', () {
      // Si le déclencheur comparait aussi l'accusé, plus personne ne pourrait
      // accuser réception : la circulaire perdrait toute valeur.
      final sql = _sql0167;
      final fn = sql.substring(sql.indexOf('fn_circ_dest_instantane_fige'));
      final comparaison = fn.substring(0, fn.indexOf('RAISE EXCEPTION'));
      expect(comparaison.contains('lu_le'), isFalse,
          reason: 'Le déclencheur compare `lu_le` : accuser deviendrait '
              'impossible.');
    });

    test('la publication ne touche toujours ni élève ni parent', () {
      // 0167 RÉÉCRIT `circulaire_publier`. La garde de 0161 doit continuer de
      // valoir sur la nouvelle version, sinon elle ne gardait que l'ancienne.
      final publier = _sql0167
          .substring(_sql0167.indexOf('FUNCTION public.circulaire_publier'));
      for (final interdit in [
        "'parent'", "'eleve'", 'students', 'student_tutors'
      ]) {
        expect(publier.contains(interdit), isFalse,
            reason: 'La publication touche « $interdit » : une circulaire '
                's\'adresse aux ÉTABLISSEMENTS.');
      }
    });

    test('le chef d\'établissement est notifié, et vers SA route', () {
      // C'est de lui qu'on attend l'accusé : sans notification, il ne découvre
      // la circulaire qu'en ouvrant l'écran de son propre chef.
      final sql = _sql0167;
      expect(sql.contains("'/user/circulaires'"), isTrue);
      expect(sql.contains("p.role IN ('directeur', 'proviseur')"), isTrue);
      expect(sql.contains("'/admin/circulaires'"), isTrue,
          reason: 'L\'administrateur de groupe doit rester notifié.');
    });
  });

  group('L\'écran est réservé à la direction', () {
    test('le routeur garde /user/circulaires', () {
      // Deux verrous, comme pour les Rapports : la sidebar masque, le routeur
      // refuse. Masquer seul laisse l\'URL atteignable — et l\'accusé de
      // lecture engage l\'établissement.
      final router = _lire('lib/core/router/app_router.dart');
      expect(router.contains('loc == Routes.userCirculaires'), isTrue,
          reason: 'La route n\'est pas dans le garde `directionRoles`.');
    });
  });
}
