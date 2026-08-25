import '../../../core/utils/write_identity.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CE QUI EMPÊCHE D'ENREGISTRER UNE MODIFICATION D'ÉLÈVE
//
//  ── POURQUOI HORS DE L'ÉCRAN ───────────────────────────────────────────────
//  Ces quatre règles ne parlent ni de widgets ni de contrôleurs : elles disent
//  si une saisie peut partir en base, et sur quelle page se trouve le problème.
//  Enfouies dans `_save()`, elles n'étaient vérifiables qu'en rejouant l'écran
//  à la main — or trois d'entre elles existent précisément parce qu'un dégât
//  s'est produit en production.
//
//  Même intention que `validateTutorDrafts` dans `models/tutor_draft.dart` :
//  la règle vit là où elle se teste.
//
//  ── LES TROIS DÉGÂTS QU'ELLES ÉVITENT ──────────────────────────────────────
//  1. Un tuteur NEUF sans `group_id` : le motif `?? ''` écrivait une chaîne
//     vide dans une colonne `uuid` NOT NULL. SQLite l'acceptait, l'écran
//     affichait « Modifications enregistrées », puis le serveur répondait
//     `22P02` et PowerSync abandonnait le LOT ENTIER — emportant l'élève et son
//     inscription modifiés juste avant. Sans message.
//  2. Une fiche de tuteur commencée puis laissée incomplète était jetée en
//     silence : l'agent lisait « enregistré » et repartait avec un dossier sans
//     aucun contact parental, dans une école où le tuteur est le seul canal
//     joignable.
//  3. Une classe non choisie : `class_id` est NOT NULL.
// ════════════════════════════════════════════════════════════════════════════

/// Une fiche de tuteur telle que la garde a besoin de la voir — sans widget,
/// sans contrôleur.
///
/// [id] `null` = fiche NEUVE (à créer). Une fiche existante n'est pas contrôlée
/// ici : elle est déjà en base, et la vider relève d'une suppression explicite.
typedef TuteurSaisi = ({String? id, String prenom, String nom, String tel});

/// Le refus, et la page où l'agent doit retourner pour le lever.
///
/// [etape] suit l'ordre du formulaire : 0 Élève, 1 Scolarité, 2 Tuteurs.
/// `-1` = le problème n'est sur aucune page (identifiant d'appareil manquant),
/// il ne sert donc à rien d'y renvoyer l'agent.
typedef RefusEdition = ({int etape, String message});

const int kEtapeAucune = -1;
const int kEtapeEleve = 0;
const int kEtapeScolarite = 1;
const int kEtapeTuteurs = 2;

/// Une fiche neuve est COMPLÈTE quand les trois champs sont renseignés.
bool _complete(TuteurSaisi t) =>
    t.prenom.trim().isNotEmpty &&
    t.nom.trim().isNotEmpty &&
    t.tel.trim().isNotEmpty;

/// Une fiche neuve est ENTAMÉE dès qu'un seul champ l'est.
bool _entamee(TuteurSaisi t) =>
    t.prenom.trim().isNotEmpty ||
    t.nom.trim().isNotEmpty ||
    t.tel.trim().isNotEmpty;

/// Le refus d'identité, ou `null`.
String? _refusIdentite(String prenom, String nom) =>
    (prenom.trim().isEmpty || nom.trim().isEmpty)
        ? 'Le prénom et le nom sont obligatoires.'
        : null;

/// Le refus lié aux identifiants de rattachement, ou `null`.
///
/// ⚠️ Exigés SEULEMENT s'il y a un tuteur neuf à créer. Sans cela, une
/// correction d'adresse — parfaitement faisable hors ligne — se serait heurtée
/// à des identifiants dont elle n'avait aucun besoin.
///
/// L'ÉCOLE s'ajoute au groupe depuis la migration 0110 :
/// `student_tutors.school_id` est NOT NULL, et c'est par lui que les coordonnées
/// des familles descendent — par école, et non plus par groupe. Un tuteur créé
/// sans lui serait refusé par le serveur exactement comme il l'était sans
/// `group_id`, avec la même conséquence : le LOT ENTIER abandonné, l'élève et
/// son inscription avec.
String? _refusRattachement(
  Iterable<TuteurSaisi> neuves,
  String? groupId,
  String? schoolId,
) {
  if (!neuves.any(_complete)) return null;
  final manquants = <String>[
    if (!isUsableId(groupId)) 'groupe',
    if (!isUsableId(schoolId)) 'école',
  ];
  return manquants.isEmpty ? null : writeIdentityMessage(manquants);
}

