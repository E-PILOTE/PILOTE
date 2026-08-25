// ════════════════════════════════════════════════════════════════════════════
//  LE MODÈLE VIENT D'ÊTRE ÉCRIT — dire QUOI et OÙ
//
//  Séparé de `import_eleves_parts.dart`, qui portait déjà les trois temps de
//  l'import : ajouter ce panneau l'aurait poussé au-delà des 500 lignes, et il
//  répond à une autre question — non pas « qu'a compris la machine ? » mais
//  « où est mon fichier ? ».
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import '../services/modele_import_csv.dart';

/// L'offre des deux fichiers d'aide, et le compte rendu une fois écrits.
///
/// ── POURQUOI CE N'EST PLUS UN LIEN DISCRET ─────────────────────────────────
/// ⚠️ Ce bloc reste VISUELLEMENT SECOND — « Choisir un fichier » garde le
/// bouton plein, parce que presque toutes les écoles tiennent déjà une liste et
/// que les faire retaper trois cents élèves serait exactement ce que l'import
/// existe pour éviter. L'ordre de priorité ne change pas.
///
/// Ce qui change, c'est l'INTITULÉ. « Pas encore de liste ? » posait une
/// question dont la plupart des écoles répondaient « non » — et elles
/// passaient à côté du fichier des libellés de classe, qui est justement ce qui
/// leur manque quand l'import rejette la moitié des lignes. On nomme donc les
/// deux fichiers et à quoi ils servent, sans filtrer le lecteur à l'entrée.
class OffreModele extends StatelessWidget {
  const OffreModele({
    super.key,
    required this.enCours,
    required this.onTelecharger,
    required this.nbClasses,
    required this.modele,
  });

  final bool enCours;
  final VoidCallback onTelecharger;
  final int nbClasses;
  final ModeleImport? modele;

  @override
  Widget build(BuildContext context) {
    final m = modele;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.help_outline_rounded, size: 17, color: kNavy),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Besoin d\'un point de départ ?',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: kTextPrimary)),
                  const SizedBox(height: 4),
                  Text(
                      nbClasses == 0
                          ? 'Nous pouvons écrire un modèle vide aux bonnes '
                              'colonnes, prêt à remplir.'
                          : 'Nous pouvons écrire deux fichiers : un modèle aux '
                              'bonnes colonnes, et la liste des '
                              '$nbClasses classe${nbClasses > 1 ? 's' : ''} de '
                              'votre école — à recopier dans la colonne '
                              '« Classe » pour qu\'aucune ligne ne soit '
                              'rejetée.',
                      style: TextStyle(
                          fontSize: 11.5, color: kTextMuted, height: 1.45)),
                ]),
          ),
        ]),
        const SizedBox(height: 12),
        AdminActionButton(
          label: enCours
              ? 'Enregistrement…'
              : m == null
                  ? 'Télécharger'
                  : 'Télécharger à nouveau',
          icon: Icons.download_outlined,
          filled: false,
          onPressed: enCours ? () {} : onTelecharger,
        ),
        if (m != null) ...[
          const SizedBox(height: 12),
          ModeleTelecharge(modele: m, nbClasses: nbClasses),
        ],
      ]),
    );
  }
}


/// Ce qui vient d'être écrit sur le disque, et à quoi chaque fichier sert.
///
/// ⚠️ On NOMME les deux fichiers et on donne le dossier. Un « modèle
/// téléchargé ✓ » sans chemin oblige l'école à fouiller ses Documents ; et
/// comme rien ne s'ouvre tout seul sur un poste d'école, elle abandonne.
class ModeleTelecharge extends StatelessWidget {
  const ModeleTelecharge(
      {super.key, required this.modele, required this.nbClasses});

  final ModeleImport modele;
  final int nbClasses;

  String get _dossier {
    final i = modele.modele.lastIndexOf(RegExp(r'[\/]'));
    return i <= 0 ? modele.modele : modele.modele.substring(0, i);
  }

  String _nom(String chemin) {
    final i = chemin.lastIndexOf(RegExp(r'[\/]'));
    return i < 0 ? chemin : chemin.substring(i + 1);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kGreen.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGreen.withValues(alpha: 0.28)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.check_circle_outline_rounded, size: 17, color: kGreen),
          const SizedBox(width: 8),
          Text('Enregistré dans vos Documents',
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w800, color: kGreen)),
        ]),
        const SizedBox(height: 10),
        _Fichier(
          nom: _nom(modele.modele),
          role: "les colonnes à remplir, avec deux lignes d'exemple à "
              'supprimer',
        ),
        if (modele.classes != null)
          _Fichier(
            nom: _nom(modele.classes!),
            role: nbClasses <= 1
                ? 'le libellé exact de votre classe — à recopier tel quel dans '
                    'la colonne « Classe »'
                : 'les $nbClasses libellés de classe de votre école, avec '
                    'niveau et filière — à recopier TELS QUELS dans la colonne '
                    '« Classe »',
          ),
        const SizedBox(height: 8),
        SelectableText(_dossier,
            style: TextStyle(fontSize: 10.5, color: kTextMuted, height: 1.3)),
      ]),
    );
  }
}

class _Fichier extends StatelessWidget {
  const _Fichier({required this.nom, required this.role});
  final String nom, role;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.description_outlined, size: 14, color: kTextMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(TextSpan(children: [
              TextSpan(
                  text: nom,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary)),
              TextSpan(
                  text: '  —  $role',
                  style: TextStyle(fontSize: 11.5, color: kTextMuted)),
            ]), style: const TextStyle(height: 1.4)),
          ),
        ]),
      );
}
