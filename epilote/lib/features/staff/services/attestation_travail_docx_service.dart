import 'dart:typed_data';

import 'package:intl/intl.dart';

import '../../../core/services/docx_kit.dart';
import '../../../core/utils/safe_file_name.dart';
import 'attestation_travail_pdf_service.dart' show AttestationAgent;

// ════════════════════════════════════════════════════════════════════════════
//  L'ATTESTATION DE TRAVAIL, EN VERSION MODIFIABLE
//
//  ── POURQUOI CETTE PIÈCE APPELLE LA RETOUCHE ───────────────────────────────
//  Banque, bailleur, visa, dossier de prêt, mutuelle : l'agent qui demande ce
//  papier sait, lui, à QUI il le destine — et le destinataire a souvent une
//  exigence de formulation que l'établissement découvre au guichet. « Pour
//  servir auprès de la BCI », « en vue d'une demande de visa Schengen », une
//  mention de durée d'engagement : rien de tout cela ne se devine à l'avance,
//  et le PDF fige le texte avant qu'on la connaisse.
//
//  Sans version modifiable, le secrétariat retape l'attestation entière dans
//  Word — ce qu'il faisait AVANT la plateforme, et ce qui se recopie faux.
//
//  ── CE QUI NE DOIT PAS ENTRER DANS LE TEXTE, MÊME MODIFIABLE ───────────────
//  ⚠️ LE SALAIRE. L'attestation de travail atteste un EMPLOI, pas une
//  rémunération — c'est ce qui la distingue du bulletin de paie, et c'est la
//  raison pour laquelle elle peut circuler. Le composeur n'expose donc aucun
//  champ de montant, et la mention de bas de page le rappelle à celui qui
//  s'apprête à modifier le document.
//
//  ── DEUX PIÈCES SOUS UN SEUL NOM ───────────────────────────────────────────
//  ⚠️ « Attestation de TRAVAIL » atteste un emploi EN COURS ; « attestation de
//  SERVICE RENDU » atteste un emploi PASSÉ. Délivrer l'une pour l'autre est un
//  faux. La garde (`peutDelivrerAttestationTravail`) vit côté PDF et
//  s'applique en amont : ce fichier ne compose que ce qu'on l'autorise à
//  composer, il ne décide de rien.
// ════════════════════════════════════════════════════════════════════════════

String _dateLongue(DateTime? d) =>
    d == null ? '……………………' : DateFormat('d MMMM yyyy', 'fr').format(d);

class AttestationTravailDocxService {
  static Uint8List build({
    required AttestationAgent agent,
    required String schoolName,
    String? city,
    String? signataire,
    String? fonctionSignataire,
    bool serviceRendu = false,
  }) {
    final titre = serviceRendu
        ? 'ATTESTATION DE SERVICE RENDU'
        : 'ATTESTATION DE TRAVAIL';

    final d = DocxBuilder(
      titre: titre,
      etablissement: 'RÉPUBLIQUE DU CONGO\n$schoolName',
    )
      ..saut()
      ..paragraphe(
        'Je soussigné(e), '
        '${(signataire ?? '').trim().isEmpty ? '……………………………' : signataire!.trim()}, '
        '${(fonctionSignataire ?? 'responsable de l\'établissement').trim()}, '
        'atteste que :',
      )
      ..saut()
      ..champ('Nom et prénom(s)', agent.fullName)
      ..champ(
        'Né${agent.gender == 'F' ? 'e' : ''} le',
        '${_dateLongue(agent.dateOfBirth)}'
        '${(agent.birthPlace ?? '').trim().isEmpty ? '' : ' à ${agent.birthPlace!.trim()}'}',
      )
      ..champ('Matricule', agent.employeeNumber)
      ..champ('Fonction', agent.fonction)
      ..champ('Statut', agent.employmentStatus)
      ..champ(
        'Grade et échelon',
        [
          if ((agent.grade ?? '').trim().isNotEmpty) agent.grade!.trim(),
          if ((agent.echelon ?? '').trim().isNotEmpty) agent.echelon!.trim(),
        ].join(' · '),
      )
      ..saut();

    if (serviceRendu) {
      d.paragraphe(
        'a exercé les fonctions ci-dessus au sein de notre établissement '
        'du ${_dateLongue(agent.hireDate)} au ${_dateLongue(agent.departureDate)}, '
        'et y a donné entière satisfaction.',
      );
    } else {
      d.paragraphe(
        'est ${agent.employe} au sein de notre établissement depuis le '
        '${_dateLongue(agent.hireDate)}, et y exerce actuellement les '
        'fonctions ci-dessus.',
      );
    }

    d
      ..saut()
      // ⚠️ La formule reste OUVERTE : c'est exactement le passage que l'agent
      // vient compléter (« auprès de la BCI », « en vue d'un visa »). La
      // laisser fermée obligerait à retaper la pièce entière.
      ..paragraphe(
        'La présente attestation lui est délivrée pour servir et valoir ce que '
        'de droit auprès de ………………………………………………………………………',
      )
      ..signature(
        [
          if ((fonctionSignataire ?? '').trim().isNotEmpty)
            fonctionSignataire!.trim(),
          if ((signataire ?? '').trim().isNotEmpty) signataire!.trim(),
        ].join('\n'),
        lieu: (city ?? '').trim().isEmpty ? null : city!.trim(),
      )
      ..mention(
        'Cette attestation porte sur un EMPLOI et non sur une rémunération : '
        'aucun montant n\'y figure, et il ne doit pas y en être ajouté — c\'est '
        'ce qui lui permet de circuler. Le bulletin de paie est la pièce des '
        'montants.',
      );

    return d.construire();
  }

  static Future<String?> enregistrer({
    required Uint8List octets,
    required AttestationAgent agent,
    bool serviceRendu = false,
  }) =>
      enregistrerDocxSous(
        nomPropose: safeFileName(
          '${serviceRendu ? 'attestation_service_rendu' : 'attestation_travail'}'
          '_${agent.lastName}_${agent.firstName}.docx',
          fallback: 'attestation',
        ),
        octets: octets,
        titreFenetre: 'Enregistrer la version modifiable',
      );
}
