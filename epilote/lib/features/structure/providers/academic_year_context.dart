import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/academic_year_model.dart';
import 'academic_year_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CONTEXTE « ANNÉE ACTIVE » — la lentille globale de tout l'espace école.
//
//  L'année scolaire est l'axe central : 18 tables métier (classes, inscriptions,
//  évaluations, bulletins, paiements, présences…) sont rattachées à
//  `academic_year_id`. Toutes les données affichées au personnel doivent être
//  filtrées par l'année ACTIVE. Par défaut, l'année active = l'année courante ;
//  l'utilisateur peut basculer sur une année passée (archivée → lecture seule)
//  via le sélecteur du header.
// ════════════════════════════════════════════════════════════════════════════

/// Année explicitement choisie par l'utilisateur via le sélecteur du header.
/// `null` = suivre automatiquement l'année courante de l'établissement.
///
/// Volontairement NON autoDispose : la sélection persiste à travers la
/// navigation entre écrans.
final selectedYearIdProvider = StateProvider<String?>((ref) => null);

/// Année ACTIVE = année sélectionnée si elle existe encore, sinon l'année
/// courante. C'est la source de vérité pour scoper toutes les requêtes.
final activeYearProvider = Provider<AcademicYearModel?>((ref) {
  final selectedId = ref.watch(selectedYearIdProvider);
  final years = ref.watch(academicYearsProvider).valueOrNull ?? const [];
  final current = ref.watch(currentAcademicYearProvider).valueOrNull;

  if (selectedId != null) {
    for (final y in years) {
      if (y.id == selectedId) return y;
    }
    // L'année sélectionnée n'est plus visible : on retombe sur l'année courante.
  }
  return current;
});

/// Id de l'année active — à injecter dans les requêtes `WHERE academic_year_id = ?`.
/// `null` tant qu'aucune année n'est résolue (aucune donnée ne doit alors fuiter).
final activeYearIdProvider = Provider<String?>((ref) =>
    ref.watch(activeYearProvider)?.id);

/// L'année active est-elle en lecture seule ?
/// Vrai si elle est verrouillée (archivée) OU si ce n'est pas l'année courante.
/// Les écritures (création de classe, inscription, saisie de notes…) doivent
/// être désactivées dans ce cas.
final yearReadOnlyProvider = Provider<bool>((ref) {
  final y = ref.watch(activeYearProvider);
  if (y == null) return true;
  return y.isLocked || !y.isCurrent;
});

/// Statut lisible de l'année active (pour badges/bannières).
enum YearStatus { current, upcoming, archived, locked, none }

YearStatus yearStatusOf(AcademicYearModel? y) {
  if (y == null) return YearStatus.none;
  if (y.isLocked) return YearStatus.locked;
  if (y.isCurrent) return YearStatus.current;
  return y.startDate.isAfter(DateTime.now())
      ? YearStatus.upcoming
      : YearStatus.archived;
}

final activeYearStatusProvider = Provider<YearStatus>(
    (ref) => yearStatusOf(ref.watch(activeYearProvider)));
