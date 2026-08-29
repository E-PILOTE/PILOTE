// ════════════════════════════════════════════════════════════════════════════
//  DÉCLARER UNE VERSION
//
//  Tout ce que ce formulaire demande existe déjà, calculé par l'intégration
//  continue, dans le `manifest.json` publié à côté de l'installateur. On invite
//  donc à COLLER ce fichier plutôt qu'à recopier six champs : une empreinte
//  SHA-256 retapée à la main est fausse une fois sur deux, et un poste qui
//  refuse l'installation pour empreinte non conforme laisse une école bloquée
//  sans comprendre pourquoi.
//
//  La saisie champ par champ reste possible — il faut pouvoir publier sans la
//  chaîne d'intégration continue, c'était l'un des plans de repli du 2 octobre.
// ════════════════════════════════════════════════════════════════════════════

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/releases_provider.dart';

Future<bool> showReleaseFormDialog(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _ReleaseFormDialog(),
  );
  return ok ?? false;
}

class _ReleaseFormDialog extends ConsumerStatefulWidget {
  const _ReleaseFormDialog();

  @override
  ConsumerState<_ReleaseFormDialog> createState() => _FormState();
}

class _FormState extends ConsumerState<_ReleaseFormDialog> {
  final _version = TextEditingController();
  final _build = TextEditingController();
  final _url = TextEditingController();
  final _sha = TextEditingController();
  final _taille = TextEditingController();
  final _minBuild = TextEditingController();
  final _notes = TextEditingController();
  final _colle = TextEditingController();

  String _platform = 'windows';
  String _channel = 'stable';
  bool _obligatoire = false;
  bool _envoi = false;
  String? _erreur;
  String? _champFautif;
  bool _manifestLu = false;

  @override
  void dispose() {
    for (final c in [
      _version, _build, _url, _sha, _taille, _minBuild, _notes, _colle,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Lit le manifest.json produit par la compilation et remplit les champs.
  void _lireManifest() {
    setState(() {
      _erreur = null;
      _champFautif = null;
    });
    try {
      // ⚠️ Le BOM. `manifest.json` est écrit par la CI avec
      // `Set-Content -Encoding utf8`, qui sous Windows PowerShell pose un BOM
      // UTF-8 (EF BB BF) en tête. Ouvrir le fichier, tout sélectionner, coller
      // ici : `jsonDecode` refuse dès le caractère 0, et son message ne parle
      // évidemment pas de BOM. C'est la CI qui produit ce fichier — le piège
      // est donc SUR le chemin normal de publication, pas au bord.
      final brut = _colle.text.trim().replaceFirst(RegExp('^﻿'), '');
      final m = jsonDecode(brut) as Map<String, dynamic>;
      String? s(String k) => m[k]?.toString();
      setState(() {
        _version.text = s('version') ?? _version.text;
        _build.text = s('build_number') ?? s('build') ?? _build.text;
        _url.text = s('download_url') ?? s('url') ?? _url.text;
        _sha.text = (s('sha256') ?? _sha.text).toLowerCase();
        _taille.text = s('size_bytes') ?? s('size') ?? _taille.text;
        _platform = s('platform') ?? _platform;
        _channel = s('channel') ?? _channel;
        _manifestLu = true;
      });
    } catch (_) {
      setState(() => _erreur =
          'Ce n\'est pas un manifest.json lisible. Collez le contenu du '
          'fichier publié à côté de l\'installateur, accolades comprises.');
    }
  }

  Future<void> _publier() async {
    final deja = ref.read(releasesProvider).valueOrNull ?? const [];
    final faute = ControleRelease.verifier(
      version: _version.text,
      build: _build.text,
      url: _url.text,
      sha: _sha.text,
      minBuild: _minBuild.text,
      deja: deja,
      platform: _platform,
      channel: _channel,
    );
    if (faute != null) {
      setState(() {
        _erreur = faute.message;
        _champFautif = faute.champ;
      });
      return;
    }

    setState(() {
      _envoi = true;
      _erreur = null;
      _champFautif = null;
    });

    // ⚠️ AVANT d'écrire quoi que ce soit : l'adresse répond-elle à qui n'a
    // aucun identifiant ? Les contrôles ci-dessus ne lisent que du texte ;
    // celui-ci est le seul qui aurait attrapé la version 3.3.0, publiée vers
    // un dépôt privé et rendue `404` à chaque poste. Voir l'en-tête de
    // `ControleRelease.verifierAdresse`.
    final injoignable = await ControleRelease.verifierAdresse(
      _url.text,
      tailleAttendue: int.tryParse(_taille.text.trim()),
    );
    if (injoignable != null) {
      if (!mounted) return;
      setState(() {
        _erreur = injoignable.message;
        _champFautif = injoignable.champ;
        _envoi = false;
      });
      return;
    }

    try {
      await ref.read(releasesServiceProvider).publier(
            version: _version.text,
            buildNumber: int.parse(_build.text.trim()),
            platform: _platform,
            channel: _channel,
            downloadUrl: _url.text,
            sha256: _sha.text,
            sizeBytes: int.tryParse(_taille.text.trim()),
            notes: _notes.text,
            minBuild: int.tryParse(_minBuild.text.trim()),
            isMandatory: _obligatoire,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() { _erreur = '$e'; _envoi = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminFormDialog(
      icon: Icons.publish_outlined,
      title: 'Publier une version',
      subtitle: 'Elle sera proposée à tous les postes de cette plateforme',
      width: 640,
      saving: _envoi,
      submitLabel: 'Publier',
      submitIcon: Icons.campaign_outlined,
      onSubmit: _envoi ? null : _publier,
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_erreur != null) ...[
          AdminErrorBanner(message: _erreur!),
          const SizedBox(height: 14),
        ],
        _bloqueManifest(),
        const SizedBox(height: 18),
        const AdminModalSectionTitle('Identité de la version'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: _champ(_version, 'Version', 'Ex. 3.2.0',
                faute: _champFautif == 'version'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _champ(_build, 'Build', 'Ex. 42',
                faute: _champFautif == 'build',
                aide: 'Un entier, strictement croissant'),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _liste('Plateforme', _platform,
              const ['windows', 'macos', 'linux'],
              (v) => setState(() => _platform = v))),
          const SizedBox(width: 12),
          Expanded(child: _liste('Canal', _channel, const ['stable', 'beta'],
              (v) => setState(() => _channel = v))),
        ]),
        const SizedBox(height: 18),
        const AdminModalSectionTitle('Fichier d\'installation'),
        const SizedBox(height: 10),
        _champ(_url, 'Adresse de téléchargement', 'https://…',
            faute: _champFautif == 'url'),
        const SizedBox(height: 12),
        _champ(_sha, 'Empreinte SHA-256', '64 caractères hexadécimaux',
            faute: _champFautif == 'sha',
            mono: true,
            aide: 'Le poste refuse d\'installer un fichier qui ne correspond '
                'pas à cette empreinte'),
        const SizedBox(height: 12),
        _champ(_taille, 'Taille en octets', 'Ex. 35651584',
            aide: 'Facultatif — sert à annoncer le poids du téléchargement'),
        const SizedBox(height: 18),
        const AdminModalSectionTitle('Contrainte imposée au parc'),
        const SizedBox(height: 10),
        _champ(_minBuild, 'Refuser en dessous du build', 'Facultatif',
            faute: _champFautif == 'minBuild',
            aide: 'Les postes plus anciens que ce build seront invités à se '
                'mettre à jour sans pouvoir reporter'),
        const SizedBox(height: 10),
        SwitchListTile(
          value: _obligatoire,
          onChanged: (v) => setState(() => _obligatoire = v),
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text('Mise à jour obligatoire',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary)),
          subtitle: Text(
              'La bannière ne pourra plus être écartée. À réserver à une '
              'correction sans laquelle les données seraient fausses.',
              style: TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.35)),
        ),
        const SizedBox(height: 12),
        _champ(_notes, 'Ce que cette version corrige', 'Visible par l\'école',
            lignes: 3),
      ]),
    );
  }

