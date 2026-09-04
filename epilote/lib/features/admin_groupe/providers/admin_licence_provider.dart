import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/licence_statut.dart';
import '../../../core/utils/subscription_days.dart';
import '../../auth/providers/auth_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA LICENCE, VUE PAR LE MINISTÈRE LUI-MÊME
//
//  ── CE QUE ÇA RÉPARE ──────────────────────────────────────────────────────
//  Depuis 0182 les deux ministères sont sur le plan « Licence de tutelle » à
//  0 XAF. Leur page Abonnement leur annonçait donc « Plan Licence de tutelle —
//  Gratuit », sans début, sans terme, sans montant : la relation commerciale
//  la plus importante de la plateforme s'affichait comme un compte d'essai.
//
//  Le contrat, lui, vit dans `tutelle_licences` (0160) — montant négocié,
//  avance, règlements, référence de marché, signataire — et n'était visible
//  QUE du fondateur, dans Économie › Licences. Le ministère n'avait aucun
//  moyen de relire ce qu'il a signé.
//
//  ── LA RLS EXISTE DÉJÀ ────────────────────────────────────────────────────
//  `tutelle_licences_lecture_groupe` (0160) : SELECT pour `is_admin_groupe()`
//  sur SON groupe. En lecture seule — « il l'a signé, il a le droit de le
//  relire ; il n'a pas celui d'en changer le montant ». Rien à ouvrir ici.
//
//  ── ⚠️ CE QUE CETTE LICENCE NE FAIT PAS ───────────────────────────────────
//  Elle n'ouvre ni ne ferme AUCUN accès. Une licence échue, un solde impayé,
//  ou l'absence totale de licence ne coupent rien : la vue de tutelle dépend
//  de `administre_referentiel_national`, et 0183 garantit qu'un ministère n'a
//  pas d'échéance d'abonnement. On ne ferme pas l'État pour un mandat en
//  retard. Ce provider AFFICHE ; il ne garde rien.
// ════════════════════════════════════════════════════════════════════════════

class LicenceDuGroupe {
  const LicenceDuGroupe({
    required this.id,
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
  });

  factory LicenceDuGroupe.fromRow(Map<String, dynamic> r) => LicenceDuGroupe(
        id: r['id'] as String,
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
      );

  final String id, intitule, statut;
  final String? referenceMarche, signataire, notes;

  /// Pourquoi le statut a changé (0186). Le ministère le lit sur sa propre
  /// page : une décision qui l'affecte et qu'il découvrirait sans explication
  /// serait une décision qu'il vient contester par téléphone.
  final String? motifStatut;
  final DateTime? statutChangeLe;
  final DateTime dateDebut, dateFin;
  final int montantXaf, avanceXaf, montantRegleXaf;

  String get statutLabel => libelleStatutLicenceOuTiret(statut);
  bool get enVigueur => licenceEnVigueur(statut);

  /// Reste dû. Un marché public se règle en tranches : le solde est la seule
  /// des trois sommes qui intéresse un ordonnateur.
  int get soldeXaf => montantXaf - montantRegleXaf;

  bool get soldee => soldeXaf <= 0;

  /// Part réglée, 0..1. `null` quand le montant est nul — une licence à titre
  /// gracieux n'est pas « réglée à 0 % », elle n'a rien à régler.
  double? get partReglee =>
      montantXaf <= 0 ? null : (montantRegleXaf / montantXaf).clamp(0.0, 1.0);

  /// Jours civils avant le terme — même arithmétique que la base et que le
  /// reste de l'application (`daysUntilDate`), jamais `difference(now)`.
  int? get joursRestants => daysUntilDate(dateFin);

  bool get echue {
    final j = joursRestants;
    return j != null && j < 0;
  }

  /// Durée totale du marché, en jours. Au moins 1 : la base impose déjà
  /// `date_fin > date_debut`, mais un `null` mal parsé ne doit pas diviser.
  int get dureeJours {
    final d = dateFin.difference(dateDebut).inDays;
    return d < 1 ? 1 : d;
  }

  /// Part de la période écoulée, 0..1 — la barre de couverture.
  ///
  /// ⚠️ À ne PAS confondre avec [partReglee]. Un marché peut être couvert à
  /// 80 % du temps et réglé à 25 % : ce sont ces deux barres côte à côte qui
  /// disent où en est l'exécution, et une seule des deux ne dit rien.
  double get partEcoulee {
    final ecoules = DateTime.now().difference(dateDebut).inDays;
    return (ecoules / dureeJours).clamp(0.0, 1.0);
  }

