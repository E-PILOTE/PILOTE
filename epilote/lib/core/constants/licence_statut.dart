/// ─── LE STATUT D'UNE LICENCE DE TUTELLE, EN UN SEUL ENDROIT ────────────────
///
/// Miroir exact de l'énumération `licence_statut` en base (migration 0160).
///
/// ⚠️ POURQUOI CE FICHIER EXISTE. Le vocabulaire était écrit TROIS fois avant
/// d'atterrir ici : `_labelStatut` et `_couleurStatut` en bas de
/// `economie_screen.dart`, et à la main dans les `DropdownMenuItem` de
/// `licence_form_dialog.dart`. Le barème des mentions puis le libellé de la
/// tutelle ont déjà appris ce que coûtent plusieurs exemplaires d'une même
/// règle : l'un d'eux finit par diverger, et c'est celui-là qui s'affiche au
/// client. Ici le client est un ministère, et la valeur affichée est l'état
/// d'un marché public.
///
/// La COULEUR vit dans `core/widgets/admin_tokens.dart`
/// (`couleurStatutLicence`) : ce fichier-ci reste du Dart pur, comme le reste
/// de `core/constants/`, pour rester lisible depuis un test sans Flutter.
library;

/// Le slug du plan qui porte les ministères de tutelle (migration 0182).
///
/// ⚠️ Ce plan ne porte AUCUN prix : les conditions réelles vivent dans
/// `tutelle_licences`. Le proposer à un groupe privé le sortirait du revenu
/// mensuel de la plateforme — la base le refuse, mais aucun écran ne doit même
/// l'offrir.
const kPlanSlugLicence = 'licence';

/// Vrai si ce plan est celui des ministères. Écrit ICI et nulle part ailleurs :
/// trois écrans en dépendent (formulaire de groupe, tableau de bord, licence).
bool estPlanDeLicence(String? slug) => slug == kPlanSlugLicence;

/// Montant de départ d'une licence de tutelle, en francs CFA.
///
/// Chiffre donné par le fondateur : « une licence est vendue pour un début à
/// 40 millions ». Il sert de VALEUR PROPOSÉE à la saisie d'un nouveau marché,
/// jamais de tarif appliqué : un marché public se négocie, et le montant réel
/// vit dans `tutelle_licences.montant_xaf`.
///
/// ⚠️ Ne jamais s'en servir pour calculer un revenu. Tant qu'aucune licence
/// n'est saisie, le revenu de licence est ZÉRO — pas 40 millions « prévus ».
/// C'est exactement la confusion que 0182 a corrigée dans l'autre sens.
const int kLicenceMontantDepartXaf = 40000000;

/// Les quatre statuts, dans l'ordre du cycle de vie d'un marché.
const kStatutsLicence = <String>['brouillon', 'active', 'echue', 'resiliee'];

/// Libellé en toutes lettres — celui des formulaires et des fiches.
///
/// ⚠️ Rend `null` pour une valeur inconnue plutôt que de retomber sur
/// « Brouillon » : afficher « brouillon » sur une licence ACTIVE ferait croire
/// qu'un marché signé ne l'est pas.
String? libelleStatutLicence(String? s) => switch (s) {
      'brouillon' => 'Brouillon',
      'active' => 'Active',
      'echue' => 'Échue',
      'resiliee' => 'Résiliée',
      _ => null,
    };

/// Libellé pour un affichage qui ne supporte pas le vide (pastille, cellule).
String libelleStatutLicenceOuTiret(String? s) =>
    libelleStatutLicence(s) ?? '—';

/// Vrai si [s] est un statut connu. Sert aux validateurs de formulaire.
bool statutLicenceConnu(String? s) =>
    s != null && kStatutsLicence.contains(s);

/// Vrai si la licence est en vigueur — le SEUL statut qui compte comme revenu
/// (cf. `LicenceTutelle.mensuelCompte`) et le seul qu'on annonce au ministère
/// comme couvrant son accès.
bool licenceEnVigueur(String? s) => s == 'active';
