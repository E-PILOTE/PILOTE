import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:realtime_client/realtime_client.dart';
import '../../../core/utils/billing_period.dart';
import '../../../core/utils/plan_referential_realtime.dart';
import '../../../core/utils/subscription_days.dart';
import '../../../core/utils/tarif_ecoles.dart' show tarifPlanRow;
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/providers/identite_etablissement.dart';
import 'economie_provider.dart' show LicenceTutelle;
import 'plans_provider.dart' show moneyXaf;

// ─── Modèle SubscriptionDetail (un groupe scolaire = un abonnement) ───────────

class SubscriptionDetail {
  const SubscriptionDetail({
    required this.id,
    required this.groupName,
    required this.adminEmail,
    required this.groupType,
    required this.status,
    required this.priceXaf,
    required this.schoolsCount,
    this.ecolesFacturees = 1,
    this.tarifNegocie = false,
    this.billingPeriod = kDefaultBillingPeriod,
    required this.createdAt,
    required this.updatedAt,
    this.groupLogo,
    this.phone,
    this.department,
    this.planId,
    this.planName,
    this.planSlug,
    this.start,
    this.end,
    this.estMinistere = false,
    this.tutelle,
    this.accesSuspendu = false,
    this.licence,
  });

  factory SubscriptionDetail.fromMap(
    Map<String, dynamic> m, {
    int schoolsCount = 0,
    LicenceTutelle? licence,
  }) {
    final plan = m['plan'];
    final planMap = plan is Map ? Map<String, dynamic>.from(plan) : const {};

    // Le MEME calcul que la page Economie, et pour la meme raison : un tarif
    // n'a de sens qu'avec son assiette. `billed_schools` fait foi (c'est lui
    // qui sert aux factures) ; a defaut, les ecoles actives comptees ici.
    final assiette = (m['billed_schools'] as num?)?.toInt() ??
        (schoolsCount > 0 ? schoolsCount : 1);
    final negocie = (m['price_override_xaf'] as num?)?.toInt();
    return SubscriptionDetail(
      id:          m['id']            as String,
      groupName:   m['name']          as String? ?? '',
      groupLogo:   m['logo_url']      as String?,
      adminEmail:  m['admin_email']   as String? ?? '',
      phone:       m['phone']         as String?,
      groupType:   m['group_type']    as String? ?? 'prive',
      department:  m['department']    as String?,
      planId:      m['plan_id']       as String?,
      planName:    planMap['name']    as String?,
      planSlug:    planMap['slug']    as String?,
      priceXaf:      negocie ?? tarifPlanRow(planMap, assiette),
      ecolesFacturees: assiette,
      tarifNegocie:  negocie != null,
      billingPeriod:
          planMap['billing_period'] as String? ?? kDefaultBillingPeriod,
      status:      m['subscription_status'] as String? ?? 'trial',
      start:       _date(m['subscription_start']),
      end:         _date(m['subscription_end']),
      schoolsCount: schoolsCount,
      createdAt:   DateTime.parse(m['created_at'] as String),
      updatedAt:   DateTime.parse(m['updated_at'] as String),
      estMinistere:
          m['administre_referentiel_national'] as bool? ?? false,
      tutelle:       m['tutelle'] as String?,
      accesSuspendu: m['acces_suspendu'] as bool? ?? false,
      licence:       licence,
    );
  }

  final String  id, groupName, adminEmail, groupType, status;
  final String? groupLogo, phone, department, planId, planName, planSlug;
  /// Ce que le groupe paie REELLEMENT par periode : bareme du plan applique
  /// a son assiette d'ecoles, ou le tarif negocie s'il y en a un.
  ///
  /// ⚠️ C'etait le tarif de BASE du plan, et rien d'autre. Sur la page
  /// Abonnements le revenu mensuel annoncait donc 120 000 F quand la page
  /// Economie, elle, en calculait 184 000 : les ecoles supplementaires et
  /// les tarifs negocies etaient perdus. Deux ecrans du meme logiciel se
  /// contredisaient de 35 % sur le chiffre d'affaires du fondateur — et
  /// c'est la page intitulee « Abonnements » qui sous-estimait.
  final int     priceXaf, schoolsCount;

