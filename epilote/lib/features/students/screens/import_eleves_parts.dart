// ════════════════════════════════════════════════════════════════════════════
//  IMPORT D'ÉLÈVES — LES PIÈCES DE L'ÉCRAN
//
//  Séparées du dialogue lui-même, qui n'orchestre que les trois temps. Ici, la
//  seule chose qui compte : montrer honnêtement ce que la machine a compris,
//  y compris ce qu'elle a laissé de côté.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/import_eleves_provider.dart';
import 'import_classe_picker.dart';

/// Ce que l'école doit préparer avant de cliquer.
class ModeEmploiImport extends StatelessWidget {
  const ModeEmploiImport({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kNavy.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kNavy.withValues(alpha: 0.16)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Depuis votre classeur Excel',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800, color: kNavy)),
        const SizedBox(height: 8),
        const _Etape('1', 'Fichier ▸ Enregistrer sous ▸ CSV.'),
        const _Etape('2',
            'La première ligne doit porter les noms des colonnes : '
            'Nom, Prénom, Date de naissance, Sexe.'),
        const _Etape('3',
            'Ajoutez « Classe » si le tableau mélange plusieurs classes ; '
            'sinon vous choisirez la classe d\'accueil à l\'étape suivante.'),
        const SizedBox(height: 10),
        Text('Rien n\'est enregistré tant que vous n\'avez pas vu et validé '
            'le tableau. Les colonnes que nous ne savons pas lire vous seront '
            'nommées.',
            style: TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.45)),
      ]),
    );
  }
}

class _Etape extends StatelessWidget {
  const _Etape(this.n, this.texte);
  final String n, texte;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: kNavy, shape: BoxShape.circle),
            child: Text(n,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(texte,
                style: const TextStyle(fontSize: 12, height: 1.4)),
          ),
        ]),
      );
}

/// Le compte, et surtout ce que la machine a laissé de côté.
class ResumeImport extends StatelessWidget {
  const ResumeImport({super.key, required this.prep});
  final PreparationImport prep;

  @override
  Widget build(BuildContext context) {
    final ignorees = prep.lecture.colonnesIgnorees;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 10, runSpacing: 10, children: [
        _Compteur('${prep.retenues.length}', 'à inscrire', kGreen),
        if (prep.rejetees.isNotEmpty)
          _Compteur('${prep.rejetees.length}', 'bloquées', kRed),
        if (prep.aVerifier.isNotEmpty)
          _Compteur('${prep.aVerifier.length}', 'à relire', kAccent),
      ]),
      const SizedBox(height: 12),
      Text(
        'Colonnes lues : '
        '${prep.lecture.colonnesReconnues.keys.join(" · ")}',
        style: TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.4),
      ),
      if (ignorees.isNotEmpty) ...[
        const SizedBox(height: 6),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline_rounded, size: 14, color: kAccent),
          const SizedBox(width: 6),
          Expanded(
            // Une colonne « Téléphone parent » abandonnée en silence fait
            // croire à l'école que les numéros sont dans le système.
            child: Text(
              'Non repris : ${ignorees.join(" · ")}. '
              'Ces informations ne seront pas enregistrées.',
              style: TextStyle(fontSize: 11.5, color: kAccent, height: 1.4),
            ),
          ),
        ]),
      ],
    ]);
  }
}

class _Compteur extends StatelessWidget {
  const _Compteur(this.valeur, this.libelle, this.couleur);
  final String valeur, libelle;
  final Color couleur;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: couleur.withValues(alpha: 0.32)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(valeur,
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w900, color: couleur)),
          const SizedBox(width: 7),
          Text(libelle, style: TextStyle(fontSize: 12, color: couleur)),
        ]),
      );
}

/// La classe d'accueil, quand le fichier n'en nomme pas.
class ChoixClasseAccueil extends StatelessWidget {
  const ChoixClasseAccueil({
    super.key,
    required this.classes,
    required this.valeur,
    required this.actif,
    required this.onChanged,
  });

