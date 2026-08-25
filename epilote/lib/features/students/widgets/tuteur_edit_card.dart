import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import '../models/tutor_draft.dart';
import '../providers/student_dossier_provider.dart';
import '../services/edition_eleve_garde.dart';
import 'inscription_form_kit.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA FICHE TUTEUR EN COURS DE MODIFICATION — et le sélecteur de photo.
//
//  ── POURQUOI CE FICHIER EXISTE ─────────────────────────────────────────────
//  Ces deux widgets étaient écrits DEUX FOIS, à la ligne près : une copie dans
//  l'éditeur du guichet (`inscriptions_edit_parts.dart`), une autre dans celui
//  du registre (`eleves_edit.dart`). Le brouillon qui les alimente l'était lui
//  aussi.
//
//  Ce n'est pas une question d'élégance. La copie du guichet a été corrigée le
//  jour où l'on a compris qu'on pouvait décocher le seul contact principal d'un
//  élève ; celle du registre ne l'a pas été, et c'est précisément là que le
//  secrétariat modifie les tuteurs tous les jours. Le défaut a donc survécu à
//  sa propre correction, dans l'écran qui sert le plus.
//
//  Une seule fiche, désormais : la prochaine correction ne pourra plus rater la
//  moitié de l'application.
// ════════════════════════════════════════════════════════════════════════════

/// Une fiche de tuteur en cours de saisie, avec ses contrôleurs de texte.
///
/// À ne pas confondre avec [TutorDraft] (`models/tutor_draft.dart`), qui décrit
/// la même fiche SANS widget — c'est lui qui porte les règles de validation, et
/// c'est volontaire : une règle enfouie dans un contrôleur ne se teste pas.
class TuteurBrouillon {
  TuteurBrouillon({
    this.id,
    String firstName = '',
    String lastName = '',
    this.relationship = 'mere',
    String phone = '',
    String email = '',
    String profession = '',
    String address = '',
    this.isPrimary = false,
    this.isEmergency = false,
  })  : firstName = TextEditingController(text: firstName),
        lastName = TextEditingController(text: lastName),
        phone = TextEditingController(text: phone),
        email = TextEditingController(text: email),
        profession = TextEditingController(text: profession),
        address = TextEditingController(text: address);

  factory TuteurBrouillon.fromInfo(StudentTutorInfo t) => TuteurBrouillon(
        id: t.id,
        firstName: t.firstName,
        lastName: t.lastName,
        relationship:
            const {'pere', 'mere', 'tuteur', 'autre'}.contains(t.relationship)
                ? t.relationship
                : 'autre',
        phone: t.phonePrimary ?? '',
        email: t.email ?? '',
        profession: t.profession ?? '',
        address: t.address ?? '',
        isPrimary: t.isPrimary,
        isEmergency: t.isEmergency,
      );

  /// `null` = fiche NEUVE, à créer. Sinon, l'identifiant de la ligne en base.
  final String? id;
  final TextEditingController firstName, lastName, phone, email, profession,
      address;
  String relationship;
  bool isPrimary, isEmergency;

  /// La fiche telle que la garde d'écriture a besoin de la voir.
  TuteurSaisi get saisi => (
        id: id,
        prenom: firstName.text,
        nom: lastName.text,
        tel: phone.text,
      );

  void dispose() {
    firstName.dispose();
    lastName.dispose();
    phone.dispose();
    email.dispose();
    profession.dispose();
    address.dispose();
  }
}

/// Carte d'édition d'une fiche tuteur.
class TuteurEditCard extends StatelessWidget {
  const TuteurEditCard({
    super.key,
    required this.draft,
    required this.index,
    required this.onChanged,
    required this.onRemove,
    required this.onPromote,
  });

  final TuteurBrouillon draft;
  final int index;
  final VoidCallback onChanged, onRemove;