  /// Assiette de facturation : le nombre d'ecoles sur lequel `priceXaf` a
  /// ete calcule. `billed_schools` fait foi — c'est lui qui sert aux
  /// factures ; le nombre d'ecoles actives peut avoir bouge depuis.
  final int     ecolesFacturees;

  /// Vrai si le montant vient d'un tarif negocie (`price_override_xaf`)
  /// et non du bareme. Un chiffre negocie ne se recalcule jamais.
  final bool    tarifNegocie;
  final String  billingPeriod;
  final DateTime  createdAt, updatedAt;
  final DateTime? start, end;

  /// Ce groupe est un ministère de tutelle (0155). Il ne porte PAS un
  /// abonnement mensuel mais une licence (0182).
  final bool estMinistere;
  final String? tutelle;

  /// Accès coupé pour impayé (0187) — distinct du statut de la licence.
  final bool accesSuspendu;

  /// ⚠️ LA LICENCE, LUE ICI ET PLUS SEULEMENT DANS « ÉCONOMIE ».
  ///
  /// C'est le défaut que le fondateur a rencontré : il a activé une licence,
  /// puis il est allé la voir sur la page où il gère les abonnements — et elle
  /// n'y était pas. Le contrat vivait dans un autre écran, qu'il faut savoir
  /// chercher. Un ministère affichait « Licence de tutelle · Gratuit », ce qui
  /// est exactement l'inverse de la vérité : 40 millions.
  final LicenceTutelle? licence;

  /// Ce que la ligne doit afficher à la place du tarif.
  String get montantLabel {
    if (!estMinistere) return priceLabel;
    final l = licence;
    if (l == null) return 'Aucune licence';
    return '${moneyXaf(l.montantXaf)} FCFA';
  }

  /// Tarif avec sa période — « 120 000 FCFA / an ». Un montant nu laissait
  /// chaque écran inventer son suffixe : l'espace admin_groupe affichait
  /// « / an » et l'espace plateforme « / mois », sur le MÊME abonnement.
  String get priceLabel => priceXaf == 0
      ? 'Gratuit'
      : '${moneyXaf(priceXaf)} FCFA / ${billingPeriodSuffix(billingPeriod)}';

  /// Contribution mensuelle de cet abonnement au revenu récurrent.
  int get monthlyPrice => monthlyEquivalent(priceXaf, billingPeriod);

  /// Suffixe de période — « an », « mois ».
  String get periodSuffix => billingPeriodSuffix(billingPeriod);

  bool get isActive => status == 'active';
  bool get isTrial  => status == 'trial';

  String get statusLabel => switch (status) {
    'trial'     => 'Essai',
    'active'    => 'Actif',
    'suspended' => 'Suspendu',
    'expired'   => 'Expiré',
    'cancelled' => 'Annulé',
    _           => status,
  };

  String get groupTypeLabel => groupType == 'public' ? 'Public' : 'Privé';

  /// Jours restants avant la fin de l'abonnement (null si pas de date de fin).
  ///
  /// Passe par `daysUntilDate` : `subscription_end` est un DATE (minuit) et
  /// `DateTime.now()` porte l'heure, si bien que la soustraction brute
  /// TRONQUAIT un jour dès que la journée avançait. Cet écran affichait donc
  /// « 21 j » là où le bandeau du groupe annonçait « 22 jours », le même jour.
  int? get daysRemaining => daysUntilDate(end);

  /// Abonnement payant qui expire dans 30 jours ou moins (et pas déjà expiré).
  bool get isExpiringSoon {
    final d = daysRemaining;
    return d != null && d >= 0 && d <= 30 && isActive;
  }

  bool get isOverdue {
    final d = daysRemaining;
    return d != null && d < 0 && status != 'cancelled';
  }

