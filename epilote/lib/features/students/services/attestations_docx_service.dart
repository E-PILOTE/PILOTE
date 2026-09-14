import 'dart:typed_data';

import 'package:intl/intl.dart';

import '../../../core/services/docx_kit.dart';
import '../../../core/utils/ine.dart';
import '../../../core/utils/safe_file_name.dart';
import '../../../core/utils/sortie_motif.dart';
import 'attestations_pdf_service.dart' show AttestationEleve;

// ════════════════════════════════════════════════════════════════════════════
//  LES ATTESTATIONS, EN VERSION MODIFIABLE
//
//  ── POURQUOI CES DEUX PIÈCES-LÀ, ET PAS LES LISTES ─────────────────────────
//  Un certificat n'est pas un état : c'est une lettre. Le motif d'une
//  radiation se formule, une mention se précise « pour servir et valoir ce que
//  de droit auprès de … », une école ajoute une ligne que la loi locale exige.
//  Le PDF fige tout cela ; l'agent qui a besoin d'un mot de plus n'a alors que
//  deux issues : raturer à la main, ou retaper la pièce entière dans Word à
//  partir de rien — ce qu'il faisait AVANT la plateforme, et ce qui se recopie
//  faux.
//
//  ⚠️ Les LISTES ne suivent pas. Un effectif de trois cents élèves en Word se
//  repagine chez le lecteur, les colonnes bougent, et deux impressions du même
//  fichier ne donnent pas le même document. Le PDF reste la forme de tout ce
//  qui doit rester STABLE.
//
//  ── LES DEUX PIÈCES DISENT DES VÉRITÉS OPPOSÉES ────────────────────────────
//  ⚠️ Le certificat de SCOLARITÉ atteste que l'élève EST inscrit ; celui de
//  RADIATION qu'il ne l'est PLUS. Les gardes qui empêchent de délivrer l'un
//  pour l'autre (`peutDelivrerScolarite`, `peutDelivrerRadiation`) vivent
//  côté PDF et s'appliquent AVANT d'arriver ici : ce fichier ne compose que
//  ce qu'on l'a autorisé à composer, il ne décide de rien.
//
//  ── CE QUI NE S'ENLÈVE PAS DU TEXTE ────────────────────────────────────────
//  ⚠️ L'IDENTIFIANT NATIONAL. C'est la raison d'être de la radiation : c'est
//  par lui que l'école d'accueil retrouve la scolarité de l'enfant au lieu
//  d'en ouvrir une neuve. Il figure donc dans le corps du texte, pas dans un
//  coin de page où une retouche le ferait disparaître.
// ════════════════════════════════════════════════════════════════════════════

String _dateLongue(DateTime? d) =>
    d == null ? '……………………' : DateFormat('d MMMM yyyy', 'fr').format(d);

/// L'en-tête commun aux deux pièces — établissement, République, titre.
DocxBuilder _socle({
  required String titre,
  required String? schoolName,
  required String? yearLabel,
}) {
  final d = DocxBuilder(
    titre: titre,
    etablissement: (schoolName ?? '').trim().isEmpty
        ? 'RÉPUBLIQUE DU CONGO'
        : 'RÉPUBLIQUE DU CONGO\n${schoolName!.trim()}',
    sousTitre: (yearLabel ?? '').trim().isEmpty
        ? null
        : 'Année scolaire ${yearLabel!.trim()}',
  )..saut();
  return d;
}

/// La formule de clôture et la place pour signer.
void _clore(
  DocxBuilder d, {
  required String? city,
  required String? signataire,
  required String? fonction,
}) {
  d
    ..saut()
    ..paragraphe(
      'En foi de quoi la présente attestation lui est délivrée pour servir '
      'et valoir ce que de droit.',
    )
    // ⚠️ Le signataire n'est écrit que s'il a QUALITÉ. Un secrétaire imprime
    // le document, il ne le signe pas : mieux vaut une ligne à remplir qu'un
    // nom qui n'engage personne — même règle que côté PDF.
    ..signature(
      [
        if ((fonction ?? '').trim().isNotEmpty) fonction!.trim(),
        if ((signataire ?? '').trim().isNotEmpty) signataire!.trim(),
      ].join('\n'),
      lieu: (city ?? '').trim().isEmpty ? null : city!.trim(),
    )
    ..mention(
      'Document produit par E-PILOTE CONGO et laissé modifiable à la demande '
      'de l\'établissement. Toute modification engage son signataire.',
    );
}

