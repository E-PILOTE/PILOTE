import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/tutelle_filtres.dart';
import '../providers/tutelle_reseau_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA DISPOSITION PAR GROUPE SCOLAIRE — le privé d'abord
//
//  ── POURQUOI DEUX SECTIONS ET NON UNE LISTE ──────────────────────────────
//  Empilés dans un seul flux, les groupes se lisaient comme un annuaire :
//  « Groupe Scolaire Bethel » entre deux directions départementales, sans que
//  rien ne dise que l'un est agréé par le ministère et les autres administrés
//  par lui. Or c'est TOUTE la différence de rôle, et c'est la question que la
//  page existe pour traiter — le MEPSA supervise sept établissements privés
//  qu'il ne possède pas, et aucun autre écran ne les lui montre.
//
//  Le privé passe donc en premier, sous un titre qui le nomme, avec le bilan
//  du pan et une phrase qui dit ce qu'il recouvre. Le public suit, pour la
//  complétude de l'état.
//
//  ── ⚠️ LES TOTAUX SONT CEUX DE LA SÉLECTION ──────────────────────────────
//  Chaque bilan — de section comme de carte — se recalcule sur les écoles
//  RETENUES par les filtres. Afficher un total de réseau au-dessus d'une liste
//  filtrée est la façon la plus simple de faire dire à un écran le contraire
//  de ce qu'il montre. Le total du groupe sous tutelle, lui, est rendu à côté
//  et NOMMÉ comme tel.
// ════════════════════════════════════════════════════════════════════════════

class TutelleGroupesVue extends StatelessWidget {
  const TutelleGroupesVue({
    super.key,
    required this.groupes,
    required this.ecoles,
    required this.onOuvrirFiche,
    required this.onVoirEcoles,
    required this.onEcrire,
  });

  final List<TutelleGroupe> groupes;

  /// Les écoles FILTRÉES — jamais le réseau complet.
  final List<TutelleEcole> ecoles;

  final void Function(TutelleGroupe, List<TutelleEcole>) onOuvrirFiche;
  final ValueChanged<TutelleGroupe> onVoirEcoles;

  /// Rédiger une circulaire adressée à ce groupe.
  ///
  /// ⚠️ C'est la SEULE action d'écriture qu'une tutelle possède sur un groupe
  /// tiers. `groups_select` la limite à son propre groupe : elle ne peut ni
  /// modifier, ni désactiver, ni supprimer un opérateur qu'elle supervise.
  /// Ajouter ici un bouton de gestion produirait un 42501 — ou, sur un UPDATE,
  /// un échec parfaitement muet.
  final ValueChanged<TutelleGroupe> onEcrire;

  @override
  Widget build(BuildContext context) {
    final sections = sectionsDuReseau(groupes, ecoles);
    if (sections.isEmpty) {
      return const AdminEmptyState(
        icon: Icons.search_off_rounded,
        title: 'Aucun groupe ne correspond',
        message: 'Élargissez les filtres, ou réinitialisez-les.',
      );
    }
    final parGroupe = ecolesParGroupe(ecoles);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: 22),
          _EnTeteSection(section: sections[i]),
          const SizedBox(height: 10),
          for (final g in sections[i].groupes) ...[
            _CarteGroupe(
              g: g,
              ecoles: parGroupe[g.id] ?? const [],
              prive: sections[i].prive,
              onOuvrirFiche: () =>
                  onOuvrirFiche(g, parGroupe[g.id] ?? const []),
              onVoirEcoles: () => onVoirEcoles(g),
              onEcrire: () => onEcrire(g),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }
}

// ─── En-tête de pan ──────────────────────────────────────────────────────────

class _EnTeteSection extends StatelessWidget {
  const _EnTeteSection({required this.section});
  final SectionReseau section;

  @override
  Widget build(BuildContext context) {
    final couleur = section.prive ? kAccent : kNavy;
    final b = section.bilan;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: couleur.withValues(alpha: 0.22)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: couleur.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
              section.prive
                  ? Icons.business_rounded
                  : Icons.account_balance_rounded,
              size: 17,
              color: couleur),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(section.titre,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: kTextPrimary)),
                  ),
                  const SizedBox(width: 8),
                  AdminBadge(
                      '${section.groupes.length} groupe'
                      '${section.groupes.length > 1 ? 's' : ''}',
                      color: couleur),
                ]),
                const SizedBox(height: 3),
                Text(section.explication,
                    style: TextStyle(
                        fontSize: 11, color: kTextMuted, height: 1.4)),
              ]),
        ),
        const SizedBox(width: 14),
        Wrap(spacing: 16, runSpacing: 4, children: [
          _Total('Écoles', fmtInt(b.nbEcoles)),
          _Total('Élèves', fmtInt(b.nbEleves)),
          _Total('Personnel', fmtInt(b.nbPersonnel)),
        ]),
      ]),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total(this.label, this.valeur);
  final String label, valeur;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(valeur,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary)),
          Text(label, style: TextStyle(fontSize: 10, color: kTextMuted)),
        ],
      );
}