  final List<ClasseCible> classes;
  final String? valeur;
  final bool actif;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    if (!actif) {
      return Row(children: [
        Icon(Icons.check_circle_outline_rounded, size: 15, color: kGreen),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
              'Le fichier indique la classe de chaque élève : elle sera '
              'utilisée telle quelle.',
              style: TextStyle(fontSize: 12, color: kTextMuted)),
        ),
      ]);
    }
    if (classes.isEmpty) {
      return const AdminErrorBanner(
          message: 'Aucune classe ouverte pour l\'année en cours. '
              'Créez les classes avant d\'importer les élèves.');
    }
    // Le sélecteur filtrant est partagé avec le panneau de correspondance :
    // un lycée complet dépasse la trentaine de classes, et une liste plate y
    // devient un défilement à l'aveugle. Niveau et filière n'y RESTREIGNENT que
    // l'affichage — la valeur retenue reste l'identifiant de la classe.
    return Wrap(
      spacing: 14,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('Classe d\'accueil',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: kTextPrimary)),
        SelecteurClasseFiltre(
          classes: classes,
          valeur: valeur,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Le tableau ligne à ligne. Les bloquées d'abord : ce sont elles qu'on va
/// corriger, et les faire chercher au milieu de trois cents lignes vertes
/// revient à ne pas les montrer.
class TableauLignes extends StatelessWidget {
  const TableauLignes({super.key, required this.prep});
  final PreparationImport prep;

  @override
  Widget build(BuildContext context) {
    final ordre = [...prep.rejetees, ...prep.retenues];
    if (ordre.isEmpty) {
      return const AdminEmptyState(
        icon: Icons.table_rows_outlined,
        title: 'Aucune ligne',
        message: 'Le fichier ne contient aucun élève.',
      );
    }
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(9)),
          ),
          child: Row(children: [
            _entete('Ligne', 52),
            _entete('Élève', 220),
            _entete('Naissance', 96),
            _entete('Classe', 96),
            Expanded(child: _entete('Vérification', null)),
          ]),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: ordre.length,
            itemBuilder: (_, i) => _LigneVue(r: ordre[i], paire: i.isEven),
          ),
        ),
      ]),
    );
  }

  Widget _entete(String t, double? w) {
    final txt = Text(t,
        style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: kTextMuted,
            letterSpacing: 0.4));
    return w == null ? txt : SizedBox(width: w, child: txt);
  }
}

class _LigneVue extends StatelessWidget {
  const _LigneVue({required this.r, required this.paire});
  final LigneResolue r;
  final bool paire;

  @override
  Widget build(BuildContext context) {
    final l = r.ligne;
    final bloquee = !r.retenue;
    final aRelire = r.retenue && l.nomDevine;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: bloquee
          ? kRed.withValues(alpha: 0.05)
          : (paire ? Colors.transparent : kSurface.withValues(alpha: 0.45)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 52,
          child: Text('${l.numero}',
              style: TextStyle(fontSize: 11.5, color: kTextMuted)),
        ),
        SizedBox(
          width: 220,
          child: Text(
            l.nomAffiche.isEmpty ? '—' : l.nomAffiche,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: bloquee ? kTextMuted : kTextPrimary,
            ),
          ),
        ),
        SizedBox(
          width: 96,
          child: Text(
            l.dateNaissance == null
                ? '—'
                : '${l.dateNaissance!.day.toString().padLeft(2, '0')}/'
                    '${l.dateNaissance!.month.toString().padLeft(2, '0')}/'
                    '${l.dateNaissance!.year}',
            style: TextStyle(fontSize: 11.5, color: kTextMuted),
          ),
        ),
        SizedBox(
          width: 96,
          child: Text(r.classeNom ?? l.classeTexte ?? '—',
              style: TextStyle(fontSize: 11.5, color: kTextMuted)),
        ),
        Expanded(
          child: bloquee
              ? Text(l.rejets.map((m) => m.texte).join(' · '),
                  style: TextStyle(fontSize: 11.5, color: kRed, height: 1.35))
              : aRelire
                  ? Text(
                      'Nom et prénom séparés automatiquement — à relire',
                      style: TextStyle(fontSize: 11.5, color: kAccent))
                  : Row(children: [
                      Icon(Icons.check_rounded, size: 13, color: kGreen),
                      const SizedBox(width: 5),
                      Text('Prêt',
                          style: TextStyle(fontSize: 11.5, color: kGreen)),
                    ]),
        ),
      ]),
    );
  }
}

