import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../structure/providers/academic_year_context.dart';
import 'leave_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE SOLDE DE CONGÉS — ce que l'instructeur ne voyait pas
//
//  ── LE DÉFAUT ─────────────────────────────────────────────────────────────
//  Le module enregistrait des demandes sans rien savoir de ce qui avait déjà
//  été accordé. Un agent pouvait déposer soixante jours ; le directeur
//  approuvait sans savoir qu'il en avait déjà pris quarante. Pas d'erreur, pas
//  de message : une décision prise à l'aveugle, et qui a l'air d'une décision.
//
//  ── ⚠️ CE QUI EST ICI, ET CE QUI N'Y EST PAS — LIRE AVANT DE COMPLÉTER ────
//
//  CE QUI EST CALCULÉ : le CONSOMMÉ et l'ENGAGÉ. Combien de jours de congé
//  annuel cet agent a déjà obtenus sur l'année scolaire en cours, et combien
//  il en a en instruction. C'est entièrement dérivé de `leave_requests` :
//  aucune colonne nouvelle, aucune écriture, aucun changement de synchro.
//
//  CE QUI N'Y EST PAS : le DROIT ANNUEL, donc le reliquat au sens strict.
//  Et c'est délibéré.
//
//  Le nombre de jours auxquels un agent a droit n'est pas une décision de
//  développeur : il vient du Code du travail pour le privé et du statut de la
//  fonction publique pour le public — deux textes, deux chiffres, et la
//  plateforme sert les DEUX (`schools.school_type`). L'ancienneté le module.
//
//  Inscrire ici un nombre « raisonnable » produirait exactement le défaut que
//  ce dépôt a déjà payé une fois : le barème de mentions avait glissé de deux
//  points, personne ne l'a vu, et 8/20 ressortait « Passable ». Un droit de
//  congé faux ne se verrait pas davantage — et il ferait refuser des congés.
//
//  ⚠️ CHIFFRE À FAIRE ÉTABLIR par le MEPSA et le METP, comme la nomenclature
//  de `core/utils/sortie_motif.dart`. Le jour où il l'est, il se pose sur
//  l'agent (c'est un terme d'emploi, au même titre que `contract_type`), et
//  [ConsommationConges.restant] devient calculable sans rien changer d'autre.
//
//  Entre-temps, l'instruction n'est plus aveugle : le décideur voit ce qui a
//  déjà été accordé, ce qui est en cours, et il décide en connaissance.
//
//  ── QUELS CONGÉS SE DÉCOMPTENT ────────────────────────────────────────────
//  Seul le congé ANNUEL. Un congé maladie, maternité, une formation ou une
//  mission ne se prennent pas sur le droit annuel — c'est toute la raison
//  d'avoir des types —, et « sans solde » le dit dans son nom. Les mélanger
//  ferait apparaître comme gros consommateur l'agent qui a été malade.
// ════════════════════════════════════════════════════════════════════════════

/// Les types de congé qui S'IMPUTENT sur le droit annuel.
const Set<String> kCongesDecomptes = {'annuel'};

/// Ce qu'un agent a déjà obtenu et engagé sur l'année scolaire en cours.
class ConsommationConges {
  const ConsommationConges({
    required this.staffId,
    required this.approuves,
    required this.enAttente,
    required this.horsDecompte,
    required this.droitAnnuel,
  });

  final String staffId;

  /// Jours de congé annuel APPROUVÉS sur l'année scolaire.
  final int approuves;

  /// Jours de congé annuel DEMANDÉS et non encore instruits.
  final int enAttente;

  /// Jours obtenus sur les autres motifs (maladie, maternité, formation,
  /// mission, sans solde). Comptés à part : ils informent sans s'imputer.
  final int horsDecompte;

  /// Droit annuel de l'agent, **`null` tant qu'aucun texte ne l'a fixé**.
  /// Voir l'en-tête de ce fichier : ce n'est pas un oubli.
  final int? droitAnnuel;

  /// Total qui pèse sur le droit si tout ce qui est en instance est accordé.
  int get engage => approuves + enAttente;

  /// Reliquat — `null` tant que le droit n'est pas établi. Jamais 0.
  int? get restant =>
      droitAnnuel == null ? null : droitAnnuel! - approuves;

  /// Reliquat si l'on accorde tout ce qui est en instance.
  int? get restantSiToutAccorde =>
      droitAnnuel == null ? null : droitAnnuel! - engage;

  /// Le droit est-il connu ? Une réponse franche vaut mieux qu'un zéro.
  bool get droitConnu => droitAnnuel != null;

  /// Dépassement AVÉRÉ (déjà accordé au-delà du droit).
  bool get depasse => restant != null && restant! < 0;

  /// Dépassement à venir si l'instruction en cours est accordée.
  bool get depasseraitSiAccorde =>
      restantSiToutAccorde != null && restantSiToutAccorde! < 0;
}

/// La consommation de chaque agent, sur l'ANNÉE SCOLAIRE ACTIVE.
///
/// ⚠️ Fenêtre = l'année scolaire, pas l'année civile. C'est la seule que la
/// base porte hors ligne, et c'est celle sur laquelle l'établissement raisonne.
/// Le document qui l'affichera devra le DIRE : un agent qui compare avec son
/// décompte administratif sur l'année civile trouverait sinon deux chiffres
/// contradictoires sans savoir lequel croire.
///
/// Dérivé de [leaveRequestsProvider] : pas une requête de plus.
final consommationCongesProvider =
    Provider.autoDispose<Map<String, ConsommationConges>>((ref) {
  final demandes = ref.watch(leaveRequestsProvider).valueOrNull;
  if (demandes == null) return const {};

  final annee = ref.watch(activeYearProvider);
  final debut = annee?.startDate.toIso8601String().substring(0, 10);
  final fin = annee?.endDate.toIso8601String().substring(0, 10);

  bool dansLAnnee(String? jour) {
    // Sans année active, on ne filtre pas : mieux vaut un total sur tout
    // l'historique — visiblement large — qu'un zéro qui passerait pour
    // « n'a rien pris ».
    if (debut == null || fin == null) return true;
    if (jour == null || jour.isEmpty) return false;
    return jour.compareTo(debut) >= 0 && jour.compareTo(fin) <= 0;
  }

  final approuves = <String, int>{};
  final attente = <String, int>{};
  final autres = <String, int>{};

  for (final d in demandes) {
    if (!dansLAnnee(d.startDate)) continue;
    final decompte = kCongesDecomptes.contains(d.leaveType);
    switch (d.status) {
      case 'approved':
        if (decompte) {
          approuves[d.staffId] = (approuves[d.staffId] ?? 0) + d.daysCount;
        } else {
          autres[d.staffId] = (autres[d.staffId] ?? 0) + d.daysCount;
        }
      case 'pending':
        if (decompte) {
          attente[d.staffId] = (attente[d.staffId] ?? 0) + d.daysCount;
        }
      // `rejected` et `cancelled` ne consomment rien : une demande refusée
      // n'a pas été prise.
    }
  }

  final agents = {
    ...approuves.keys,
    ...attente.keys,
    ...autres.keys,
  };

  return {
    for (final id in agents)
      id: ConsommationConges(
        staffId: id,
        approuves: approuves[id] ?? 0,
        enAttente: attente[id] ?? 0,
        horsDecompte: autres[id] ?? 0,
        // Voir l'en-tête : tant que le droit n'est pas établi par les
        // ministères, il reste inconnu — et l'écran le dit.
        droitAnnuel: null,
      ),
  };
});
