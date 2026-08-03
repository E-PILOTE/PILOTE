// ══════════════════════════════════════════════════════════════════════════════
//  LES PAPIERS QUE L'ÉCOLE DÉLIVRE
//
//  Le module « Documents » suit les pièces que l'école REÇOIT — acte de
//  naissance, photo, certificat médical. Rien ne lui permettait d'ÉMETTRE.
//  Or un secrétariat passe ses journées à cela : une famille vient chercher un
//  certificat de scolarité pour une bourse, un transport, une allocation, un
//  visa. Sans la plateforme, il se tape à la machine — et se recopie faux.
//
//  ── DEUX PAPIERS, DEUX VÉRITÉS OPPOSÉES ────────────────────────────────────
//  Le CERTIFICAT DE SCOLARITÉ atteste que l'élève EST inscrit. Le délivrer pour
//  un élève sorti serait un faux — d'où `peutDelivrerScolarite`.
//
//  Le CERTIFICAT DE RADIATION atteste qu'il ne l'est PLUS, et pourquoi. C'est
//  le papier sans lequel l'école d'accueil ne peut pas l'inscrire. Le délivrer
//  pour un élève encore présent serait un faux symétrique — d'où
//  `peutDelivrerRadiation`.
//
//  Les deux portent l'IDENTIFIANT NATIONAL. C'est même la raison d'être de la
//  radiation : c'est par lui que l'école d'accueil retrouvera sa scolarité au
//  lieu d'en ouvrir une neuve.
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/attestation_kit.dart';
import '../../../core/services/official_pdf_kit.dart';
import '../../../core/utils/ine.dart';
import '../../../core/utils/sortie_motif.dart';

/// L'élève tel qu'il apparaît sur un papier officiel.
class AttestationEleve {
  const AttestationEleve({
    required this.firstName,
    required this.lastName,
    required this.className,
    this.ine,
    this.matricule,
    this.gender,
    this.dateOfBirth,
    this.placeOfBirth,
  });

  final String firstName, lastName, className;
  final String? ine, matricule, gender, placeOfBirth;
  final DateTime? dateOfBirth;

  String get fullName => '${lastName.toUpperCase()} $firstName'.trim();

  /// « né » ou « née ». Un certificat qui se trompe de genre se fait refuser
  /// au guichet — c'est le genre de détail qui décide de sa valeur.
  String get ne => gender == 'F' ? 'née' : 'né';
  String get eleve => gender == 'F' ? 'l\'élève' : 'l\'élève';
  String get inscrit => gender == 'F' ? 'inscrite' : 'inscrit';
  String get radie => gender == 'F' ? 'radiée' : 'radié';
}

/// Statuts d'inscription pour lesquels un certificat de scolarité est vrai.
bool peutDelivrerScolarite(String? enrollmentStatus) =>
    enrollmentStatus == 'active';

/// Statuts pour lesquels un certificat de radiation est vrai.
bool peutDelivrerRadiation(String? enrollmentStatus) =>
    enrollmentStatus == 'withdrawn' ||
    enrollmentStatus == 'transferred' ||
    enrollmentStatus == 'graduated';

