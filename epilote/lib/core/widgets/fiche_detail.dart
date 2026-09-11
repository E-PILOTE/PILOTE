import 'package:flutter/material.dart';

import '../services/fiche_detail_pdf.dart';
import 'admin_modal_shapes.dart';
import 'admin_tokens.dart';
import 'fiche_detail_model.dart';
import 'pdf_preview_dialog.dart';

export 'fiche_detail_model.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA MODALE DE DÉTAIL — cherchable, cliquable, imprimable, et sans plafond
//
//  ── LES TROIS PROPRIÉTÉS QUI COMPTENT ─────────────────────────────────────
//  1. VIRTUALISÉE. `ListView.builder` sur une liste APLATIE : mille écoles ne
//     construisent que ce qui tient à l'écran. C'est la seule raison pour
//     laquelle plus rien n'est tronqué — et donc la seule raison pour laquelle
//     les chiffres de la modale restent vrais quand le réseau grossit.
//  2. CHERCHABLE dès qu'il y a de quoi chercher. Un champ de recherche sur six
//     lignes est du bruit ; son absence sur trois cents est une impasse.
//  3. IMPRIMABLE — et l'aperçu vient AVANT l'impression : on voit le document
//     avant d'envoyer quoi que ce soit à une imprimante.
//
//  ── ⚠️ CE QUI EST IMPRIMÉ EST CE QUI EST AFFICHÉ ──────────────────────────
//  Filtre actif ⇒ document filtré, et le document le dit en toutes lettres.
//  L'inverse — imprimer tout pendant que l'écran montre trois lignes — produit
//  un document que personne n'a relu.
// ════════════════════════════════════════════════════════════════════════════

/// Nombre de lignes à partir duquel la recherche apparaît.
const int kSeuilRechercheFiche = 12;

Future<void> ouvrirFicheDetail(BuildContext context, FicheDetail fiche) =>
    showDialog<void>(
      context: context,
      builder: (_) => _FicheDetailDialog(fiche: fiche),
    );

class _FicheDetailDialog extends StatefulWidget {
  const _FicheDetailDialog({required this.fiche});

  final FicheDetail fiche;

  @override
  State<_FicheDetailDialog> createState() => _FicheDetailDialogState();
}

class _FicheDetailDialogState extends State<_FicheDetailDialog> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.fiche;
    final f = source.filtree(_q.text);
    final rangees = _aplatir(f);
    final chercher = source.nbLignes >= kSeuilRechercheFiche;

    return AdminFormDialog(
      icon: f.icone,
      title: f.titre,
      subtitle: f.sousTitre,
      accent: f.couleur,
      width: 640,
      maxHeight: 760,
      scrollable: false,
      bodyPadding: EdgeInsets.zero,
      hero: _Bandeau(fiche: f),
      body: Column(mainAxisSize: MainAxisSize.min, children: [
        if (chercher)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: TextField(
              controller: _q,
              onChanged: (_) => setState(() {}),
              decoration: adminInputDecoration(
                'Rechercher',
                icon: Icons.search_rounded,
                hint: 'Département, établissement, groupe…',
              ).copyWith(
                isDense: true,
                suffixIcon: _q.text.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(Icons.close_rounded,
                            size: 17, color: kTextMuted),
                        onPressed: () => setState(_q.clear),
                      ),
              ),
            ),
          ),
        if (f.barres.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 2),
            child: Column(children: [
              for (final b in f.barres) ...[
                _Barre(barre: b),
                const SizedBox(height: 9),
              ],
            ]),
          ),
        Flexible(
          child: rangees.isEmpty
              ? _Vide(filtre: f.filtre)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  itemCount: rangees.length,
                  itemBuilder: (_, i) => rangees[i].build(context),
                ),
        ),
      ]),
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        child: Row(children: [
          Expanded(
            child: Text(
              _compte(source, f),
              style: TextStyle(fontSize: 11.5, color: kTextMuted),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _imprimer(context, f),
            icon: const Icon(Icons.print_outlined, size: 16),
            label: const Text('Imprimer'),
            style: OutlinedButton.styleFrom(
              foregroundColor: f.couleur,
              side: BorderSide(color: f.couleur.withValues(alpha: 0.45)),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Fermer', style: TextStyle(color: kTextMuted)),
          ),
        ]),
      ),
    );
  }

  String _compte(FicheDetail source, FicheDetail vue) {
    if (source.nbLignes == 0) return '';
    if (vue.filtre.isEmpty) {
      return '${vue.nbLignes} ligne${vue.nbLignes > 1 ? 's' : ''}';
    }
    return '${vue.nbLignes} sur ${source.nbLignes} · l’impression suivra ce '
        'filtre';
  }

  void _imprimer(BuildContext context, FicheDetail f) => showPdfPreviewDialog(
        context,
        title: f.titre,
        subtitle: [
          if ((f.sousTitre ?? '').isNotEmpty) f.sousTitre!,
          if (f.filtre.isNotEmpty) 'filtré sur « ${f.filtre} »',
        ].join(' · '),
        build: (_) => FicheDetailPdf.build(f),
        pdfFileName: '${f.nomFichier}.pdf',
        accent: f.couleur,
      );
}

