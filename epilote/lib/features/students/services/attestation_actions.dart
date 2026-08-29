// ══════════════════════════════════════════════════════════════════════════════
//  DÉLIVRER UNE ATTESTATION — le geste, depuis n'importe quel écran
//
//  Le service produit le PDF ; ce fichier réunit ce dont il a besoin (l'école,
//  l'année, le signataire) et refuse de délivrer un papier faux.
//
//  ── LE REFUS EST LA PARTIE UTILE ───────────────────────────────────────────
//  Un certificat de scolarité pour un élève sorti, ou un certificat de
//  radiation pour un élève présent, sont des FAUX. Le secrétariat qui les
//  imprime ne s'en rend pas compte, la famille les présente de bonne foi, et
//  c'est au guichet qu'on découvre le problème. La plateforme dit non ici,
//  avec la raison.
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/pdf_preview_dialog.dart';
import '../../auth/providers/auth_provider.dart';
import '../../structure/providers/academic_year_context.dart';
import '../../structure/providers/academic_year_provider.dart';
import 'attestations_pdf_service.dart';
import 'registre_documents.dart';

/// Ce que l'établissement met sur le papier : son nom, sa ville, le signataire.
class _Emetteur {
  const _Emetteur(this.schoolName, this.city, this.yearLabel, this.signataire,
      this.fonction);
  final String schoolName, yearLabel;
  final String? city, signataire, fonction;
}

_Emetteur _emetteur(WidgetRef ref) {
  final school = ref.read(currentSchoolProvider).valueOrNull;
  final year = ref.read(activeYearProvider);
  final profile = ref.read(authNotifierProvider).valueOrNull;

  // Le signataire n'est proposé que si l'agent connecté dirige l'établissement.
  // Un secrétaire imprime le document, il ne le signe pas : mieux vaut une
  // ligne vide qu'un nom qui n'a pas qualité.
  final dirige = profile?.role == 'directeur' || profile?.role == 'proviseur';
  final nom = dirige
      ? '${profile?.firstName ?? ''} ${profile?.lastName ?? ''}'.trim()
      : null;
  final fonction = switch (profile?.role) {
    'directeur' => 'Le Directeur',
    'proviseur' => 'Le Proviseur',
    _ => null,
  };

  return _Emetteur(
    (school?['name'] as String?)?.trim().isNotEmpty ?? false
        ? (school!['name'] as String).trim()
        : 'l’établissement',
    (school?['city'] as String?) ?? (school?['department'] as String?),
    year?.label ?? '',
    (nom?.isEmpty ?? true) ? null : nom,
    dirige ? fonction : null,
  );
}

void _refus(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: Theme.of(context).colorScheme.error,
      content: Text(message),
    ));

/// Certificat de scolarité — atteste que l'élève EST inscrit.
Future<void> delivrerCertificatScolarite(
  BuildContext context,
  WidgetRef ref, {
  required AttestationEleve eleve,
  required String? enrollmentStatus,
  String? studentId,
}) async {
  if (!peutDelivrerScolarite(enrollmentStatus)) {
    _refus(
        context,
        'Aucune inscription active : un certificat de scolarité attesterait '
        'une présence qui n’existe pas.');
    return;
  }
  final e = _emetteur(ref);
  // Le registre note l'ACTE : le document est produit au nom d'une personne
  // nommée, et l'établissement en répond. Ne lève jamais — le certificat passe
  // avant son enregistrement.
  await noterDocumentEmis(
    ref,
    documentType: TypeDocument.certificatScolarite,
    studentId: studentId,
    recipientName: eleve.fullName,
    recipientRef: '${eleve.className} · ${eleve.matricule ?? '—'}',
  );
  if (!context.mounted) return;
  await showPdfPreviewDialog(
    context,
    title: 'Certificat de scolarité',
    subtitle: '${eleve.fullName} · ${eleve.className}',
    pdfFileName:
        'certificat_scolarite_${eleve.lastName}_${eleve.firstName}.pdf'
            .replaceAll(' ', '_'),
    build: (_) => AttestationsPdfService.certificatScolarite(
      eleve: eleve,
      schoolName: e.schoolName,
      yearLabel: e.yearLabel,
      city: e.city,
      signataire: e.signataire,
      fonction: e.fonction,
    ),
  );
}

/// Certificat de radiation (exeat) — atteste qu'il ne l'est PLUS, et pourquoi.
///
/// C'est le papier sans lequel l'école d'accueil ne peut pas inscrire l'enfant.
/// Il porte l'identifiant national : c'est par lui que la scolarité se reprend
/// au lieu de recommencer.
Future<void> delivrerCertificatRadiation(
  BuildContext context,
  WidgetRef ref, {
  required AttestationEleve eleve,
  required String? enrollmentStatus,
  required String? motif,
  DateTime? dateSortie,
  String? observations,
  String? studentId,
}) async {
  if (!peutDelivrerRadiation(enrollmentStatus)) {
    _refus(
        context,
        'Cet élève est toujours inscrit : prononcez d’abord sa sortie, le '
        'certificat en découlera.');
    return;
  }
  final e = _emetteur(ref);
  await noterDocumentEmis(
    ref,
    documentType: TypeDocument.certificatRadiation,
    studentId: studentId,
    recipientName: eleve.fullName,
    recipientRef: '${eleve.className} · ${eleve.matricule ?? '—'}',
    purpose: motif,
  );
  if (!context.mounted) return;
  await showPdfPreviewDialog(
    context,
    title: 'Certificat de radiation',
    subtitle: '${eleve.fullName} · ${eleve.className}',
    pdfFileName:
        'certificat_radiation_${eleve.lastName}_${eleve.firstName}.pdf'
            .replaceAll(' ', '_'),
    build: (_) => AttestationsPdfService.certificatRadiation(
      eleve: eleve,
      schoolName: e.schoolName,
      yearLabel: e.yearLabel,
      motif: motif,
      dateSortie: dateSortie,
      observations: observations,
      city: e.city,
      signataire: e.signataire,
      fonction: e.fonction,
    ),
  );
}
