/// ─── LE SOCLE NATIF DE LA PLATEFORME ───────────────────────────────────────
///
/// Tableau de bord, Annonces & Agenda, Messagerie, Tickets, Journal d'audit,
/// Paramètres… ne sont PAS des modules : ce sont le tissu natif. On ne les vend
/// pas dans un plan, on ne les retire pas d'un profil d'accès, et un impayé ne
/// les coupe pas — une école qui ne peut plus être jointe par sa hiérarchie,
/// ni ouvrir un ticket, ni lire ses paramètres, n'est pas une école en retard
/// de paiement : c'est une école coupée.
///
/// ⚠️ POURQUOI CE FICHIER EXISTE — LE DÉFAUT DU 2026-09-03.
/// La base portait une catégorie `COMMUNICATION` avec trois MODULES
/// (`annonces`, `messagerie`, `evenements`), accordés aux cinq profils d'accès.
/// La sidebar du personnel construit ses sections DEPUIS LA BASE et ajoutait la
/// section native par-dessus : chaque agent voyait DEUX sections
/// « COMMUNICATION », « Messagerie » deux fois — et les entrées venues de la
/// base menaient à `/user/m/<slug>`, l'hôte générique des modules pas encore
/// bâtis. Un clic ouvrait une page vide.
///
/// Le doublon ne venait pas d'une faute d'écran : il venait de ce que le modèle
/// se contredisait — un canal « jamais vendu » figurait au catalogue vendable.
///
/// ⚠️ CE FICHIER EST LA SEULE DÉCLARATION, POUR LES DEUX ESPACES.
/// Les entrées natives étaient écrites DEUX fois dans `nav_config.dart` (une
/// fois par espace) et une TROISIÈME fois en base sous forme de modules. Les
/// copies avaient déjà divergé (« Messages » d'un côté, « Messagerie » de
/// l'autre) — c'est exactement la dérive qui produit un doublon silencieux.
/// Une entrée se déclare ici, une seule fois, et les deux barres la lisent.
///
/// ⚠️ [kSlugsReserves] est la MÊME liste que celle du déclencheur SQL
/// (migration 0177). `socle_natif_test.dart` vérifie que les deux ne divergent
/// pas : la divergence ne se verrait qu'à l'écran, chez l'agent.
library;

import 'package:flutter/material.dart';

import 'routes.dart';

/// Les espaces qui partagent ce socle.
///
/// ⚠️ Le `super_admin` n'y figure pas, et c'est délibéré : ses entrées de même
/// nom sont des outils de PLATEFORME (« Paramètres plateforme », « Tickets
/// support », « Messages d'accueil des postes »), pas les pages d'un
/// établissement. Les forcer ici ajouterait de l'indirection sans supprimer un
/// doublon — sa barre n'est d'ailleurs jamais construite depuis la base, donc
/// aucun module ne peut l'ombrer.
enum EspaceNav { groupe, etablissement }

/// Le bloc de la barre qui accueille une entrée.
///
/// La même page ne se range pas au même endroit selon l'espace : le journal
/// d'audit est un outil SYSTÈME pour un cabinet de groupe, et une config
/// d'ÉTABLISSEMENT réservée à la direction dans une école. La zone appartient
/// donc à la place, pas à l'entrée.
enum ZoneNav {
  /// Bloc de tête, au-dessus de la zone défilante.
  tete,

  /// Configs natives réservées à la direction de l'établissement.
  etablissement,

  /// Bloc épinglé COMMUNICATION.
  communication,

  /// Bloc épinglé SYSTÈME.
  systeme,
}

/// Où une entrée se pose dans un espace donné : sa route et son bloc.
class PlaceNav {
  const PlaceNav(this.route, this.zone);

  final String route;
  final ZoneNav zone;
}

/// Une entrée native, et où elle mène dans chaque espace.
class EntreeNative {
  const EntreeNative({
    required this.libelle,
    required this.icone,
    required this.places,
    this.slug,
  });

  final String libelle;
  final IconData icone;

