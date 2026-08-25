// ════════════════════════════════════════════════════════════════════════════
//  LE DIALOGUE DE MISE À JOUR
//
//  Trois moments, et le troisième est le seul irréversible :
//    1. lire ce que la version corrige ;
//    2. télécharger — long, interruptible, sans conséquence ;
//    3. installer — l'application se ferme.
//
//  L'avertissement de l'étape 3 n'est pas une politesse. Un secrétariat qui
//  saisit sa rentrée depuis deux heures doit lire « enregistrez votre travail »
//  AVANT que l'installateur démarre, pas après.
// ════════════════════════════════════════════════════════════════════════════

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/update_provider.dart';
import '../services/update_installer.dart';

Future<void> showUpdateDialog(
        BuildContext context, WidgetRef ref, EtatMiseAJour etat) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UpdateDialog(etat: etat),
    );

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.etat});
  final EtatMiseAJour etat;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  ProgressionTelechargement? _progres;
  File? _pret;
  String? _erreur;
  bool _occupe = false;

  AppRelease get _release => widget.etat.disponible!;

  Future<void> _telecharger() async {
    setState(() {
      _occupe = true;
      _erreur = null;
      _progres = const ProgressionTelechargement(0, null);
    });
    try {
      final f = await UpdateInstaller.telecharger(
        _release,
        onProgress: (p) {
          if (mounted) setState(() => _progres = p);
        },
      );
      if (mounted) setState(() { _pret = f; _occupe = false; });
    } on EchecMiseAJour catch (e) {
      if (mounted) setState(() { _erreur = e.message; _occupe = false; });
    } catch (e) {
      if (mounted) setState(() { _erreur = '$e'; _occupe = false; });
    }
  }

  Future<void> _installer() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.power_settings_new_rounded, color: kRed, size: 30),
        title: const Text('L’application va se fermer'),
        content: const Text(
          'L’installateur remplace le programme en cours d’exécution : '
          'E-PILOTE doit se fermer.\n\n'
          'Enregistrez votre travail en cours avant de continuer. Les données '
          'déjà saisies sont conservées — elles vivent dans la base du poste, '
          'que l’installation ne touche pas.',
          style: TextStyle(height: 1.45),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Pas maintenant')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: kRed),
            child: const Text('Fermer et installer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await UpdateInstaller.lancer(_pret!);
      // On laisse à l'installateur le temps de prendre la main avant de rendre
      // le fichier accessible : le fermer trop tôt le ferait échouer.
      await Future<void>.delayed(const Duration(milliseconds: 800));
      exit(0);
    } on EchecMiseAJour catch (e) {
      if (mounted) setState(() => _erreur = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _release;
    final p = _progres;

    return AlertDialog(
      icon: Icon(Icons.system_update_alt_rounded, color: kNavy, size: 30),
      title: Text('Version ${r.version}'),
      content: SizedBox(
        width: 460,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Installée : ${widget.etat.versionInstallee}'
              '${r.tailleLisible.isEmpty ? '' : '  ·  téléchargement ${r.tailleLisible}'}',
              style: TextStyle(fontSize: 12, color: kTextMuted),
            ),
          ),
          if (r.notes != null && r.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 190),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kNavy.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kBorder),
              ),
              child: SingleChildScrollView(
                child: Text(r.notes!.trim(),
                    style: const TextStyle(fontSize: 12.5, height: 1.5)),
              ),
            ),
          ],
          if (p != null && _pret == null) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: p.fraction),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                p.fraction == null
                    ? '${(p.recus / (1024 * 1024)).toStringAsFixed(1)} Mo reçus'
                    : '${(p.fraction! * 100).round()} %  ·  '
                        '${(p.recus / (1024 * 1024)).toStringAsFixed(1)} Mo',
                style: TextStyle(fontSize: 11.5, color: kTextMuted),
              ),
            ),
          ],
          if (_pret != null) ...[
            const SizedBox(height: 14),
            Row(children: [
              Icon(Icons.verified_rounded, size: 18, color: kGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Fichier téléchargé et vérifié : son empreinte correspond à '
                  'la version publiée.',
                  style: TextStyle(fontSize: 12, color: kGreen),
                ),
              ),
            ]),
          ],
          if (_erreur != null) ...[
            const SizedBox(height: 14),
            AdminErrorBanner(message: _erreur!),
          ],
        ]),
      ),
      actions: [
        TextButton(
          onPressed: _occupe ? null : () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
        if (_pret == null)
          FilledButton.icon(
            onPressed: _occupe ? null : _telecharger,
            icon: const Icon(Icons.download_rounded, size: 17),
            label: Text(_occupe ? 'Téléchargement…' : 'Télécharger'),
          )
        else
          FilledButton.icon(
            onPressed: _installer,
            icon: const Icon(Icons.play_arrow_rounded, size: 17),
            label: const Text('Installer'),
            style: FilledButton.styleFrom(backgroundColor: kGreen),
          ),
      ],
    );
  }
}