class AttestationsPdfService {
  // ── Certificat de scolarité ────────────────────────────────────────────────
  static Future<Uint8List> certificatScolarite({
    required AttestationEleve eleve,
    required String schoolName,
    required String yearLabel,
    String? city,
    String? signataire,
    String? fonction,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();
    final maintenant = DateTime.now();

    final corps = <pw.Widget>[
      AttestationKit.formuleSoussigne(f, signataire, fonction, schoolName),
      pw.SizedBox(height: 14),
      AttestationKit.paragraphe(f, [
        AttestationKit.texte(f, 'que '),
        AttestationKit.fort(f, eleve.fullName),
        ..._identite(f, eleve),
        AttestationKit.texte(f, ' est régulièrement '),
        AttestationKit.fort(f, eleve.inscrit),
        AttestationKit.texte(f, ' dans notre établissement, en classe de '),
        AttestationKit.fort(f, eleve.className),
        AttestationKit.texte(f, ', au titre de l’année scolaire '),
        AttestationKit.fort(f, yearLabel),
        AttestationKit.texte(f, '.'),
      ]),
      pw.SizedBox(height: 16),
      AttestationKit.formuleFinale(f),
    ];

    return AttestationKit.build(
      titre: 'Certificat de scolarité',
      kicker: 'ATTESTATION OFFICIELLE',
      badge: 'CERTIFICAT\nDE SCOLARITÉ',
      emetteur: schoolName,
      sousTitre: 'Année scolaire $yearLabel',
      fonts: f,
      logo: logo,
      corps: corps,
      city: city,
      quand: maintenant,
      signataire: signataire,
      fonction: fonction,
    );
  }

  // ── Certificat de radiation (exeat) ────────────────────────────────────────
  static Future<Uint8List> certificatRadiation({
    required AttestationEleve eleve,
    required String schoolName,
    required String yearLabel,
    required String? motif,
    DateTime? dateSortie,
    String? observations,
    String? city,
    String? signataire,
    String? fonction,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();
    final maintenant = DateTime.now();

    final corps = <pw.Widget>[
      AttestationKit.formuleSoussigne(f, signataire, fonction, schoolName),
      pw.SizedBox(height: 14),
      AttestationKit.paragraphe(f, [
        AttestationKit.texte(f, 'que '),
        AttestationKit.fort(f, eleve.fullName),
        ..._identite(f, eleve),
        AttestationKit.texte(f, ', inscrit${eleve.gender == 'F' ? 'e' : ''} en classe de '),
        AttestationKit.fort(f, eleve.className),
        AttestationKit.texte(f, ' au titre de l’année scolaire '),
        AttestationKit.fort(f, yearLabel),
        AttestationKit.texte(f, ', a été '),
        AttestationKit.fort(f, eleve.radie),
        AttestationKit.texte(f, ' des effectifs de notre établissement'),
        if (dateSortie != null) ...[
          AttestationKit.texte(f, ' le '),
          AttestationKit.fort(f, AttestationKit.jourCourt.format(dateSortie)),
        ],
        AttestationKit.texte(f, '.'),
      ]),
      if (motif != null) ...[
        pw.SizedBox(height: 10),
        AttestationKit.paragraphe(f, [
          AttestationKit.texte(f, 'Motif : '),
          AttestationKit.fort(f, sortieMotifLabel(motif)),
          AttestationKit.texte(f, '.'),
        ]),
      ],
      if (observations != null && observations.trim().isNotEmpty) ...[
        pw.SizedBox(height: 10),
        AttestationKit.paragraphe(f, [AttestationKit.texte(f, 'Observations : ${observations.trim()}')]),
      ],
      pw.SizedBox(height: 16),
      // La phrase qui rend ce papier utile à celui qui le reçoit.
      OfficialPdfKit.frame(
        title: 'À L’ATTENTION DE L’ÉTABLISSEMENT D’ACCUEIL',
        color: kPdfGreen,
        fonts: f,
        child: pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: kPdfSurface,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: kPdfBorder),
          ),
          child: pw.Text(
            eleve.ine == null
                ? 'Aucun identifiant national n’a encore été attribué à cet '
                    'élève. Rapprochez-vous de l’établissement d’origine '
                    'avant de créer un nouveau dossier : une seconde inscription '
                    'romprait la continuité de sa scolarité.'
                : 'Identifiant national : ${formatIne(eleve.ine)}. '
                    'Recherchez-le avec cet identifiant avant toute nouvelle '
                    'inscription : sa scolarité antérieure doit être reprise, '
                    'et non recommencée.',
            style: pw.TextStyle(
                font: f.regular, fontSize: 9.5, color: kPdfText, lineSpacing: 2),
          ),
        ),
      ),
      pw.SizedBox(height: 14),
      AttestationKit.formuleFinale(f),
    ];

    return AttestationKit.build(
      titre: 'Certificat de radiation',
      kicker: 'ATTESTATION OFFICIELLE',
      badge: 'CERTIFICAT\nDE RADIATION',
      emetteur: schoolName,
      sousTitre: 'Année scolaire $yearLabel',
      fonts: f,
      logo: logo,
      corps: corps,
      city: city,
      quand: maintenant,
      signataire: signataire,
      fonction: fonction,
    );
  }

  /// La ligne d'identité : naissance, identifiant national, matricule.
  static List<pw.InlineSpan> _identite(PdfFonts f, AttestationEleve e) {
    final out = <pw.InlineSpan>[];
    if (e.dateOfBirth != null) {
      out
        ..add(AttestationKit.texte(f, ', ${e.ne} le '))
        ..add(AttestationKit.fort(f, AttestationKit.jourLong.format(e.dateOfBirth!)));
      if (e.placeOfBirth != null && e.placeOfBirth!.trim().isNotEmpty) {
        out
          ..add(AttestationKit.texte(f, ' à '))
          ..add(AttestationKit.fort(f, e.placeOfBirth!.trim()));
      }
    }
    // L'identifiant national d'abord : c'est le seul des deux qui suive
    // l'enfant hors de cette école.
    if (e.ine != null) {
      out
        ..add(AttestationKit.texte(f, ', identifiant national '))
        ..add(AttestationKit.fort(f, formatIne(e.ine)));
    } else if (e.matricule != null && e.matricule!.trim().isNotEmpty) {
      out
        ..add(AttestationKit.texte(f, ', matricule '))
        ..add(AttestationKit.fort(f, e.matricule!.trim()));
    }
    return out;
  }
}