  /// ⚠️ Une place PAR ESPACE : « Annonces & Agenda » n'est pas le même écran
  /// pour un ministère et pour un surveillant. Ce qui est commun, c'est
  /// l'entrée — son nom, son icône, son rang — pas sa destination. Un espace
  /// absent de cette carte ne montre simplement pas l'entrée.
  final Map<EspaceNav, PlaceNav> places;

  /// Le slug qu'un module ne peut PAS porter, parce que cette page l'occupe
  /// déjà nativement.
  ///
  /// ⚠️ Ne se renseigne que pour les entrées visibles dans
  /// [EspaceNav.etablissement] : c'est la SEULE barre construite depuis la
  /// base, donc la seule qu'un module puisse doubler. Réserver un slug pour
  /// une entrée que seul un cabinet de groupe voit n'empêcherait rien.
  final String? slug;
}

/// Les entrées natives, dans l'ordre où elles se lisent.
///
/// ⚠️ L'ORDRE DE CETTE LISTE EST L'ORDRE À L'ÉCRAN, zone par zone. Déplacer une
/// ligne ici déplace l'entrée dans les DEUX barres.
///
/// ⚠️ AJOUTER UNE ENTRÉE NE SUFFIT PAS : si elle est visible côté
/// établissement, son slug doit rejoindre le déclencheur SQL (0177), sans quoi
/// rien n'empêche quelqu'un de recréer le même objet au catalogue — et le
/// doublon revient, chez tous les agents de toutes les écoles.
const List<EntreeNative> kSocleNatif = [
  // ── Bloc de tête ─────────────────────────────────────────────────────────
  EntreeNative(
    libelle: 'Tableau de bord',
    icone: Icons.dashboard_rounded,
    slug: 'dashboard',
    places: {
      EspaceNav.groupe: PlaceNav(Routes.adminDashboard, ZoneNav.tete),
      EspaceNav.etablissement: PlaceNav(Routes.userDashboard, ZoneNav.tete),
    },
  ),
  // ⚠️ UNE SECTION NE SE JUSTIFIE QU'À PARTIR DE DEUX ENTRÉES : « Réseau sous
  // tutelle » a d'abord eu sa propre section « TUTELLE » — un titre, un
  // séparateur et une seule ligne dessous. Un ministère sait qu'il est un
  // ministère. L'entrée rejoint le bloc de tête, là où elle est de toute façon
  // la première question du jour. Elle n'existe que pour un ministère : à un
  // groupe ordinaire, les RPC répondent 42501, et l'entrée lui laisserait
  // croire qu'il lui manque un droit.
  EntreeNative(
    libelle: 'Réseau sous tutelle',
    icone: Icons.hub_rounded,
    places: {
      EspaceNav.groupe: PlaceNav(Routes.adminTutelle, ZoneNav.tete),
    },
  ),

  // ── Configs natives de l'établissement (direction seulement) ─────────────
  EntreeNative(
    libelle: 'Calendrier scolaire',
    icone: Icons.event_note_rounded,
    slug: 'calendrier',
    places: {
      EspaceNav.etablissement:
          PlaceNav(Routes.calendrier, ZoneNav.etablissement),
    },
  ),
  // ⚠️ Direction SEULEMENT, et pas par confort d'affichage : les états lisent
  // l'école entière, hors du périmètre de classes de l'agent. Le routeur pose
  // le même verrou — les deux doivent rester.
  EntreeNative(
    libelle: 'Rapports',
    icone: Icons.description_rounded,
    slug: 'rapports',
    places: {
      EspaceNav.etablissement:
          PlaceNav(Routes.userRapports, ZoneNav.etablissement),
    },
  ),

  // ── Communication ────────────────────────────────────────────────────────
  EntreeNative(
    // « & Agenda » n'est pas décoratif : l'agenda est un ONGLET de cet écran
    // (`StaffAnnouncementsScreen(initialTab: 1)`), pas une page à part. Le
    // module `evenements` qui prétendait le contraire menait à une coquille
    // vide — c'est l'un des trois doublons retirés par 0176.
    libelle: 'Annonces & Agenda',
    icone: Icons.campaign_rounded,
    slug: 'annonces',
    places: {
      EspaceNav.groupe: PlaceNav(Routes.adminAnnonces, ZoneNav.communication),
      EspaceNav.etablissement:
          PlaceNav(Routes.annonces, ZoneNav.communication),
    },
  ),
  // ⚠️ LA MESSAGERIE PORTE AUSSI LA PAROLE DE LA TUTELLE. Il y a eu ici une
  // entrée « Circulaires », quatrième canal pour un objet dont la base ne
  // comptait AUCUNE ligne. Un ministère qui veut écrire à un groupe qu'il
  // supervise le sélectionne dans « Réseau sous tutelle » et lui envoie un
  // message : le même geste que pour n'importe quel destinataire.
  EntreeNative(
    libelle: 'Messagerie',
    icone: Icons.forum_rounded,
    slug: 'messagerie',
    places: {
      EspaceNav.groupe: PlaceNav(Routes.adminMessagerie, ZoneNav.communication),
      EspaceNav.etablissement:
          PlaceNav(Routes.messagerie, ZoneNav.communication),
    },
  ),
  EntreeNative(
    libelle: 'Espace Parent',
    icone: Icons.family_restroom_rounded,
    places: {
      EspaceNav.etablissement:
          PlaceNav(Routes.espaceParent, ZoneNav.communication),
    },
  ),

  // ── Système ──────────────────────────────────────────────────────────────
  EntreeNative(
    libelle: 'Tickets',
    icone: Icons.confirmation_num_rounded,
    slug: 'support',
    places: {
      EspaceNav.groupe: PlaceNav(Routes.adminSupport, ZoneNav.systeme),
      EspaceNav.etablissement: PlaceNav(Routes.userSupport, ZoneNav.systeme),
    },
  ),
  EntreeNative(
    libelle: "Journal d'audit",
    icone: Icons.menu_book_rounded,
    slug: 'audit',
    places: {
      EspaceNav.groupe: PlaceNav(Routes.adminAudit, ZoneNav.systeme),
      // Côté école, l'audit est une config de DIRECTION, pas un outil système
      // offert à tout agent : il change donc de bloc en changeant d'espace.
      EspaceNav.etablissement:
          PlaceNav(Routes.userAudit, ZoneNav.etablissement),
    },
  ),
  EntreeNative(
    libelle: 'Paramètres',
    icone: Icons.settings_rounded,
    slug: 'parametres',
    places: {
      EspaceNav.groupe: PlaceNav(Routes.adminParametres, ZoneNav.systeme),
      EspaceNav.etablissement:
          PlaceNav(Routes.userParametres, ZoneNav.systeme),
    },
  ),
];

