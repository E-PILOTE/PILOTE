import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/photo_avatar.dart';
import '../../admin_groupe/providers/admin_users_provider.dart' show roleLabel;
import '../../auth/providers/auth_provider.dart';
import '../../staff/providers/staff_photo_provider.dart';
import '../providers/mon_profil_provider.dart';
import '../services/mon_avatar_service.dart';

// ════════════════════════════════════════════════════════════════════════════
//  L'EN-TÊTE — et la photo qu'on ne pouvait pas déposer
//
//  Le visage affiché ici est celui que verront l'annuaire, la messagerie et le
//  fil d'annonces. C'est le premier endroit de l'application où quelqu'un peut
//  poser le sien.
//
//  ⚠️ La photo s'applique tout de suite, sans attendre « Enregistrer » : elle
//  ne fait pas partie du formulaire d'identité. Les mêler ferait perdre la
//  photo d'une personne qui la choisit puis quitte la page sans valider — et
//  sur une connexion lente, l'envoi finirait après la sortie de l'écran.
//
//  ⚠️ Côté personnel, la photo passe par une DEMANDE que le serveur applique.
//  `profiles.avatar_url` local ne bouge donc pas tout de suite : sans lire la
//  demande en attente, l'agent verrait son ancienne photo et conclurait que son
//  geste a échoué.
// ════════════════════════════════════════════════════════════════════════════

class ProfilIdentite extends ConsumerStatefulWidget {
  const ProfilIdentite({super.key, required this.moi});
  final MonProfil moi;

  @override
  ConsumerState<ProfilIdentite> createState() => _ProfilIdentiteState();
}

class _ProfilIdentiteState extends ConsumerState<ProfilIdentite> {
  Uint8List? _apercu;
  bool _envoi = false;

  MonProfil get moi => widget.moi;

  Future<void> _changerLaPhoto() async {
    setState(() => _envoi = true);
    try {
      final url = await deposerMaPhoto(
        client: ref.read(supabaseClientProvider),
        profil: moi.profil,
        onApercu: (o) {
          if (mounted) setState(() => _apercu = o);
        },
      );
      if (url == null) return; // sélecteur refermé — ce n'est pas une erreur
      _dire('Photo mise à jour.', kGreen);
    } catch (e) {
      if (mounted) setState(() => _apercu = null);
      _dire('$e', kRed);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  Future<void> _retirerLaPhoto() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Retirer votre photo ?'),
        content: const Text(
            'Vos initiales reprendront sa place partout dans l\'application.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _envoi = true);
    try {
      await retirerMaPhoto(
        client: ref.read(supabaseClientProvider),
        profil: moi.profil,
      );
      if (mounted) setState(() => _apercu = null);
      _dire('Photo retirée.', kGreen);
    } catch (e) {
      _dire('$e', kRed);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  void _dire(String msg, Color couleur) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: couleur));
  }

  /// Ce que la pastille doit montrer MAINTENANT.
  ///
  /// Tant qu'une demande n'est pas appliquée, c'est elle qui fait foi : la
  /// colonne locale porte encore l'ancienne adresse.
  ({String? url, String? refus, bool enAttente}) _photoAffichee() {
    if (!moi.profil.isSchoolStaff) {
      return (url: moi.profil.avatarUrl, refus: null, enAttente: false);
    }
    final d = ref
        .watch(demandesPhotoAgentProvider)
        .maybeWhen(data: (m) => m[moi.profil.id], orElse: () => null);
    if (d == null) {
      return (url: moi.profil.avatarUrl, refus: null, enAttente: false);
    }
    if (d.refus != null && d.refus!.isNotEmpty) {
      return (url: moi.profil.avatarUrl, refus: d.refus, enAttente: false);
    }
    if (d.effacer) return (url: null, refus: null, enAttente: true);
    return (url: d.urlEnAttente ?? moi.profil.avatarUrl, refus: null,
        enAttente: d.enAttente);
  }

  @override
  Widget build(BuildContext context) {
    final p = moi.profil;
    final rattachement = ref.watch(monRattachementProvider);
    final compact = MediaQuery.sizeOf(context).width < 720;
    final photo = _photoAffichee();

    return Column(children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kNavyDark, kNavy],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: kNavy.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Row(children: [
          _pastille(p.fullName, photo.url),
          const SizedBox(width: 18),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                p.fullName.isEmpty ? 'Profil sans nom' : p.fullName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800),
                overflow: TextOverflow.ellipsis,
              ),
              if (moi.emailDuCompte != null) ...[
                const SizedBox(height: 3),
                Text(moi.emailDuCompte!,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12.5),
                    overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 6, children: [
                _puce(roleLabel(p.role), Icons.shield_rounded),
                if (rattachement != null)
                  _puce(rattachement, Icons.business_rounded),
                if (!p.isActive) _puce('Compte désactivé', Icons.block_rounded),
                if (photo.enAttente)
                  _puce('Photo en attente d\'envoi', Icons.cloud_upload_rounded),
              ]),
              if (!compact && moi.peutModifierSaFiche) ...[
                const SizedBox(height: 14),
                _boutonsPhoto(photo.url != null),
              ],
            ]),
          ),
          if (compact && moi.peutModifierSaFiche) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Changer ma photo',
              onPressed: _envoi ? null : _changerLaPhoto,
              icon: const Icon(Icons.photo_camera_rounded, color: Colors.white),
            ),
          ],
        ]),
      ),
      if (photo.refus != null) ...[
        const SizedBox(height: 12),
        AdminErrorBanner(
            message: 'Photo refusée par le serveur : ${photo.refus}'),
      ],
    ]);
  }

  Widget _pastille(String nom, String? url) => Stack(children: [
        SizedBox(
          width: 84,
          height: 84,
          child: _apercu != null
              ? ClipOval(
                  child: Image.memory(_apercu!,
                      fit: BoxFit.cover, width: 84, height: 84))
              : PhotoAvatar(
                  name: nom.isEmpty ? '?' : nom,
                  photoUrl: url,
                  size: 84,
                  background: Colors.white.withValues(alpha: 0.15),
                  foreground: Colors.white,
                ),
        ),
        if (_envoi)
          const Positioned.fill(
            child: DecoratedBox(
              decoration:
                  BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
              child: Center(
                child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white)),
              ),
            ),
          ),
      ]);

  Widget _boutonsPhoto(bool aUnePhoto) => Row(children: [
        OutlinedButton.icon(
          onPressed: _envoi ? null : _changerLaPhoto,
          icon: const Icon(Icons.photo_camera_rounded, size: 15),
          label: Text(aUnePhoto ? 'Changer' : 'Ajouter ma photo',
              style: const TextStyle(fontSize: 12.5)),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
          ),
        ),
        if (aUnePhoto) ...[
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: _envoi ? null : _retirerLaPhoto,
            icon: const Icon(Icons.delete_outline_rounded, size: 15),
            label: const Text('Retirer', style: TextStyle(fontSize: 12.5)),
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
          ),
        ],
      ]);

  Widget _puce(String texte, IconData icone) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icone, size: 13, color: Colors.white70),
          const SizedBox(width: 5),
          Flexible(
            child: Text(texte,
                style: const TextStyle(color: Colors.white, fontSize: 11.5),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      );
}
