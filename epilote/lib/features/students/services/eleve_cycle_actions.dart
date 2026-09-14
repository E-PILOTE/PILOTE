import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/write_identity.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cartes/providers/cartes_provider.dart' show CarteEleveRow;
import '../../cartes/services/cartes_actions.dart' show imprimerCarteEleve;
import '../../classes/providers/class_provider.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../structure/providers/academic_year_context.dart';
import '../providers/student_dossier_provider.dart';
import '../providers/students_provider.dart';
import '../providers/students_registry_provider.dart';
import '../providers/transfers_provider.dart';
import '../widgets/class_chooser_dialog.dart';
import '../widgets/sortie_eleve_dialog.dart';
import 'attestation_actions.dart';
import 'attestations_pdf_service.dart' show AttestationEleve;

// ════════════════════════════════════════════════════════════════════════════
//  LE CYCLE DE VIE D'UN ÉLÈVE — les sept gestes, enfin partageables
//
//  ── POURQUOI CE FICHIER EXISTE ─────────────────────────────────────────────
//  Ces gestes — délivrer un certificat, refaire une carte, changer de classe,
//  annuler une inscription, transférer, radier, désactiver — vivaient dans
//  `eleves_actions_parts.dart`, un `part of` de l'écran de la LISTE. Ils
//  n'étaient donc atteignables que depuis le tiroir de 460 pixels.
//
//  ⚠️ LA FICHE DE L'ÉLÈVE NE SAVAIT PAS AGIR. Elle porte onze registres —
//  parcours, résultats, assiduité, finances, actes — et n'avait que
//  « Modifier » et « Imprimer ». L'agent qui instruit un dossier y lit
//  précisément ce qui motive une sortie ou une réaffectation, et devait
//  refermer la fiche, retrouver l'élève dans la liste, rouvrir le tiroir. La
//  vue superficielle détenait tout le pouvoir, la vue profonde aucun.
//
//  Rien n'est réécrit ici : les gestes sont DÉPLACÉS, avec leurs gardes. Les
//  dupliquer côté fiche aurait produit deux vocabulaires de motifs de sortie
//  — donc des statistiques de déperdition qu'on ne sait plus additionner — et
//  deux endroits où corriger la prochaine règle.
//
//  ── CE QUI N'EST PAS ICI, ET POURQUOI ──────────────────────────────────────
//  ⚠️ Aucune de ces fonctions ne navigue. Elles renvoient un booléen qui dit
//  si l'élève a quitté la vue, et c'est l'APPELANT qui referme : le tiroir se
//  referme sur lui-même, la fiche revient à la liste. Un `Navigator.pop` caché
//  dans un service ferme la mauvaise chose dès qu'une deuxième vue l'appelle.
// ════════════════════════════════════════════════════════════════════════════

/// Ce qu'un geste du cycle de vie a besoin de savoir d'un élève.
///
/// ⚠️ Un objet EXPLICITE plutôt que la ligne de liste (`StudentRow`) : la
/// fiche ne lit pas le même registre que la liste, et lui faire fabriquer une
/// `StudentRow` incomplète produirait un certificat à la classe vide — un
/// papier faux, signé, remis à une famille.
class EleveCible {
  const EleveCible({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.matricule,
    this.ine,
    this.gender,
    this.dateOfBirth,
    this.placeOfBirth,
    this.photoUrl,
    this.className,
    this.enrollmentId,
    this.enrollmentStatus,
    this.isBoarder = false,
  });

  final String id, firstName, lastName, matricule;
  final String? ine, gender, placeOfBirth, photoUrl;
  final DateTime? dateOfBirth;
  final String? className, enrollmentId, enrollmentStatus;
  final bool isBoarder;

  String get fullName => '$firstName $lastName'.trim();

  /// Sans inscription, les gestes qui portent sur l'ANNÉE n'ont pas d'objet :
  /// on ne change pas la classe de quelqu'un qui n'en a pas.
  bool get aUneInscription => (enrollmentId ?? '').isNotEmpty;

