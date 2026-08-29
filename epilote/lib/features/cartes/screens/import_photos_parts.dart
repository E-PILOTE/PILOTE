import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/cartes_provider.dart';
import '../services/appariement_photos.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LES DEUX PREMIERS TEMPS DE L'IMPORT : choisir les fichiers, puis revoir ce
//  qui va être écrit. Ici, rien n'est encore parti en base et tout se corrige.
//  La suite — pendant et après l'écriture — vit dans `import_photos_fin.dart`.
//
//  Aucune décision dans ce fichier : la logique vit dans
//  `services/appariement_photos.dart`, qui se teste sans rien afficher.
// ════════════════════════════════════════════════════════════════════════════

class EnTeteImport extends StatelessWidget {
  const EnTeteImport(
      {super.key,
      required this.className,
      required this.etape,
      this.onFermer});

  final String className;
  final int etape;
  final VoidCallback? onFermer;

  static const _titres = ['Choisir', 'Vérifier', 'Import en cours', 'Résultat'];

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
        child: Row(children: [
          Icon(Icons.photo_library_rounded, color: kNavy, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Photos — $className',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: kNavy)),
                Text('${etape + 1}/4 · ${_titres[etape]}',
                    style: TextStyle(fontSize: 12, color: kTextMuted)),
              ],
            ),
          ),
          if (onFermer != null)
            IconButton(
                onPressed: onFermer, icon: const Icon(Icons.close_rounded)),
        ]),
      );
}

// ─── 1. Choix ────────────────────────────────────────────────────────────────

class ChoixFichiers extends StatelessWidget {
  const ChoixFichiers({
    super.key,
    required this.eleves,
    required this.className,
    required this.onChoisir,
  });

  final List<CarteEleveRow> eleves;
  final String className;
  final VoidCallback onChoisir;

  @override
  Widget build(BuildContext context) {
    final sansPhoto = eleves.where((e) => !e.aUnePhoto).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$sansPhoto élève${sansPhoto > 1 ? 's' : ''} sans photo sur '
            '${eleves.length} dans $className.',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: kNavy),
          ),
          const SizedBox(height: 14),
          Text(
            'Sélectionnez les fichiers photographiés. Ceux dont le nom porte '
            'le matricule, l’identifiant national ou le nom de l’élève seront '
            'rattachés automatiquement ; les autres — les IMG_0042.JPG sortis '
            'd’un appareil — se rattachent à la main à l’écran suivant, la '
            'vignette à côté du nom.',
            style: TextStyle(fontSize: 13, color: kTextMuted, height: 1.5),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kBorder),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Puce(
                    'Rien n’est écrit avant votre validation, à l’étape '
                    'suivante.'),
                _Puce(
                    'Un rapprochement douteux est écarté, jamais deviné : une '
                    'photo sur le mauvais élève est pire qu’une carte sans '
                    'photo.'),
                _Puce(
                    'Les photos déjà présentes sont conservées, sauf demande '
                    'explicite.'),
                _Puce('Aucun réseau requis : les fichiers montent plus tard.'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: OutlinedButton.icon(
              onPressed: onChoisir,
              icon: const Icon(Icons.folder_open_rounded, size: 18),
              label: const Text('Parcourir…'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Puce extends StatelessWidget {
  const _Puce(this.texte);
  final String texte;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Icon(Icons.circle, size: 5, color: kTextMuted),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(texte,
                style: TextStyle(
                    fontSize: 12.5, color: kTextMuted, height: 1.45)),
          ),
        ]),
      );
}

// ─── 2. Revue ────────────────────────────────────────────────────────────────

class RevueAppariement extends StatelessWidget {
  const RevueAppariement({
    super.key,
    required this.resultat,
    required this.manuels,
    required this.elevesLibres,
    required this.onRattacher,
  });

  final ResultatAppariement resultat;
  final Map<String, CarteEleveRow> manuels;
  final List<CarteEleveRow> elevesLibres;
  final void Function(FichierPhoto, CarteEleveRow?) onRattacher;