  /// Nombre de mois couverts — au moins 1, pour ne jamais diviser par zéro.
  /// Miroir exact de `LicenceTutelle.moisCouverts` côté fondateur : les deux
  /// espaces doivent annoncer le MÊME équivalent mensuel.
  int get moisCouverts {
    // Même tolérance que `annuelXaf` : un marché annuel couvre DOUZE mois,
    // pas 11,96 arrondis à 12 par chance.
    if ((dureeJours - 365).abs() <= 15) return 12;
    final m = (dureeJours / 30.44).round();
    return m < 1 ? 1 : m;
  }

  /// Le marché ramené au mois — la seule base comparable à un abonnement.
  int get mensuelXaf => (montantXaf / moisCouverts).round();

  /// Le marché ramené à l'année, pour un budget annuel de l'État.
  ///
  /// ⚠️ UN MARCHÉ ANNUEL VAUT SON MONTANT, PAS 100,3 % DE SON MONTANT.
  /// Du 01/01 au 31/12 il y a 364 jours d'écart, pas 365 : la règle de trois
  /// affichait « 40 000 000 F de marché → 40 109 890 F par an », et le coût
  /// par établissement héritait de l'écart (3 342 491 au lieu de 3 333 333).
  /// Mathématiquement juste, faux à lire sur une fiche de marché — et c'est
  /// ce chiffre-là qu'un ordonnateur recopie dans un budget.
  ///
  /// On ne proratise donc qu'au-delà d'un écart réel à l'année (± 15 jours) :
  /// un marché de trois ans reste ramené, un marché annuel reste lui-même.
  int get annuelXaf => (dureeJours - 365).abs() <= 15
      ? montantXaf
      : (montantXaf * 365 / dureeJours).round();

  /// Coût annuel par établissement couvert. `null` si le réseau est inconnu ou
  /// vide — afficher « 0 F par école » sur un marché de 40 millions serait
  /// pire que ne rien afficher.
  int? coutAnnuelParEtablissement(int nbEtablissements) =>
      nbEtablissements <= 0 ? null : (annuelXaf / nbEtablissements).round();

  /// Coût annuel par élève couvert. Le chiffre qu'un ordonnateur compare.
  int? coutAnnuelParEleve(int nbEleves) =>
      nbEleves <= 0 ? null : (annuelXaf / nbEleves).round();
}

/// La licence à MONTRER parmi celles du groupe.
///
/// ⚠️ Un ministère peut en avoir plusieurs : un marché se renouvelle, et les
/// précédents restent en base comme historique. On montre celle qui couvre
/// aujourd'hui ; à défaut, la plus récente par son terme — y compris échue,
/// parce qu'une licence expirée est précisément ce qu'il faut voir.
LicenceDuGroupe? licenceAMontrer(List<LicenceDuGroupe> licences) {
  if (licences.isEmpty) return null;
  final tri = [...licences]..sort((a, b) => b.dateFin.compareTo(a.dateFin));
  for (final l in tri) {
    if (l.enVigueur && !l.echue) return l;
  }
  return tri.first;
}

/// Toutes les licences du groupe connecté, terme décroissant.
///
/// Rend une liste VIDE pour un groupe ordinaire : la RLS n'en montre aucune,
/// et le déclencheur de 0160 interdit d'en créer hors d'un ministère.
final licencesDuGroupeProvider =
    FutureProvider.autoDispose<List<LicenceDuGroupe>>((ref) async {
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null || groupId.isEmpty) return const [];

  // ⚠️ Pas de `catch (_) {}` muet : une page de licence qui affiche « aucune
  // licence » parce que la requête a échoué ferait croire à un ministère que
  // son marché n'est pas enregistré.
  final rows = await ref
      .watch(supabaseClientProvider)
      .from('tutelle_licences')
      .select('id, intitule, date_debut, date_fin, montant_xaf, avance_xaf, '
          'montant_regle_xaf, statut, reference_marche, signataire, notes, '
          'motif_statut, statut_change_le')
      .eq('group_id', groupId)
      .order('date_fin', ascending: false) as List;

  return [
    for (final r in rows)
      LicenceDuGroupe.fromRow(Map<String, dynamic>.from(r as Map)),
  ];
});
