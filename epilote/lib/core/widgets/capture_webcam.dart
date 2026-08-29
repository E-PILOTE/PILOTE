import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../utils/cadre_identite.dart';
import 'admin_ui.dart';

// ════════════════════════════════════════════════════════════════════════════
//  PRENDRE LA PHOTO À LA WEBCAM
//
//  ── CE QUI MANQUAIT ────────────────────────────────────────────────────────
//  La fiche n'acceptait qu'un FICHIER. Or l'élève est là, devant le bureau, le
//  jour de l'inscription — et la photo, elle, est « à apporter ». Elle n'arrive
//  jamais. C'est pour cela que des cartes scolaires sortent avec « PHOTO
//  MANQUANTE » : pas un défaut de la carte, un défaut du moment où on demande
//  la photo.
//
//  ── LE CADRE EST MONTRÉ AVANT, PAS APPLIQUÉ APRÈS ──────────────────────────
//  L'aperçu porte le rectangle exact qui sera conservé (22 × 28 mm, le cadre de
//  la carte). Ce qui est en dehors est assombri : l'opérateur voit ce qu'il
//  garde pendant qu'il cadre, au lieu de le découvrir sur la planche imprimée.
//
//  ── CE QUE CE FICHIER NE FAIT PAS ──────────────────────────────────────────
//  Il ne parle ni à Supabase ni à PowerSync : il rend des octets. C'est
//  l'appelant qui décide où ils vont (`queueAvatarUpload` pour un élève,
//  `preparerPhotoAgent` pour un agent). Une photo prise et non enregistrée doit
//  pouvoir être jetée sans conséquence.
// ════════════════════════════════════════════════════════════════════════════

/// Vrai là où le greffon `camera` a une implémentation.
///
/// ⚠️ **Linux n'en a pas.** Le poste de développement en est un ; les postes
/// d'école sont sous Windows. Le bouton doit donc disparaître, pas échouer :
/// un bouton qui ouvre une erreur apprend à l'utilisateur à ne plus cliquer.
bool get webcamPossible =>
    !kIsWeb &&
    (Platform.isWindows ||
        Platform.isAndroid ||
        Platform.isIOS ||
        Platform.isMacOS);

/// Ouvre la prise de vue et rend les octets JPEG déjà recadrés, ou `null` si
/// l'opérateur renonce.
Future<Uint8List?> capturerPhotoWebcam(BuildContext context) =>
    showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _CaptureDialog(),
    );

/// Une photo choisie : ses octets et un nom de fichier (dont l'extension sort).
typedef PhotoChoisie = ({Uint8List octets, String nomFichier});

/// L'extension d'un nom de fichier, en minuscules, `jpg` à défaut.
///
/// Le défaut n'est pas anodin : cette extension sert à nommer l'objet dans le
/// Storage et à deviner son type MIME. Un nom sans point (une capture, un
/// fichier renommé) ne doit pas produire un objet sans extension, que le
/// navigateur téléchargerait au lieu de l'afficher.
String extensionPhoto(String nomFichier) {
  final i = nomFichier.lastIndexOf('.');
  if (i < 0 || i == nomFichier.length - 1) return 'jpg';
  return nomFichier.substring(i + 1).toLowerCase();
}

/// Demande la source de la photo — webcam ou fichier — puis la rend.
///
/// Là où la webcam n'existe pas (Linux), il n'y a pas de question à poser : on
/// ouvre directement le sélecteur de fichiers. Une boîte de dialogue à un seul
/// choix est un clic volé.
///
/// [extensions] restreint le sélecteur ; `null` accepte toute image.
Future<PhotoChoisie?> choisirPhotoPersonne(
  BuildContext context, {
  List<String>? extensions,
}) async {
  var source = _Source.fichier;
  if (webcamPossible) {
    final choix = await showDialog<_Source>(
      context: context,
      builder: (_) => const _ChoixSourceDialog(),
    );
    if (choix == null) return null;
    source = choix;
  }

  if (source == _Source.webcam) {
    if (!context.mounted) return null;
    final octets = await capturerPhotoWebcam(context);
    if (octets == null) return null;
    // `recadrerEnIdentite` ré-encode toujours en JPEG.
    return (octets: octets, nomFichier: 'webcam.jpg');
  }

  final res = await FilePicker.platform.pickFiles(
    type: extensions == null ? FileType.image : FileType.custom,
    allowedExtensions: extensions,
    withData: true,
  );
  final f = res?.files.firstOrNull;
  final octets = f?.bytes;
  if (f == null || octets == null) return null;
  return (octets: octets, nomFichier: f.name);
}

enum _Source { webcam, fichier }

class _ChoixSourceDialog extends StatelessWidget {
  const _ChoixSourceDialog();

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(kModalRadius),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AdminModalHeader(
                  icon: Icons.add_a_photo_rounded,
                  title: 'La photo',
                  subtitle: 'La personne est là ? Prenez-la maintenant.',
                  onClose: () => Navigator.of(context).pop(),
                ),
                _Option(
                  icon: Icons.photo_camera_rounded,
                  titre: 'Prendre la photo',
                  detail: 'Avec la webcam du poste, cadrée pour la carte',
                  couleur: kGreen,
                  onTap: () => Navigator.of(context).pop(_Source.webcam),
                ),
                Divider(height: 1, color: kBorder),
                _Option(
                  icon: Icons.folder_open_rounded,
                  titre: 'Choisir un fichier',
                  detail: 'Une photo déjà sur ce poste ou sur une clé USB',
                  couleur: kNavy,
                  onTap: () => Navigator.of(context).pop(_Source.fichier),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      );
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.titre,
    required this.detail,
    required this.couleur,
    required this.onTap,
  });

  final IconData icon;
  final String titre;
  final String detail;
  final Color couleur;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: couleur.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: couleur, size: 21),
        ),
        title: Text(titre,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
        subtitle: Text(detail,
            style: TextStyle(fontSize: 12.5, color: kTextMuted)),
        trailing: Icon(Icons.chevron_right_rounded, color: kTextMuted),
      );
}

