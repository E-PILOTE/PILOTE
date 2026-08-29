import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/auth_provider.dart' show supabaseClientProvider;
import '../../navigation/widgets/module_scaffold.dart'
    show writeRefusedForLicense;
import '../providers/cartes_provider.dart';
import '../providers/import_photos_provider.dart';
import '../services/appariement_photos.dart';
import 'import_photos_fin.dart';
import 'import_photos_parts.dart';

// ════════════════════════════════════════════════════════════════════════════
//  IMPORTER LES PHOTOS D'UNE CLASSE
//
//  ── LE GESTE RÉEL, PAS LE GESTE IDÉAL ──────────────────────────────────────
//  L'école photographie une classe, vide la carte mémoire dans un dossier, et
//  se retrouve avec `IMG_0042.JPG` quarante fois. Un import qui n'accepterait
//  que des fichiers nommés au matricule ne servirait personne.
//
//  Il y a donc DEUX chemins, et le second est le principal :
//   • l'appariement automatique, quand les fichiers portent une identité
//     (matricule, identifiant national, nom) — exact et sans à-peu-près ;
//   • l'appariement à la MAIN, où l'agent voit la vignette à côté de la liste
//     des élèves encore sans photo. C'est le cas normal, pas le cas dégradé.
//
//  ── QUATRE TEMPS, ET ON N'ÉCRIT QU'AU TROISIÈME ────────────────────────────
//  choix des fichiers → revue du tableau → écriture avec progression → rapport.
//  Rien ne part en base avant que l'agent ait vu ce qui va partir : six cents
//  photos posées en silence puis découvertes fausses ne se défont pas.
// ════════════════════════════════════════════════════════════════════════════

Future<void> ouvrirImportPhotos(
  BuildContext context,
  WidgetRef ref, {
  required String classId,
  required String className,
}) async {
  final eleves = await ref.read(cartesElevesProvider(classId).future);
  if (!context.mounted) return;

  if (eleves.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Aucune inscription active dans cette classe.'),
    ));
    return;
  }

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ImportPhotosDialog(
        eleves: eleves, className: className, classId: classId),
  );
}

enum _Etape { choix, revue, ecriture, rapport }

class _ImportPhotosDialog extends ConsumerStatefulWidget {
  const _ImportPhotosDialog({
    required this.eleves,
    required this.className,
    required this.classId,
  });

  final List<CarteEleveRow> eleves;
  final String className, classId;

  @override
  ConsumerState<_ImportPhotosDialog> createState() =>
      _ImportPhotosDialogState();
}

class _ImportPhotosDialogState extends ConsumerState<_ImportPhotosDialog> {
  _Etape _etape = _Etape.choix;

  List<FichierPhoto> _fichiers = const [];
  ResultatAppariement? _resultat;
  bool _remplacer = false;

  /// Rattachements décidés à la main : chemin du fichier → élève.
  final Map<String, CarteEleveRow> _manuels = {};

  int _rang = 0;
  String _encours = '';
  RapportImportPhotos? _rapport;
  bool _annule = false;

  // ── 1. Choisir ────────────────────────────────────────────────────────────

  Future<void> _choisir() async {
    // `withData: false` : on ne charge PAS les octets. Six cents photos de
    // téléphone tiennent plusieurs gigaoctets, et l'appariement n'a besoin que
    // du nom. Les octets se lisent un par un au moment d'écrire.
    final res = await FilePicker.platform.pickFiles(
      dialogTitle: 'Photos de la classe ${widget.className}',
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: kExtensionsPhoto,
      withData: false,
    );
    if (res == null || res.files.isEmpty) return;

    final fichiers = <FichierPhoto>[
      for (final f in res.files)
        if (f.path != null)
          FichierPhoto(chemin: f.path!, nom: f.name, taille: f.size),
    ];
    if (fichiers.isEmpty) return;

    setState(() {
      _fichiers = fichiers;
      _manuels.clear();
      _recalculer();
      _etape = _Etape.revue;
    });
  }

  void _recalculer() {
    _resultat = apparierPhotos(
      fichiers: _fichiers,
      eleves: widget.eleves,
      remplacerExistantes: _remplacer,
    );
  }

  // ── 2. Revoir ─────────────────────────────────────────────────────────────

  /// Tout ce qui sera écrit : l'automatique plus le manuel.
  List<PhotoAppariee> get _aEcrire {
    final r = _resultat;
    if (r == null) return const [];
    final auto = r.apparies;
    final dejaPris = {for (final p in auto) p.fichier.chemin};
    return [
      ...auto,
      for (final e in _manuels.entries)
        if (!dejaPris.contains(e.key))
          PhotoAppariee(
            _fichiers.firstWhere((f) => f.chemin == e.key),
            e.value,
            CleAppariement.nom,
          ),
    ];
  }

