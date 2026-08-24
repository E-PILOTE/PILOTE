import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/import_eleves_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CHOISIR UNE CLASSE DANS UNE LISTE QUI PEUT ÊTRE LONGUE
//
//  ── NIVEAU ET FILIÈRE FILTRENT, ILS N'ENREGISTRENT RIEN ────────────────────
//  ⚠️ C'est la règle de ce fichier, et elle n'est pas négociable. Un élève est
//  rattaché par le SEUL identifiant de classe : `ClasseCible` documente déjà
//  pourquoi — deux façons de désigner la même classe, c'est la possibilité
//  qu'elles se contredisent. Choisir « Tle D » dit déjà le niveau et la
//  filière ; ajouter des sélecteurs qui les redisent ouvrirait la question
//  « niveau Seconde + classe Tle D, lequel gagne ? », qui n'a pas de bonne
//  réponse.
//
//  Ces deux menus ne sortent donc jamais d'ici : ils RESTREIGNENT la liste
//  affichée, et la valeur remontée reste l'identifiant de la classe.
//
//  ── ILS N'APPARAISSENT PAS TOUJOURS ────────────────────────────────────────
//  Une école primaire de six classes n'a pas besoin qu'on filtre six lignes ;
//  deux menus de plus y seraient du bruit. Ils ne se montrent qu'au-delà du
//  seuil où une liste plate devient pénible, et seulement si le critère
//  partage réellement les classes en deux groupes ou plus.
// ════════════════════════════════════════════════════════════════════════════

/// Au-delà de ce nombre de classes, une liste déroulante plate devient pénible
/// à parcourir — un lycée congolais complet dépasse largement.
const int _kSeuilFiltres = 10;

class SelecteurClasseFiltre extends StatefulWidget {
  const SelecteurClasseFiltre({
    super.key,
    required this.classes,
    required this.valeur,
    required this.onChanged,
    this.hint = 'Choisir…',
    this.largeur = 240,
  });

  final List<ClasseCible> classes;

  /// Identifiant de la classe retenue, ou `null`.
  final String? valeur;

  /// `null` désactive le sélecteur (écriture en cours).
  final ValueChanged<String?>? onChanged;

  final String hint;
  final double largeur;

  @override
  State<SelecteurClasseFiltre> createState() => _SelecteurClasseFiltreState();
}

class _SelecteurClasseFiltreState extends State<SelecteurClasseFiltre> {
  String? _niveau;
  String? _filiere;

  List<String> _valeursDe(String? Function(ClasseCible) champ) {
    final s = <String>{
      for (final c in widget.classes)
        if ((champ(c) ?? '').trim().isNotEmpty) champ(c)!.trim(),
    }.toList()
      ..sort();
    return s;
  }

  List<ClasseCible> get _visibles => [
        for (final c in widget.classes)
          if ((_niveau == null || (c.niveau ?? '').trim() == _niveau) &&
              (_filiere == null || (c.filiere ?? '').trim() == _filiere))
            c,
      ];

  /// Un filtre vient de changer : si la classe déjà choisie n'est plus dans la
  /// liste, on la relâche TOUT DE SUITE.
  ///
  /// ⚠️ Laisser une valeur absente des items ferait sauter l'assertion de
  /// `DropdownButton`, et la corriger pendant le `build` est interdit — d'où ce
  /// nettoyage dans le gestionnaire d'événement, où il est légal.
  void _appliquer(void Function() muter) {
    setState(muter);
    final v = widget.valeur;
    if (v != null && !_visibles.any((c) => c.id == v)) {
      widget.onChanged?.call(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final niveaux = _valeursDe((c) => c.niveau);
    final filieres = _valeursDe((c) => c.filiere);
    final assezLong = widget.classes.length >= _kSeuilFiltres;
    final montreNiveau = assezLong && niveaux.length >= 2;
    final montreFiliere = assezLong && filieres.length >= 2;
    final visibles = _visibles;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (montreNiveau)
          _Filtre(
            libelle: 'Niveau',
            valeur: _niveau,
            valeurs: niveaux,
            onChanged: widget.onChanged == null
                ? null
                : (v) => _appliquer(() => _niveau = v),
          ),
        if (montreFiliere)
          _Filtre(
            libelle: 'Filière',
            valeur: _filiere,
            valeurs: filieres,
            onChanged: widget.onChanged == null
                ? null
                : (v) => _appliquer(() => _filiere = v),
          ),
        SizedBox(
          width: widget.largeur,
          child: DropdownButtonFormField<String>(
            // La clé porte les filtres ET la valeur : `DropdownButtonFormField`
            // garde son état interne, et sans reconstruction il continuerait
            // d'afficher une classe que le filtre vient d'écarter.
            key: ValueKey('${_niveau ?? ''}|${_filiere ?? ''}|'
                '${widget.valeur ?? ''}|${visibles.length}'),
            initialValue: visibles.any((c) => c.id == widget.valeur)
                ? widget.valeur
                : null,
            isDense: true,
            isExpanded: true,
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              hintText: visibles.isEmpty ? 'Aucune classe' : widget.hint,
            ),
            items: [
              for (final c in visibles)
                DropdownMenuItem(
                    value: c.id,
                    child: Text(c.nom, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: visibles.isEmpty ? null : widget.onChanged,
          ),
        ),
      ],
    );
  }
}

/// Un menu de restriction. « Tous » le relâche.
class _Filtre extends StatelessWidget {
  const _Filtre({
    required this.libelle,
    required this.valeur,
    required this.valeurs,
    required this.onChanged,
  });

  final String libelle;
  final String? valeur;
  final List<String> valeurs;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 170,
        child: DropdownButtonFormField<String?>(
          key: ValueKey('$libelle|${valeur ?? ''}'),
          initialValue: valeur,
          isDense: true,
          isExpanded: true,
          decoration: InputDecoration(
            isDense: true,
            labelText: libelle,
            labelStyle: TextStyle(fontSize: 12, color: kTextMuted),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          items: [
            DropdownMenuItem(value: null, child: Text('Tous', style: TextStyle(color: kTextMuted))),
            for (final v in valeurs)
              DropdownMenuItem(
                  value: v, child: Text(v, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: onChanged,
        ),
      );
}
