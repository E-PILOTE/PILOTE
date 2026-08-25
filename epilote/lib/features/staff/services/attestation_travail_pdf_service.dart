// ══════════════════════════════════════════════════════════════════════════════
//  ATTESTATION DE TRAVAIL — le papier que tout agent finit par demander
//
//  Banque, bailleur, visa, dossier de prêt, mutuelle : un fonctionnaire ou un
//  contractuel en réclame plusieurs par an. Sans la plateforme, le secrétariat
//  la retape, et la date d'entrée en service — celle qui fonde l'ancienneté —
//  s'y recopie de mémoire.
//
//  ── CE QU'ELLE DIT, ET CE QU'ELLE NE DIT PAS ───────────────────────────────
//  Elle atteste un EMPLOI, pas une rémunération. Le salaire n'y figure jamais :
//  une attestation de travail qui porte un montant devient un bulletin de paie
//  déguisé, et le module Paie a son propre document, ses propres droits.
//
//  ⚠️ Elle n'est délivrée qu'à un agent EN SERVICE. Pour un agent parti, c'est
//  une attestation de SERVICE RENDU qu'il faut — un autre papier, au passé, qui
//  porte la date de fin. Les confondre produirait un faux.
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/attestation_kit.dart';
import '../../../core/services/official_pdf_kit.dart';

/// L'agent tel qu'il apparaît sur un papier officiel.
class AttestationAgent {
  const AttestationAgent({
    required this.firstName,
    required this.lastName,
    required this.fonction,
    this.employeeNumber,
    this.employmentStatus,
    this.grade,
    this.echelon,
    this.gender,
    this.dateOfBirth,
    this.birthPlace,
    this.hireDate,
    this.departureDate,
  });

  final String firstName, lastName, fonction;
  final String? employeeNumber, employmentStatus, grade, echelon, gender;
  final String? birthPlace;
  final DateTime? dateOfBirth, hireDate, departureDate;

  String get fullName => '${lastName.toUpperCase()} $firstName'.trim();
  String get ne => gender == 'F' ? 'née' : 'né';
  String get employe => gender == 'F' ? 'employée' : 'employé';
  String get exerce => gender == 'F' ? 'a exercé' : 'a exercé';

  /// La qualité statutaire, quand elle est connue : fonctionnaire,
  /// contractuel, volontaire… Elle change ce que l'attestation vaut auprès
  /// d'une banque.
  String? get qualite => switch (employmentStatus) {
        'fonctionnaire' => 'fonctionnaire',
        'contractuel'   => 'agent contractuel',
        'volontaire'    => 'agent volontaire',
        'prestataire'   => 'prestataire',
        'stagiaire'     => 'stagiaire',
        'benevole'      => 'bénévole',
        _               => null,
      };
}

/// Une attestation de travail suppose un agent en service.
bool peutDelivrerAttestationTravail({required bool isActive}) => isActive;

class AttestationTravailPdfService {
  static Future<Uint8List> build({
    required AttestationAgent agent,
    required String schoolName,
    String? city,
    String? signataire,
    String? fonctionSignataire,
    bool serviceRendu = false,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();
    final maintenant = DateTime.now();

    final titre = serviceRendu
        ? 'Attestation de service rendu'
        : 'Attestation de travail';

    final corps = <pw.Widget>[
      AttestationKit.formuleSoussigne(f, signataire, fonctionSignataire, schoolName),
      pw.SizedBox(height: 14),
      AttestationKit.paragraphe(f, [
        AttestationKit.texte(f, 'que '),
        AttestationKit.fort(f, agent.fullName),
        ..._identite(f, agent),
        if (serviceRendu) ...[
          AttestationKit.texte(f, ' ${agent.exerce} les fonctions de '),
          AttestationKit.fort(f, agent.fonction),
          AttestationKit.texte(f, ' au sein de notre établissement'),
        ] else ...[
          AttestationKit.texte(f, ' est ${agent.employe} au sein de notre '
              'établissement en qualité de '),
          AttestationKit.fort(f, agent.fonction),
        ],
        ..._periode(f, agent, serviceRendu),
        AttestationKit.texte(f, '.'),
      ]),
      if (agent.grade != null || agent.echelon != null) ...[
        pw.SizedBox(height: 10),
        AttestationKit.paragraphe(f, [
          AttestationKit.texte(f, 'Grade : '),
          AttestationKit.fort(f, agent.grade ?? '—'),
          if (agent.echelon != null) ...[
            AttestationKit.texte(f, ' — échelon '),
            AttestationKit.fort(f, agent.echelon!),
          ],
          AttestationKit.texte(f, '.'),
        ]),
      ],
      pw.SizedBox(height: 16),
      AttestationKit.formuleFinale(f),
    ];

    return AttestationKit.build(
      titre: titre,
      kicker: 'ATTESTATION OFFICIELLE',
      badge: serviceRendu ? 'SERVICE\nRENDU' : 'ATTESTATION\nDE TRAVAIL',
      emetteur: schoolName,
      sousTitre: agent.qualite == null
          ? agent.fonction
          : '${agent.fonction} · ${agent.qualite}',
      fonts: f,
      logo: logo,
      corps: corps,
      city: city,
      quand: maintenant,
      signataire: signataire,
      fonction: fonctionSignataire,
    );
  }

  static List<pw.InlineSpan> _identite(PdfFonts f, AttestationAgent a) {
    final out = <pw.InlineSpan>[];
    if (a.dateOfBirth != null) {
      out
        ..add(AttestationKit.texte(f, ', ${a.ne} le '))
        ..add(AttestationKit.fort(f, AttestationKit.jourLong.format(a.dateOfBirth!)));
      if (a.birthPlace != null && a.birthPlace!.trim().isNotEmpty) {
        out
          ..add(AttestationKit.texte(f, ' à '))
          ..add(AttestationKit.fort(f, a.birthPlace!.trim()));
      }
    }
    if (a.employeeNumber != null && a.employeeNumber!.trim().isNotEmpty) {
      out
        ..add(AttestationKit.texte(f, ', matricule '))
        ..add(AttestationKit.fort(f, a.employeeNumber!.trim()));
    }
    if (a.qualite != null) {
      out.add(AttestationKit.texte(f, ', ${a.qualite}'));
    }
    return out;
  }

  /// La période servie. C'est elle qui fonde l'ancienneté — et la seule chose
  /// qu'une attestation retapée à la main finit toujours par fausser.
  static List<pw.InlineSpan> _periode(
      PdfFonts f, AttestationAgent a, bool serviceRendu) {
    final out = <pw.InlineSpan>[];
    if (a.hireDate != null) {
      out
        ..add(AttestationKit.texte(f, ' depuis le '))
        ..add(AttestationKit.fort(f, AttestationKit.jourLong.format(a.hireDate!)));
    }
    if (serviceRendu && a.departureDate != null) {
      out
        ..add(AttestationKit.texte(f, ' et jusqu’au '))
        ..add(AttestationKit.fort(
            f, AttestationKit.jourLong.format(a.departureDate!)));
    } else if (serviceRendu) {
      out.add(AttestationKit.texte(f, ' et jusqu’à son départ'));
    }
    return out;
  }
}
