// ════════════════════════════════════════════════════════════════════════════
//  BROUILLON DE TUTEUR — une fiche parent/tuteur en cours de saisie dans
//  l'assistant d'inscription.
//
//  ── POURQUOI CE FICHIER EXISTE ─────────────────────────────────────────────
//  L'étape « Parents » marque Prénom, Nom et Téléphone d'une étoile, et rien ne
//  les vérifiait. À l'enregistrement, toute fiche incomplète était simplement
//  SAUTÉE par une boucle : le secrétariat qui saisissait le numéro de la mère
//  sans son nom de famille validait un dossier sans aucun contact, sans le
//  moindre message. Le seul moyen de joindre la famille disparaissait entre
//  deux écrans.
//
//  La règle vit donc ici, en dehors du widget, pour être vérifiable : c'est une
//  perte de données silencieuse, la sorte qu'aucun essai à l'écran ne révèle.
// ════════════════════════════════════════════════════════════════════════════

class TutorDraft {
  TutorDraft({this.isPrimary = false});

  String firstName = '';
  String lastName = '';
  String relationship = 'mere';
  String phonePrimary = '';
  String? phoneSecondary;
  String? email;
  String? profession;
  String? address;
  bool isPrimary;
  bool isEmergency = false;

  /// Aucun champ saisi : la fiche n'a jamais servi. L'assistant en pose une
  /// d'office à l'ouverture — la laisser vide est un choix légitime, pas un
  /// oubli, et ne doit rien bloquer.
  bool get isBlank =>
      firstName.trim().isEmpty &&
      lastName.trim().isEmpty &&
      phonePrimary.trim().isEmpty &&
      (email ?? '').trim().isEmpty &&
      (profession ?? '').trim().isEmpty &&
      (address ?? '').trim().isEmpty &&
      (phoneSecondary ?? '').trim().isEmpty;

  /// Les trois champs marqués obligatoires à l'écran sont présents.
  bool get isComplete =>
      firstName.trim().isNotEmpty &&
      lastName.trim().isNotEmpty &&
      phonePrimary.trim().isNotEmpty;

  /// Comment désigner cette fiche dans un message d'erreur.
  ///
  /// On parle de « la fiche de X », jamais de « X est incomplet » : un prénom
  /// ne dit pas le genre de la personne, et le message s'adresse de toute
  /// façon à la fiche, pas au tuteur.
  String get displayLabel {
    final f = firstName.trim(), l = lastName.trim();
    final name = [f, l].where((s) => s.isNotEmpty).join(' ');
    return name.isEmpty ? 'Cette fiche de tuteur' : 'La fiche de $name';
  }
}

/// Les liens de parenté proposés à la saisie — source unique des listes
/// déroulantes, alignée sur [tutorRelationshipLabel] juste en dessous.
const Map<String, String> kLiensParente = {
  'pere': 'Père',
  'mere': 'Mère',
  'tuteur': 'Tuteur légal',
  'autre': 'Autre',
};

/// Libellé lisible d'un lien de parenté (`mere` → « Mère »).
///
/// Source unique : la même correspondance existait en trois exemplaires (le
/// tiroir élève, la fiche d'inscription, le récapitulatif) — et le
/// récapitulatif de l'assistant, lui, n'en avait aucun et affichait le code
/// brut « (mere) » au moment précis où l'on relit avant d'enregistrer.
String tutorRelationshipLabel(String code) => switch (code) {
      'pere' => 'Père',
      'mere' => 'Mère',
      'tuteur' => 'Tuteur légal',
      'autre' => 'Autre',
      _ => code.isEmpty ? '—' : code,
    };

/// Message d'erreur bloquant l'étape « Parents », ou `null` si elle est valide.
///
/// Deux refus, et un seul silence :
///  • aucune fiche remplie → refus (un élève doit avoir un contact) ;
///  • une fiche entamée mais incomplète → refus NOMMÉ, jamais un abandon ;
///  • une fiche jamais touchée → ignorée sans bruit.
String? validateTutorDrafts(List<TutorDraft> tutors) {
  final used = [for (final t in tutors) if (!t.isBlank) t];
  if (used.isEmpty) {
    return 'Renseignez au moins un parent ou tuteur : prénom, nom et '
        'téléphone. C\'est par ce numéro que l\'école joindra la famille.';
  }
  for (final t in used) {
    if (t.isComplete) continue;
    return '${t.displayLabel} est incomplète : prénom, nom et téléphone sont '
        'obligatoires. Complétez-la ou videz-la entièrement.';
  }
  return null;
}

/// Les fiches à réellement enregistrer — celles qui ont été remplies.
///
/// À n'appeler qu'après [validateTutorDrafts] : à ce stade, toute fiche non
/// vierge est complète, donc rien ne peut plus se perdre ici.
List<TutorDraft> tutorsToPersist(List<TutorDraft> tutors) =>
    [for (final t in tutors) if (!t.isBlank) t];
