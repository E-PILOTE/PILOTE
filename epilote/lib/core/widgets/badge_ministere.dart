import 'package:flutter/material.dart';

import '../constants/tutelle.dart';
import 'admin_tokens.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA PASTILLE QUI DIT « CE N'EST PAS UN GROUPE SCOLAIRE »
//
//  ── LE DÉFAUT QU'ELLE CORRIGE ─────────────────────────────────────────────
//  Les deux ministères vivaient dans les listes comme les cinq groupes privés,
//  avec la même carte, la même icône, et une pastille « MEPSA » ou « METP » de
//  la même forme que « Privé » ou « Premium ». Rien ne disait qu'on regardait
//  une ADMINISTRATION DE TUTELLE et non un client de plus : il fallait ouvrir
//  la fiche, et encore — la fiche affichait « Type : Public ».
//
//  ── POURQUOI ELLE EST PLEINE, ET NON TEINTÉE ──────────────────────────────
//  Toutes les autres pastilles de ces écrans sont des fonds à 10 % d'opacité.
//  Une pastille de plus dans le même registre se serait rangée dans la file au
//  lieu d'en sortir. Le fond plein est le seul de l'écran : il se voit sans
//  qu'on le cherche, dans une liste de mille groupes comme dans une liste de
//  sept. C'est le but — la distinction doit se lire, pas se déduire.
//
//  ⚠️ La couleur reste celle de la tutelle (`couleurTutelle`) : MEPSA et METP
//  ne se confondent pas non plus entre eux.
// ════════════════════════════════════════════════════════════════════════════

/// Pastille « MINISTÈRE · MEPSA », à poser partout où un groupe se montre.
///
/// N'affiche rien pour un groupe ordinaire : c'est un marqueur d'exception, il
/// perdrait tout son sens s'il fallait le lire sur chaque ligne.
class BadgeMinistere extends StatelessWidget {
  const BadgeMinistere({
    super.key,
    required this.estMinistere,
    required this.tutelle,
    this.compact = false,
  });

  /// `school_groups.administre_referentiel_national`.
  final bool estMinistere;

  /// `mepsa` ou `metp` — donne la couleur et le sigle.
  final String? tutelle;

  /// Sans le sigle : pour les lignes étroites (notifications, listes denses),
  /// où le nom du ministère est déjà écrit juste à côté.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!estMinistere) return const SizedBox.shrink();
    final couleur = couleurTutelle(tutelle);
    final sigle = sigleTutelle(tutelle);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: couleur,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.account_balance_rounded, size: 11, color: Colors.white),
        const SizedBox(width: 5),
        Text(
          compact || sigle == null ? 'MINISTÈRE' : 'MINISTÈRE · $sigle',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      ]),
    );
  }
}

/// Icône d'un groupe dans une liste : l'institution pour un ministère, le
/// bâtiment pour tous les autres.
///
/// ⚠️ `_typeIcon('public')` rendait déjà `account_balance` : un groupe public
/// ordinaire et un ministère portaient la MÊME icône. Passer par ici règle la
/// question à la source plutôt que dans chaque écran.
IconData iconeGroupe({required bool estMinistere, required IconData siGroupe}) =>
    estMinistere ? Icons.account_balance_rounded : siGroupe;

/// Le nom sous lequel un groupe se présente.
///
/// Pour un ministère, son nom d'usage (« Ministère MEPSA ») plutôt que sa
/// raison sociale enregistrée, qui varie d'une saisie à l'autre — la base
/// porte aujourd'hui « MEPSA — Ministère Enseign. Primaire » d'un côté et
/// « Ministère de l'Enseignement Technique et Professionnel » de l'autre.
String nomAffichableGroupe({
  required String nom,
  required bool estMinistere,
  required String? tutelle,
}) =>
    estMinistere ? (nomUsageMinistere(tutelle) ?? nom) : nom;
