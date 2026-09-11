import 'dart:typed_data';

import 'package:intl/intl.dart';

import '../../../core/services/docx_kit.dart';
import '../../../core/utils/safe_file_name.dart';
import '../providers/tutelle_destinataires_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  L'INSTRUCTION DE TUTELLE, EN VERSION MODIFIABLE
//
//  ── POURQUOI CETTE PIÈCE-LÀ, PLUS QU'AUCUNE AUTRE ──────────────────────────
//  Une instruction de tutelle est un ACTE ADMINISTRATIF, et son corps est du
//  TEXTE LIBRE : il est écrit à la main, phrase par phrase, par un agent du
//  ministère. C'est donc la pièce de toute l'application où la retouche avant
//  signature est la règle et non l'exception — un visa hiérarchique se relit,
//  un considérant se reformule, un délai se précise.
//
//  ⚠️ Le PDF reste la pièce de référence : c'est lui qui est ARCHIVÉ et
//  opposable, et il porte la date d'ENVOI, pas celle de l'impression. La
//  version Word sert à préparer ou à amender — jamais à remplacer l'archive.
//  La mention de bas de document le dit, plutôt que de le laisser supposer.
//
//  ── LE BORDEREAU N'EST PAS UN ACCUSÉ DE RÉCEPTION ──────────────────────────
//  ⚠️ La liste des destinataires atteste de ce qui a été ADRESSÉ, jamais de ce
//  qui a été lu : la plateforme n'a aucun moyen d'établir la seconde chose.
//  Le document reprend cette réserve telle quelle du PDF — l'affaiblir dans la
//  version modifiable reviendrait à laisser écrire, par omission, une preuve
//  qui n'existe pas.
// ════════════════════════════════════════════════════════════════════════════

String _dateLongue(DateTime d) => DateFormat('d MMMM yyyy', 'fr').format(d);

class TutelleInstructionDocxService {
  /// Compose l'instruction en document Word modifiable.
  ///
  /// [emiseLe] est passée par l'appelant, comme pour le PDF : le document doit
  /// porter l'heure de l'ENVOI, pas celle de l'export. Un ministère qui
  /// réédite sa pièce trois mois plus tard doit retrouver la même date.
  static Uint8List build({
    required String objet,
    required String corps,
    required String groupeNom,
    required List<DestinataireTutelle> destinataires,
    required DateTime emiseLe,
    String? tutelle,
    String? signataire,
  }) {
    // Le groupe d'abord, les établissements ensuite : c'est l'ordre
    // hiérarchique de l'adresse, et celui dans lequel une administration lit
    // un bordereau.
    final auGroupe = [for (final d in destinataires) if (d.estLeGroupe) d];
    final auxEcoles = [for (final d in destinataires) if (!d.estLeGroupe) d];

    final d = DocxBuilder(
      titre: 'INSTRUCTION',
      etablissement: [
        'RÉPUBLIQUE DU CONGO',
        if ((tutelle ?? '').trim().isNotEmpty) tutelle!.trim(),
      ].join('\n'),
      sousTitre: 'Émise le ${_dateLongue(emiseLe)}',
    )
      ..saut()
      ..champ('Objet', objet)
      ..champ('Réseau destinataire', groupeNom)
      ..saut()
      ..section('Texte de l\'instruction')
      // Le corps est du texte libre : il traverse tel quel, retours à la ligne
      // compris. C'est précisément ce que l'auteur vient amender.
      ..paragraphe(corps.trim());

    d
      ..section('Bordereau de diffusion')
      ..tableau(
        entetes: const ['Destinataire', 'Qualité', 'Établissement'],
        lignes: [
          for (final x in [...auGroupe, ...auxEcoles])
            [
              (x.nom ?? '').trim().isEmpty ? '—' : x.nom!.trim(),
              x.fonction,
              x.estLeGroupe ? 'Administration du réseau' : (x.ecole ?? '—'),
            ],
        ],
        siVide: 'Aucun destinataire enregistré pour cette instruction.',
      )
      ..signature(
        (signataire ?? '').trim().isEmpty
            ? 'Pour la tutelle,'
            : 'Pour la tutelle,\n${signataire!.trim()}',
      )
      // ⚠️ Les deux réserves du PDF, reprises mot pour mot. Les alléger dans
      // une version qu'on peut modifier reviendrait à laisser fabriquer, par
      // omission, une preuve de réception qui n'existe pas.
      ..mention(
        'Le présent bordereau atteste de ce qui a été ADRESSÉ, et non de ce '
        'qui a été lu : la plateforme n\'établit pas la réception.',
      )
      ..mention(
        'Version modifiable produite le '
        '${_dateLongue(DateTime.now())}. La pièce de référence, archivée et '
        'opposable, reste le document PDF émis le ${_dateLongue(emiseLe)}.',
      );

    return d.construire();
  }

  static Future<String?> enregistrer({
    required Uint8List octets,
    required String objet,
  }) =>
      enregistrerDocxSous(
        nomPropose:
            safeFileName('Instruction_$objet.docx', fallback: 'instruction'),
        octets: octets,
        titreFenetre: 'Enregistrer la version modifiable',
      );
}
