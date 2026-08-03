// ════════════════════════════════════════════════════════════════════════════
//  LA PREMIÈRE HEURE D'UN ÉTABLISSEMENT
//
//  Le 2 octobre, mille écoles ouvrent l'application sur du VIDE. Aucune n'a
//  jamais utilisé de système : il n'en existait pas au Congo. Un tableau de
//  bord à zéro, une dizaine de menus, et rien qui dise par où commencer — c'est
//  là qu'un établissement abandonne, dans la demi-heure, et qu'on ne le
//  récupère plus.
//
//  ── L'ORDRE N'EST PAS UNE PRÉFÉRENCE, C'EST UNE DÉPENDANCE ─────────────────
//  Sans année scolaire, une classe ne peut pas exister. Sans classe, aucune
//  inscription. Sans inscription, aucune note. Chaque étape ouvre la suivante,
//  et sauter la première fait échouer les quatre autres sans que personne
//  comprenne pourquoi. La liste dit donc CE QUI BLOQUE, pas seulement ce qui
//  manque.
//
//  ── ELLE DISPARAÎT QUAND ELLE A SERVI ──────────────────────────────────────
//  Une liste de démarrage qui reste affichée pour toujours devient du mobilier :
//  on ne la lit plus. Celle-ci s'efface dès que l'établissement est en ordre de
//  marche.
//
//  100 % hors ligne : `db.watch`, comme tout l'espace école.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/routes.dart';
import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/auth_provider.dart';
import 'academic_year_context.dart';

/// Une étape du démarrage.
class EtapeDemarrage {
  const EtapeDemarrage({
    required this.titre,
    required this.faite,
    required this.compte,
    required this.route,
    required this.pourquoi,
    required this.bloque,
    this.parLeReseau = false,
  });

  final String titre;
  final bool faite;

  /// Ce qui existe déjà — « 0 classe », « 12 agents ».
  final int compte;

  final String route;

  /// À quoi sert cette étape, en une phrase.
  final String pourquoi;

  /// Ce que son absence empêche. C'est cela qui fait agir, pas la case vide.
  final String bloque;

  /// L'établissement ne peut PAS faire cette étape lui-même : elle relève de
  /// l'administration du réseau. L'envoyer sur un écran en lecture seule sans
  /// le dire, c'est le laisser chercher un bouton qui n'existe pas.
  final bool parLeReseau;
}

/// L'état de démarrage d'un établissement.
class Demarrage {
  const Demarrage(this.etapes);
  final List<EtapeDemarrage> etapes;

  int get faites => etapes.where((e) => e.faite).length;
  int get total => etapes.length;
  bool get termine => total > 0 && faites == total;
  double get avancement => total == 0 ? 0 : faites / total;

  /// La première étape non faite : la seule sur laquelle il faut insister.
  /// Proposer cinq actions à qui n'en a jamais fait aucune, c'est n'en proposer
  /// aucune.
  EtapeDemarrage? get prochaine {
    for (final e in etapes) {
      if (!e.faite) return e;
    }
    return null;
  }

  static const vide = Demarrage([]);
}

final demarrageProvider = StreamProvider.autoDispose<Demarrage>((ref) {
  ref.keepAlive();
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final schoolId = profile?.schoolId;
  final yearId = ref.watch(activeYearIdProvider);
  if (schoolId == null || schoolId.isEmpty) return Stream.value(Demarrage.vide);

  // Une seule requête : cinq comptes, cinq sous-requêtes. Cinq `watch` séparés
  // rouvriraient cinq flux sur la même base pour afficher une seule carte.
  return db.watch(
    '''
    SELECT
      (SELECT COUNT(*) FROM academic_years
        WHERE (school_id = ?1 OR school_id IS NULL)
          AND COALESCE(is_current, 0) <> 0)                       AS annees,
      (SELECT COUNT(*) FROM school_levels
        WHERE school_id = ?1 AND COALESCE(is_active, 1) <> 0)     AS niveaux,
      (SELECT COUNT(*) FROM classes
        WHERE school_id = ?1 AND academic_year_id = ?2
          AND COALESCE(is_active, 1) <> 0)                        AS classes,
      (SELECT COUNT(*) FROM profiles
        WHERE school_id = ?1 AND COALESCE(is_active, 1) <> 0)     AS agents,
      (SELECT COUNT(*) FROM class_enrollments
        WHERE school_id = ?1 AND academic_year_id = ?2
          AND status = 'active')                                  AS eleves
    ''',
    parameters: [schoolId, yearId ?? ''],
  ).map((rows) {
    if (rows.isEmpty) return Demarrage.vide;
    final r = rows.first;
    int n(String k) => (r[k] as num?)?.toInt() ?? 0;

    return Demarrage([
      EtapeDemarrage(
        titre: 'Année scolaire ouverte',
        faite: n('annees') > 0,
        compte: n('annees'),
        route: Routes.calendrier,
        parLeReseau: true,
        pourquoi: 'Tout se rattache à une année : les classes, les notes, les '
            'paiements.',
        bloque: 'Sans année courante, rien ne peut être créé. L\'année est '
            'ouverte par l\'administration du réseau.',
      ),
      EtapeDemarrage(
        titre: 'Recevoir la structure du réseau',
        faite: n('niveaux') > 0,
        compte: n('niveaux'),
        route: Routes.structure,
        parLeReseau: true,
        pourquoi: 'Les cycles et niveaux de l\'établissement (CP1, 6ᵉ, '
            'Terminale…) sont posés par l\'administration du réseau.',
        bloque: 'Sans niveaux, aucune classe ne peut être ouverte. '
            'Rapprochez-vous de l\'administration du réseau.',
      ),
      EtapeDemarrage(
        titre: 'Créer les classes',
        faite: n('classes') > 0,
        compte: n('classes'),
        route: Routes.classes,
        pourquoi: 'Une classe par division réelle : 6ᵉ A, 6ᵉ B, CM2…',
        bloque: 'Sans classe, aucun élève ne peut être inscrit.',
      ),
      EtapeDemarrage(
        titre: 'Enregistrer le personnel',
        faite: n('agents') > 1,
        compte: n('agents'),
        pourquoi: 'Chaque agent a son compte : c\'est lui qui signe ce qu\'il '
            'saisit.',
        route: Routes.personnel,
        bloque: 'Sans enseignants, ni emploi du temps ni saisie de notes.',
      ),
      EtapeDemarrage(
        titre: 'Inscrire les élèves',
        faite: n('eleves') > 0,
        compte: n('eleves'),
        route: Routes.inscriptions,
        pourquoi: 'C\'est le gros du travail de rentrée — et tout le reste en '
            'dépend.',
        bloque: 'Sans élèves, l\'établissement reste vide sur tous les écrans.',
      ),
    ]);
  });
});
