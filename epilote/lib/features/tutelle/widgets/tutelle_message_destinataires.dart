part of 'tutelle_message_dialog.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA SÉLECTION DES DESTINATAIRES
//
//  Deux blocs, et la coupure a un sens juridique : d'un côté la PERSONNE
//  MORALE que le ministère agrée — son administrateur ; de l'autre les CHEFS
//  D'ÉTABLISSEMENT, qui dirigent chacun une école. Écrire au premier n'est pas
//  écrire aux seconds, et l'écran ne doit pas laisser croire l'inverse.
// ════════════════════════════════════════════════════════════════════════════

class _Destinataires extends StatelessWidget {
  const _Destinataires({
    required this.async,
    required this.couleur,
    required this.coches,
    required this.onBascule,
    required this.onTousLesChefs,
  });

  final AsyncValue<List<DestinataireTutelle>> async;
  final Color couleur;
  final Set<String> coches;
  final ValueChanged<String> onBascule;
  final void Function(List<String> ids, bool cocher) onTousLesChefs;

  @override
  Widget build(BuildContext context) => switch (async) {
        AsyncData(:final value) when value.isEmpty => const _Bandeau(
            couleur: null,
            icone: Icons.person_off_rounded,
            texte: 'Ce groupe n’a ni administrateur ni chef d’établissement '
                'actif : personne ne peut recevoir de message aujourd’hui.',
            rouge: true,
          ),
        AsyncData(:final value) => _liste(value),
        AsyncError(:final error) => _Bandeau(
            couleur: null,
            icone: Icons.error_outline_rounded,
            texte: messageErreur(error, contexte: 'Destinataires'),
            rouge: true,
          ),
        _ => const _Bandeau(
            couleur: null,
            icone: Icons.hourglass_empty_rounded,
            texte: 'Recherche des interlocuteurs…',
          ),
      };

  Widget _liste(List<DestinataireTutelle> tous) {
    final groupe = [for (final d in tous) if (d.estLeGroupe) d];
    final chefs = [for (final d in tous) if (!d.estLeGroupe) d];
    final idsChefs = [for (final d in chefs) d.userId];
    final tousCoches =
        idsChefs.isNotEmpty && idsChefs.every(coches.contains);

    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Column(children: [
        _Titre(
          libelle: 'LE GROUPE SCOLAIRE',
          couleur: couleur,
          compte: '${coches.where((id) => groupe.any((d) => d.userId == id)).length}'
              ' / ${groupe.length}',
        ),
        for (final d in groupe)
          _Ligne(
            d: d,
            coche: coches.contains(d.userId),
            couleur: couleur,
            onTap: () => onBascule(d.userId),
          ),
        if (chefs.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Text(
              'Aucun chef d’établissement enregistré dans ce groupe.',
              style: TextStyle(fontSize: 11.5, color: kTextMuted),
            ),
          )
        else ...[
          _Titre(
            libelle: 'LES ÉTABLISSEMENTS',
            couleur: couleur,
            compte: '${idsChefs.where(coches.contains).length}'
                ' / ${chefs.length}',
            action: TextButton(
              onPressed: () => onTousLesChefs(idsChefs, !tousCoches),
              style: TextButton.styleFrom(
                foregroundColor: couleur,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(tousCoches ? 'Tout décocher' : 'Tout cocher',
                  style: const TextStyle(fontSize: 11.5)),
            ),
          ),
          for (final d in chefs)
            _Ligne(
              d: d,
              coche: coches.contains(d.userId),
              couleur: couleur,
              onTap: () => onBascule(d.userId),
            ),
        ],
      ]),
    );
  }
}

class _Titre extends StatelessWidget {
  const _Titre({
    required this.libelle,
    required this.couleur,
    required this.compte,
    this.action,
  });

  final String libelle, compte;
  final Color couleur;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.fromLTRB(14, 9, action == null ? 14 : 6, 9),
        decoration: BoxDecoration(
          color: kSurface,
          border: Border(bottom: BorderSide(color: kBorder)),
        ),
        child: Row(children: [
          // ⚠️ `Flexible` : « LES ÉTABLISSEMENTS » + le compte + « Tout
          // décocher » débordaient la largeur de la modale (516 pt utiles).
          Flexible(
            child: Text(libelle,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: kTextMuted)),
          ),
          const SizedBox(width: 8),
          // Le compte est DIT : sans lui, on croit avoir coché ce qu'on n'a
          // pas coché, et le message part à une personne au lieu de quatre.
          Text(compte,
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: couleur)),
          const Spacer(),
          ?action,
        ]),
      );
}

class _Ligne extends StatelessWidget {
  const _Ligne({
    required this.d,
    required this.coche,
    required this.couleur,
    required this.onTap,
  });

  final DestinataireTutelle d;
  final bool coche;
  final Color couleur;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 2, 14, 2),
          decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(color: kBorder.withValues(alpha: 0.5))),
          ),
          child: Row(children: [
            Checkbox(
              value: coche,
              onChanged: (_) => onTap(),
              activeColor: couleur,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(d.libelle,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: kTextPrimary)),
                    Text(
                      d.ecole == null ? d.fonction : '${d.fonction} · ${d.ecole}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: kTextMuted),
                    ),
                  ]),
            ),
          ]),
        ),
      );
}

class _Bandeau extends StatelessWidget {
  const _Bandeau({
    required this.couleur,
    required this.icone,
    required this.texte,
    this.rouge = false,
  });

  final Color? couleur;
  final IconData icone;
  final String texte;
  final bool rouge;

  @override
  Widget build(BuildContext context) {
    final c = couleur ?? (rouge ? kRed : kTextMuted);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withValues(alpha: 0.22)),
      ),
      child: Row(children: [
        Icon(icone, size: 16, color: c),
        const SizedBox(width: 10),
        Expanded(
          child: Text(texte,
              style:
                  TextStyle(fontSize: 12, color: kTextPrimary, height: 1.4)),
        ),
      ]),
    );
  }
}
