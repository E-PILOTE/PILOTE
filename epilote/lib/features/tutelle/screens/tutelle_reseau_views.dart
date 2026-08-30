part of 'tutelle_reseau_screen.dart';

// ─── En-tête : QUEL réseau on regarde ────────────────────────────────────────

/// ⚠️ Il nomme le périmètre AVANT les chiffres.
///
/// Un ministère lit deux totaux dans la même application : celui de ses propres
/// écoles (« Mes écoles ») et celui de tout son ministère. Ils sont différents
/// — pour le MEPSA, 14 contre 25. Un tableau qui ne dit pas lequel il compte
/// est un tableau dont on ne peut rien conclure.
class _EnTeteTutelle extends StatelessWidget {
  const _EnTeteTutelle({
    required this.tutelle,
    required this.nbGroupes,
    required this.nbEcoles,
  });

  final String? tutelle;
  final int nbGroupes, nbEcoles;

  @override
  Widget build(BuildContext context) {
    final couleur = couleurTutelle(tutelle);
    final sigle = sigleTutelle(tutelle);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: couleur.withValues(alpha: 0.25)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: couleur.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(Icons.hub_rounded, color: couleur, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(
              sigle == null
                  ? 'Toutes les écoles sous votre tutelle'
                  : 'Toutes les écoles sous tutelle $sigle',
              style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            'Ce tableau couvre $nbEcoles école${nbEcoles > 1 ? 's' : ''} '
            'réparties dans $nbGroupes groupe${nbGroupes > 1 ? 's' : ''} — '
            'y compris ceux que vous ne gérez pas. Les effectifs de vos '
            'propres établissements se lisent sous « Mes écoles » : les deux '
            'nombres ne se confondent pas.',
            style: TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.45),
          ),
          const SizedBox(height: 6),
          Text(
            'Effectifs agrégés. Aucun nom d\'élève, aucune note, aucun '
            'paiement — la supervision n\'est pas la gestion.',
            style: TextStyle(
                fontSize: 11,
                color: couleur,
                fontWeight: FontWeight.w600,
                height: 1.4),
          ),
        ])),
      ]),
    );
  }
}

// ─── Le cas d'un groupe qui n'a pas de tutelle à exercer ────────────────────

class _PasDeTutelle extends StatelessWidget {
  const _PasDeTutelle();

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.hub_outlined, size: 44, color: kTextMuted),
            const SizedBox(height: 14),
            Text('Réservé aux ministères de tutelle',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary)),
            const SizedBox(height: 8),
            Text(
              'Cette page présente toutes les écoles d\'un ministère, y compris '
              'celles d\'autres groupes. Votre groupe gère ses propres '
              'établissements : ils se trouvent sous « Mes écoles ».',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: kTextMuted, height: 1.5),
            ),
          ]),
        ),
      );
}

/// ⚠️ Une erreur s'affiche COMME une erreur, jamais comme un réseau vide.
class _ErreurReseau extends StatelessWidget {
  const _ErreurReseau({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline_rounded, color: kRed, size: 40),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: kTextMuted, height: 1.5)),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ]),
      );
}

// ─── Vue « écoles » ──────────────────────────────────────────────────────────

class TutelleEcolesVue extends StatelessWidget {
  const TutelleEcolesVue({super.key, required this.ecoles});
  final List<TutelleEcole> ecoles;

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
          _LigneEcole(e: ecoles[i], derniere: i == ecoles.length - 1),
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
          Expanded(flex: 2, child: _Th('Département')),
          Expanded(flex: 2, child: _Th('Élèves')),
          Expanded(flex: 2, child: _Th('Personnel')),
          Expanded(flex: 2, child: _Th('Agrément')),
        ]),
      );
}

class _Th extends StatelessWidget {
  const _Th(this.t);
  final String t;
  @override
  Widget build(BuildContext context) => Text(t,
      style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: kTextMuted));
}