class _CaptureDialog extends StatefulWidget {
  const _CaptureDialog();

  @override
  State<_CaptureDialog> createState() => _CaptureDialogState();
}

class _CaptureDialogState extends State<_CaptureDialog> {
  CameraController? _cam;
  String? _panne;
  bool _occupe = false;
  Uint8List? _prise;

  @override
  void initState() {
    super.initState();
    _ouvrir();
  }

  @override
  void dispose() {
    // La caméra reste allumée tant qu'on ne la libère pas — voyant compris.
    _cam?.dispose();
    super.dispose();
  }

  Future<void> _ouvrir() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() => _panne = 'Aucune caméra détectée sur ce poste. '
            'Branchez une webcam, puis rouvrez cette fenêtre.');
        return;
      }
      final c = CameraController(
        cameras.first,
        ResolutionPreset.high,
        // Sans cela, Windows réclame aussi le micro : une autorisation de plus
        // à refuser pour une photo qui n'a pas de son.
        enableAudio: false,
      );
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _cam = c);
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() => _panne = _messageDe(e));
    } catch (e) {
      if (!mounted) return;
      setState(() => _panne = 'La caméra n’a pas pu être ouverte : $e');
    }
  }

  /// Dire CE QUI bloque. « Erreur caméra » n'aide personne à la déloger.
  String _messageDe(CameraException e) => switch (e.code) {
        'CameraAccessDenied' || 'CameraAccessDeniedWithoutPrompt' =>
          'Windows refuse l’accès à la caméra pour cette application. '
              'Paramètres → Confidentialité et sécurité → Caméra.',
        'CameraAccessRestricted' =>
          'L’accès à la caméra est bloqué par une règle de l’ordinateur.',
        'cameraNotFound' =>
          'La caméra a disparu — débranchée, ou prise par une autre '
              'application (Teams, Zoom, l’application Caméra).',
        _ => 'La caméra n’a pas pu être ouverte (${e.code}). '
            'Vérifiez qu’aucune autre application ne l’utilise.',
      };

  Future<void> _declencher() async {
    final c = _cam;
    if (c == null || _occupe) return;
    setState(() => _occupe = true);
    try {
      final fichier = await c.takePicture();
      final brut = await fichier.readAsBytes();
      final coupee = await recadrerEnIdentite(brut);
      if (!mounted) return;
      setState(() {
        _prise = coupee;
        _occupe = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _occupe = false;
        _panne = 'La photo n’a pas pu être prise : $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
          child: Container(
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(kModalRadius),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AdminModalHeader(
                  icon: Icons.photo_camera_rounded,
                  title: 'Prendre la photo',
                  subtitle: _prise != null
                      ? 'Voici ce qui sera imprimé sur la carte.'
                      : 'Cadrez le visage dans le rectangle clair.',
                  onClose: () => Navigator.of(context).pop(),
                ),
                Flexible(child: _corps()),
                _actions(),
              ],
            ),
          ),
        ),
      );

  Widget _corps() {
    final panne = _panne;
    if (panne != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: AdminErrorBanner(message: panne),
      );
    }
    final prise = _prise;
    if (prise != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: AspectRatio(
          aspectRatio: kRatioIdentite,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(prise, fit: BoxFit.cover),
          ),
        ),
      );
    }
    final c = _cam;
    if (c == null) {
      return const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(20),
      child: AspectRatio(
        aspectRatio: c.value.aspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [CameraPreview(c), const _Guide()],
          ),
        ),
      ),
    );
  }

  Widget _actions() {
    if (_panne != null) {
      // « Réessayer » plutôt qu'un simple « Fermer » : la panne la plus
      // fréquente est une caméra prise par une autre application. On la ferme,
      // on réessaie — sans avoir à rouvrir la fiche.
      return AdminModalActions(
        cancelLabel: 'Fermer',
        submitLabel: 'Réessayer',
        submitIcon: Icons.refresh_rounded,
        onSubmit: () {
          setState(() => _panne = null);
          _ouvrir();
        },
      );
    }
    if (_prise != null) {
      return AdminModalActions(
        cancelLabel: 'Refaire',
        onCancel: () => setState(() => _prise = null),
        submitLabel: 'Utiliser cette photo',
        submitIcon: Icons.check_rounded,
        submitColor: kGreen,
        onSubmit: () => Navigator.of(context).pop(_prise),
      );
    }
    return AdminModalActions(
      submitLabel: 'Prendre la photo',
      submitIcon: Icons.camera_alt_rounded,
      saving: _cam == null || _occupe,
      onSubmit: _declencher,
    );
  }
}

/// Le rectangle conservé, montré PAR-DESSUS l'aperçu.
///
/// Il reprend exactement [cadreIdentite] : toute la hauteur, la largeur au
/// rapport, centré. Ce qui est en dehors est assombri — c'est ce qui sera jeté.
class _Guide extends StatelessWidget {
  const _Guide();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, bornes) {
          final c = cadreIdentite(
            bornes.maxWidth.round(),
            bornes.maxHeight.round(),
          );
          final marge = (bornes.maxWidth - c.largeur) / 2;
          return Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: marge,
                child: const ColoredBox(color: Colors.black54),
              ),
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: marge,
                child: const ColoredBox(color: Colors.black54),
              ),
              Positioned(
                left: marge,
                top: 0,
                bottom: 0,
                width: c.largeur.toDouble(),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white70, width: 1.5),
                  ),
                ),
              ),
            ],
          );
        },
      );
}
