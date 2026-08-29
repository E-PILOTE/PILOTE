// ══════════════════════════════════════════════════════════════════════════════
//  NOTER UN DOCUMENT DÉLIVRÉ — le geste qui manquait
//
//  Un certificat de scolarité, une carte scolaire, une attestation de travail
//  engagent l'établissement. Jusqu'ici, les délivrer n'écrivait RIEN : ni la
//  base, ni `audit_logs` — qui journalise les modifications de lignes, or
//  délivrer un papier n'en modifie aucune. Le geste le plus quotidien du
//  secrétariat était donc le seul totalement invisible.
//
//  ── TROIS RÈGLES, ET ELLES DÉCOULENT TOUTES DE LA MÊME ────────────────────
//  « Un journal ne doit jamais coûter la donnée qu'il observe » (migration
//  0144). Ici, la donnée observée est le document lui-même.
//
//   1. **CETTE FONCTION NE LÈVE JAMAIS.** Si noter échoue, le document sort
//      quand même. Une famille au guichet n'a pas à repartir sans son
//      certificat parce que le registre a hoqueté.
//
//   2. **ELLE N'ÉCRIT RIEN D'INVALIDE.** Sans `group_id` / `school_id` / agent,
//      on s'abstient. Une chaîne vide dans une colonne `uuid` remonterait en
//      22P02 — code FATAL pour le connecteur, qui jetterait le LOT ENTIER en
//      attente sur le poste. Le registre coûterait alors les inscriptions du
//      matin. Voir `core/utils/write_identity.dart`.
//      (Le cas ne se produit que sur un profil déjà cassé, qui ne peut de toute
//      façon rien écrire d'autre — 20 comptes sur 67 étaient dans cet état en
//      juillet.)
//
//   3. **JAMAIS D'IDENTIFIANT DÉTERMINISTE.** Deux certificats délivrés le même
//      jour au même élève sont DEUX actes — un duplicata demandé le lendemain
//      d'une perte est précisément ce que le registre doit montrer. Les
//      confondre effacerait le fait. C'est la règle de
//      `core/utils/identite_offline.dart`, du côté « ce qui peut légitimement
//      exister en plusieurs exemplaires ».
//
//  ── L'AGENT NOTÉ EST CELUI AU CLAVIER ─────────────────────────────────────
//  Sur un poste partagé, `activeAgentIdProvider` désigne l'agent réellement
//  devant l'écran, pas le compte qui a ouvert la session de l'appareil. Noter
//  le second rendrait le registre inutile — et injuste.
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/write_identity.dart';
import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/active_agent_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../structure/providers/academic_year_context.dart';

const _uuid = Uuid();

/// Les papiers que l'établissement émet. Codes métier en français, comme les
/// autres énumérations du domaine (`non_reinscrit`, `exclusion_definitive`).
class TypeDocument {
  static const certificatScolarite = 'certificat_scolarite';
  static const certificatRadiation = 'certificat_radiation';
  static const carteScolaire = 'carte_scolaire';
  static const attestationTravail = 'attestation_travail';

  static const tous = [
    certificatScolarite,
    certificatRadiation,
    carteScolaire,
    attestationTravail,
  ];
}

String libelleTypeDocument(String code) => switch (code) {
      TypeDocument.certificatScolarite => 'Certificat de scolarité',
      TypeDocument.certificatRadiation => 'Certificat de radiation',
      TypeDocument.carteScolaire => 'Carte scolaire',
      TypeDocument.attestationTravail => 'Attestation de travail',
      // Un code inconnu s'affiche tel quel plutôt que « Autre » : le jour où un
      // type est ajouté sans passer ici, le registre reste lisible.
      _ => code,
    };

/// Inscrit un document au registre. Ne lève jamais, n'écrit jamais d'invalide.
///
/// [recipientRef] fige le contexte au jour de l'émission (classe, matricule) :
/// un élève qui change de classe ne doit pas réécrire le passé du registre.
Future<void> noterDocumentEmis(
  WidgetRef ref, {
  required String documentType,
  required String recipientName,
  String? studentId,
  String? staffProfileId,
  String? recipientRef,
  String? purpose,
}) async {
  try {
    final profil = ref.read(authNotifierProvider).valueOrNull;
    final identite = buildWriteIdentity(
      groupId: profil?.groupId,
      schoolId: profil?.schoolId,
      actorId: ref.read(activeAgentIdProvider),
    );
    // Règle 2 : on s'abstient plutôt que d'écrire un identifiant vide.
    if (identite == null) return;
    if (recipientName.trim().isEmpty) return;

    final nomAgent = await _nomAgent(identite.actorId);

    await db.execute(
      '''
      INSERT INTO issued_documents (
        id, group_id, school_id, academic_year_id, document_type,
        student_id, staff_profile_id, recipient_name, recipient_ref,
        issued_by, issued_by_name, issued_at, purpose, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        _uuid.v4(),
        identite.groupId,
        identite.schoolId,
        ref.read(activeYearIdProvider),
        documentType,
        studentId,
        staffProfileId,
        recipientName.trim(),
        recipientRef,
        identite.actorId,
        nomAgent,
        DateTime.now().toUtc().toIso8601String(),
        purpose,
        DateTime.now().toUtc().toIso8601String(),
      ],
    );
  } catch (_) {
    // Règle 1 : le document passe avant son enregistrement.
  }
}

/// Le nom de l'agent, figé dans la ligne. `profiles` n'a pas de colonne
/// `email` : on ne dispose que du prénom et du nom, et cela suffit — le
/// registre nomme un agent, il ne l'authentifie pas.
Future<String?> _nomAgent(String id) async {
  try {
    final r = await db.getOptional(
      'SELECT first_name, last_name FROM profiles WHERE id = ? LIMIT 1',
      [id],
    );
    if (r == null) return null;
    final n = '${r['first_name'] ?? ''} ${r['last_name'] ?? ''}'.trim();
    return n.isEmpty ? null : n;
  } catch (_) {
    return null;
  }
}
