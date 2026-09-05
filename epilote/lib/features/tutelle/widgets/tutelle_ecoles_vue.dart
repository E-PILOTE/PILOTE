import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/tutelle_reseau_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA TABLE DES ÉTABLISSEMENTS DU RÉSEAU
//
//  Sortie du fichier de vues de l'écran, qui dépassait la cible de 500 lignes
//  dès qu'on lui ajoutait la disposition par groupe. Découpe le long d'une
//  couture réelle : cette table est une pièce entière, réutilisable telle
//  quelle dans une fiche de groupe.
//
//  ── ⚠️ CHAQUE LIGNE EST CLIQUABLE, ET C'EST LE POINT ─────────────────────
//  La RPC `tutelle_ecoles` rend le chef d'établissement, le téléphone, le
//  courriel, les coordonnées et la capacité. La table n'en montre aucun — elle
//  n'a pas la place, et ce n'est pas son rôle. Sans une porte vers la fiche,
//  ces colonnes traversaient le réseau pour être jetées à l'arrivée.
// ════════════════════════════════════════════════════════════════════════════

class TutelleEcolesVue extends StatelessWidget {
  const TutelleEcolesVue({
    super.key,
    required this.ecoles,
    required this.onOuvrir,
  });

  final List<TutelleEcole> ecoles;
  final ValueChanged<TutelleEcole> onOuvrir;

  @override
  Widget build(BuildContext context) {
    if (ecoles.isEmpty) {
      return const AdminEmptyState(
        icon: Icons.search_off_rounded,
        title: 'Aucune école ne correspond',
        message: 'Élargissez les filtres, ou réinitialisez-les.',
      );
    }
    return AdminCard(
      padding: EdgeInsets.zero,
      child: Column(children: [
        const _EnTeteColonnes(),
        for (var i = 0; i < ecoles.length; i++)
          _LigneEcole(
            e: ecoles[i],
            derniere: i == ecoles.length - 1,
            onTap: () => onOuvrir(ecoles[i]),
          ),
      ]),
    );
  }
}

class _EnTeteColonnes extends StatelessWidget {
  const _EnTeteColonnes();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: kSurface,
          border: Border(bottom: BorderSide(color: kBorder)),
        ),
        child: const Row(children: [
          Expanded(flex: 4, child: _Th('Établissement')),
          Expanded(flex: 3, child: _Th('Groupe')),
          Expanded(flex: 3, child: _Th('Chef d’établissement')),
          Expanded(flex: 2, child: _Th('Département')),
          Expanded(flex: 2, child: _Th('Élèves')),
          Expanded(flex: 2, child: _Th('Personnel')),
          Expanded(flex: 2, child: _Th('Agrément')),
          SizedBox(width: 22),
        ]),
      );
}

class _Th extends StatelessWidget {
  const _Th(this.t);
  final String t;
  @override
  Widget build(BuildContext context) => Text(t,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: kTextMuted));
}

class _LigneEcole extends StatelessWidget {
  const _LigneEcole({
    required this.e,
    required this.derniere,
    required this.onTap,
  });

  final TutelleEcole e;
  final bool derniere;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
          decoration: BoxDecoration(
            border: derniere
                ? null
                : Border(
                    bottom: BorderSide(color: kBorder.withValues(alpha: 0.6))),
          ),
          child: Row(children: [
            Expanded(
                flex: 4,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(
                          child: Text(e.nom,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: kTextPrimary)),
                        ),
                        // Un établissement fermé compte encore dans les
                        // totaux : il doit se voir, pas disparaître.
                        if (!e.actif) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: kRed.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('Inactif',
                                style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: kRed)),
                          ),
                        ],
                      ]),
                      if (e.typeEtablissementCourt != null || e.ville != null)
                        Text(
                          [
                            if (e.typeEtablissementCourt != null)
                              e.typeEtablissementCourt!,
                            if (e.ville != null) e.ville!,
                          ].join(' · '),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: kTextMuted),
                        ),
                    ])),
            Expanded(
                flex: 3,
                child: Text(e.groupeNom,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: kTextPrimary))),
            Expanded(
                flex: 3,
                child: Text(
                    (e.chefEtablissement ?? '').trim().isEmpty
                        ? 'Non désigné'
                        : e.chefEtablissement!.trim(),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        color: (e.chefEtablissement ?? '').trim().isEmpty
                            ? kTextMuted
                            : kTextPrimary))),
            Expanded(
                flex: 2,
                child: Text(e.departement ?? '—',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: kTextPrimary))),
            Expanded(
                flex: 2,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fmtInt(e.nbEleves),
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: kTextPrimary)),
                      // La part de filles est la première ventilation d'un
                      // état de rentrée : elle vaut la ligne qu'elle occupe.
                      if (e.nbEleves > 0)
                        Text(
                            '${(e.nbFilles * 100 / e.nbEleves).round()} % filles',
                            style:
                                TextStyle(fontSize: 10.5, color: kTextMuted)),
                    ])),
            Expanded(
                flex: 2,
                child: Text(
                    '${fmtInt(e.nbPersonnel)}  ·  ${fmtInt(e.nbClasses)} cl.',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: kTextPrimary))),
            Expanded(flex: 2, child: _PastilleAgrement(e: e)),
            Icon(Icons.chevron_right_rounded, size: 18, color: kTextMuted),
          ]),
        ),
      );
}

/// ⚠️ « Non déclaré », jamais « non agréé ».
///
/// La plateforme n'instruit aucun agrément : elle enregistre une mention qu'un
/// administrateur a saisie, ou pas. Écrire « non agréée » ferait porter par un
/// logiciel une accusation qu'il n'a aucun moyen d'établir — et cette phrase
/// s'afficherait à côté du nom d'un établissement réel.
class _PastilleAgrement extends StatelessWidget {
  const _PastilleAgrement({required this.e});
  final TutelleEcole e;

  @override
  Widget build(BuildContext context) {
    if (!e.aDeclareUnAgrement) {
      return Text('Non déclaré',
          style: TextStyle(fontSize: 11.5, color: kTextMuted));
    }
    final definitif = e.agrementType == 'definitif';
    final couleur = definitif ? kGreen : kAccent;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(definitif ? 'Définitif' : 'Provisoire',
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w700, color: couleur)),
      ),
      const SizedBox(height: 2),
      Text(e.agrementNumero!,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10.5, color: kTextMuted)),
    ]);
  }
}
