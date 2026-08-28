import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/erreur_metier.dart';
import '../../navigation/providers/permissions_provider.dart';
import 'communication_scope.dart';

// ════════════════════════════════════════════════════════════════════════════
//  PUBLIER AU NOM DE L'ÉCOLE EST UN DROIT — IL N'ÉTAIT CELUI DE PERSONNE
//
//  Le domaine Communication vivait entièrement hors du modèle de permissions :
//  aucun module dans `modules`, donc aucun `ModuleScaffold`, aucun
//  `PermissionGate`, aucun `canProvider` dans ses 55 fichiers. Tout membre du
//  personnel — un enseignant, un surveillant, le responsable de la cantine —
//  pouvait publier une annonce visible de toutes les familles, et supprimer
//  celle d'un autre.
//
//  ── POURQUOI LE GARDE HABITUEL NE MARCHAIT PAS ICI ────────────────────────
//  Ce n'est pas un oubli distrait. `canProvider` lit `myPermissionsProvider`,
//  qui interroge la base LOCALE PowerSync du profil d'accès de l'agent. Or
//  `super_admin` et `admin_groupe` ne font pas tourner PowerSync (règle
//  centrale du projet) et n'ont pas de profil d'accès : pour eux,
//  `canProvider` rend TOUJOURS faux.
//
//  Ces écrans sont PARTAGÉS par les trois espaces — mêmes fichiers, trois
//  groupes de routes. Les garder avec `canProvider` seul aurait retiré la
//  publication à l'admin groupe et au super-admin, c'est-à-dire aux deux rôles
//  qui en ont le plus besoin. D'où un garde SCOPE-AWARE, comme le reste du
//  module : hors périmètre école, la ROUTE garde déjà (rôle) ; dans le
//  périmètre école, le VERBE décide.
//
//  ── LE GARDE VIT DANS L'ÉCRITURE, PAS SEULEMENT DANS LE BOUTON ────────────
//  Les providers servent à cacher le bouton ; `exigerDroitComm` est appelé
//  dans les fonctions d'écriture elles-mêmes. Un écran neuf qui appellerait
//  `createAnnouncementScoped` sans y penser reste gardé — c'est la seule forme
//  de garde qu'on n'oublie pas.
// ════════════════════════════════════════════════════════════════════════════

const String kSlugAnnonces = 'annonces';
const String kSlugMessagerie = 'messagerie';
const String kSlugEvenements = 'evenements';

/// Le membre peut-il faire [action] sur le module [slug] de communication ?
///
/// Hors périmètre école (super-admin, admin groupe), rend `true` : ces espaces
/// n'ont pas de profil d'accès, et leurs routes sont déjà gardées par le rôle.
bool droitComm(Ref ref, String slug, String action) {
  final ctx = ref.watch(communicationContextProvider);
  if (!ctx.isSchool) return true;
  return ref.watch(canProvider((slug: slug, action: action)));
}

/// Variante pour un widget (`WidgetRef`), sans abonnement — usage ponctuel dans
/// un `onPressed` ou une fonction d'écriture.
bool droitCommLu(WidgetRef ref, String slug, String action) {
  final ctx = ref.read(communicationContextProvider);
  if (!ctx.isSchool) return true;
  return ref.read(canProvider((slug: slug, action: action)));
}

/// Refuse l'écriture, avec une phrase pour l'agent, si le droit manque.
///
/// À appeler au DÉBUT de chaque fonction d'écriture partagée. `ErreurMetier`
/// remonte telle quelle à l'écran (voir `core/utils/message_erreur.dart`) : la
/// personne apprend qu'elle n'a pas ce droit, au lieu de voir « une erreur
/// inattendue » ou, pire, un bouton qui ne fait rien.
void exigerDroitComm(WidgetRef ref, String slug, String action) {
  if (droitCommLu(ref, slug, action)) return;
  throw ErreurMetier(switch (slug) {
    kSlugAnnonces =>
      'Votre profil ne permet pas de publier ou modifier une annonce de '
          'l\'établissement.',
    kSlugEvenements =>
      'Votre profil ne permet pas de publier ou modifier un événement de '
          'l\'établissement.',
    _ => 'Votre profil ne permet pas cette action.',
  });
}

/// Le membre peut-il publier une annonce au nom de l'établissement ?
final peutPublierAnnonceProvider = Provider.autoDispose<bool>(
    (ref) => droitComm(ref, kSlugAnnonces, 'create'));

/// … la modifier (épingler, archiver, corriger) ?
final peutModifierAnnonceProvider = Provider.autoDispose<bool>(
    (ref) => droitComm(ref, kSlugAnnonces, 'update'));

/// … la supprimer ?
final peutSupprimerAnnonceProvider = Provider.autoDispose<bool>(
    (ref) => droitComm(ref, kSlugAnnonces, 'delete'));

/// Le membre peut-il publier un événement ?
final peutPublierEvenementProvider = Provider.autoDispose<bool>(
    (ref) => droitComm(ref, kSlugEvenements, 'create'));

/// … le modifier ?
final peutModifierEvenementProvider = Provider.autoDispose<bool>(
    (ref) => droitComm(ref, kSlugEvenements, 'update'));

/// … le supprimer ?
final peutSupprimerEvenementProvider = Provider.autoDispose<bool>(
    (ref) => droitComm(ref, kSlugEvenements, 'delete'));