/// Le refus lié aux fiches de tuteur entamées mais incomplètes, ou `null`.
String? _refusTuteurs(Iterable<TuteurSaisi> neuves) {
  final incomplets = neuves.where((t) => _entamee(t) && !_complete(t)).length;
  if (incomplets == 0) return null;
  return '$incomplets fiche(s) de tuteur incomplète(s) : le prénom, le nom et '
      'le téléphone sont obligatoires — complétez-les ou supprimez la fiche.';
}

/// `null` = rien ne s'oppose à l'enregistrement.
///
/// L'ordre des contrôles suit celui du formulaire : on renvoie l'agent à la
/// PREMIÈRE page fautive, pas à la dernière. Le renvoyer aux tuteurs alors que
/// le nom manque à la page 1 lui ferait chercher au mauvais endroit.
RefusEdition? refusEdition({
  required String prenom,
  required String nom,
  required String? classId,
  required List<TuteurSaisi> tuteurs,
  required String? groupId,
  required String? schoolId,
}) {
  final identite = _refusIdentite(prenom, nom);
  if (identite != null) return (etape: kEtapeEleve, message: identite);

  if (classId == null || classId.trim().isEmpty) {
    return (
      etape: kEtapeScolarite,
      message: 'Sélectionnez la classe (cycle ▸ niveau ▸ classe).',
    );
  }

  final neuves = tuteurs.where((t) => t.id == null);

  final rattachement = _refusRattachement(neuves, groupId, schoolId);
  if (rattachement != null) {
    return (etape: kEtapeAucune, message: rattachement);
  }

  final tut = _refusTuteurs(neuves);
  if (tut != null) return (etape: kEtapeTuteurs, message: tut);

  return null;
}

// ─── La même garde, pour l'écran qui ne touche pas à la scolarité ────────────

/// Pages du formulaire de modification du REGISTRE (page Élèves) : il en a deux,
/// Identité et Tuteurs. La classe n'y est pas modifiable — elle se change par
/// « Changer de classe », qui exige une inscription, pas une identité.
const int kEtapeRegistreEleve = 0;
const int kEtapeRegistreTuteurs = 1;

/// `null` = rien ne s'oppose à l'enregistrement d'une modification au registre.
///
/// ⚠️ CETTE GARDE N'EXISTAIT QUE CÔTÉ GUICHET. L'écran de modification de la
/// page Élèves — celui que le secrétariat ouvre le plus souvent, puisque c'est
/// là que vivent les élèves une fois inscrits — enregistrait sans aucun de ces
/// contrôles, et reproduisait donc DEUX des dégâts décrits en tête de fichier :
///
///  • il passait `groupId ?? ''` à la création d'un tuteur, écrivant une chaîne
///    vide dans une colonne `uuid NOT NULL` : l'écran affichait « Modifications
///    enregistrées », puis PowerSync perdait le lot entier, élève compris ;
///  • il sautait en silence toute fiche de tuteur incomplète.
///
/// Les règles sont exactement les mêmes qu'au guichet — seule change la page où
/// renvoyer l'agent, ce module n'ayant pas d'étape Scolarité.
RefusEdition? refusEditionRegistre({
  required String prenom,
  required String nom,
  required List<TuteurSaisi> tuteurs,
  required String? groupId,
  required String? schoolId,
}) {
  final identite = _refusIdentite(prenom, nom);
  if (identite != null) return (etape: kEtapeRegistreEleve, message: identite);

  final neuves = tuteurs.where((t) => t.id == null);

  final rattachement = _refusRattachement(neuves, groupId, schoolId);
  if (rattachement != null) {
    return (etape: kEtapeAucune, message: rattachement);
  }

  final tut = _refusTuteurs(neuves);
  if (tut != null) return (etape: kEtapeRegistreTuteurs, message: tut);

  return null;
}