  String get remainingLabel {
    final d = daysRemaining;
    if (d == null) return '—';
    if (d < 0) return 'Expiré depuis ${-d} j';
    if (d == 0) return "Expire aujourd'hui";
    if (d < 30) return '$d jours restants';
    if (d < 365) return '${(d / 30).round()} mois restants';
    return '${(d / 365).round()} an(s) restant(s)';
  }

  String get initials => initialesEtablissement(groupName);
}

DateTime? _date(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v as String);
}

// ─── Modèle PlanOption (sélecteur de plan dans le formulaire) ─────────────────

/// ⚠️ `LicenceResume` a été SUPPRIMÉE. Elle ne portait que quatre champs —
/// assez pour AFFICHER la ligne, pas assez pour l'OUVRIR. Le bouton « Gérer la
/// licence » rouvrait donc un formulaire de CRÉATION sur un ministère qui avait
/// déjà son marché : on aurait saisi une seconde licence, et la garde
/// anti-chevauchement (0186) l'aurait refusée au dernier moment. Un résumé qui
/// ne permet pas d'agir n'est pas un résumé, c'est une impasse.
///
/// La page charge désormais le contrat complet — `LicenceTutelle`, le même
/// objet qu'en Économie. Une seule définition pour les deux écrans : deux
/// modèles du même marché finissent par en montrer deux versions.

class PlanOption {
  const PlanOption({
    required this.id,
    required this.name,
    required this.priceXaf,
    this.billingPeriod = kDefaultBillingPeriod,
  });
  final String id, name;
  final int    priceXaf;
  final String billingPeriod;

  String get priceLabel => priceXaf == 0
      ? 'Gratuit'
      : '${moneyXaf(priceXaf)} FCFA / ${billingPeriodSuffix(billingPeriod)}';
}

// ─── Modèle données globales ───────────────────────────────────────────────────

class SubscriptionsData {
  const SubscriptionsData({
    required this.subscriptions,
    required this.plans,
    required this.total,
    required this.actifs,
    required this.trials,
    required this.inactifs,
    required this.expiringSoon,
    required this.mrr,
  });

  final List<SubscriptionDetail> subscriptions;
  final List<PlanOption>         plans;
  final int total, actifs, trials, inactifs, expiringSoon, mrr;

  static const empty = SubscriptionsData(
    subscriptions: [], plans: [], total: 0, actifs: 0,
    trials: 0, inactifs: 0, expiringSoon: 0, mrr: 0,
  );
}

// ─── Provider principal ─────────────────────────────────────────────────────────