class AttestationsDocxService {
  /// Certificat de scolarité — atteste que l'élève EST inscrit.
  static Uint8List certificatScolarite({
    required AttestationEleve eleve,
    String? schoolName,
    String? yearLabel,
    String? city,
    String? signataire,
    String? fonction,
  }) {
    final d = _socle(
      titre: 'CERTIFICAT DE SCOLARITÉ',
      schoolName: schoolName,
      yearLabel: yearLabel,
    )
      ..paragraphe(
        'Je soussigné(e), ${(signataire ?? '').trim().isEmpty ? '……………………………' : signataire!.trim()}, '
        '${(fonction ?? 'responsable de l\'établissement').trim()}, '
        'certifie que :',
      )
      ..saut()
      ..champ('Nom et prénom(s)', eleve.fullName)
      ..champ(
        'Né${eleve.gender == 'F' ? 'e' : ''} le',
        '${_dateLongue(eleve.dateOfBirth)}'
        '${(eleve.placeOfBirth ?? '').trim().isEmpty ? '' : ' à ${eleve.placeOfBirth!.trim()}'}',
      )
      ..champ('Matricule', eleve.matricule)
      ..champ(
        'Identifiant national (INE)',
        eleve.ine == null ? kIneEnAttente : formatIne(eleve.ine),
      )
      ..saut()
      ..paragraphe(
        'est régulièrement ${eleve.inscrit} dans notre établissement en classe '
        'de ${eleve.className}'
        '${(yearLabel ?? '').trim().isEmpty ? '' : ' au titre de l\'année scolaire ${yearLabel!.trim()}'}.',
      );
    _clore(d, city: city, signataire: signataire, fonction: fonction);
    return d.construire();
  }

  /// Certificat de radiation (exeat) — atteste qu'il ne l'est PLUS, et pourquoi.
  static Uint8List certificatRadiation({
    required AttestationEleve eleve,
    String? motif,
    DateTime? dateSortie,
    String? observations,
    String? schoolName,
    String? yearLabel,
    String? city,
    String? signataire,
    String? fonction,
  }) {
    final d = _socle(
      titre: 'CERTIFICAT DE RADIATION',
      schoolName: schoolName,
      yearLabel: yearLabel,
    )
      ..paragraphe(
        'Je soussigné(e), ${(signataire ?? '').trim().isEmpty ? '……………………………' : signataire!.trim()}, '
        '${(fonction ?? 'responsable de l\'établissement').trim()}, '
        'certifie que :',
      )
      ..saut()
      ..champ('Nom et prénom(s)', eleve.fullName)
      ..champ(
        'Né${eleve.gender == 'F' ? 'e' : ''} le',
        '${_dateLongue(eleve.dateOfBirth)}'
        '${(eleve.placeOfBirth ?? '').trim().isEmpty ? '' : ' à ${eleve.placeOfBirth!.trim()}'}',
      )
      ..champ('Matricule', eleve.matricule)
      // ⚠️ L'INE est LA raison d'être de cette pièce : c'est par lui que
      // l'école d'accueil reprend la scolarité au lieu d'en ouvrir une neuve.
      ..champ(
        'Identifiant national (INE)',
        eleve.ine == null ? kIneEnAttente : formatIne(eleve.ine),
      )
      ..saut()
      ..paragraphe(
        'a été ${eleve.radie} des effectifs de notre établissement, où '
        '${eleve.gender == 'F' ? 'elle' : 'il'} était ${eleve.inscrit} en '
        'classe de ${eleve.className}, à compter du '
        '${_dateLongue(dateSortie)}.',
      )
      ..champ('Motif', sortieMotifLabel(motif));

    if ((observations ?? '').trim().isNotEmpty) {
      d
        ..saut()
        ..section('Observations')
        ..paragraphe(observations!.trim());
    }

    _clore(d, city: city, signataire: signataire, fonction: fonction);
    return d.construire();
  }

  /// Ouvre « Enregistrer sous » pour la version Word d'une pièce déjà composée.
  static Future<String?> enregistrer({
    required Uint8List octets,
    required String base,
    required AttestationEleve eleve,
  }) =>
      enregistrerDocxSous(
        nomPropose: safeFileName(
          '${base}_${eleve.lastName}_${eleve.firstName}.docx',
          fallback: 'attestation',
        ),
        octets: octets,
        titreFenetre: 'Enregistrer la version modifiable',
      );
}
