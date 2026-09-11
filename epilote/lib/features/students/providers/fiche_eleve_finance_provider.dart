import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/powersync/powersync_service.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CE QUI A ÉTÉ VERSÉ POUR CET ÉLÈVE — le RELEVÉ, pas le calcul
//
//  ── CE FICHIER NE DIT PAS CE QUE L'ÉLÈVE DOIT ──────────────────────────────
//  ⚠️ Le montant dû se lit dans `finance/providers/decompte_du_provider.dart`,
//  et NULLE PART AILLEURS. Ce calcul applique la fenêtre de présence, les
//  frais annexes, l'exonération et le statut de boursier ; il est verrouillé
//  par ses propres tests, et son en-tête dit explicitement que toute autre
//  version qui divergerait est celle qui a tort.
//
//  Réécrire ici un « reste dû » à partir des versements produirait un second
//  chiffre pour la même chose, sur la fiche que la caisse ouvre devant la
//  famille. La fiche appelle donc `decompteDuProvider` et se contente, elle,
//  de RELEVER les versements ligne par ligne.
//
//  ── POURQUOI LES VERSEMENTS ANNULÉS RESTENT VISIBLES ───────────────────────
//  ⚠️ Un versement annulé n'est pas un versement effacé. Une famille qui a un
//  reçu en main doit retrouver l'opération sur la fiche, avec son annulation
//  et son motif — sans quoi le guichet nie une pièce que le parent tient.
//  Ils sont donc lus, marqués, et exclus des seuls totaux.
// ════════════════════════════════════════════════════════════════════════════

DateTime? _d(Object? v) =>
    (v is String && v.isNotEmpty) ? DateTime.tryParse(v) : null;

String _s(Object? v) => (v as String?)?.trim() ?? '';

int _i(Object? v) => (v as num?)?.round() ?? 0;

/// Un versement, tel qu'il figure au journal de caisse.
class VersementLigne {
  const VersementLigne({
    required this.date,
    required this.montant,
    required this.libelle,
    required this.typeFrais,
    required this.methode,
    required this.recu,
    required this.reference,
    required this.statut,
    required this.periode,
    required this.anneeLabel,
    required this.annuleLe,
    required this.motifAnnulation,
    required this.rembourse,
    required this.notes,
  });

  final DateTime? date, annuleLe;
  final int montant, rembourse;
  final String libelle, typeFrais, methode, recu, reference, statut;
  final String periode, anneeLabel, motifAnnulation, notes;

  /// ⚠️ Seul `confirmed` compte dans un total. « En attente » est une
  /// promesse, « annulé » une opération défaite : les additionner ferait dire
  /// à la caisse qu'elle a encaissé ce qu'elle n'a pas.
  bool get compte => statut == 'confirmed';

  bool get annule => statut == 'cancelled' || annuleLe != null;
}

/// Le relevé des versements de l'élève, toutes années.
///
/// L'ordre décroissant met en tête le dernier versement — la première chose
/// qu'un caissier vérifie quand une famille se présente.
final ficheVersementsProvider = StreamProvider.autoDispose
    .family<List<VersementLigne>, String>((ref, studentId) {
  return db.watch(
    '''
    SELECT sp.payment_date, sp.amount_xaf, sp.payment_method,
           sp.receipt_number, sp.transaction_reference, sp.status,
           sp.period_month, sp.period_year, sp.notes,
           sp.cancelled_at, sp.cancellation_reason, sp.refunded_amount_xaf,
           fs.name AS fee_name, fs.fee_type,
           ay.label AS year_label
      FROM student_payments sp
      LEFT JOIN fee_structures fs ON fs.id = sp.fee_structure_id
      LEFT JOIN academic_years ay ON ay.id = sp.academic_year_id
     WHERE sp.student_id = ?
     ORDER BY sp.payment_date DESC
    ''',
    parameters: [studentId],
  ).map((rows) => [
        for (final r in rows)
          VersementLigne(
            date: _d(r['payment_date']),
            montant: _i(r['amount_xaf']),
            // Le barème a pu être retiré depuis : on garde alors le type de
            // frais, qui reste lisible, plutôt qu'une ligne sans intitulé.
            libelle: _s(r['fee_name']).isNotEmpty
                ? _s(r['fee_name'])
                : _s(r['fee_type']),
            typeFrais: _s(r['fee_type']),
            methode: _s(r['payment_method']),
            recu: _s(r['receipt_number']),
            reference: _s(r['transaction_reference']),
            statut: _s(r['status']),
            periode: _periode(r['period_month'], r['period_year']),
            anneeLabel: _s(r['year_label']),
            annuleLe: _d(r['cancelled_at']),
            motifAnnulation: _s(r['cancellation_reason']),
            rembourse: _i(r['refunded_amount_xaf']),
            notes: _s(r['notes']),
          ),
      ]);
});

const _mois = [
  '', 'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

/// « octobre 2025 » — le mois que le versement couvre, quand il en couvre un.
///
/// Une mensualité sans son mois est une ligne que personne ne sait rapprocher
/// d'un échéancier ; un frais d'inscription, lui, n'en porte pas, et afficher
/// « mois 0 » serait pire que rien.
String _periode(Object? mois, Object? annee) {
  final m = (mois as num?)?.toInt() ?? 0;
  final a = (annee as num?)?.toInt() ?? 0;
  if (m < 1 || m > 12) return '';
  return a > 0 ? '${_mois[m]} $a' : _mois[m];
}