final subscriptionsProvider =
    FutureProvider.autoDispose<SubscriptionsData>((ref) async {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);

  // Realtime
  Timer? debounce;
  void scheduleInvalidate() {
    debounce?.cancel();
    debounce = Timer(const Duration(seconds: 2), () => ref.invalidateSelf());
  }

  try {
    final channel = client.channel('platform_subscriptions_list')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'school_groups',
          callback: (_) => scheduleInvalidate(),
        )
        // Un changement de tarif ne touche pas `school_groups` : sans ça, la
        // colonne « Montant » garde l'ancien prix toute la session.
        .watchPlanReferential(scheduleInvalidate)
        .subscribe();
    ref.onDispose(() {
      debounce?.cancel();
      client.removeChannel(channel);
    });
  } catch (_) {}

  // ── Nombre d'écoles par groupe ──────────────────────────────────────────────
  final Map<String, int> schoolsByGroup = {};
  try {
    final rows = await client.from('schools').select('group_id') as List;
    for (final r in rows) {
      final gid = (r as Map)['group_id'] as String?;
      if (gid != null) schoolsByGroup[gid] = (schoolsByGroup[gid] ?? 0) + 1;
    }
  } catch (_) {}

  // ── Licence de tutelle par groupe ───────────────────────────────────────────
  //  ⚠️ On garde la PLUS PERTINENTE, pas la dernière : une licence active qui
  //  couvre aujourd'hui passe avant un brouillon signé pour l'an prochain.
  //  Même règle que `licenceAMontrer` côté ministère — deux écrans qui
  //  choisiraient différemment afficheraient deux contrats pour un seul.
  final Map<String, LicenceTutelle> licencesByGroup = {};
  try {
    // Les mêmes colonnes qu'en Économie : la ligne AFFICHE le contrat et le
    // bouton l'OUVRE. Deux requêtes différentes pour le même objet finiraient
    // par montrer deux vérités.
    final rows = await client
        .from('tutelle_licences')
        .select('id, group_id, tutelle, intitule, date_debut, date_fin, '
            'montant_xaf, avance_xaf, montant_regle_xaf, statut, '
            'reference_marche, signataire, notes, motif_statut, '
            'statut_change_le, school_groups!group_id(name, acces_suspendu, '
            'acces_suspendu_motif)')
        .order('date_fin', ascending: false) as List;
    final aujourdhui = DateTime.now();
    for (final r in rows) {
      final m = Map<String, dynamic>.from(r as Map);
      final gid = m['group_id'] as String?;
      if (gid == null) continue;
      final resume = LicenceTutelle.fromRow(m);
      final deja = licencesByGroup[gid];
      final couvre = resume.estActive && resume.dateFin.isAfter(aujourdhui);
      if (deja == null || (couvre && !deja.estActive)) {
        licencesByGroup[gid] = resume;
      }
    }
  } catch (_) {}

  // ── Abonnements (groupes + plan joint) ──────────────────────────────────────
  List<SubscriptionDetail> subs = [];
  try {
    final rows = await client
        .from('school_groups')
        .select('id, name, logo_url, admin_email, phone, group_type, '
            'department, plan_id, subscription_status, subscription_start, '
            'subscription_end, created_at, updated_at, tutelle, '
            'administre_referentiel_national, acces_suspendu, '
            'price_override_xaf, billed_schools, '
            'plan:subscription_plans(name, slug, price_xaf, billing_period, '
            'extra_school_2_5_xaf, extra_school_6_10_xaf, '
            'extra_school_11_20_xaf, extra_school_21p_xaf)')
        .order('created_at', ascending: false) as List;
    subs = rows.map((r) {
      final m = Map<String, dynamic>.from(r as Map);
      return SubscriptionDetail.fromMap(
        m,
        schoolsCount: schoolsByGroup[m['id']] ?? 0,
        licence: licencesByGroup[m['id']],
      );
    }).toList();
  } catch (_) {}

  // ── Plans disponibles (pour changer de plan) ────────────────────────────────
  List<PlanOption> plans = [];
  try {
    final rows = await client
        .from('subscription_plans')
        .select('id, name, price_xaf, billing_period')
        .eq('is_active', true)
        .order('price_xaf', ascending: true) as List;
    plans = rows.map((r) {
      final m = Map<String, dynamic>.from(r as Map);
      return PlanOption(
        id:       m['id']   as String,
        name:     m['name'] as String? ?? '',
        priceXaf: (m['price_xaf'] as num?)?.toInt() ?? 0,
        billingPeriod:
            m['billing_period'] as String? ?? kDefaultBillingPeriod,
      );
    }).toList();
  } catch (_) {}

  // ── KPIs ──────────────────────────────────────────────────────────────────
  int actifs = 0, trials = 0, inactifs = 0, expiringSoon = 0, mrr = 0;
  for (final s in subs) {
    if (s.isActive) {
      actifs++;
      // Ramené au mois : le MRR mélangeait des tarifs annuels et mensuels.
      mrr += s.monthlyPrice;
    } else if (s.isTrial) {
      trials++;
    } else {
      inactifs++;
    }
    if (s.isExpiringSoon) expiringSoon++;
  }

  return SubscriptionsData(
    subscriptions: subs,
    plans:         plans,
    total:         subs.length,
    actifs:        actifs,
    trials:        trials,
    inactifs:      inactifs,
    expiringSoon:  expiringSoon,
    mrr:           mrr,
  );
});
