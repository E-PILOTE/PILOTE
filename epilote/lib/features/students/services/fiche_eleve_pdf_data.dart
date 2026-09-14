import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../finance/providers/decompte_du_provider.dart';
import '../providers/fiche_eleve_actes_provider.dart';
import '../providers/fiche_eleve_finance_provider.dart';
import '../providers/fiche_eleve_provider.dart';
import '../providers/fiche_eleve_resultats_provider.dart';
import '../providers/fiche_eleve_vie_provider.dart';
import '../providers/student_dossier_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CE QUE L'IMPRESSION DOIT LIRE — séparé de ce qu'elle doit composer
//
//  ── POURQUOI DEUX FICHIERS ─────────────────────────────────────────────────
//  Le composeur (`fiche_eleve_pdf_service.dart`) tenait les deux moitiés et
//  passait les 500 lignes de la règle maison. La coupe suit une couture de
//  cohésion : ici on interroge onze providers, là on dessine des tableaux.
//  Les deux moitiés ne changent jamais pour la même raison.
//
//  ── POURQUOI LA LECTURE PRÉCÈDE, ET NE SE REFAIT PAS ───────────────────────
//  ⚠️ Le composeur est appelé DEUX FOIS pour un seul document : une fois pour
//  l'aperçu, une fois pour l'enregistrement. S'il relisait les tables à chaque
//  appel, un tick de synchronisation entre les deux suffirait à faire diverger
//  le fichier enregistré de l'aperçu qu'on vient de valider — un défaut qu'on
//  ne saurait ni reproduire ni expliquer. On lit une fois, on compose deux.
// ════════════════════════════════════════════════════════════════════════════

/// Tout ce que l'impression doit connaître, lu une fois, hors du composeur.
class FicheElevePdfMatiere {
  const FicheElevePdfMatiere({
    required this.dossier,
    required this.parcours,
    required this.bulletins,
    required this.actes,
    required this.complet,
    required this.anneeLabel,
    this.assiduite,
    this.incidents = const [],
    this.visites = const [],
    this.versements = const [],
    this.decompte,
  });

  final StudentDossier dossier;
  final List<ParcoursAnnee> parcours;
  final List<BulletinLigne> bulletins;
  final ActesEleve actes;

  /// `true` = dossier complet interne. `false` = fiche administrative.
  final bool complet;

  final String anneeLabel;

  // Ne sont renseignés QUE pour le dossier complet interne.
  final Assiduite? assiduite;
  final List<IncidentLigne> incidents;
  final List<VisiteLigne> visites;
  final List<VersementLigne> versements;
  final DecompteDu? decompte;
}

/// L'année sur laquelle porte l'impression, telle que l'écran la connaît.
typedef AnneePdf = ({String id, String label, DateTime? debut, DateTime? fin});

/// Lit tout ce qu'il faut, puis rend la matière du document.
///
/// ⚠️ La lecture se fait ICI et non dans le composeur : celui-ci doit pouvoir
/// être appelé deux fois (l'aperçu, puis l'enregistrement) sans relire onze
/// tables, et sans qu'un tick de synchronisation change le document entre les
/// deux — un aperçu qui ne correspond pas au fichier enregistré est un défaut
/// qu'on ne saurait pas expliquer.
Future<FicheElevePdfMatiere> rassemblerFicheEleve(
  WidgetRef ref, {
  required String studentId,
  required StudentDossier dossier,
  required AnneePdf? annee,
  required bool complet,
}) async {
  final parcours = await ref.read(ficheParcoursProvider(studentId).future);
  final bulletins = await ref.read(ficheBulletinsProvider(studentId).future);
  final actes = await ref.read(ficheActesProvider(studentId).future);

  if (!complet) {
    return FicheElevePdfMatiere(
      dossier: dossier,
      parcours: parcours,
      bulletins: bulletins,
      actes: actes,
      complet: false,
      anneeLabel: annee?.label ?? '',
    );
  }

  final anneeId = annee?.id ?? '';
  final incidents = await ref.read(ficheDisciplineProvider(studentId).future);
  final visites = await ref.read(ficheInfirmerieProvider(studentId).future);
  final versements = await ref.read(ficheVersementsProvider(studentId).future);
  final assiduite = anneeId.isEmpty
      ? null
      : await ref.read(ficheAssiduiteProvider((studentId, anneeId)).future);

  // Le décompte est porté par l'INSCRIPTION de l'année, pas par l'élève.
  final insc = parcours
      .where((p) => annee == null || p.anneeLabel == annee.label)
      .firstOrNull;
  final decompte = (insc == null || insc.enrollmentId.isEmpty)
      ? null
      : await ref.read(decompteDuProvider(insc.enrollmentId).future);

  return FicheElevePdfMatiere(
    dossier: dossier,
    parcours: parcours,
    bulletins: bulletins,
    actes: actes,
    complet: true,
    anneeLabel: annee?.label ?? '',
    assiduite: assiduite,
    incidents: incidents,
    visites: visites,
    versements: versements,
    decompte: decompte,
  );
}


// ── Les trois mises en forme communes aux deux composeurs ──────────────────
//
// ⚠️ Elles vivent ICI, dans le fichier que les deux composeurs importent déjà,
// et non dans l'un d'eux : les faire venir de l'autre créerait un cycle
// d'imports entre « ce qui sort de l'école » et « ce qui n'en sort pas », deux
// fichiers qu'on a justement séparés pour que la frontière reste nette.

/// Une date, ou le tiret qui dit qu'il n'y en a pas.
///
/// ⚠️ Le tiret, jamais le vide. Sur une pièce qui circule, une case blanche se
/// lit comme un oubli de mise en page ; « — » dit que la question a été posée.
String fmtDatePdf(DateTime? d) =>
    d == null ? '—' : DateFormat('dd/MM/yyyy').format(d);

/// Un nombre à deux décimales, ou le tiret.
String fmtNum1Pdf(double? v) => v == null ? '—' : v.toStringAsFixed(2);

/// Un texte, ou le tiret — même raison que [fmtDatePdf].
String fmtOuTiret(String v) => v.trim().isEmpty ? '—' : v.trim();