  AttestationEleve versAttestation({String? lieuNaissance}) => AttestationEleve(
        firstName: firstName,
        lastName: lastName,
        className: className ?? '—',
        ine: ine,
        matricule: matricule,
        gender: gender,
        dateOfBirth: dateOfBirth,
        placeOfBirth: lieuNaissance ?? placeOfBirth,
      );
}

/// Dit non, et pourquoi. Un refus muet se lit comme un bouton cassé.
void refuserGeste(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: kRed));

/// Confirmation courte avant un geste qui retire l'élève de quelque chose.
Future<bool?> confirmerGeste(
  BuildContext context,
  String titre,
  String corps,
  String libelleOk,
  Color couleur,
) =>
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(titre),
        content: Text(corps),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Retour')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: couleur),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(libelleOk),
          ),
        ],
      ),
    );

// ─── Réaffectation ──────────────────────────────────────────────────────────

/// Change la classe de l'inscription courante. `true` si quelque chose a changé.
Future<bool> changerClasseEleve(
    BuildContext context, WidgetRef ref, EleveCible e) async {
  final classId = await choisirClasseEleve(context,
      titre: 'Changer de classe', sousTitre: e.fullName);
  if (classId == null || !context.mounted) return false;
  final done = await runModuleWrite(
    context,
    () => changeEnrollmentClass(
        enrollmentId: e.enrollmentId!, newClassId: classId),
    success: 'Élève réaffecté',
  );
  if (done) ref.invalidate(studentsRegistryProvider);
  return done;
}

/// Renvoie l'inscription au pipeline de validation.
/// `true` = l'élève a quitté l'effectif de cette vue (l'appelant referme).
Future<bool> annulerInscriptionEleve(
    BuildContext context, WidgetRef ref, EleveCible e) async {
  final ok = await confirmerGeste(
      context,
      'Annuler l\'inscription ?',
      '« ${e.fullName} » repartira dans la page Inscriptions (statut « en '
          'attente de validation »). Sa classe est conservée.',
      'Annuler l\'inscription',
      kAccent);
  if (ok != true || !context.mounted) return false;
  final done = await runModuleWrite(
    context,
    () => revertEnrollmentToValidation(e.enrollmentId!),
    success: 'Inscription renvoyée au pipeline',
  );
  if (done) ref.invalidate(studentsRegistryProvider);
  return done;
}

// ─── Sorties ────────────────────────────────────────────────────────────────

/// Transfert (`transferred`) ou radiation (`withdrawn`), motif obligatoire.
/// `true` = l'élève a quitté l'effectif (l'appelant referme).
Future<bool> sortirEleve(
  BuildContext context,
  WidgetRef ref,
  EleveCible e, {
  required String status,
}) async {
  final isTransfer = status == 'transferred';
  final res = await demanderMotifSortie(context,
      fullName: e.fullName, transfert: isTransfer);
  if (res == null || !context.mounted) return false;
  final profile = ref.read(authNotifierProvider).valueOrNull;

  // ⚠️ LA PROMESSE DU DIALOGUE SE VÉRIFIE AVANT, PAS APRÈS. Il annonce que
  // « le transfert est inscrit au registre » ; l'écriture était pourtant
  // conditionnée à un `group_id` et un `school_id` que l'appareil n'a pas
  // toujours. Sans eux, la ligne du registre était sautée EN SILENCE : l'élève
  // quittait l'effectif, le registre des transferts restait muet, et l'école
  // d'accueil n'avait aucune trace à opposer. On refuse la sortie entière
  // plutôt que d'en réussir la moitié.
  if (isTransfer && !isUsableId(profile?.groupId)) {
    refuserGeste(context, writeIdentityMessage(const ['groupe']));
    return false;
  }
  if (isTransfer && !isUsableId(profile?.schoolId)) {
    refuserGeste(context, writeIdentityMessage(const ['école']));
    return false;
  }

  final done = await runModuleWrite(
    context,
    () async {
      await setEnrollmentExit(
          enrollmentId: e.enrollmentId!,
          status: status,
          motif: res.motif,
          reason: res.reason);
      // Réconciliation : un transfert alimente le registre des Transferts
      // (statut « terminé », l'élève étant déjà sorti). Les identifiants ont
      // été vérifiés avant d'ouvrir l'écriture : ce qui reste ici, c'est le cas
      // légitime d'une RADIATION, qui n'alimente pas ce registre.
      if (isTransfer && res.toSchoolName != null) {
        await createTransfer(
          groupId: profile!.groupId!,
          fromSchoolId: profile.schoolId!,
          studentId: e.id,
          toSchoolName: res.toSchoolName!,
          toSchoolId: res.toSchoolId,
          transferDate: DateTime.now(),
          reason: res.reason,
          academicYearId: ref.read(activeYearIdProvider),
          initialStatus: 'completed',
          approvedBy: profile.id,
        );
      }
    },
    success: isTransfer ? 'Élève transféré' : 'Élève radié',
  );
  if (!done) return false;
  ref.invalidate(studentsRegistryProvider);

  // Le papier au moment où la famille est encore au guichet. La chercher plus
  // tard dans un registre où elle ne figure plus est bien plus coûteux.
  if (context.mounted) {
    await delivrerCertificatRadiation(
      context,
      ref,
      eleve: e.versAttestation(),
      enrollmentStatus: status,
      studentId: e.id,
      motif: res.motif,
      dateSortie: DateTime.now(),
      observations: res.reason,
    );
  }
  return true;
}