/// Les slugs occupés nativement SANS porter de ligne de menu.
///
/// `evenements` en fait partie : l'agenda existe bien, mais comme ONGLET de
/// l'écran d'annonces. Le module du même nom menait à une coquille vide et
/// affichait pourtant une troisième ligne « COMMUNICATION » (0176). Réservé
/// sans entrée : le slug est pris, la ligne n'existe pas.
const Set<String> kSlugsSansEntree = {'evenements'};

/// Les entrées d'une [zone] dans un [espace], dans l'ordre de déclaration.
///
/// [sans] retire des entrées par libellé — la sauvegarde des mineurs retire la
/// messagerie privée aux élèves, un groupe ordinaire ne voit pas la tutelle.
/// On FILTRE la déclaration au lieu d'en écrire une seconde : une seconde liste
/// finit toujours par diverger de celle-ci.
List<EntreeNative> socleDe(
  EspaceNav espace,
  ZoneNav zone, {
  Set<String> sans = const {},
}) =>
    [
      for (final e in kSocleNatif)
        if (e.places[espace]?.zone == zone && !sans.contains(e.libelle)) e,
    ];

/// Les slugs qu'un module ne peut pas porter.
///
/// ⚠️ Doit rester identique à `slugs_natifs()` en base (0177).
Set<String> get kSlugsReserves => {
      ...kSlugsSansEntree,
      for (final e in kSocleNatif)
        if (e.slug != null) e.slug!,
    };
