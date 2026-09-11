import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/message_erreur.dart';
import '../../../core/widgets/admin_ui.dart';
import '../providers/mon_profil_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  MES INFORMATIONS — trois champs, et deux choses qu'on ne peut pas changer
//
//  ⚠️ L'e-mail est en LECTURE SEULE, et la page dit POURQUOI. Il ne vit pas
//  dans `profiles` mais dans `auth.users` : c'est l'identifiant de session, pas
//  une coordonnée. La confusion entre les deux a déjà coûté une soirée au
//  fondateur, qui a lu une adresse de CONTACT sur son écran des abonnements et
//  n'a pas pu ouvrir l'espace d'un client avec.
//
//  ⚠️ Le formulaire se VERROUILLE quand la fiche affichée n'est pas celle du
//  compte de l'appareil (poste partagé, agent basculé par code PIN). Ce n'est
//  pas de la prudence d'écran : l'écriture serait refusée par la RLS à la
//  remontée, en `42501`, et ferait abandonner tout le lot PowerSync.
// ════════════════════════════════════════════════════════════════════════════

class ProfilInfos extends ConsumerStatefulWidget {
  const ProfilInfos({super.key, required this.moi});
  final MonProfil moi;

  @override
  ConsumerState<ProfilInfos> createState() => _ProfilInfosState();
}

class _ProfilInfosState extends ConsumerState<ProfilInfos> {
  final _prenom = TextEditingController();
  final _nom = TextEditingController();
  final _telephone = TextEditingController();
  bool _hydrate = false;
  bool _envoi = false;
  String? _erreur;

  MonProfil get moi => widget.moi;

  @override
  void dispose() {
    _prenom.dispose();
    _nom.dispose();
    _telephone.dispose();
    super.dispose();
  }

  /// Remplit les champs UNE fois : la ligne locale reste la source de vérité,
  /// mais elle ne doit pas écraser une saisie en cours à chaque synchro.
  void _hydrater() {
    if (_hydrate) return;
    _prenom.text = moi.profil.firstName;
    _nom.text = moi.profil.lastName;
    _telephone.text = moi.profil.phone ?? '';
    _hydrate = true;
  }

  Future<void> _enregistrer() async {
    if (_prenom.text.trim().isEmpty || _nom.text.trim().isEmpty) {
      setState(() => _erreur = 'Le prénom et le nom sont obligatoires.');
      return;
    }
    setState(() {
      _envoi = true;
      _erreur = null;
    });
    try {
      await enregistrerMonProfil(
        ref,
        moi: moi,
        prenom: _prenom.text,
        nom: _nom.text,
        telephone: _telephone.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: kGreen, content: const Text('Profil mis à jour.')));
      }
    } catch (e) {
      setState(() => _erreur = messageErreur(e));
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    _hydrater();
    final modifiable = moi.peutModifierSaFiche;
    final etroit = MediaQuery.sizeOf(context).width < 640;

    return AdminCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!modifiable) ...[
          _AvertissementPosteBanalise(nom: moi.nomComplet),
          const SizedBox(height: 14),
        ],
        if (etroit) ...[
          _champ(_prenom, 'Prénom', Icons.badge_outlined, modifiable),
          const SizedBox(height: 12),
          _champ(_nom, 'Nom', Icons.person_outline_rounded, modifiable),
        ] else
          Row(children: [
            Expanded(
                child:
                    _champ(_prenom, 'Prénom', Icons.badge_outlined, modifiable)),
            const SizedBox(width: 12),
            Expanded(
                child: _champ(
                    _nom, 'Nom', Icons.person_outline_rounded, modifiable)),
          ]),
        const SizedBox(height: 12),
        _champ(_telephone, 'Téléphone', Icons.phone_outlined, modifiable,
            clavier: TextInputType.phone),
        const SizedBox(height: 12),
        _emailLectureSeule(),
        if (_erreur != null) ...[
          const SizedBox(height: 14),
          AdminErrorBanner(message: _erreur!),
        ],
        if (modifiable) ...[
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            AdminActionButton(
              label: _envoi ? 'Enregistrement…' : 'Enregistrer',
              icon: _envoi
                  ? Icons.hourglass_empty_rounded
                  : Icons.check_rounded,
              color: kNavy,
              onPressed: _envoi ? () {} : _enregistrer,
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _champ(TextEditingController c, String label, IconData icone,
          bool actif, {TextInputType? clavier}) =>
      TextField(
        controller: c,
        enabled: actif,
        keyboardType: clavier,
        decoration: adminInputDecoration(label, icon: icone),
      );

  /// L'adresse qui ouvre la session — et la raison de son verrou.
  Widget _emailLectureSeule() {
    final email = moi.emailDuCompte;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Row(children: [
        Icon(Icons.key_rounded, size: 18, color: kTextMuted),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Compte de connexion',
                style: TextStyle(
                    fontSize: 11.5,
                    color: kTextMuted,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(email ?? 'Session ouverte par un autre compte',
                style: TextStyle(
                    fontSize: 13.5,
                    color: email == null ? kTextMuted : kTextPrimary,
                    fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text(
              'Cette adresse ouvre votre session ; elle ne se modifie pas '
              'depuis cette page. Pour en changer, passez par votre '
              'administrateur.',
              style: TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.35),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// Ce que voit un agent dont la fiche n'appartient pas au compte de l'appareil.
class _AvertissementPosteBanalise extends StatelessWidget {
  const _AvertissementPosteBanalise({required this.nom});
  final String nom;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: kAccent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kAccent.withValues(alpha: 0.35)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.groups_rounded, size: 18, color: kAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Ce poste est ouvert avec le compte d\'un autre membre. La fiche '
              'de $nom s\'affiche, mais ne peut pas être modifiée d\'ici : la '
              'correction se demande depuis l\'écran Personnel.',
              style: TextStyle(fontSize: 12.5, color: kTextPrimary, height: 1.4),
            ),
          ),
        ]),
      );
}