  /// Désigne CETTE fiche comme contact principal et retire le titre aux autres.
  /// La bascule appartient à la liste : une carte ne voit pas ses voisines.
  final VoidCallback onPromote;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: draft.isPrimary ? kNavy.withValues(alpha: 0.3) : kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(draft.isPrimary ? 'Tuteur principal' : 'Contact ${index + 1}',
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 14, color: kNavy)),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: kRed, size: 18),
            tooltip: 'Supprimer ce tuteur',
            onPressed: onRemove,
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child:
                  FormTextField(controller: draft.firstName, label: 'Prénom *')),
          const SizedBox(width: 12),
          Expanded(
              child: FormTextField(controller: draft.lastName, label: 'Nom *')),
        ]),
        FormDropdown<String>(
          label: 'Lien de parenté',
          value: draft.relationship,
          items: kLiensParente,
          onChanged: (v) {
            draft.relationship = v ?? 'autre';
            onChanged();
          },
        ),
        FormTextField(
            controller: draft.phone,
            label: 'Téléphone *',
            keyboardType: TextInputType.phone),
        FormTextField(
            controller: draft.email,
            label: 'Email',
            keyboardType: TextInputType.emailAddress),
        FormTextField(controller: draft.profession, label: 'Profession'),
        FormTextField(controller: draft.address, label: 'Adresse'),
        // ⚠️ ON NE PEUT PAS DÉCOCHER LE CONTACT PRINCIPAL, ON LE DÉPLACE.
        // La case posait `draft.isPrimary = v` sans regarder les autres fiches :
        // on pouvait marquer les quatre tuteurs comme principaux, ou — pire —
        // décocher le seul qu'il y avait et laisser l'élève sans contact
        // principal du tout. Le numéro que l'école compose en premier
        // disparaissait alors du dossier, sans un message.
        FormCheckTile(
          label: draft.isPrimary
              ? 'Contact principal — c\'est ce numéro que l\'école appelle'
              : 'Faire de ce contact le principal',
          value: draft.isPrimary,
          onChanged: (_) => onPromote(),
        ),
        FormCheckTile(
          label: 'Contact d\'urgence',
          value: draft.isEmergency,
          onChanged: (v) {
            draft.isEmergency = v;
            onChanged();
          },
        ),
      ]),
    );
  }
}

/// Déplace le titre de contact principal sur [cible], et le retire à toutes les
/// autres fiches.
///
/// Vit hors du widget parce que c'est la règle, pas l'affichage : un élève a UN
/// contact principal, et le geste « faire de celui-ci le principal » est le seul
/// moyen d'en changer. Testée par `test/contact_principal_test.dart`.
void promouvoirContactPrincipal(
    List<TuteurBrouillon> tuteurs, TuteurBrouillon cible) {
  for (final t in tuteurs) {
    t.isPrimary = identical(t, cible);
  }
}

/// Sélecteur de photo (cercle + bouton appareil photo).
class PhotoPickerEleve extends StatelessWidget {
  const PhotoPickerEleve({
    super.key,
    required this.bytes,
    required this.url,
    required this.initials,
    required this.onPick,
  });
  final Uint8List? bytes;
  final String? url;
  final String initials;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    Widget avatar;
    if (bytes != null) {
      avatar = CircleAvatar(radius: 46, backgroundImage: MemoryImage(bytes!));
    } else if (url != null && url!.isNotEmpty) {
      avatar = CircleAvatar(
        radius: 46,
        backgroundColor: kSurface,
        backgroundImage: CachedNetworkImageProvider(url!),
      );
    } else {
      avatar = CircleAvatar(
        radius: 46,
        backgroundColor: kNavy.withValues(alpha: 0.10),
        child: Text(initials,
            style: TextStyle(
                color: kNavy, fontSize: 28, fontWeight: FontWeight.w800)),
      );
    }
    return Stack(children: [
      Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: kBorder, width: 2),
        ),
        child: avatar,
      ),
      Positioned(
        right: 0,
        bottom: 0,
        child: Material(
          color: kNavy,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPick,
            child: const Padding(
              padding: EdgeInsets.all(7),
              child: Icon(Icons.photo_camera_outlined,
                  size: 16, color: Colors.white),
            ),
          ),
        ),
      ),
    ]);
  }
}
