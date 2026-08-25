import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/academic_year_model.dart';
import '../../auth/providers/active_agent_provider.dart';
import 'academic_year_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CONTEXTE « ANNÉE ACTIVE » — la lentille globale de tout l'espace école.
//
//  L'année scolaire est l'axe central : 23 tables métier (classes, inscriptions,
//  évaluations, bulletins, paiements, présences, stages…) portent une colonne
//  `academic_year_id`. Toutes les données affichées au personnel doivent être
//  filtrées par l'année ACTIVE. Par défaut, l'année active = l'année courante ;
//  l'utilisateur peut basculer sur une année passée (archivée → lecture seule)
//  via le sélecteur du header.
// ════════════════════════════════════════════════════════════════════════════

/// Année explicitement choisie via le sélecteur du header.
/// `null` = suivre automatiquement l'année courante de l'établissement.
///
/// NON autoDispose : la sélection persiste à travers la navigation — c'est une
/// lentille d'application, pas un état d'écran.
///
/// Mais elle est RATTACHÉE À L'AGENT AU CLAVIER (`build()` observe
/// [activeAgentIdProvider], comme `ThemeIdNotifier`). Sur un poste partagé, le
/// proviseur qui consulte 2024-2025 puis rend la main laissait sa lentille au
/// suivant : le comptable arrivait sur une caisse en lecture seule sans avoir
/// rien fait, et appelait le support. La bascule d'agent — comme la
/// déconnexion, qui vide l'identité de l'appareil — ramène chacun sur l'année
/// en cours.
class SelectedYearIdNotifier extends Notifier<String?> {
  @override
  String? build() {
    ref.watch(activeAgentIdProvider); // change d'agent ⇒ lentille réinitialisée
    return null;
  }

  /// Bascule la lentille. `null` = revenir au suivi automatique de l'année
  /// courante.
  void select(String? yearId) => state = yearId;
}

final selectedYearIdProvider =
    NotifierProvider<SelectedYearIdNotifier, String?>(
        SelectedYearIdNotifier.new);

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
