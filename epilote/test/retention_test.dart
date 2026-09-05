import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'ecran_reglages_source.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA CONSERVATION SE TIENT, ELLE NE SE RÈGLE PAS (2026-08-28)
//
//  Cahier des charges, règle n°4 : « Bulletins : conservés 10 ans · Données
//  financières : 5 ans ». `docs/ANALYSE.md` la marquait en rouge : « aucune
//  rétention, aucune purge, aucun archivage daté nulle part ».
//
//  ── CE QUE L'OBLIGATION DEMANDE VRAIMENT ──────────────────────────────────
//  « Conservés 10 ans » est un PLANCHER : le ministère doit pouvoir faire
//  rééditer un bulletin dix ans plus tard. Ce n'est pas une obligation de
//  purger, c'est une obligation de NE PAS PERDRE.
//
//  Mais « interdire toute suppression pendant dix ans » serait faux dans
//  l'autre sens : une comptable qui saisit une dépense de travers doit pouvoir
//  la retirer le jour même. Une pièce comptable ne devient une PIÈCE qu'une
//  fois l'exercice arrêté.
//
//  D'où la règle retenue, celle de toute comptabilité : on corrige dans
//  l'exercice ouvert, la CLÔTURE scelle. Le plancher est alors tenu par une
//  propriété plus simple et plus sûre qu'une purge — rien ne supprime en masse.
//
//  ── VÉRIFIÉ EN PRODUCTION (transaction annulée) ───────────────────────────
//    année ouverte, Direction supprime  → OUI (corrigeable)
//    année CLOSE,   Direction supprime  → refusé (scellé)
//    année ouverte, Secrétariat         → refusé (le verbe reste exigé)
//
//  Le troisième cas est le plus important : la migration RECOMPOSE la politique
//  au lieu de la réécrire, donc durcir la conservation ne devait pas rouvrir
//  les droits. Il l'a confirmé.
//
//  ── ET L'ÉCRAN A CESSÉ DE PROMETTRE ───────────────────────────────────────
//  « Conservation des données » offrait quatre réglages — rétention des
//  dossiers, rétention des journaux, archivage automatique, seuil d'inactivité.
//  Les valeurs partaient dans `group_settings`, et AUCUN code ne les lisait.
//  Un administrateur réglait la conservation des dossiers d'élèves d'un
//  ministère et croyait la plateforme tenue par son choix.
// ════════════════════════════════════════════════════════════════════════════

const _kMigration =
    '../database/migrations/0145_la_cloture_scelle_ce_quon_doit_conserver.sql';

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('$chemin introuvable — tourner depuis `epilote/`.');
  return f.readAsStringSync().replaceAll('\r\n', '\n');
}

void main() {
  group('La clôture scelle', () {
    final sql = _lire(_kMigration);

    test('les trois pièces nommées au cahier des charges sont scellées', () {
      for (final t in ['bulletins', 'expenses', 'student_payments']) {
        expect(sql.contains("('$t',"), isTrue,
            reason: '`$t` doit être scellée par la clôture de son année.');
      }
      expect(sql.contains('annee_scellee(academic_year_id)'), isTrue);
    });

    test('le sceau filtre, il ne lève pas', () {
      expect(sql.contains('ALTER POLICY'), isTrue);
      expect(sql.contains('USING'), isTrue,
          reason: 'Un `RAISE` produirait un 42501 — code fatal pour le '
              'connecteur PowerSync, qui jetterait le lot entier. `USING` ne '
              'voit pas la ligne : zéro ligne touchée, aucune erreur.');
      expect(RegExp(r'RAISE\s+EXCEPTION').hasMatch(sql), isFalse);
    });

    test('durcir la conservation ne rouvre pas les droits', () {
      // La politique est RECOMPOSÉE : `(ancienne) AND NOT scellée`. La
      // réécrire de zéro aurait effacé le verbe de module au passage.
      expect(sql.contains('SELECT qual FROM pg_policies'), isTrue,
          reason: 'Le verbe existant doit être repris, pas remplacé.');
    });

    test('ce qui ne peut pas être scellé sans mentir ne l\'est pas', () {
      // `payroll` n'a pas d'`academic_year_id`, et son écran ne lit pas
      // `yearReadOnlyProvider` : un sceau y produirait une suppression qui ne
      // supprime rien, sans message.
      expect(sql.contains("('payroll',"), isFalse);
      expect(sql.contains('`payroll` n\'est PAS scellée'), isTrue,
          reason: 'Une omission doit être écrite, sinon elle passe pour un '
              'oubli.');
    });
  });

  group('L\'écran ne promet plus ce que rien ne tient', () {
    final src = sourceEcranReglages();

    test('les quatre réglages inertes ont disparu', () {
      for (final champ in [
        'dataRetentionMonths: v',
        'auditRetentionMonths: v',
        'autoArchiveInactive: v',
        'archiveAfterMonths: v',
      ]) {
        expect(src.contains(champ), isFalse,
            reason: 'Ce réglage n\'était lu par aucun code : le proposer '
                'faisait prendre une décision qui n\'aurait pas lieu.');
      }
    });

    test('la section énonce ce qui est réellement tenu', () {
      expect(src.contains('_ConservationCard'), isTrue);
      expect(src.contains('Bulletins — 10 ans'), isTrue);
      expect(src.contains('Données financières — 5 ans'), isTrue);
      expect(src.contains('Aucune purge automatique'), isTrue,
          reason: 'Le silence sur la purge laisserait croire qu\'elle existe.');
    });

    test('le journal d\'audit est annoncé non effaçable', () {
      // Migration 0127 : « un journal que l'audité efface n'est pas un
      // journal ». L'écran doit le dire, y compris de lui-même.
      expect(src.contains('Journal d\\\'audit — conservé'), isTrue);
    });
  });

  group('Rien ne supprime en masse — c\'est ce qui tient le plancher', () {
    test('aucun DELETE sans clause WHERE dans le code applicatif', () {
      final fautes = <String>[];
      for (final f in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        for (final m
            in RegExp(r"DELETE FROM (\w+)([^']*)").allMatches(f.readAsStringSync())) {
          if (!m.group(2)!.toUpperCase().contains('WHERE')) {
            fautes.add('${f.path} → ${m.group(0)}');
          }
        }
      }
      expect(fautes, isEmpty,
          reason: 'Un `DELETE` sans `WHERE` viderait une table entière : '
              'c\'est exactement ce que la conservation interdit.\n'
              '${fautes.join('\n')}');
    });
  });
}