/// Retire l'élève du registre actif. `true` = l'appelant referme.
Future<bool> desactiverEleve(
    BuildContext context, WidgetRef ref, EleveCible e) async {
  final ok = await confirmerGeste(
      context,
      'Désactiver cet élève ?',
      '« ${e.fullName} » sera retiré du registre actif. Son dossier et son '
          'historique sont conservés.',
      'Désactiver',
      kRed);
  if (ok != true || !context.mounted) return false;
  final done = await runModuleWrite(context, () => deactivateStudent(e.id),
      success: 'Élève désactivé');
  if (done) ref.invalidate(studentsRegistryProvider);
  return done;
}

// ─── Les papiers ────────────────────────────────────────────────────────────

/// Le papier que le secrétariat délivre tous les jours — bourse, transport,
/// allocation, visa. Il se tapait à la machine, donc il se recopiait faux.
Future<void> certificatScolariteEleve(
    BuildContext context, WidgetRef ref, EleveCible e) async {
  // Le lieu de naissance ne vit pas dans la ligne de liste : il se relit au
  // dossier. Un certificat sans lieu de naissance se fait refuser au guichet.
  final lieu = e.placeOfBirth ??
      (await ref.read(studentDossierProvider(e.id).future)).s('place_of_birth');
  if (!context.mounted) return;
  await delivrerCertificatScolarite(
    context,
    ref,
    eleve: e.versAttestation(lieuNaissance: lieu.isEmpty ? null : lieu),
    enrollmentStatus: e.enrollmentStatus,
    studentId: e.id,
  );
}

/// La carte que l'élève PORTE — duplicata au guichet. Elle se recompose depuis
/// le dossier : réimprimée après un changement de classe, elle porte la
/// nouvelle, ce qu'une carte stockée ne saurait pas faire.
Future<void> carteScolaireEleve(
    BuildContext context, WidgetRef ref, EleveCible e) async {
  await imprimerCarteEleve(
    context,
    ref,
    eleve: CarteEleveRow(
      studentId: e.id,
      firstName: e.firstName,
      lastName: e.lastName,
      matricule: e.matricule,
      className: e.className ?? '—',
      status: e.enrollmentStatus ?? '',
      ine: e.ine,
      gender: e.gender,
      dateOfBirth: e.dateOfBirth,
      placeOfBirth: e.placeOfBirth,
      isBoarder: e.isBoarder,
      photoUrl: e.photoUrl,
    ),
  );
}
