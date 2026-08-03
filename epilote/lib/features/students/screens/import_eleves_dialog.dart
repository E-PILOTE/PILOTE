// ════════════════════════════════════════════════════════════════════════════
//  IMPORTER UNE LISTE D'ÉLÈVES
//
//  Trois temps, jamais mélangés : on choisit le fichier, on REGARDE ce que la
//  machine y a compris, puis seulement on écrit.
//
//  Le temps du milieu est le seul qui compte. Une secrétaire ne peut pas
//  vérifier trois cents dossiers après coup ; elle peut vérifier un tableau
//  avant. On lui montre donc, dans cet ordre : ce qui bloque et pourquoi, ce
//  qu'il faut relire, ce que la machine a laissé de côté, et enfin ce qui
//  entrera.
// ════════════════════════════════════════════════════════════════════════════

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../../structure/providers/academic_year_context.dart';
import '../providers/import_eleves_provider.dart';
import '../services/import_liste_eleves.dart';
import 'import_eleves_parts.dart';

Future<bool> showImportElevesDialog(BuildContext context) async {
  final fait = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _ImportElevesDialog(),
  );
  return fait ?? false;
}

class _ImportElevesDialog extends ConsumerStatefulWidget {
  const _ImportElevesDialog();

  @override
  ConsumerState<_ImportElevesDialog> createState() => _ImportState();
}

class _ImportState extends ConsumerState<_ImportElevesDialog> {
  String? _fichier;
  PreparationImport? _prep;
  String? _classeParDefaut;
  String? _erreur;
  bool _travaille = false;

  // Écriture en cours
  int _faites = 0;
  int _total = 0;
  BilanImport? _bilan;

