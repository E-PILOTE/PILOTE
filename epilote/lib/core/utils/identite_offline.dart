import 'package:uuid/uuid.dart';

// ════════════════════════════════════════════════════════════════════════════
//  UN IDENTIFIANT QUI SE DÉDUIT, AU LIEU DE SE TIRER AU SORT
//
//  ── LE PROBLÈME, PROPRE À L'OFFLINE-FIRST ──────────────────────────────────
//  Deux appareils hors ligne peuvent poser LE MÊME FAIT. L'appel de la 6ᵉ A du
//  12 mars au matin, c'est un fait unique : le professeur principal et le
//  surveillant le saisissent chacun de son côté, sans réseau, chacun avec son
//  `Uuid().v4()`.
//
//  Deux lignes remontent alors pour un seul appel, et rien ne les rapproche :
//  le connecteur remonte chaque ligne par un `upsert` sur `id`, or les `id`
//  diffèrent. La contrainte serveur ne les rattrape pas non plus quand elle
//  porte sur une colonne restée NULL — en SQL, deux NULL ne sont pas égaux.
//  Résultat visible : la feuille d'appel joint les DEUX enregistrements et
//  affiche chaque élève deux fois, avec deux statuts contradictoires.
//
//  ── LA PARADE ──────────────────────────────────────────────────────────────
//  Quand une ligne EST sa clé métier, son identifiant se déduit de cette clé.
//  UUID v5 : même entrée ⇒ même sortie, sur tous les appareils, sans aucune
//  coordination. Les deux saisies produisent le même `id`, le connecteur fait
//  deux `upsert` sur la même ligne, et les appareils convergent.
//
//  ── POURQUOI PAS UNE CONTRAINTE D'UNICITÉ EN BASE ? ────────────────────────
//  Parce qu'elle transformerait la convergence en PERTE. Un 23505 fait partie
//  des codes FATALS du connecteur : il abandonne le LOT ENTIER en attente. Une
//  contrainte qui « protège » l'appel du matin en jetant les paiements et les
//  notes saisis dans la même heure est un remède pire que le mal. On rend donc
//  l'écriture idempotente, au lieu de la rendre interdite.
//
//  ── QUAND S'EN SERVIR ──────────────────────────────────────────────────────
//  Seulement pour les lignes dont la clé métier est stable et non révisable :
//  un appel (classe × date × période), une entrée d'appel (appel × élève).
//  PAS pour ce qui peut légitimement exister en plusieurs exemplaires — un
//  paiement, une évaluation, un incident : deux versements de 5 000 F le même
//  jour sont deux versements, et les confondre effacerait de l'argent.
// ════════════════════════════════════════════════════════════════════════════

/// Espace de noms propre à E-PILOTE (tiré une fois, figé pour toujours).
///
/// Le changer réattribuerait TOUS les identifiants déduits : les appareils
/// cesseraient de converger et les lignes existantes seraient orphelines.
const String kNamespaceEpilote = '9f2a6c31-8d47-5b0e-9c14-6a7b3e5d8f20';

const _uuid = Uuid();

/// Identifiant déduit de [cle] — mêmes composantes, même identifiant, partout.
///
/// [type] nomme la sorte de ligne (`'attendance_record'`…) pour qu'une classe
/// et un élève portant le même identifiant ne produisent jamais la même clé.
/// Les composantes sont jointes par un séparateur qui ne peut apparaître dans
/// un UUID ni dans une date.
String idDeterministe(String type, List<String> cle) =>
    _uuid.v5(kNamespaceEpilote, [type, ...cle].join('␟'));
