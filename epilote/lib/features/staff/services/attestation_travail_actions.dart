import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/pdf_preview_dialog.dart';
import '../../auth/providers/auth_provider.dart';
import '../../structure/providers/academic_year_provider.dart';
import '../../students/services/registre_documents.dart';
import '../../user/widgets/staff_account_widgets.dart' show staffRoleLabel;
import '../providers/staff_dossier_provider.dart';
import 'attestation_travail_docx_service.dart';
import 'attestation_travail_pdf_service.dart';

// ════════════════════════════════════════════════════════════════════════════
//  DÉLIVRER L'ATTESTATION D'UN AGENT — le geste, séparé de l'écran
//
//  ── POURQUOI CE FICHIER EXISTE ─────────────────────────────────────────────
//  Il vivait en tête de `personnel_dossier_sheet.dart`, qui est une FEUILLE
//  D'ÉCRAN. Deux choses y cohabitaient sans jamais changer pour la même
//  raison : comment un dossier RH s'affiche, et ce qu'on met sur un papier
//  officiel. La feuille a franchi les 500 lignes en gagnant la version Word,
//  et la coupe suit cette couture-là.
//
//  C'est aussi le patron déjà employé côté élèves
//  (`students/services/attestation_actions.dart`) : le service compose la
//  pièce, ce fichier réunit ce dont elle a besoin — l'école, le signataire —
//  et refuse de délivrer un papier faux.
//
//  ── LE SIGNATAIRE N'EST PROPOSÉ QUE S'IL A QUALITÉ ─────────────────────────
//  ⚠️ Un secrétaire IMPRIME le document, il ne le SIGNE pas. Mieux vaut une
//  ligne vide à remplir à la main qu'un nom qui n'engage personne — même règle
//  que pour les attestations d'élèves.
// ════════════════════════════════════════════════════════════════════════════

/// Délivre l'attestation de travail de l'agent.
Future<void> delivrerAttestationTravailAgent(
    BuildContext context, WidgetRef ref, StaffDossier d) async {
  final school = ref.read(currentSchoolProvider).valueOrNull;
  final moi = ref.read(authNotifierProvider).valueOrNull;
  final dirige = moi?.role == 'directeur' || moi?.role == 'proviseur';
  final nom = dirige ? '${moi?.firstName ?? ''} ${moi?.lastName ?? ''}'.trim() : '';

  // Au registre comme les papiers d'élèves : une attestation de travail sert à
  // ouvrir un compte, obtenir un prêt, justifier un revenu. L'établissement
  // doit pouvoir dire qui l'a délivrée. Ne lève jamais.
  await noterDocumentEmis(
    ref,
    documentType: TypeDocument.attestationTravail,
    staffProfileId: d.id,
    recipientName: d.fullName,
    recipientRef: staffRoleLabel(d.role),
  );
  if (!context.mounted) return;

  await showPdfPreviewDialog(
    context,
    title: 'Attestation de travail',
    subtitle: '${d.fullName} · ${staffRoleLabel(d.role)}',
    pdfFileName:
        'attestation_travail_${d.lastName}_${d.firstName}.pdf'.replaceAll(' ', '_'),
    build: (_) => AttestationTravailPdfService.build(
      agent: AttestationAgent(
        firstName: d.firstName,
        lastName: d.lastName,
        fonction: staffRoleLabel(d.role),
        employeeNumber: d.employeeNumber,
        employmentStatus: d.employmentStatus,
        grade: d.grade,
        echelon: d.echelon,
        gender: d.gender,
        birthPlace: d.birthPlace,
        dateOfBirth:
            d.dateOfBirth == null ? null : DateTime.tryParse(d.dateOfBirth!),
        hireDate: d.hireDate == null ? null : DateTime.tryParse(d.hireDate!),
      ),
      schoolName: (school?['name'] as String?)?.trim().isNotEmpty ?? false
          ? (school!['name'] as String).trim()
          : 'l\'établissement',
      city: (school?['city'] as String?) ?? (school?['department'] as String?),
      signataire: nom.isEmpty ? null : nom,
      fonctionSignataire: switch (moi?.role) {
        'directeur' => 'Le Directeur',
        'proviseur' => 'Le Proviseur',
        _ => null,
      },
    ),
    // ⚠️ LA VERSION MODIFIABLE. L'agent qui demande ce papier sait, lui, à QUI
    // il le destine — et le destinataire a souvent une exigence de
    // formulation que l'établissement découvre au guichet : « pour servir
    // auprès de la BCI », « en vue d'une demande de visa ». Le PDF fige le
    // texte avant qu'on la connaisse, et le secrétariat retapait alors
    // l'attestation entière dans Word.
    //
    // ⚠️ Aucun montant n'y figure et il ne doit pas y en être ajouté : cette
    // pièce atteste un EMPLOI, pas une rémunération — c'est ce qui lui permet
    // de circuler. Le document Word le rappelle à qui s'apprête à le modifier.
    onWord: () {
      final agent = AttestationAgent(
        firstName: d.firstName,
        lastName: d.lastName,
        fonction: staffRoleLabel(d.role),
        employeeNumber: d.employeeNumber,
        employmentStatus: d.employmentStatus,
        grade: d.grade,
        echelon: d.echelon,
        gender: d.gender,
        birthPlace: d.birthPlace,
        dateOfBirth:
            d.dateOfBirth == null ? null : DateTime.tryParse(d.dateOfBirth!),
        hireDate: d.hireDate == null ? null : DateTime.tryParse(d.hireDate!),
      );
      return AttestationTravailDocxService.enregistrer(
        octets: AttestationTravailDocxService.build(
          agent: agent,
          schoolName:
              (school?['name'] as String?)?.trim().isNotEmpty ?? false
                  ? (school!['name'] as String).trim()
                  : 'l\'établissement',
          city:
              (school?['city'] as String?) ?? (school?['department'] as String?),
          signataire: nom.isEmpty ? null : nom,
          fonctionSignataire: switch (moi?.role) {
            'directeur' => 'Le Directeur',
            'proviseur' => 'Le Proviseur',
            _ => null,
          },
        ),
        agent: agent,
      );
    },
  );
}