  @override
  Widget build(BuildContext context) {
    // Les fichiers sans correspondance sont ceux que l'agent rattache à la
    // main. Ils passent EN PREMIER : c'est le travail qui reste, pas le
    // résidu d'un échec.
    final aLaMain = resultat.ecartes
        .where((e) => e.raison == RaisonEcart.aucuneCorrespondance)
        .toList();
    final autresEcarts = resultat.ecartes
        .where((e) => e.raison != RaisonEcart.aucuneCorrespondance)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      children: [
        if (aLaMain.isNotEmpty) ...[
          _Section('À rattacher', aLaMain.length, kAccent,
              'Ces fichiers ne portent aucune identité. Désignez l’élève.'),
          for (final e in aLaMain)
            _LigneManuelle(
              fichier: e.fichier,
              choisi: manuels[e.fichier.chemin],
              eleves: elevesLibres,
              onChoix: (el) => onRattacher(e.fichier, el),
            ),
          const SizedBox(height: 18),
        ],
        if (resultat.apparies.isNotEmpty) ...[
          _Section('Rattachés automatiquement', resultat.apparies.length,
              kGreen, 'Correspondance exacte, vérifiée dans les deux sens.'),
          for (final p in resultat.apparies) _LigneAuto(p),
          const SizedBox(height: 18),
        ],
        if (autresEcarts.isNotEmpty) ...[
          _Section('Écartés', autresEcarts.length, kTextMuted,
              'Rien ne sera écrit pour ces fichiers.'),
          for (final e in autresEcarts) _LigneEcartee(e),
          const SizedBox(height: 18),
        ],
        if (resultat.elevesRestants.isNotEmpty)
          _Section(
              'Resteront sans photo',
              resultat.elevesRestants.length,
              kTextMuted,
              resultat.elevesRestants.take(12).map((e) => e.fullName).join(', ') +
                  (resultat.elevesRestants.length > 12 ? '…' : '')),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.titre, this.n, this.couleur, this.aide);
  final String titre, aide;
  final int n;
  final Color couleur;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(titre,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: couleur)),
              const SizedBox(width: 8),
              AdminBadge('$n', color: couleur),
            ]),
            const SizedBox(height: 3),
            Text(aide,
                style: TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.4)),
          ],
        ),
      );
}

/// La vignette du fichier — lue depuis le disque, sans réseau.
class _Vignette extends StatelessWidget {
  const _Vignette(this.fichier);
  final FichierPhoto fichier;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Image.file(
          File(fichier.chemin),
          width: 34,
          height: 42,
          fit: BoxFit.cover,
          cacheWidth: 96,
          errorBuilder: (_, _, _) => Container(
            width: 34,
            height: 42,
            color: kSurface,
            child: Icon(Icons.broken_image_outlined, size: 16, color: kRed),
          ),
        ),
      );
}

class _LigneAuto extends StatelessWidget {
  const _LigneAuto(this.p);
  final PhotoAppariee p;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          _Vignette(p.fichier),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.eleve.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text('${p.fichier.nom} · ${libelleCle(p.cle)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: kTextMuted)),
              ],
            ),
          ),
          Icon(Icons.check_circle_rounded, size: 18, color: kGreen),
        ]),
      );
}

class _LigneEcartee extends StatelessWidget {
  const _LigneEcartee(this.e);
  final PhotoEcartee e;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          _Vignette(e.fichier),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.fichier.nom,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13)),
                Text(
                  e.eleve == null
                      ? libelleRaison(e.raison)
                      : '${libelleRaison(e.raison)} — ${e.eleve!.fullName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: kTextMuted),
                ),
              ],
            ),
          ),
        ]),
      );
}

class _LigneManuelle extends StatelessWidget {
  const _LigneManuelle({
    required this.fichier,
    required this.choisi,
    required this.eleves,
    required this.onChoix,
  });

  final FichierPhoto fichier;
  final CarteEleveRow? choisi;
  final List<CarteEleveRow> eleves;
  final ValueChanged<CarteEleveRow?> onChoix;

  @override
  Widget build(BuildContext context) {
    // L'élève déjà choisi sort de `elevesLibres` : il faut le remettre dans la
    // liste, sinon le menu n'a plus de quoi afficher sa propre valeur.
    final options = <CarteEleveRow>[
      ?choisi,
      ...eleves.where((e) => e.studentId != choisi?.studentId),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        _Vignette(fichier),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Text(fichier.nom,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5)),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<CarteEleveRow?>(
            initialValue: choisi,
            isExpanded: true,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(),
              hintText: 'Aucun élève',
            ),
            items: [
              const DropdownMenuItem<CarteEleveRow?>(
                  value: null, child: Text('— ignorer ce fichier —')),
              for (final e in options)
                DropdownMenuItem<CarteEleveRow?>(
                  value: e,
                  child: Text(e.fullName,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: onChoix,
          ),
        ),
      ]),
    );
  }
}