  Widget _bloqueManifest() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kNavy.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: kNavy.withValues(alpha: 0.18)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.content_paste_rounded, size: 16, color: kNavy),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Coller le manifest.json de la compilation',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: kNavy)),
            ),
            if (_manifestLu)
              Row(children: [
                Icon(Icons.check_circle_rounded, size: 14, color: kGreen),
                const SizedBox(width: 5),
                Text('champs remplis',
                    style: TextStyle(fontSize: 11.5, color: kGreen)),
              ]),
          ]),
          const SizedBox(height: 6),
          Text(
              'C\'est la voie sûre : l\'empreinte n\'est jamais retapée. '
              'Sinon, remplissez les champs à la main ci-dessous.',
              style:
                  TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.4)),
          const SizedBox(height: 10),
          TextField(
            controller: _colle,
            maxLines: 3,
            style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace'),
            decoration: InputDecoration(
              isDense: true,
              hintText: '{ "version": "3.2.0", "build_number": 42, … }',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: _colle.text.trim().isEmpty ? null : _lireManifest,
              icon: const Icon(Icons.auto_fix_high_outlined, size: 15),
              style: OutlinedButton.styleFrom(foregroundColor: kNavy),
              label: const Text('Remplir depuis ce manifeste',
                  style: TextStyle(fontSize: 12)),
            ),
          ),
        ]),
      );

  Widget _champ(
    TextEditingController c,
    String label,
    String hint, {
    bool faute = false,
    bool mono = false,
    String? aide,
    int lignes = 1,
  }) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: faute ? kRed : kTextPrimary)),
        const SizedBox(height: 5),
        TextField(
          controller: c,
          maxLines: lignes,
          style: TextStyle(
              fontSize: 12.5, fontFamily: mono ? 'monospace' : null),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: faute ? kRed : kBorder),
            ),
          ),
        ),
        if (aide != null) ...[
          const SizedBox(height: 4),
          Text(aide,
              style:
                  TextStyle(fontSize: 10.5, color: kTextMuted, height: 1.35)),
        ],
      ]);

  Widget _liste(String label, String valeur, List<String> choix,
          ValueChanged<String> onChanged) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: kTextPrimary)),
        const SizedBox(height: 5),
        DropdownButtonFormField<String>(
          initialValue: valeur,
          isDense: true,
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          items: [
            for (final c in choix)
              DropdownMenuItem(value: c, child: Text(c)),
          ],
          onChanged: (v) => onChanged(v ?? valeur),
        ),
      ]);
}
