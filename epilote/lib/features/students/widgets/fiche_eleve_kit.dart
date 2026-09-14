import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LES BRIQUES DE LA FICHE ÉLÈVE
//
//  ── UNE RÈGLE QUI TRAVERSE TOUT CE FICHIER : LE VIDE SE DIT ────────────────
//  ⚠️ `FicheVide` n'est pas un ornement. Sur une fiche qui prétend tout
//  montrer, une section absente et une section vide se ressemblent — et le
//  lecteur conclut toujours la même chose : « il n'y a rien ». Or « aucune
//  sanction enregistrée » et « les sanctions ne sont pas remontées jusqu'ici »
//  ne s'agissent pas de la même façon. Chaque section rend donc son vide
//  explicitement, avec la phrase qui dit ce qui a été cherché.
//
//  Le PDF officiel du groupe applique déjà cette règle ; on la reprend telle
//  quelle plutôt que d'en inventer une seconde.
//
//  ── POURQUOI UN KIT ET NON DES WIDGETS PRIVÉS ──────────────────────────────
//  Sept sections, un tiroir et un service PDF composent la même matière. Sans
//  briques communes, la septième section serait écrite à la main comme les six
//  autres — et la prochaine correction d'alignement n'en atteindrait qu'une.
// ════════════════════════════════════════════════════════════════════════════

/// Une section de la fiche : un titre, une icône, et ce qu'elle contient.
///
/// [compte] s'affiche à côté du titre quand la section porte une collection
/// (« Sanctions · 3 »). Il vaut mieux que le lecteur voie le nombre AVANT de
/// dérouler : c'est ce qui lui dit s'il doit lire.
class FicheSection extends StatelessWidget {
  const FicheSection({
    super.key,
    required this.titre,
    required this.icone,
    required this.enfants,
    this.couleur,
    this.compte,
    this.action,
    this.note,
  });

  final String titre;
  final IconData icone;
  final List<Widget> enfants;
  final Color? couleur;

  /// Nombre d'éléments de la collection portée par la section, ou `null` quand
  /// la section n'en porte pas (l'identité n'a pas de « compte »).
  final int? compte;

  /// Le bouton de la section — « Modifier » là où la fiche est propriétaire de
  /// la donnée, « Ouvrir dans … » là où elle ne l'est pas.
  final Widget? action;

  /// Une phrase sous le titre, quand la section a besoin d'être située — par
  /// exemple pour dire de quelle année elle parle.
  final String? note;

  @override
  Widget build(BuildContext context) {
    final c = couleur ?? kNavy;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: kBorder)),
          ),
          child: Row(children: [
            Icon(icone, size: 18, color: c),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(
                        titre,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: kTextPrimary,
                        ),
                      ),
                    ),
                    if (compte != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: c.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$compte',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: c,
                          ),
                        ),
                      ),
                    ],
                  ]),
                  if (note != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      note!,
                      style: TextStyle(fontSize: 11, color: kTextMuted),
                    ),
                  ],
                ],
              ),
            ),
            ?action,
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: enfants,
          ),
        ),
      ]),
    );
  }
}

/// Une donnée : son intitulé, sa valeur.
///
/// [alerte] passe la ligne en rouge — réservé à ce qui manque et qui EMPÊCHE
/// quelque chose (pas de contact principal, dossier incomplet), jamais à une
/// simple absence de saisie.
class FicheLigne extends StatelessWidget {
  const FicheLigne({
    super.key,
    required this.label,
    required this.valeur,
    this.alerte = false,
    this.gras = false,
  });

  final String label;
  final String valeur;
  final bool alerte, gras;

  @override
  Widget build(BuildContext context) {
    final c = alerte ? kRed : kTextPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 170,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: kTextMuted, height: 1.35),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SelectableText(
            valeur.isEmpty ? '—' : valeur,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: valeur.isEmpty ? kTextMuted : c,
              fontWeight:
                  gras || alerte ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ]),
    );
  }
}

/// Ce qu'une section a cherché et n'a pas trouvé.
///
/// ⚠️ Le texte doit nommer CE QUI a été cherché, et non dire « rien ». « Aucun
/// passage à l'infirmerie enregistré » informe ; « Aucune donnée » ne dit même
/// pas de quoi on parle.
class FicheVide extends StatelessWidget {
  const FicheVide(this.texte, {super.key});
  final String texte;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(Icons.remove_rounded, size: 14, color: kTextMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texte,
              style: TextStyle(
                fontSize: 12,
                color: kTextMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ]),
      );
}

