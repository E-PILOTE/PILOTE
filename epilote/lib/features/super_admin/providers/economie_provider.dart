import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/paged_fetch.dart';
import '../../../core/utils/billing_period.dart';
import '../../../core/utils/tarif_ecoles.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/utils/garder_au_chaud.dart';

// ════════════════════════════════════════════════════════════════════════════
//  L'ÉCONOMIE DE LA PLATEFORME
//
//  Trois nombres qu'aucun écran ne rapprochait : ce qui rentre (abonnements
//  des groupes privés), ce qui sort (Supabase, PowerSync…), et l'écart.
//
//  ── ⚠️ UN REVENU ET UN COÛT NE S'ADDITIONNENT QU'AU MOIS ──────────────────
//  Un abonnement annuel et un abonnement mensuel ne se somment pas bruts.
//  Tout est ramené au mois par `monthlyEquivalent` — la même fonction que la
//  base (`billing_period_months`).
//
//  ── ⚠️ CE N'EST PAS UNE COMPTABILITÉ ──────────────────────────────────────
//  C'est un ordre de grandeur d'exploitation. Il ignore les impayés, les
//  délais d'encaissement et tout ce qui n'a pas été saisi dans
//  `platform_costs`. Le dire vaut mieux que laisser croire à un résultat.
//
//  ⚠️ Données de FONDATEUR : `platform_costs` est fermée au super_admin par
//  RLS. Aucun groupe scolaire ne doit jamais voir ce que coûte l'infra.
// ════════════════════════════════════════════════════════════════════════════

class CoutPlateforme {
  const CoutPlateforme({
    required this.id,
    required this.label,
    required this.categorie,
    required this.montantXaf,
    required this.periodicite,
    required this.isActive,
    this.fournisseur,
    this.montantOrigine,
    this.deviseOrigine,
    this.notes,
  });

  factory CoutPlateforme.fromRow(Map<String, dynamic> r) => CoutPlateforme(
        id: r['id'] as String,
        label: r['label'] as String? ?? '—',
        fournisseur: r['fournisseur'] as String?,
        categorie: r['categorie'] as String? ?? 'autre',
        montantXaf: (r['montant_xaf'] as num?)?.toInt() ?? 0,
        periodicite: r['periodicite'] as String? ?? 'mensuel',
        montantOrigine: (r['montant_origine'] as num?)?.toDouble(),
        deviseOrigine: r['devise_origine'] as String?,
        isActive: r['is_active'] as bool? ?? true,
        notes: r['notes'] as String?,
      );

  final String id, label, categorie, periodicite;
  final String? fournisseur, deviseOrigine, notes;
  final int montantXaf;
  final double? montantOrigine;
  final bool isActive;

  int get mensuelXaf => monthlyEquivalent(montantXaf, periodicite);
}

/// Un groupe qui paie — la ligne derrière le revenu d'abonnement.
///
/// ⚠️ Elle existe pour une seule raison : `mrrAbonnementsXaf` était un
/// total SANS lignes. La fiche du KPI expliquait le calcul en trois
/// paragraphes et ne montrait pas un seul groupe — or c'est exactement ce
/// qu'on veut voir quand un chiffre surprend. Un total qu'on ne peut pas
/// décomposer est un total qu'on finit par ne plus croire.
class AbonnementCompte {
  const AbonnementCompte({
    required this.nom,
    required this.mensuelXaf,
    required this.ecoles,
    required this.periode,
    required this.negocie,
  });

  final String nom;

  /// Le tarif RAMENÉ AU MOIS — un plan annuel de 2 500 000 F pèse 208 333 F.
  final int mensuelXaf;

  final int ecoles;
  final String? periode;

  /// Tarif négocié (`price_override_xaf`) plutôt que la grille du plan.
  final bool negocie;
}

class EconomieData {
  const EconomieData({
    required this.couts,
    required this.mrrAbonnementsXaf,
    this.abonnements = const [],
    this.groupesInactifs = 0,
  });

  static const empty = EconomieData(couts: [], mrrAbonnementsXaf: 0);

  final List<CoutPlateforme> couts;

  /// Les groupes actifs, du plus gros contributeur au plus petit.
  final List<AbonnementCompte> abonnements;

  /// Combien de groupes ne comptent PAS. Un chiffre à dire : sans lui, la
  /// liste semble incomplète plutôt que filtrée.
  final int groupesInactifs;