// ─── Aplatissement : une seule liste, donc une seule virtualisation ─────────
//
//  ⚠️ Un `Column` de sections dans un `SingleChildScrollView` construirait TOUT
//  — c'est exactement ce qu'on remplace. Les titres de section deviennent donc
//  des éléments de la liste comme les autres.
List<_Rangee> _aplatir(FicheDetail f) {
  final out = <_Rangee>[];
  for (final s in f.sections) {
    // Une section entièrement vidée par la recherche disparaît : garder son
    // titre au-dessus du vide fait croire à une donnée manquante.
    if (s.lignes.isEmpty && f.filtre.isNotEmpty) continue;
    out.add(_Rangee.section(s.titre, s.enTetesEffectifs, s.nbColonnes));
    if (s.lignes.isEmpty) {
      out.add(_Rangee.note(s.videLabel));
    } else {
      for (final l in s.lignes) {
        out.add(_Rangee.ligne(l));
      }
    }
    if ((s.note ?? '').isNotEmpty) out.add(_Rangee.note(s.note!));
  }
  for (final n in f.notes) {
    out.add(_Rangee.note(n));
  }
  return out;
}

class _Rangee {
  const _Rangee.section(this.section, this.enTetes, this.nbColonnes)
      : ligne = null,
        note = null;
  const _Rangee.ligne(this.ligne)
      : section = null,
        note = null,
        enTetes = const [],
        nbColonnes = 0;
  const _Rangee.note(this.note)
      : section = null,
        ligne = null,
        enTetes = const [],
        nbColonnes = 0;

  final String? section, note;
  final LigneFiche? ligne;
  final List<String> enTetes;
  final int nbColonnes;

  Widget build(BuildContext context) {
    if (section != null) {
      return _TitreSection(
          texte: section!, enTetes: enTetes, nbColonnes: nbColonnes);
    }
    if (note != null) return _Note(texte: note!);
    return _Ligne(ligne: ligne!);
  }
}

// ─── Pièces ─────────────────────────────────────────────────────────────────

class _Bandeau extends StatelessWidget {
  const _Bandeau({required this.fiche});

  final FicheDetail fiche;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: BoxDecoration(
          color: fiche.couleur.withValues(alpha: 0.06),
          border: Border(bottom: BorderSide(color: kBorder)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(fiche.totalLabel.toUpperCase(),
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: kTextMuted)),
            const Spacer(),
            Text(fiche.total,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: kTextPrimary)),
          ]),
          if (fiche.chiffres.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (label, valeur) in fiche.chiffres)
                  _Pastille(label: label, valeur: valeur),
              ],
            ),
          ],
        ]),
      );
}

class _Pastille extends StatelessWidget {
  const _Pastille({required this.label, required this.valeur});

  final String label, valeur;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: kCardBg,
          border: Border.all(color: kBorder),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(valeur,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 11, color: kTextMuted)),
        ]),
      );
}

class _TitreSection extends StatelessWidget {
  const _TitreSection(
      {required this.texte, required this.enTetes, required this.nbColonnes});

  final String texte;
  final List<String> enTetes;
  final int nbColonnes;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Row(children: [
          Expanded(
            child: Text(texte.toUpperCase(),
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: kTextMuted)),
          ),
          // Les en-têtes des colonnes chiffrées : sans eux, « 412 · 28 » à
          // droite d'un nom d'école ne veut rien dire.
          if (nbColonnes > 0)
            for (final e in enTetes.skip(1))
              SizedBox(
                width: 74,
                child: Text(e.toUpperCase(),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: kTextMuted)),
              ),
        ]),
      );
}

class _Ligne extends StatelessWidget {
  const _Ligne({required this.ligne});

  final LigneFiche ligne;

  @override
  Widget build(BuildContext context) {
    final cliquable = ligne.onTap != null;
    final contenu = Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: BoxDecoration(
        color: kCardBg,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(ligne.titre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: kTextPrimary)),
                if ((ligne.sousTitre ?? '').isNotEmpty)
                  Text(ligne.sousTitre!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: kTextMuted)),
              ]),
        ),
        for (final c in ligne.colonnes)
          SizedBox(
            width: 74,
            child: Text(c,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: kTextMuted)),
          ),
        SizedBox(
          width: 74,
          child: Text(ligne.valeur,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary)),
        ),
        // ⚠️ Le chevron n'est pas décoratif : un détail qui ne se signale pas
        // ne se clique pas, et personne ne le trouve jamais.
        if (cliquable) ...[
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, size: 18, color: kTextMuted),
        ],
      ]),
    );

    if (!cliquable) return contenu;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => ligne.onTap!(context),
        child: contenu,
      ),
    );
  }
}

class _Barre extends StatelessWidget {
  const _Barre({required this.barre});

  final BarreFiche barre;

  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox(
          width: 118,
          child: Text(barre.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: kTextMuted)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: barre.valeur.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: barre.couleur.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(barre.couleur),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 40,
          child: Text('${(barre.valeur * 100).round()} %',
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w800)),
        ),
      ]);
}

class _Note extends StatelessWidget {
  const _Note({required this.texte});

  final String texte;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 12),
        child: Text(texte,
            style: TextStyle(fontSize: 12, color: kTextMuted, height: 1.5)),
      );
}

class _Vide extends StatelessWidget {
  const _Vide({required this.filtre});

  final String filtre;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            filtre.isEmpty
                ? 'Rien à afficher pour l’instant.'
                : 'Aucune ligne ne correspond à « $filtre ».',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: kTextMuted),
          ),
        ),
      );
}