// ─── Carte d'un groupe ───────────────────────────────────────────────────────

class _CarteGroupe extends StatelessWidget {
  const _CarteGroupe({
    required this.g,
    required this.ecoles,
    required this.prive,
    required this.onOuvrirFiche,
    required this.onVoirEcoles,
    required this.onEcrire,
  });

  final TutelleGroupe g;
  final List<TutelleEcole> ecoles;
  final bool prive;
  final VoidCallback onOuvrirFiche, onVoirEcoles, onEcrire;

  @override
  Widget build(BuildContext context) {
    final couleur = prive ? kAccent : kNavy;
    final bilan = BilanReseau.de(ecoles);
    final partiel = ecoles.length != g.nbEcoles;

    return AdminCard(
      hoverable: true,
      onTap: onOuvrirFiche,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: couleur.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
              prive ? Icons.business_rounded : Icons.account_balance_rounded,
              size: 18,
              color: couleur),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(g.nom,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: kTextPrimary)),
                  ),
                  const SizedBox(width: 8),
                  if (g.aDeclareUnAgrement)
                    AdminBadge(
                      g.agrementType == 'definitif'
                          ? 'Agrément définitif'
                          : 'Agrément provisoire',
                      color: g.agrementType == 'definitif' ? kGreen : kAccent,
                      icon: Icons.verified_outlined,
                    )
                  else
                    AdminBadge('Agrément non déclaré', color: kTextMuted),
                  if (!g.actif) ...[
                    const SizedBox(width: 6),
                    AdminBadge('Inactif', color: kRed),
                  ],
                ]),
                const SizedBox(height: 3),
                Text(
                  [
                    if (g.departement != null) g.departement!,
                    if (g.telephone != null) g.telephone!,
                    if (g.email != null) g.email!,
                  ].join(' · '),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: kTextMuted),
                ),
                const SizedBox(height: 10),
                Wrap(spacing: 18, runSpacing: 6, children: [
                  _Chiffre(
                      'Écoles',
                      fmtInt(bilan.nbEcoles),
                      // ⚠️ Le total du groupe sous tutelle est rendu ICI, et
                      // nommé : sans lui, une vue filtrée annonce « 2 » pour
                      // un opérateur qui en tient cinq.
                      partiel ? 'sur ${fmtInt(g.nbEcoles)}' : null),
                  _Chiffre('Élèves', fmtInt(bilan.nbEleves), null),
                  _Chiffre(
                      'Filles',
                      bilan.partFilles == null
                          ? '—'
                          : '${bilan.partFilles!.round()} %',
                      null),
                  _Chiffre('Personnel', fmtInt(bilan.nbPersonnel), null),
                  _Chiffre('Classes', fmtInt(bilan.nbClasses), null),
                ]),
              ]),
        ),
        const SizedBox(width: 10),
        Column(mainAxisSize: MainAxisSize.min, children: [
          TextButton.icon(
            onPressed: onOuvrirFiche,
            icon: const Icon(Icons.description_outlined, size: 15),
            label: const Text('Fiche'),
            style: TextButton.styleFrom(foregroundColor: couleur),
          ),
          TextButton.icon(
            onPressed: onVoirEcoles,
            icon: const Icon(Icons.list_alt_rounded, size: 15),
            label: const Text('Ses écoles'),
            style: TextButton.styleFrom(foregroundColor: kTextMuted),
          ),
          TextButton.icon(
            onPressed: onEcrire,
            icon: const Icon(Icons.mark_as_unread_outlined, size: 15),
            label: const Text('Écrire'),
            style: TextButton.styleFrom(foregroundColor: kTextMuted),
          ),
        ]),
      ]),
    );
  }
}

class _Chiffre extends StatelessWidget {
  const _Chiffre(this.label, this.valeur, this.appoint);
  final String label, valeur;
  final String? appoint;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(valeur,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary)),
            if (appoint != null) ...[
              const SizedBox(width: 4),
              Text(appoint!,
                  style: TextStyle(fontSize: 10.5, color: kTextMuted)),
            ],
          ]),
          Text(label, style: TextStyle(fontSize: 10.5, color: kTextMuted)),
        ],
      );
}
