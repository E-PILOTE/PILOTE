import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/import_eleves_provider.dart';
import 'import_classe_picker.dart';

// ════════════════════════════════════════════════════════════════════════════
//  « CLASSE INCONNUE » — LA RÉPARER ICI, PAS DANS EXCEL
//
//  ── LE DÉFAUT QUE CE PANNEAU CORRIGE ───────────────────────────────────────
//  Le rapprochement de classe est volontairement STRICT : `cleClasse` réunit
//  « 6e A », « 6ème A » et « 6EME A », mais refuse d'aller plus loin, parce
//  qu'envoyer un enfant en 6ᵉ B au lieu de 6ᵉ A ne se découvre qu'au conseil de
//  classe. Cette sévérité est juste et on n'y touche pas.
//
//  Mais elle n'avait AUCUNE porte de sortie. Une école qui a créé « 6e A » et
//  dont le classeur porte « 6A » voyait ses quarante lignes rejetées avec
//  « créez-la, ou corrigez le fichier » : il fallait fermer la fenêtre, rouvrir
//  Excel, faire un chercher-remplacer, réenregistrer en CSV, tout recommencer.
//  À la rentrée, avec trois cents élèves à saisir, c'est le moment où l'on
//  renonce au logiciel et où l'on ressort le cahier.
//
//  ── UNE LIGNE PAR LIBELLÉ, PAS PAR ÉLÈVE ───────────────────────────────────
//  Quarante élèves en « 6A », c'est UN problème, pas quarante. Le panneau
//  regroupe donc par libellé et annonce le nombre de lignes que chaque
//  correspondance débloque : on voit ce qu'on répare avant de le réparer.
//
//  ── CE N'EST PAS UN RAPPROCHEMENT AUTOMATIQUE ──────────────────────────────
//  ⚠️ Rien n'est pré-sélectionné, et rien ne se devine. Un humain lit le
//  libellé, choisit la classe, et voit combien d'élèves il déplace. La
//  tolérance reste dans la tête de celui qui décide, jamais dans le code.
// ════════════════════════════════════════════════════════════════════════════

class CorrespondanceClasses extends StatelessWidget {
  const CorrespondanceClasses({
    super.key,
    required this.inconnus,
    required this.classes,
    required this.correspondances,
    required this.onChanged,
  });

  /// Les libellés non reconnus, du plus bloquant au moins bloquant.
  final List<LibelleInconnu> inconnus;

  /// Les classes ouvertes de l'école — les seules destinations possibles.
  final List<ClasseCible> classes;

  /// Clé normalisée du libellé → identifiant de classe déjà choisi.
  final Map<String, String> correspondances;

  /// `null` pendant l'écriture : on regarde, on ne touche plus.
  final void Function(String libelle, String? classeId)? onChanged;

  @override
  Widget build(BuildContext context) {
    if (inconnus.isEmpty) return const SizedBox.shrink();

    final bloquees = inconnus.fold<int>(0, (s, i) => s + i.lignes);
    final resolus = inconnus
        .where((i) => correspondances.containsKey(cleClasse(i.libelle)))
        .length;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: kAccent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kAccent.withValues(alpha: 0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.rule_folder_outlined, size: 17, color: kAccent),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      inconnus.length == 1
                          ? 'Un libellé de classe ne correspond à aucune '
                              'classe de l\'école'
                          : '${inconnus.length} libellés de classe ne '
                              'correspondent à aucune classe de l\'école',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: kTextPrimary)),
                  const SizedBox(height: 3),
                  Text(
                      'Indiquez la classe visée : '
                      '$bloquees ligne${bloquees > 1 ? 's' : ''} '
                      '${bloquees > 1 ? 'redeviennent' : 'redevient'} '
                      'importable${bloquees > 1 ? 's' : ''} sans toucher au '
                      'fichier.',
                      style: TextStyle(
                          fontSize: 11.5, color: kTextMuted, height: 1.4)),
                ]),
          ),
          if (resolus > 0)
            Padding(
              padding: const EdgeInsets.only(left: 10, top: 2),
              child: Text('$resolus/${inconnus.length}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: kGreen)),
            ),
        ]),
        const SizedBox(height: 12),
        for (final i in inconnus)
          _Rang(
            inconnu: i,
            classes: classes,
            valeur: correspondances[cleClasse(i.libelle)],
            onChanged: onChanged == null
                ? null
                : (id) => onChanged!(i.libelle, id),
          ),
      ]),
    );
  }
}

class _Rang extends StatelessWidget {
  const _Rang({
    required this.inconnu,
    required this.classes,
    required this.valeur,
    required this.onChanged,
  });

  final LibelleInconnu inconnu;
  final List<ClasseCible> classes;
  final String? valeur;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final resolu = valeur != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                  color: resolu
                      ? kGreen.withValues(alpha: 0.45)
                      : kBorder),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (resolu) ...[
                Icon(Icons.check_rounded, size: 13, color: kGreen),
                const SizedBox(width: 5),
              ],
              Text('« ${inconnu.libelle} »',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary)),
              const SizedBox(width: 7),
              Text(
                  '${inconnu.lignes} ligne${inconnu.lignes > 1 ? 's' : ''}',
                  style: TextStyle(fontSize: 11, color: kTextMuted)),
            ]),
          ),
          Icon(Icons.arrow_forward_rounded, size: 15, color: kTextMuted),
          SelecteurClasseFiltre(
            classes: classes,
            valeur: valeur,
            onChanged: onChanged,
            hint: 'Classe de l\'école…',
          ),
        ],
      ),
    );
  }
}
