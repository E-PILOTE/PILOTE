import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../finance/providers/obligation_provider.dart';
import '../../finance/services/bareme_applicable.dart';
import '../../finance/services/obligation.dart';
import '../../structure/providers/academic_year_context.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LES FRAIS D'INSCRIPTION, AU GUICHET DES INSCRIPTIONS.
//
//  ── LE TROU QUE CECI COMBLE ────────────────────────────────────────────────
//  Aucun fichier du module Inscription ne référençait Finance. On inscrivait un
//  élève sans jamais lui réclamer les frais d'inscription ; le chef validait
//  sans savoir si c'était payé ; aucun reçu ne sortait du guichet. Or dans une
//  école privée congolaise, c'est le versement qui FAIT l'inscription — et dans
//  le public, l'inscription est le seul frais qui se paie légalement.
//
//  Le socle existait déjà, entier et testé : `fee_structures` porte le barème,
//  `baremesApplicables` choisit la bonne ligne, `student_payments` encaisse avec
//  un reçu inviolable. Il n'y avait qu'un câble à poser.
//
//  ── CE QU'ON NE FAIT PAS, ET POURQUOI ──────────────────────────────────────
//  On ne BLOQUE jamais une validation sur un impayé. Refuser l'entrée d'un
//  enfant à l'école pour un versement en retard serait pire que le mal, et
//  c'est déjà la doctrine retenue pour les pièces manquantes du dossier : on
//  avertit, on laisse passer, on garde la trace.
//
//  On ne montre QUE le frais d'inscription, pas la scolarité entière. La
//  mensualité se recouvre au fil de l'année dans le module Paiements ; la
//  rappeler ici transformerait un guichet d'admission en écran de recouvrement,
//  et donnerait au secrétariat un chiffre dont il n'a que faire au moment
//  d'ouvrir un dossier.
// ════════════════════════════════════════════════════════════════════════════

/// Où en est un élève de ses frais d'INSCRIPTION.
class FraisInscription {
  const FraisInscription({
    this.du = 0,
    this.verse = 0,
    this.feeStructureId,
    this.libelle,
    this.montantBareme = 0,
    this.exoneration,
    this.motifExoneration,
  });

  /// Ce que l'élève doit réellement — exonération DÉJÀ déduite.
  final int du;

  /// Le tarif plein affiché par le barème, avant exonération.
  ///
  /// Conservé pour que le guichet montre la remise au lieu d'un montant
  /// mystérieusement plus bas que celui annoncé à la famille.
  final int montantBareme;

  /// Taux d'exonération de scolarité (%) accordé sur cette inscription, et sa
  /// justification. `null` = aucune.
  final int? exoneration;
  final String? motifExoneration;

  bool get estExonere => (exoneration ?? 0) > 0;

  /// Ce que l'exonération retire à l'école.
  int get montantExonere => (montantBareme - du).clamp(0, montantBareme);

  /// Net déjà encaissé sur ce frais, cette année (remboursements déduits).
  final int verse;

  /// Le barème retenu — nécessaire pour rattacher un encaissement.
  /// `null` = aucun barème d'inscription ne s'applique.
  final String? feeStructureId;

  /// Le nom du barème, tel que le groupe l'a écrit (« Inscription — Terminale »).
  final String? libelle;

  /// ⚠️ « Aucun barème » n'est PAS « à jour ». Trente écoles publiques du
  /// réseau n'ont aucun tarif posé ; les afficher réglées serait aussi faux que
  /// de les afficher débitrices. C'est `EtatObligation.sansBareme` qui le dit.
  ///
  /// ⚠️ Le test porte sur `montantBareme`, PAS sur `du` : un élève exonéré à
  /// 100 % a un dû nul et un barème parfaitement défini. Tester `du` l'aurait
  /// rangé parmi les écoles sans tarif — et le guichet aurait affiché « aucun
  /// barème » à un boursier dont la bourse venait justement d'être saisie.
  bool get baremeDefini => feeStructureId != null && montantBareme > 0;

  int get reste => (du - verse).clamp(0, du);

  /// ⚠️ `exonereTotal` distingue les deux dûs nuls : aucun tarif publié, ou
  /// tarif intégralement remis. Sans lui, un boursier à 100 % ressortait
  /// « Barème non défini » et la caisse partait chercher un tarif qui existe.
  EtatObligation get etat => etatObligation(
        du: du,
        verse: verse,
        exonereTotal: baremeDefini && du <= 0,
      );

  String get libelleEtat => baremeDefini
      ? libelleEtatObligation(etat)
      : 'Aucun barème d\'inscription défini';
}

/// Nom lisible d'un état — réexporté ici pour éviter que l'écran importe le
/// service Finance pour une seule chaîne.
String libelleEtatObligation(EtatObligation e) => libelleEtat(e);

