import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/billing_period.dart';
import '../../../core/utils/tarif_ecoles.dart';
import '../../auth/providers/auth_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  L'ÉCONOMIE DE LA PLATEFORME
//
//  Trois nombres qu'aucun écran ne rapprochait : ce qui rentre (abonnements +
//  licences de tutelle), ce qui sort (Supabase, PowerSync…), et l'écart.
//
//  ── ⚠️ UN REVENU ET UN COÛT NE S'ADDITIONNENT QU'AU MOIS ──────────────────
//  Une licence annuelle de 18 M et un abonnement mensuel de 30 000 ne se
//  somment pas bruts. Tout est ramené au mois par `monthlyEquivalent` — la
//  même fonction que la base (`billing_period_months`).
//
//  ── ⚠️ CE N'EST PAS UNE COMPTABILITÉ ──────────────────────────────────────
//  C'est un ordre de grandeur d'exploitation. Il ignore les impayés, les
//  délais d'encaissement (un marché public se règle en mois, parfois en
//  année) et tout ce qui n'a pas été saisi dans `platform_costs`. Le dire
//  vaut mieux que laisser croire à un résultat.
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

class LicenceTutelle {
  const LicenceTutelle({
    required this.id,
    required this.groupId,
    required this.groupeNom,
    required this.tutelle,
    required this.intitule,
    required this.dateDebut,
    required this.dateFin,
    required this.montantXaf,
    required this.avanceXaf,
    required this.montantRegleXaf,
    required this.statut,
    this.referenceMarche,
    this.signataire,
    this.notes,
    this.motifStatut,
    this.statutChangeLe,
    this.accesSuspendu = false,
    this.accesSuspenduMotif,
  });

  factory LicenceTutelle.fromRow(Map<String, dynamic> r) {
    final g = r['school_groups'] as Map<String, dynamic>?;
    return LicenceTutelle(
      id: r['id'] as String,
      groupId: r['group_id'] as String,
      groupeNom: g?['name'] as String? ?? '—',
      tutelle: r['tutelle'] as String? ?? '',
      intitule: r['intitule'] as String? ?? 'Licence de tutelle',
      dateDebut: DateTime.parse(r['date_debut'] as String),
      dateFin: DateTime.parse(r['date_fin'] as String),
      montantXaf: (r['montant_xaf'] as num?)?.toInt() ?? 0,
      avanceXaf: (r['avance_xaf'] as num?)?.toInt() ?? 0,
      montantRegleXaf: (r['montant_regle_xaf'] as num?)?.toInt() ?? 0,
      statut: r['statut'] as String? ?? 'brouillon',
      referenceMarche: r['reference_marche'] as String?,
      signataire: r['signataire'] as String?,
      notes: r['notes'] as String?,
      motifStatut: r['motif_statut'] as String?,
      statutChangeLe:
          DateTime.tryParse(r['statut_change_le'] as String? ?? ''),
      accesSuspendu: g?['acces_suspendu'] as bool? ?? false,
      accesSuspenduMotif: g?['acces_suspendu_motif'] as String?,
    );
  }

  final String id, groupId, groupeNom, tutelle, intitule, statut;
  final String? referenceMarche, signataire, notes;

  /// Pourquoi le statut a changé — obligatoire pour suspendre ou résilier
  /// (migration 0186). Affiché des DEUX côtés : le ministère a le droit de
  /// savoir pourquoi son marché est suspendu.
  final String? motifStatut;

  /// Quand. Le QUI vit dans `audit_logs` (déclencheur posé par 0186 : cette
  /// table était la seule table chère de la base sans historique).
  final DateTime? statutChangeLe;

  /// ⚠️ L'ACCÈS DU GROUPE, pas l'état de la licence. Les deux sont
  /// DÉLIBÉRÉMENT séparés (0187) : une licence suspendue ne coupe rien ;
  /// couper l'accès est un second geste, explicite. Affiché ici parce que
  /// c'est la fiche du marché qu'on regarde quand on décide de l'un ou de
  /// l'autre.
  final bool accesSuspendu;
  final String? accesSuspenduMotif;
  final DateTime dateDebut, dateFin;
  final int montantXaf, avanceXaf, montantRegleXaf;

  bool get estActive => statut == 'active';
  int get soldeXaf => montantXaf - montantRegleXaf;