/// L'entrée d'un registre daté — une sanction, une visite, un versement.
///
/// La date tient la colonne de gauche et ne bouge pas d'une ligne à l'autre :
/// c'est ce qui permet de lire une chronologie en diagonale.
class FicheChrono extends StatelessWidget {
  const FicheChrono({
    super.key,
    required this.date,
    required this.titre,
    this.detail,
    this.badge,
    this.couleur,
  });

  final String date;
  final String titre;
  final String? detail;
  final String? badge;
  final Color? couleur;

  @override
  Widget build(BuildContext context) {
    final c = couleur ?? kNavy;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: c, width: 3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 86,
          child: Text(
            date,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: kTextMuted,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titre,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary,
                  height: 1.35,
                ),
              ),
              if ((detail ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  detail!.trim(),
                  style:
                      TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.4),
                ),
              ],
            ],
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 10),
          AdminBadge(badge!, color: c),
        ],
      ]),
    );
  }
}

/// Un chiffre et ce qu'il compte.
class FicheStat extends StatelessWidget {
  const FicheStat({
    super.key,
    required this.label,
    required this.valeur,
    this.couleur,
  });

  final String label, valeur;
  final Color? couleur;

  @override
  Widget build(BuildContext context) {
    final c = couleur ?? kNavy;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withValues(alpha: 0.22)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          valeur,
          style:
              TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: c),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: kTextMuted)),
      ]),
    );
  }
}

/// La rangée de chiffres d'une section, qui se replie sur les écrans étroits.
class FicheStats extends StatelessWidget {
  const FicheStats(this.tuiles, {super.key});
  final List<Widget> tuiles;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Wrap(spacing: 10, runSpacing: 10, children: tuiles),
      );
}

/// Un petit tableau — le parcours, les notes d'une matière.
///
/// ⚠️ Il défile HORIZONTALEMENT dans son propre cadre. Un tableau qui pousse
/// la page entière vers la droite rend la fiche illisible sur le portable
/// d'entrée de gamme qui est le poste réel des écoles.
class FicheTableau extends StatelessWidget {
  const FicheTableau({
    super.key,
    required this.entetes,
    required this.lignes,
    required this.largeurs,
    this.vide = 'Rien à afficher.',
  });

  final List<String> entetes;
  final List<List<String>> lignes;
  final List<double> largeurs;
  final String vide;

  @override
  Widget build(BuildContext context) {
    if (lignes.isEmpty) return FicheVide(vide);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: kBorder)),
          ),
          child: Row(
            children: [
              for (var i = 0; i < entetes.length; i++)
                SizedBox(
                  width: largeurs[i],
                  child: Text(
                    entetes[i].toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: kTextMuted,
                    ),
                  ),
                ),
            ],
          ),
        ),
        for (final l in lignes)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: kBorder.withValues(alpha: 0.55)),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < l.length && i < largeurs.length; i++)
                  SizedBox(
                    width: largeurs[i],
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Text(
                        l[i].isEmpty ? '—' : l[i],
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: l[i].isEmpty ? kTextMuted : kTextPrimary,
                          fontWeight:
                              i == 0 ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ]),
    );
  }
}

/// Le renvoi vers le module qui POSSÈDE la donnée.
///
/// ── POURQUOI CE BOUTON EXISTE ──────────────────────────────────────────────
/// ⚠️ La fiche montre des notes, des versements, des absences — elle ne les
/// modifie pas. Une moyenne se corrige dans Évaluation, qui a ses règles de
/// clôture ; un versement se corrige dans Finance, où un reçu déjà délivré ne
/// se réécrit pas en silence ; une absence porte l'agent qui l'a posée et la
/// date à laquelle il l'a fait. Ouvrir l'écriture ici construirait une porte
/// dérobée autour de chaque règle que l'application fait respecter — dans un
/// registre scolaire, c'est ainsi qu'une note change sans trace.
///
/// Le bouton emmène donc l'agent LÀ où la correction est légitime, plutôt que
/// de la lui offrir ici.
class FicheRenvoi extends StatelessWidget {
  const FicheRenvoi({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton.icon(
        onPressed: onTap,
        icon: Icon(Icons.open_in_new_rounded, size: 14, color: kNavy),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: kNavy,
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
}