  /// Les élèves encore libres — ceux qu'un rattachement manuel peut viser.
  ///
  /// Un élève déjà servi (automatiquement ou à la main) en sort : proposer
  /// deux fois le même enfant, c'est fabriquer l'ambiguïté que l'appariement
  /// automatique refuse par ailleurs.
  List<CarteEleveRow> get _elevesLibres {
    final pris = {for (final p in _aEcrire) p.eleve.studentId};
    return [
      for (final e in widget.eleves)
        if ((!e.aUnePhoto || _remplacer) && !pris.contains(e.studentId)) e,
    ];
  }

  void _rattacher(FichierPhoto f, CarteEleveRow? e) => setState(() {
        if (e == null) {
          _manuels.remove(f.chemin);
        } else {
          _manuels[f.chemin] = e;
        }
      });

  // ── 3. Écrire ─────────────────────────────────────────────────────────────

  Future<void> _ecrire() async {
    final lot = _aEcrire;
    if (lot.isEmpty) return;
    if (writeRefusedForLicense(context)) return;

    setState(() {
      _etape = _Etape.ecriture;
      _rang = 0;
      _annule = false;
    });

    final rapport = await ecrirePhotosImportees(
      client: ref.read(supabaseClientProvider),
      apparies: lot,
      interrompu: () => _annule,
      onProgres: (rang, total, eleve) {
        if (!mounted) return;
        setState(() {
          _rang = rang;
          _encours = eleve;
        });
      },
    );

    if (!mounted) return;
    ref.invalidate(cartesElevesProvider(widget.classId));
    setState(() {
      _rapport = rapport;
      _etape = _Etape.rapport;
    });
  }

  // ── Rendu ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EnTeteImport(
              className: widget.className,
              etape: _etape.index,
              onFermer: _etape == _Etape.ecriture
                  ? null
                  : () => Navigator.of(context).pop(),
            ),
            Divider(height: 1, color: kBorder),
            Flexible(child: _corps()),
            Divider(height: 1, color: kBorder),
            _barreActions(),
          ],
        ),
      ),
    );
  }

  Widget _corps() => switch (_etape) {
        _Etape.choix => ChoixFichiers(
            eleves: widget.eleves,
            className: widget.className,
            onChoisir: _choisir,
          ),
        _Etape.revue => RevueAppariement(
            resultat: _resultat!,
            manuels: _manuels,
            elevesLibres: _elevesLibres,
            onRattacher: _rattacher,
          ),
        _Etape.ecriture => ProgressionImport(
            rang: _rang,
            total: _aEcrire.length,
            eleve: _encours,
            annule: _annule,
          ),
        _Etape.rapport => RapportImport(rapport: _rapport!),
      };

  Widget _barreActions() {
    final r = _resultat;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(children: [
        if (_etape == _Etape.revue && r != null) ...[
          // Le drapeau qui protège les visages de l'année en cours : réimporter
          // le dossier de l'an dernier ne doit pas les remplacer en silence.
          Checkbox(
            value: _remplacer,
            onChanged: (v) => setState(() {
              _remplacer = v ?? false;
              _manuels.clear();
              _recalculer();
            }),
          ),
          Flexible(
            child: Text('Remplacer les photos existantes',
                style: TextStyle(fontSize: 12.5, color: kTextMuted)),
          ),
        ],
        const Spacer(),
        if (_etape == _Etape.ecriture)
          TextButton(
            onPressed: _annule ? null : () => setState(() => _annule = true),
            child: Text(_annule ? 'Arrêt en cours…' : 'Arrêter'),
          )
        else
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_etape == _Etape.rapport ? 'Fermer' : 'Annuler'),
          ),
        const SizedBox(width: 10),
        if (_etape == _Etape.choix)
          FilledButton.icon(
            onPressed: _choisir,
            style: FilledButton.styleFrom(backgroundColor: kNavy),
            icon: const Icon(Icons.folder_open_rounded, size: 17),
            label: const Text('Choisir les fichiers'),
          ),
        if (_etape == _Etape.revue)
          FilledButton.icon(
            onPressed: _aEcrire.isEmpty ? null : _ecrire,
            style: FilledButton.styleFrom(backgroundColor: kGreen),
            icon: const Icon(Icons.check_rounded, size: 17),
            label: Text(_aEcrire.isEmpty
                ? 'Rien à importer'
                : 'Importer ${_aEcrire.length} photo'
                    '${_aEcrire.length > 1 ? 's' : ''}'),
          ),
      ]),
    );
  }
}