  Future<void> _choisirFichier() async {
    setState(() {
      _erreur = null;
      _travaille = true;
    });
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv', 'txt'],
        withData: true,
      );
      if (res == null || res.files.isEmpty) {
        if (mounted) setState(() => _travaille = false);
        return;
      }
      final f = res.files.single;
      final octets = f.bytes ??
          (f.path != null ? await File(f.path!).readAsBytes() : null);
      if (octets == null) {
        throw const FichierIllisible('Fichier illisible sur ce poste.');
      }
      _fichier = f.name;
      await _relire(octets);
    } catch (e) {
      if (mounted) {
        setState(() {
          _erreur = '$e';
          _travaille = false;
          _prep = null;
        });
      }
    }
  }

  /// Relit le fichier depuis zéro. Indispensable quand la classe d'accueil
  /// change : les rejets « aucune classe indiquée » doivent disparaître, et
  /// une ligne déjà marquée ne se démarque pas.
  List<int>? _octets;

  Future<void> _relire(List<int> octets) async {
    _octets = octets;
    final profile = ref.read(authNotifierProvider).valueOrNull;
    final yearId = ref.read(activeYearIdProvider);
    if (profile?.schoolId == null || yearId == null) {
      throw const FichierIllisible(
          'Aucune année scolaire courante : impossible d\'inscrire.');
    }
    final lecture = lireFichierEleves(octets,
        anneeReference: DateTime.now().year);
    final prep = await preparerImport(
      lecture: lecture,
      schoolId: profile!.schoolId!,
      yearId: yearId,
      classeParDefaut: _classeParDefaut,
    );
    if (!mounted) return;
    setState(() {
      _prep = prep;
      _travaille = false;
    });
  }

  Future<void> _changerClasse(String? id) async {
    setState(() => _classeParDefaut = id);
    final o = _octets;
    if (o == null) return;
    setState(() => _travaille = true);
    try {
      await _relire(o);
    } catch (e) {
      if (mounted) setState(() { _erreur = '$e'; _travaille = false; });
    }
  }

  Future<void> _ecrire() async {
    final prep = _prep;
    final profile = ref.read(authNotifierProvider).valueOrNull;
    final yearId = ref.read(activeYearIdProvider);
    if (prep == null || profile?.schoolId == null || yearId == null) return;

    setState(() {
      _travaille = true;
      _faites = 0;
      _total = prep.retenues.length;
    });
    try {
      final bilan = await executerImport(
        preparation: prep,
        schoolId: profile!.schoolId!,
        groupId: profile.groupId ?? '',
        yearId: yearId,
        saisiPar: profile.id,
        progression: (f, t) {
          if (mounted) setState(() { _faites = f; _total = t; });
        },
      );
      if (mounted) setState(() { _bilan = bilan; _travaille = false; });
    } catch (e) {
      if (mounted) setState(() { _erreur = '$e'; _travaille = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bilan = _bilan;
    final prep = _prep;

    return AdminFormDialog(
      icon: Icons.upload_file_outlined,
      title: 'Importer une liste d\'élèves',
      subtitle: _fichier ?? 'Fichier CSV exporté depuis Excel',
      width: 860,
      maxHeight: 700,
      footer: _pied(prep, bilan),
      body: bilan != null
          ? BilanImportVue(bilan: bilan)
          : _travaille && _total > 0
              ? _enCours()
              : prep == null
                  ? _accueil()
                  : _apercu(prep),
    );
  }

  // ── Écran 1 : choisir le fichier ────────────────────────────────────────
  Widget _accueil() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_erreur != null) ...[
            AdminErrorBanner(message: _erreur!),
            const SizedBox(height: 16),
          ],
          const ModeEmploiImport(),
          const SizedBox(height: 20),
          Center(
            child: AdminPrimaryButton(
              label: _travaille ? 'Lecture…' : 'Choisir un fichier',
              icon: Icons.folder_open_outlined,
              onTap: _travaille ? () {} : _choisirFichier,
            ),
          ),
        ],
      );

  // ── Écran 2 : ce que la machine a compris ───────────────────────────────
  Widget _apercu(PreparationImport prep) {
    final classes = ref.watch(classesImportProvider).valueOrNull ?? const [];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_erreur != null) ...[
        AdminErrorBanner(message: _erreur!),
        const SizedBox(height: 14),
      ],
      ResumeImport(prep: prep),
      const SizedBox(height: 16),
      ChoixClasseAccueil(
        classes: classes,
        valeur: _classeParDefaut,
        // Le fichier porte sa propre colonne « Classe » : le choix devient
        // inutile, et proposer les deux ferait croire à un conflit.
        actif: !prep.lecture.colonnesReconnues.values
            .contains(ChampImport.classe),
        onChanged: _travaille ? null : _changerClasse,
      ),
      const SizedBox(height: 16),
      TableauLignes(prep: prep),
    ]);
  }

  // ── Écran 3 : l'écriture ────────────────────────────────────────────────
  Widget _enCours() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(children: [
          Text('Inscription en cours',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: kNavy)),
          const SizedBox(height: 6),
          Text('$_faites élève${_faites > 1 ? 's' : ''} sur $_total',
              style: TextStyle(fontSize: 12.5, color: kTextMuted)),
          const SizedBox(height: 16),
          SizedBox(
            width: 320,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _total == 0 ? null : _faites / _total,
                minHeight: 7,
                backgroundColor: kNavy.withValues(alpha: 0.12),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text('Ne fermez pas la fenêtre. Les élèves sont enregistrés sur ce '
              'poste ; ils partiront vers le serveur dès la connexion revenue.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.4)),
        ]),
      );

  // ── Le pied, différent à chaque temps ───────────────────────────────────
  Widget _pied(PreparationImport? prep, BilanImport? bilan) {
    if (bilan != null) {
      return PiedImport(
        principal: 'Terminer',
        icone: Icons.check_rounded,
        onPrincipal: () => Navigator.of(context).pop(true),
      );
    }
    if (prep == null) {
      return PiedImport(
        onAnnuler: () => Navigator.of(context).pop(false),
      );
    }
    final n = prep.retenues.length;
    return PiedImport(
      onAnnuler: _travaille ? null : () => Navigator.of(context).pop(false),
      principal: n == 0
          ? 'Aucun élève à inscrire'
          : 'Inscrire $n élève${n > 1 ? 's' : ''}',
      icone: Icons.person_add_alt_1_outlined,
      onPrincipal: (n == 0 || _travaille) ? null : _ecrire,
    );
  }
}
