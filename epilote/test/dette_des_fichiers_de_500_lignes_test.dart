import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'ecran_abonnement_groupe_source.dart';
import 'ecran_abonnements_source.dart';
import 'ecran_administrateurs_source.dart';
import 'ecran_dashboard_fondateur_source.dart';
import 'ecran_groupes_source.dart';
import 'ecran_reglages_source.dart';
import 'ecran_tableau_de_bord_source.dart';
import 'ecran_utilisateurs_source.dart';
import 'source_bibliotheque.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA RÈGLE DES 500 LIGNES, RENDUE OPPOSABLE
//
//  ── POURQUOI UN CLIQUET PLUTÔT QU'UNE INTERDICTION ────────────────────────
//  Le dépôt compte encore 83 fichiers au-dessus de 500 lignes ; interdire
//  franchement ferait tomber la suite entière et le test serait désactivé dans
//  la semaine. Un CLIQUET, lui, tient : la dette peut diminuer, jamais
//  augmenter. Chaque découpage abaisse le plafond, et un fichier neuf trop
//  gros fait tomber ce test le jour où il est écrit — pas six mois plus tard.
//
//  ⚠️ Ne JAMAIS relever [_plafond] pour faire passer un test. Ce nombre ne
//  monte pas. S'il gêne, c'est qu'il fait son travail : découper.
//
//  ── ET LES QUATRE ÉCRANS DÉJÀ DÉCOUPÉS ────────────────────────────────────
//  Neuf écrans ont été coupés en `part` : abonnements (2 652 lignes),
//  utilisateurs (2 346), administrateurs (3 134), groupes (3 400), modules
//  (3 192), modules du groupe (3 057), accès (3 027), formules (2 844) et
//  tableau de bord (2 975). Rien n'empêche qu'un morceau
//  regrossisse jusqu'à redevenir le fichier qu'on venait de casser : ces
//  bibliothèques-là sont donc tenues à la règle stricte.
// ════════════════════════════════════════════════════════════════════════════

/// Nombre de fichiers de `lib/` dépassant 500 lignes, au 2026-09-05.
///
/// Il en restait 98 au matin ; neuf écrans ont été découpés depuis.
const int _plafond = 83;

const int _limite = 500;

List<({String chemin, int lignes})> _fichiersTropLongs() {
  final res = <({String chemin, int lignes})>[];
  for (final e in Directory('lib').listSync(recursive: true)) {
    if (e is! File || !e.path.endsWith('.dart')) continue;
    final n = e.readAsStringSync().replaceAll('\r\n', '\n').split('\n').length;
    if (n > _limite) {
      res.add((chemin: e.path.replaceAll(r'\', '/'), lignes: n));
    }
  }
  res.sort((a, b) => b.lignes.compareTo(a.lignes));
  return res;
}

void main() {
  group('La dette ne remonte pas', () {
    test('pas plus de $_plafond fichiers au-dessus de $_limite lignes', () {
      final trop = _fichiersTropLongs();
      expect(trop.length, lessThanOrEqualTo(_plafond),
          reason: 'La dette a AUGMENTÉ. Les plus gros aujourd’hui :\n'
              '${trop.take(5).map((f) => '  ${f.lignes}  ${f.chemin}').join('\n')}\n'
              'Découpez le long des coutures de cohésion — ne relevez pas le '
              'plafond.');
    });

    test('le plafond suit la réalité : il ne doit pas rester trop haut', () {
      // Un cliquet qu'on oublie d'abaisser cesse de servir. Dix fichiers de
      // marge, c'est déjà beaucoup pour ce qu'il garde.
      final trop = _fichiersTropLongs();
      expect(_plafond - trop.length, lessThanOrEqualTo(10),
          reason: 'Le plafond est de $_plafond, il n’en reste que '
              '${trop.length} : abaissez-le à ${trop.length}.');
    });
  });

  group('Les écrans découpés le restent', () {
    final bibliotheques = <String, Map<String, int>>{
      'abonnements': taillesBibliotheque(
          coquille: coquilleAbonnements, dossier: dossierAbonnements),
      'utilisateurs': taillesEcranUtilisateurs(),
      'administrateurs': taillesEcranAdministrateurs(),
      'groupes': taillesEcranGroupes(),
      'tableau de bord': taillesTableauDeBord(),
      'tableau de bord fondateur': taillesDashboardFondateur(),
      'paramètres du groupe': taillesEcranReglages(),
      'abonnement du groupe': taillesAbonnementGroupe(),
    };

    for (final e in bibliotheques.entries) {
      test('aucun fichier de l’écran ${e.key} ne dépasse $_limite lignes', () {
        final trop = {
          for (final f in e.value.entries)
            if (f.value > _limite) f.key: f.value,
        };
        expect(trop, isEmpty, reason: 'À redécouper : $trop');
      });
    }

    test('les bibliothèques suivies sont bien éclatées', () {
      // Un découpage « défait » se voit ici avant de rendre toutes les sondes
      // de ces écrans vertes-mais-aveugles. Le seuil est volontairement bas :
      // le compte EXACT attendu par chaque écran vit dans son propre helper
      // (`minimumPieces`), qui refuse de rendre la source en dessous. Ici on
      // ne garde que « ce n'est plus un fichier unique ».
      for (final e in bibliotheques.entries) {
        expect(e.value.length, greaterThanOrEqualTo(4),
            reason: '${e.key} n’a plus que ${e.value.length} fichiers.');
      }
    });
  });
}