  /// Nombre de mois couverts — au moins 1, pour ne jamais diviser par zéro.
  int get moisCouverts {
    final m = (dateFin.difference(dateDebut).inDays / 30.44).round();
    return m < 1 ? 1 : m;
  }

  /// La licence ramenée au mois, seule base comparable au reste.
  int get mensuelXaf => (montantXaf / moisCouverts).round();

  /// ⚠️ Compté seulement si la licence est ACTIVE. Un brouillon n'est pas un
  /// revenu, et une licence résiliée encore moins.
  int get mensuelCompte => estActive ? mensuelXaf : 0;

  int get joursRestants => dateFin.difference(DateTime.now()).inDays;

  /// Durée totale du marché, en jours (au moins 1 : ne jamais diviser par 0).
  int get dureeJours {
    final d = dateFin.difference(dateDebut).inDays;
    return d < 1 ? 1 : d;
  }

  /// Part de la période écoulée, 0..1.
  ///
  /// ⚠️ À ne PAS confondre avec la part RÉGLÉE. Un marché peut être couvert à
  /// 80 % du temps et réglé à 25 % : c'est cet écart qui déclenche une
  /// relance, et aucune des deux mesures seule ne le montre.
  double get partEcoulee =>
      (DateTime.now().difference(dateDebut).inDays / dureeJours)
          .clamp(0.0, 1.0);

  /// Part réglée, 0..1. `null` si le marché ne porte aucun montant.
  double? get partReglee =>
      montantXaf <= 0 ? null : (montantRegleXaf / montantXaf).clamp(0.0, 1.0);
}

class EconomieData {
  const EconomieData({
    required this.couts,
    required this.licences,
    required this.mrrAbonnementsXaf,
  });

  static const empty = EconomieData(
      couts: [], licences: [], mrrAbonnementsXaf: 0);

  final List<CoutPlateforme> couts;
  final List<LicenceTutelle> licences;

  /// Revenu mensuel des abonnements des groupes ACTIFS, calculé groupe par
  /// groupe (le prix suit le nombre d'écoles depuis la migration 0159).
  final int mrrAbonnementsXaf;

  int get mrrLicencesXaf =>
      licences.fold(0, (s, l) => s + l.mensuelCompte);

  int get mrrTotalXaf => mrrAbonnementsXaf + mrrLicencesXaf;

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

  int get soldeDuXaf =>
      licences.where((l) => l.estActive).fold(0, (s, l) => s + l.soldeXaf);
}