/// Ce que l'écriture a donné.
class BilanImportVue extends StatelessWidget {
  const BilanImportVue({super.key, required this.bilan});
  final BilanImport bilan;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(bilan.parfait ? Icons.check_circle_rounded : Icons.warning_rounded,
            size: 26, color: bilan.parfait ? kGreen : kAccent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                '${bilan.importes} élève${bilan.importes > 1 ? "s" : ""} '
                'inscrit${bilan.importes > 1 ? "s" : ""}',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: kNavy)),
            const SizedBox(height: 3),
            Text(
                'Les inscriptions sont en attente de validation par la '
                'direction, comme celles saisies à la main.',
                style: TextStyle(fontSize: 12, color: kTextMuted, height: 1.4)),
          ]),
        ),
      ]),
      if (bilan.echecs.isNotEmpty) ...[
        const SizedBox(height: 18),
        Text('${bilan.echecs.length} ligne(s) refusée(s) à l\'enregistrement',
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w800, color: kRed)),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 240),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: kRed.withValues(alpha: 0.28)),
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final e in bilan.echecs)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  child: Text('Ligne ${e.ligne} — ${e.nom} : ${e.cause}',
                      style: TextStyle(fontSize: 11.5, color: kRed)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: () => Clipboard.setData(ClipboardData(
              text: bilan.echecs
                  .map((e) => 'Ligne ${e.ligne} — ${e.nom} : ${e.cause}')
                  .join('\n'))),
          icon: const Icon(Icons.copy_rounded, size: 14),
          style: TextButton.styleFrom(foregroundColor: kTextMuted),
          label: const Text('Copier la liste des refus',
              style: TextStyle(fontSize: 11.5)),
        ),
      ],
    ]);
  }
}

/// Pied de page avec un bouton principal réellement désactivable.
///
/// `AdminFormDialog` retire tout le pied — bouton Annuler compris — quand
/// `onSubmit` est nul, et `AdminPrimaryButton.onTap` n'accepte pas le nul. On
/// pose donc notre propre pied plutôt que de toucher au chrome partagé, utilisé
/// par des dizaines d'écrans.
class PiedImport extends StatelessWidget {
  const PiedImport({
    super.key,
    this.onAnnuler,
    this.principal,
    this.icone,
    this.onPrincipal,
  });

  final VoidCallback? onAnnuler;
  final String? principal;
  final IconData? icone;
  final VoidCallback? onPrincipal;

  @override
  Widget build(BuildContext context) {
    final actif = onPrincipal != null;
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      if (onAnnuler != null)
        TextButton(
          onPressed: onAnnuler,
          style: TextButton.styleFrom(foregroundColor: kTextMuted),
          child: const Text('Annuler'),
        ),
      if (principal != null) ...[
        const SizedBox(width: 10),
        FilledButton.icon(
          onPressed: onPrincipal,
          icon: Icon(icone ?? Icons.check_rounded, size: 16),
          style: FilledButton.styleFrom(
            backgroundColor: actif ? kNavy : kBorder,
            foregroundColor: actif ? Colors.white : kTextMuted,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
          label: Text(principal!),
        ),
      ],
    ]);
  }
}