/// Le barème d'inscription applicable à une CLASSE, et ce que l'élève a versé
/// dessus.
///
/// La clé est l'inscription : elle porte à la fois l'élève (qui paie), la
/// classe (donc le niveau, donc le tarif) et l'année (donc le périmètre des
/// versements). Prendre l'élève seul obligerait chaque appelant à retrouver les
/// deux autres, et l'un d'eux finirait par être oublié.
final fraisInscriptionProvider = FutureProvider.autoDispose
    .family<FraisInscription, String>((ref, enrollmentId) async {
  final baremes = ref.watch(baremesApplicablesProvider).valueOrNull ?? const [];
  final yearId = ref.watch(activeYearIdProvider);
  if (yearId == null) return const FraisInscription();

  final enr = await db.getOptional(
    'SELECT ce.student_id, ce.exemption_rate, ce.exemption_motif, c.level_id '
    '  FROM class_enrollments ce '
    '  LEFT JOIN classes c ON c.id = ce.class_id '
    ' WHERE ce.id = ?',
    [enrollmentId],
  );
  if (enr == null) return const FraisInscription();

  final ligne = baremeInscriptionPour(baremes, enr['level_id'] as String?);
  if (ligne == null) return const FraisInscription();

  // L'inscription fait partie de `kFraisScolarite` : une exonération la réduit.
  final taux = (enr['exemption_rate'] as num?)?.round();

  // Le versé se compte SUR CE BARÈME, pas sur tous les versements de l'élève :
  // une mensualité réglée ne solde pas l'inscription. `montant - remboursé`
  // parce qu'un remboursement partiel laisse la ligne « confirmed ».
  final p = await db.getOptional(
    'SELECT COALESCE(SUM(MAX(amount_xaf - COALESCE(refunded_amount_xaf, 0), 0)), 0) AS net '
    '  FROM student_payments '
    ' WHERE student_id = ? AND academic_year_id = ? AND fee_structure_id = ? '
    "   AND status IN ('confirmed', 'refunded')",
    [enr['student_id'], yearId, ligne.id],
  );

  return FraisInscription(
    du: apresExoneration(ligne.montant, taux),
    montantBareme: ligne.montant,
    exoneration: taux,
    motifExoneration: enr['exemption_motif'] as String?,
    verse: (p?['net'] as num?)?.round() ?? 0,
    feeStructureId: ligne.id,
    // L'intitulé voyage désormais avec la ligne de barème (migration 0108) :
    // la requête qui allait le rechercher une seconde fois était un aller-retour
    // pour rien.
    libelle: ligne.nom,
  );
});

/// L'exonération portée par une inscription — indépendamment de tout barème.
///
/// ⚠️ Séparée de [fraisInscriptionProvider] à dessein : celui-ci rend un objet
/// vide dès qu'aucun tarif n'est publié, et l'exonération disparaîtrait avec
/// lui. Or une école sans barème peut parfaitement avoir accordé une bourse —
/// le jour où le tarif arrive, la remise doit déjà être là.
typedef ExonerationDossier = ({int? taux, String? motif, bool boursierDeclare});

/// [boursierDeclare] vient de `students.has_scholarship` : la SITUATION de
/// l'enfant, pas la décision financière. Les deux ne se confondent pas — c'est
/// tout l'objet de la migration 0109 — mais l'écart entre les deux est
/// précisément ce qu'il faut montrer : un élève déclaré boursier sans taux
/// saisi doit encore la scolarité entière, et personne ne s'en doute.
final exonerationProvider = StreamProvider.autoDispose
    .family<ExonerationDossier, String>((ref, enrollmentId) {
  return db.watch(
    'SELECT ce.exemption_rate AS taux, ce.exemption_motif AS motif, '
    '       s.has_scholarship AS boursier '
    '  FROM class_enrollments ce '
    '  JOIN students s ON s.id = ce.student_id '
    ' WHERE ce.id = ?',
    parameters: [enrollmentId],
  ).map((rows) {
    if (rows.isEmpty) {
      return (taux: null, motif: null, boursierDeclare: false);
    }
    final r = rows.first;
    return (
      taux: (r['taux'] as num?)?.round(),
      motif: r['motif'] as String?,
      // `== 1` serait le piège habituel : la valeur arrive à 0, 1 ou NULL.
      boursierDeclare: ((r['boursier'] as num?) ?? 0) != 0,
    );
  });
});

/// La ligne de barème « inscription » qui s'applique à ce niveau, s'il y en a
/// une.
///
/// Passe par `baremesApplicables` — et pas par un filtre direct — parce que
/// jusqu'à quatre lignes peuvent coexister pour le même frais (réseau, école,
/// niveau, école+niveau). En prendre une au hasard, c'est réclamer un montant
/// qui varie d'un poste à l'autre.
LigneBareme? baremeInscriptionPour(
  List<LigneBareme> visibles,
  String? levelId,
) {
  for (final b in baremesApplicables(visibles, levelId: levelId)) {
    if (b.feeType == 'inscription') return b;
  }
  return null;
}

/// Ce que coûtera l'inscription dans une CLASSE donnée — avant que
/// l'inscription n'existe.
///
/// Sert à l'assistant de saisie : le secrétariat doit pouvoir annoncer le
/// montant à la famille au moment où il choisit la classe, pas le découvrir
/// après avoir enregistré.
final fraisInscriptionClasseProvider =
    FutureProvider.autoDispose.family<FraisInscription, String>(
        (ref, classId) async {
  final baremes = ref.watch(baremesApplicablesProvider).valueOrNull ?? const [];
  final c = await db.getOptional(
    'SELECT level_id FROM classes WHERE id = ?',
    [classId],
  );
  final ligne = baremeInscriptionPour(baremes, c?['level_id'] as String?);
  if (ligne == null) return const FraisInscription();
  // Aucune exonération ici : l'inscription n'existe pas encore, donc la
  // décision non plus. Le tarif annoncé à la famille est le tarif PLEIN — et
  // c'est plus honnête que d'anticiper une remise que personne n'a accordée.
  return FraisInscription(
    du: ligne.montant,
    montantBareme: ligne.montant,
    feeStructureId: ligne.id,
    libelle: ligne.nom,
  );
});