final economieProvider =
    FutureProvider.autoDispose<EconomieData>((ref) async {
  final client = ref.read(supabaseClientProvider);

  // ⚠️ Aucun `catch (_) {}` muet ici. Un tableau d'économie qui affiche 0
  // parce qu'une requête a échoué est pire que pas de tableau du tout.
  final coutsRows = await client
      .from('platform_costs')
      .select('id, label, fournisseur, categorie, montant_xaf, periodicite, '
          'montant_origine, devise_origine, is_active, notes')
      .order('montant_xaf', ascending: false) as List;

  final licencesRows = await client
      .from('tutelle_licences')
      .select('id, group_id, tutelle, intitule, date_debut, date_fin, '
          'montant_xaf, avance_xaf, montant_regle_xaf, statut, '
          'reference_marche, signataire, notes, motif_statut, '
          'statut_change_le, school_groups!group_id(name, acces_suspendu, '
          'acces_suspendu_motif)')
      .order('date_fin', ascending: false) as List;

  final groupes = await client
      .from('school_groups')
      .select('plan_id, subscription_status, billed_schools, price_override_xaf, '
          'subscription_plans!plan_id(price_xaf, billing_period, '
          'extra_school_2_5_xaf, extra_school_6_10_xaf, '
          'extra_school_11_20_xaf, extra_school_21p_xaf)') as List;

  var mrr = 0;
  for (final g in groupes) {
    final m = Map<String, dynamic>.from(g as Map);
    if (m['subscription_status'] != 'active') continue;
    final plan = m['subscription_plans'] as Map<String, dynamic>?;
    final du = (m['price_override_xaf'] as num?)?.toInt() ??
        tarifPlanRow(plan, (m['billed_schools'] as num?)?.toInt() ?? 1);
    mrr += monthlyEquivalent(du, plan?['billing_period'] as String?);
  }

  return EconomieData(
    couts: coutsRows
        .map((r) => CoutPlateforme.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList(),
    licences: licencesRows
        .map((r) => LicenceTutelle.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList(),
    mrrAbonnementsXaf: mrr,
  );
});

/// Les groupes qui PEUVENT recevoir une licence de tutelle — ceux qui
/// supervisent un réseau. Vendre une licence à un autre reviendrait à
/// facturer un accès qu'il n'a pas (le déclencheur en base le refuse).
final groupesSuperviseursProvider =
    FutureProvider.autoDispose<List<({String id, String nom, String tutelle})>>(
        (ref) async {
  final client = ref.read(supabaseClientProvider);
  final rows = await client
      .from('school_groups')
      .select('id, name, tutelle')
      .eq('administre_referentiel_national', true)
      .order('name') as List;
  return [
    for (final r in rows)
      (
        id: (r as Map)['id'] as String,
        nom: r['name'] as String? ?? '—',
        tutelle: r['tutelle'] as String? ?? '',
      ),
  ];
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

Future<void> enregistrerLicence(WidgetRef ref,
    {String? id, required Map<String, dynamic> champs}) async {
  final client = ref.read(supabaseClientProvider);
  if (id == null) {
    await client.from('tutelle_licences').insert(champs);
  } else {
    await client.from('tutelle_licences').update({
      ...champs,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }
}

/// Change le statut d'une licence — activer, suspendre, reprendre, résilier.
///
/// ⚠️ PASSE PAR LA RPC, jamais par un `update` direct sur la colonne. La
/// fonction `licence_changer_statut` (0186) porte quatre règles qu'un update
/// ne porterait pas : le motif obligatoire pour arrêter quelque chose, le
/// refus de ressusciter un marché résilié, le refus d'activer un marché dont
/// le terme est passé, et le refus de deux licences actives qui se chevauchent
/// (elles compteraient DEUX FOIS dans le revenu).
///
/// ⚠️ ET ELLE NE COUPE RIEN. Suspendre un marché ne ferme ni le ministère ni
/// son réseau : c'est un état contractuel. L'accès dépend de
/// `administre_referentiel_national` (0155), et rien d'autre.
Future<void> changerStatutLicence(
  WidgetRef ref, {
  required String licenceId,
  required String statut,
  String? motif,
}) async {
  await ref.read(supabaseClientProvider).rpc('licence_changer_statut', params: {
    'p_licence_id': licenceId,
    'p_statut': statut,
    'p_motif': motif,
  });
  ref.invalidate(economieProvider);
}

/// Coupe l'accès de l'espace d'un groupe — le levier contre l'impayé (0187).
///
/// ⚠️ RIEN À VOIR AVEC LE STATUT DE LA LICENCE, et c'est voulu. Une licence
/// suspendue reste sans effet sur l'accès ; couper est une décision distincte,
/// qui exige son propre motif et laisse sa propre trace. Les lier ferait de
/// chaque suspension comptable une coupure d'État.
///
/// La coupure agit côté SERVEUR : `auth_peut_superviser()` rend faux, et les
/// quatre RPC de tutelle (réseau, écoles, destinataires, circulaires) refusent
/// en 42501 — exactement le périmètre du marché qui n'est pas payé. Elle ne
/// touche ni les écoles du réseau, ni la synchro hors ligne de leur personnel.
Future<void> couperAccesGroupe(WidgetRef ref,
    {required String groupId, required String motif}) async {
  await ref.read(supabaseClientProvider).rpc('suspendre_acces_groupe',
      params: {'p_group_id': groupId, 'p_motif': motif});
  ref.invalidate(economieProvider);
}

/// Rouvre l'accès. Aucun motif exigé : on ne met jamais de friction sur le
/// geste qui rétablit.
Future<void> retablirAccesGroupe(WidgetRef ref,
    {required String groupId}) async {
  await ref
      .read(supabaseClientProvider)
      .rpc('retablir_acces_groupe', params: {'p_group_id': groupId});
  ref.invalidate(economieProvider);
}

Future<void> supprimerLicence(WidgetRef ref, String id) async {
  await ref.read(supabaseClientProvider).from('tutelle_licences').delete().eq('id', id);
}
