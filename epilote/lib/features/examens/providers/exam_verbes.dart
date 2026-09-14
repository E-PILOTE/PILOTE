import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../navigation/providers/permissions_provider.dart' show canProvider;
import 'exam_candidates_provider.dart' show kSlugExamens;

// ════════════════════════════════════════════════════════════════════════════
//  LES VERBES DU MODULE EXAMENS — UN SEUL ENDROIT, ALIGNÉ SUR LA RLS
//
//  ── LA RÈGLE, ET POURQUOI ELLE COÛTE CHER QUAND ELLE EST ROMPUE ───────────
//  Un bouton ne doit JAMAIS demander moins que la politique serveur.
//
//  L'application est offline-first : le clic écrit dans le SQLite local,
//  l'écran affiche le résultat, l'agent passe à la suite. Le refus arrive
//  plus tard, à la remontée — en `42501`, qui est un code FATAL
//  (`powersync_connector.dart`). Fatal veut dire : PowerSync complète la
//  transaction et **jette le lot entier**. Pas seulement le geste refusé :
//  tout ce qui l'accompagnait dans le même lot.
//
//  Le geste, lui, a été montré comme réussi. C'est le mode de défaillance le
//  plus coûteux du module, et il est entièrement silencieux.
//
//  L'inverse — un bouton plus exigeant que la RLS — ne perd rien : il cache
//  une action à quelqu'un qui aurait pu la faire. C'est un choix de produit,
//  pas un défaut, et il se rattrape d'une case dans le profil d'accès.
//
//  ── LA TABLE DE CORRESPONDANCE (relevée en base le 2026-09-10) ────────────
//
//  | Geste                     | Écrit                    | Politique serveur              |
//  |---------------------------|--------------------------|--------------------------------|
//  | Inscrire un candidat      | INSERT exam_candidates   | `examens/create`               |
//  | Cocher une pièce, n° cand.| UPDATE exam_candidates   | `examens/update`               |
//  | Saisir le résultat        | UPDATE exam_candidates   | `examens/update`               |
//  | Marquer déposé / rouvrir  | UPDATE exam_candidates   | `examens/update`               |
//  | Retirer une candidature   | DELETE exam_candidates   | `examens/`**`delete`**         |
//  | Encaisser les frais       | INSERT student_payments  | create sur **l'un des trois** : |
//  |                           |                          | `paiements-eleves`, `inscriptions`, `examens` |
//
//  ── CE QUI ÉTAIT ROMPU ────────────────────────────────────────────────────
//  Le RETRAIT était gardé par `update`. Aujourd'hui latent — les 14 profils
//  qui ont `update` ont tous `delete`. Le jour où une école crée un profil
//  « saisie sans suppression », le retrait part en local, s'affiche, puis se
//  fait refuser : le candidat revient à la synchro suivante, et le lot qui
//  l'accompagnait est perdu.
//
//  ── DEUX DÉCISIONS PRISES ICI, ET CE QU'ELLES CHANGENT ────────────────────
//
//  1. LE DÉPÔT PASSE SUR `validate`. La RLS n'exige que `update` : ce
//     resserrement ne perd donc aucune écriture. Il ferme une porte à sens
//     unique — après dépôt le retrait est bloqué (`row.isSubmitted`), et
//     ROUVRIR un dossier déposé demande déjà `validate`
//     (`exam_dossier_dialog.dart`). Le Secrétariat pouvait donc verrouiller
//     un dossier sans pouvoir le déverrouiller. Poser et défaire appartiennent
//     à la même main.
//     ⚠️ Conséquence en production : le profil « Secrétariat » (7 groupes) ne
//     marque plus « déposé ». Une case « valider » dans son profil d'accès le
//     lui rend, école par école. Le bouton ne DISPARAÎT pas — il se désactive
//     en disant pourquoi.
//
//  2. L'ENCAISSEMENT RECOPIE LA DISJONCTION DE LA RLS, au lieu de choisir un
//     seul module. C'est ce qui rend la caisse au comptable : « Comptabilité »
//     LIT `examens` mais n'y a aucun droit d'écriture — le bouton Frais lui
//     était donc caché, alors que `payments_insert` accepte son
//     `paiements-eleves/create` depuis toujours. Et le Secrétariat, qui
//     encaisse aujourd'hui par `examens/create`, le garde : aucune régression
//     trois semaines avant le déploiement.
//
//  ── CE QUI RESTE DÉLIBÉRÉMENT NON UTILISÉ ─────────────────────────────────
//  `approve` et `manage` sont accordés à la Direction en base et lus par zéro
//  ligne. C'est VOULU : les brancher sur la saisie du résultat et sur les
//  frais retirerait ces deux gestes au Secrétariat, qui les fait en pratique —
//  transcrire une proclamation et encaisser 5 000 F sont des tâches de
//  secrétariat, pas des décisions de direction. Ces deux verbes restent
//  disponibles pour une école qui voudrait ce cloisonnement ; le code ne
//  l'impose pas.
// ════════════════════════════════════════════════════════════════════════════

/// Le module de la caisse. La politique `payments_insert` l'accepte au même
/// titre que `examens` et `inscriptions`.
const String kSlugPaiementsEleves = 'paiements-eleves';

/// Inscrire un candidat — `INSERT exam_candidates`.
final peutInscrireCandidatProvider = Provider.autoDispose<bool>(
    (ref) => ref.watch(canProvider((slug: kSlugExamens, action: 'create'))));

/// Modifier une candidature : cocher une pièce, saisir un numéro, saisir le
/// résultat reçu — `UPDATE exam_candidates`.
final peutModifierCandidatProvider = Provider.autoDispose<bool>(
    (ref) => ref.watch(canProvider((slug: kSlugExamens, action: 'update'))));

/// Retirer une candidature — `DELETE exam_candidates`.
/// ⚠️ `delete`, jamais `update` : voir l'en-tête de ce fichier.
final peutRetirerCandidatProvider = Provider.autoDispose<bool>(
    (ref) => ref.watch(canProvider((slug: kSlugExamens, action: 'delete'))));

/// Marquer un dossier déposé au centre d'examen — geste engageant, apparié à
/// la réouverture qui demande déjà `validate`.
final peutDeposerDossierProvider = Provider.autoDispose<bool>(
    (ref) => ref.watch(canProvider((slug: kSlugExamens, action: 'validate'))));

/// Encaisser les frais d'examen — `INSERT student_payments`.
///
/// Recopie EXACTEMENT la disjonction de `payments_insert` (moins
/// `inscriptions`, qui n'ouvre pas cet écran). Ne pas la remplacer par un
/// module unique : ce serait une règle différente de celle du serveur, qui
/// dériverait à la première évolution de la politique.
final peutEncaisserFraisExamenProvider = Provider.autoDispose<bool>((ref) =>
    ref.watch(canProvider((slug: kSlugPaiementsEleves, action: 'create'))) ||
    ref.watch(canProvider((slug: kSlugExamens, action: 'create'))));