  /// Revenu mensuel des abonnements des groupes ACTIFS, calculé groupe par
  /// groupe (le prix suit le nombre d'écoles depuis la migration 0159).
  final int mrrAbonnementsXaf;

  /// Tout le revenu récurrent vient des abonnements des groupes privés.
  int get mrrTotalXaf => mrrAbonnementsXaf;

  int get coutMensuelXaf =>
      couts.where((c) => c.isActive).fold(0, (s, c) => s + c.mensuelXaf);

  int get margeMensuelleXaf => mrrTotalXaf - coutMensuelXaf;

  /// ⚠️ `null` si aucun revenu : une marge de « -100 % » sur zéro recette est
  /// un chiffre qui n'apprend rien et alarme pour rien.
  double? get tauxMarge =>
      mrrTotalXaf == 0 ? null : margeMensuelleXaf * 100 / mrrTotalXaf;

  /// Combien de groupes mono-école couvrent l'infrastructure. Le nombre le
  /// plus parlant du tableau : c'est le seuil de survie, pas une projection.
  int seuilEnGroupes(int prixGroupeMonoEcole) => prixGroupeMonoEcole <= 0
      ? 0
      : (coutMensuelXaf / prixGroupeMonoEcole).ceil();
}

final economieProvider =
    FutureProvider.autoDispose<EconomieData>((ref) async {
  garderAuChaud(ref);
  final client = ref.read(supabaseClientProvider);

  // ⚠️ Aucun `catch (_) {}` muet ici. Un tableau d'économie qui affiche 0
  // parce qu'une requête a échoué est pire que pas de tableau du tout.
  // ⚠️ Paginées (2026-09-09) : le MRR se reconstitue à partir de CES lignes.
  // Un plafond à 1 000 groupes ferait disparaître du chiffre d'affaires sans
  // erreur — et l'écart ne se verrait qu'en comparant deux écrans.
  final coutsRows = await fetchAllRows(() => client
      .from('platform_costs')
      .select('id, label, fournisseur, categorie, montant_xaf, periodicite, '
          'montant_origine, devise_origine, is_active, notes')
      .order('montant_xaf', ascending: false)
      .order('id'));

  final groupes = await fetchAllRows(() => client
      .from('school_groups')
      .select('name, plan_id, subscription_status, billed_schools, '
          'price_override_xaf, '
          'subscription_plans!plan_id(price_xaf, billing_period, '
          'extra_school_2_5_xaf, extra_school_6_10_xaf, '
          'extra_school_11_20_xaf, extra_school_21p_xaf)')
      .order('id'));

  var mrr = 0;
  var inactifs = 0;
  final lignes = <AbonnementCompte>[];
  for (final g in groupes) {
    final m = Map<String, dynamic>.from(g as Map);
    if (m['subscription_status'] != 'active') {
      inactifs++;
      continue;
    }
    final plan = m['subscription_plans'] as Map<String, dynamic>?;
    final ecoles = (m['billed_schools'] as num?)?.toInt() ?? 1;
    final negocie = (m['price_override_xaf'] as num?)?.toInt();
    final du = negocie ?? tarifPlanRow(plan, ecoles);
    final mensuel = monthlyEquivalent(du, plan?['billing_period'] as String?);
    mrr += mensuel;
    lignes.add(AbonnementCompte(
      nom: m['name'] as String? ?? '—',
      mensuelXaf: mensuel,
      ecoles: ecoles,
      periode: plan?['billing_period'] as String?,
      negocie: negocie != null,
    ));
  }
  lignes.sort((a, b) => b.mensuelXaf.compareTo(a.mensuelXaf));

  return EconomieData(
    couts: coutsRows
        .map((r) => CoutPlateforme.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList(),
    mrrAbonnementsXaf: mrr,
    abonnements: lignes,
    groupesInactifs: inactifs,
  );
});

// ─── Écritures ──────────────────────────────────────────────────────────────

Future<void> enregistrerCout(WidgetRef ref,
    {String? id, required Map<String, dynamic> champs}) async {
  final client = ref.read(supabaseClientProvider);
  if (id == null) {
    await client.from('platform_costs').insert(champs);
  } else {
    await client.from('platform_costs').update({
      ...champs,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }
}

Future<void> supprimerCout(WidgetRef ref, String id) async {
  await ref.read(supabaseClientProvider).from('platform_costs').delete().eq('id', id);
}