class _LigneEcole extends StatelessWidget {
  const _LigneEcole({required this.e, required this.derniere});
  final TutelleEcole e;
  final bool derniere;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
        decoration: BoxDecoration(
          border: derniere
              ? null
              : Border(bottom: BorderSide(color: kBorder.withValues(alpha: 0.6))),
        ),
        child: Row(children: [
          Expanded(
              flex: 4,
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.nom,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: kTextPrimary)),
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
              flex: 2,
              child: Text(e.departement ?? '—',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: kTextPrimary))),
          Expanded(
              flex: 2,
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(fmtInt(e.nbEleves),
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: kTextPrimary)),
                // La part de filles est la première ventilation d'un état de
                // rentrée : elle vaut la ligne qu'elle occupe.
                if (e.nbEleves > 0)
                  Text('${(e.nbFilles * 100 / e.nbEleves).round()} % filles',
                      style: TextStyle(fontSize: 10.5, color: kTextMuted)),
              ])),
          Expanded(
              flex: 2,
              child: Text('${fmtInt(e.nbPersonnel)}  ·  ${fmtInt(e.nbClasses)} cl.',
                  style: TextStyle(fontSize: 12, color: kTextPrimary))),
          Expanded(flex: 2, child: _PastilleAgrement(e: e)),
        ]),
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

// ─── Vue « groupes » ─────────────────────────────────────────────────────────

class TutelleGroupesVue extends StatelessWidget {
  const TutelleGroupesVue({
    super.key,
    required this.groupes,
    required this.ecoles,
    required this.onVoirEcoles,
  });

  final List<TutelleGroupe> groupes;

  /// Les écoles FILTRÉES — c'est sur elles que les totaux par groupe sont
  /// recalculés, jamais sur les totaux du réseau : sinon une carte de groupe
  /// annoncerait 300 élèves au-dessus d'une liste filtrée qui en montre 40.
  final List<TutelleEcole> ecoles;
  final ValueChanged<TutelleGroupe> onVoirEcoles;

  @override
  Widget build(BuildContext context) {
    final parGroupe = <String, List<TutelleEcole>>{};
    for (final e in ecoles) {
      parGroupe.putIfAbsent(e.groupId, () => []).add(e);
    }
    final visibles = [
      for (final g in groupes)
        if (parGroupe.containsKey(g.id)) g,
    ];
    if (visibles.isEmpty) {
      return const AdminEmptyState(
        icon: Icons.search_off_rounded,
        title: 'Aucun groupe ne correspond',
        message: 'Élargissez les filtres, ou réinitialisez-les.',
      );
    }
    return Column(
      children: [
        for (final g in visibles) ...[
          _CarteGroupe(
            g: g,
            bilan: BilanReseau.de(parGroupe[g.id]!),
            onVoirEcoles: () => onVoirEcoles(g),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _CarteGroupe extends StatelessWidget {
  const _CarteGroupe({
    required this.g,
    required this.bilan,
    required this.onVoirEcoles,
  });

  final TutelleGroupe g;
  final BilanReseau bilan;
  final VoidCallback onVoirEcoles;

  @override
  Widget build(BuildContext context) {
    final couleur = g.estPublic ? kNavy : kAccent;
    return AdminCard(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: couleur.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
              g.estPublic ? Icons.account_balance_rounded : Icons.business_rounded,
              size: 18,
              color: couleur),
        ),
        const SizedBox(width: 13),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
            AdminBadge(g.estPublic ? 'Public' : 'Privé', color: couleur),
            if (g.aDeclareUnAgrement) ...[
              const SizedBox(width: 6),
              AdminBadge(
                g.agrementType == 'definitif'
                    ? 'Agrément définitif'
                    : 'Agrément provisoire',
                color: g.agrementType == 'definitif' ? kGreen : kAccent,
                icon: Icons.verified_outlined,
              ),
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
            _Chiffre('Écoles', fmtInt(bilan.nbEcoles)),
            _Chiffre('Élèves', fmtInt(bilan.nbEleves)),
            _Chiffre(
                'Filles',
                bilan.partFilles == null
                    ? '—'
                    : '${bilan.partFilles!.round()} %'),
            _Chiffre('Personnel', fmtInt(bilan.nbPersonnel)),
            _Chiffre('Classes', fmtInt(bilan.nbClasses)),
          ]),
        ])),
        const SizedBox(width: 10),
        TextButton.icon(
          onPressed: onVoirEcoles,
          icon: const Icon(Icons.list_alt_rounded, size: 15),
          label: const Text('Ses écoles'),
          style: TextButton.styleFrom(foregroundColor: kNavy),
        ),
      ]),
    );
  }
}

class _Chiffre extends StatelessWidget {
  const _Chiffre(this.label, this.valeur);
  final String label, valeur;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(valeur,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: kTextPrimary)),
        Text(label, style: TextStyle(fontSize: 10.5, color: kTextMuted)),
      ]);
}
