// ══════════════════════════════════════════════════════════════════════════════
//  IMPRIMER DES CARTES — le geste, depuis la campagne ou depuis une fiche
//
//  Le service (`carte_scolaire_pdf_service.dart`) dessine ; le provider
//  (`cartes_provider.dart`) rassemble les visages ; ce fichier fait le geste et
//  dit la vérité sur ce qui va sortir de l'imprimante.
//
//  ── ANNONCER LES VISAGES MANQUANTS AVANT, PAS APRÈS ────────────────────────
//  Le compte affiché à l'écran vient de `photo_url` en base. Le compte réel
//  d'une planche vient de ce que ce poste-ci a pu CHARGER : une photo peut
//  exister sur le serveur et rester introuvable ici (jamais affichée sur ce
//  poste, pas de réseau aujourd'hui). L'écart n'est pas un détail — c'est la
//  différence entre une planche qu'on découpe et une planche qu'on jette.
//
//  On le mesure donc APRÈS chargement, avant l'aperçu, et on demande
//  confirmation quand il y en a. Une école peut vouloir des cartes sans photo
//  (cantine, bibliothèque) : le but n'est pas d'interdire, c'est que personne
//  ne l'apprenne aux ciseaux.
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/pdf_preview_dialog.dart';
import '../../../data/models/academic_year_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../structure/providers/academic_year_context.dart';
import '../../structure/providers/academic_year_provider.dart';
import '../../students/services/carte_scolaire_pdf_service.dart';
import '../../students/services/registre_documents.dart';
import '../providers/cartes_provider.dart';

/// Ce que l'établissement met sur la carte.
class EmetteurCarte {
  const EmetteurCarte(this.schoolName, this.city, this.yearLabel);
  final String schoolName, yearLabel;
  final String? city;
}

EmetteurCarte emetteurCarte(WidgetRef ref) {
  final school = ref.read(currentSchoolProvider).valueOrNull;
  final AcademicYearModel? year = ref.read(activeYearProvider);
  final nom = (school?['name'] as String?)?.trim();
  return EmetteurCarte(
    nom == null || nom.isEmpty ? 'Établissement' : nom,
    (school?['city'] as String?) ?? (school?['department'] as String?),
    year?.label ?? '',
  );
}

/// Faut-il continuer malgré les visages manquants ? `true` s'il n'y en a pas.
Future<bool> _confirmerSansPhoto(
  BuildContext context, {
  required int sansPhoto,
  required int total,
}) async {
  if (sansPhoto == 0) return true;
  final tous = sansPhoto == total;
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(tous ? 'Aucune photo disponible' : '$sansPhoto carte'
          '${sansPhoto > 1 ? 's' : ''} sans photo'),
      content: Text(
        tous
            ? "Aucun visage n'a pu être chargé sur ce poste : les $total cartes "
                'sortiront avec un cadre vide. Les photos se prennent depuis la '
                "fiche de l'élève ; si elles existent déjà, ouvrez une fois la "
                'liste de la classe avec le réseau pour que ce poste les garde.'
            : 'Sur $total cartes, $sansPhoto sortiront avec un cadre vide — soit '
                "l'élève n'a pas de photo, soit ce poste ne l'a jamais chargée. "
                'Les autres sont complètes.',
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Annuler')),
        FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Imprimer quand même')),
      ],
    ),
  );
  return ok ?? false;
}

void _rien(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

/// Planche de cartes pour une liste d'élèves (une classe, une sélection).
Future<void> imprimerPlancheCartes(
  BuildContext context,
  WidgetRef ref, {
  required List<CarteEleveRow> eleves,
  required String titre,
}) async {
  final actifs = eleves.where((e) => peutDelivrerCarte(e.status)).toList();
  if (actifs.isEmpty) {
    _rien(
        context,
        'Aucune inscription active dans cette sélection : une carte scolaire '
        "atteste d'une présence, elle ne se délivre pas à un élève sorti.");
    return;
  }

  final prep = await preparerCartes(actifs, enAttente: filePhotosEnAttente(ref));
  if (!context.mounted) return;

  if (!await _confirmerSansPhoto(context,
      sansPhoto: prep.sansPhoto, total: prep.cartes.length)) {
    return;
  }
  if (!context.mounted) return;

  final em = emetteurCarte(ref);
  final planches =
      (prep.cartes.length + kCartesParPlanche - 1) ~/ kCartesParPlanche;

  // Une ligne de registre PAR ÉLÈVE, pas une par planche. Le registre répond à
  // « combien de cartes cet enfant a-t-il reçues ? » — la question des
  // duplicatas — et une ligne « classe de 40 » n'y répondrait pas.
  for (final e in actifs) {
    await noterDocumentEmis(
      ref,
      documentType: TypeDocument.carteScolaire,
      studentId: e.studentId,
      recipientName: e.fullName,
      recipientRef: '${e.className} · ${e.matricule}',
      purpose: titre,
    );
  }
  if (!context.mounted) return;

  await showPdfPreviewDialog(
    context,
    title: 'Cartes scolaires — $titre',
    subtitle: '${prep.cartes.length} carte'
        '${prep.cartes.length > 1 ? 's' : ''} · $planches planche'
        '${planches > 1 ? 's' : ''} A4 recto-verso',
    pdfFileName:
        'cartes_scolaires_${titre}_${em.yearLabel}.pdf'.replaceAll(' ', '_'),
    build: (_) => CarteScolairePdfService.planche(
      eleves: prep.cartes,
      schoolName: em.schoolName,
      yearLabel: em.yearLabel,
      city: em.city,
    ),
  );
}

/// Carte seule — le guichet, quand un élève perd la sienne en cours d'année.
Future<void> imprimerCarteEleve(
  BuildContext context,
  WidgetRef ref, {
  required CarteEleveRow eleve,
}) async {
  if (!peutDelivrerCarte(eleve.status)) {
    _rien(
        context,
        "Aucune inscription active : une carte scolaire attesterait d'une "
        "qualité que l'élève n'a plus.");
    return;
  }

  final prep =
      await preparerCartes([eleve], enAttente: filePhotosEnAttente(ref));
  if (!context.mounted || prep.cartes.isEmpty) return;

  if (!await _confirmerSansPhoto(context,
      sansPhoto: prep.sansPhoto, total: 1)) {
    return;
  }
  if (!context.mounted) return;

  final em = emetteurCarte(ref);
  await noterDocumentEmis(
    ref,
    documentType: TypeDocument.carteScolaire,
    studentId: eleve.studentId,
    recipientName: eleve.fullName,
    recipientRef: '${eleve.className} · ${eleve.matricule}',
    purpose: 'Duplicata au guichet',
  );
  if (!context.mounted) return;
  await showPdfPreviewDialog(
    context,
    title: 'Carte scolaire',
    subtitle: '${eleve.fullName} · ${eleve.className}',
    pdfFileName:
        'carte_scolaire_${eleve.lastName}_${eleve.firstName}.pdf'
            .replaceAll(' ', '_'),
    build: (_) => CarteScolairePdfService.carteUnique(
      eleve: prep.cartes.first,
      schoolName: em.schoolName,
      yearLabel: em.yearLabel,
      city: em.city,
    ),
  );
}

/// L'agent connecté peut-il produire des cartes ? Réservé au personnel de
/// l'établissement — le rôle sert de garde-fou local, le verrou qui compte
/// reste le module `cartes` (profil d'accès) et la RLS.
bool peutProduireDesCartes(WidgetRef ref) {
  final role = ref.read(authNotifierProvider).valueOrNull?.role;
  return role != null && role != 'eleve' && role != 'parent';
}
