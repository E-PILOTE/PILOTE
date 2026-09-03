import 'dart:io';

import 'package:epilote/features/super_admin/providers/school_groups_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE RÔLE DE TUTELLE S'ACCORDE — À UN SEUL GROUPE PAR MINISTÈRE
//
//  ── CE QUI EXISTAIT, ET CE QUI N'EXISTAIT PAS ─────────────────────────────
//  `school_groups.administre_referentiel_national` (migration 0155) désigne LE
//  ministère de tutelle d'un enseignement. Ce booléen ouvre, à lui seul :
//  l'écriture du référentiel national des examens, la lecture de tout le
//  réseau du ministère — écoles qu'il ne possède pas comprises, avec le nom de
//  leurs chefs d'établissement —, l'émission de circulaires, et la vente d'une
//  licence de tutelle.
//
//  Il a pourtant vécu deux ans sans écran pour l'écrire : posé une fois par la
//  migration 0155, jamais retouché. Et la règle « exactement un par ministère »
//  n'était vérifiée que par un bloc `DO` DANS cette migration — c'est-à-dire
//  nulle part, une fois la migration passée.
//
//  ⚠️ TANT QUE RIEN N'ÉCRIVAIT LA COLONNE, LE TROU ÉTAIT THÉORIQUE. L'écran
//  qui accorde le rôle le rend réel : deux groupes marqués pour le même
//  ministère écriraient tous les deux la même session d'examen d'État, et
//  chacun verrait les écoles de l'autre. D'où l'ordre suivi — l'index unique
//  (migration 0178) AVANT l'interrupteur, pas après.
//
//  ── CE QUE CE FICHIER GARDE ───────────────────────────────────────────────
//  Le conflit se DIT côté écran et se REFUSE côté base. Les deux moitiés sont
//  gardées ici : la fonction qui nomme le détenteur, et le fait que la base
//  porte bien un index — pas seulement un déclencheur, ni seulement un
//  commentaire.
// ════════════════════════════════════════════════════════════════════════════

const _migration =
    '../database/migrations/0178_AVANT_LE_BUILD_une_seule_tutelle_par_ministere.sql';
const _formulaire =
    'lib/features/super_admin/screens/groups/group_form_modal.dart';
const _interrupteur =
    'lib/features/super_admin/screens/groups/group_tutelle_role.dart';

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('Fichier introuvable : $chemin — sonde aveugle.');
  return f.readAsStringSync();
}

/// Un groupe réduit à ce que la règle regarde : son ministère, et s'il en est
/// la tutelle. Tout le reste est du remplissage exigé par le constructeur.
GroupDetail _groupe({
  required String id,
  required String nom,
  required String tutelle,
  bool tuteur = false,
}) =>
    GroupDetail(
      id: id,
      name: nom,
      groupType: 'public',
      subscriptionStatus: 'active',
      adminEmail: 'x@y.cg',
      planId: 'p',
      planName: 'Plan',
      priceXaf: 0,
      maxSchools: 1,
      maxStudents: 1,
      isActive: true,
      schoolCount: 0,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      tutelle: tutelle,
      administreReferentielNational: tuteur,
    );

void main() {
  final mepsa = _groupe(
      id: 'm', nom: 'MEPSA — Ministère', tutelle: 'mepsa', tuteur: true);
  final metp = _groupe(
      id: 't', nom: 'Ministère Technique', tutelle: 'metp', tuteur: true);
  final prive = _groupe(id: 'p', nom: 'Réseau Saint-Pierre', tutelle: 'mepsa');
  final reseau = [mepsa, metp, prive];

  group('Qui détient déjà le rôle', () {
    test('le ministère du même enseignement est nommé', () {
      expect(detenteurDuRoleDeTutelle(reseau, 'mepsa'), 'MEPSA — Ministère');
      expect(detenteurDuRoleDeTutelle(reseau, 'metp'), 'Ministère Technique');
    });

    test('un groupe ne se voit pas reprocher d’être ce qu’il est déjà', () {
      // Rouvrir la fiche du MEPSA pour changer son téléphone ne doit pas
      // afficher « MEPSA détient déjà ce rôle » ni bloquer son propre
      // interrupteur.
      expect(detenteurDuRoleDeTutelle(reseau, 'mepsa', saufId: 'm'), isNull);
    });

    test('un ministère n’en bloque pas un autre', () {
      // Le rôle se compte PAR MINISTÈRE : que le MEPSA soit pourvu ne dit
      // rien du METP.
      final sansMetp = [mepsa, prive];
      expect(detenteurDuRoleDeTutelle(sansMetp, 'metp'), isNull);
    });

    test('sans ministère choisi, il n’y a rien à dire', () {
      // L'interrupteur est alors désactivé : « être la tutelle » n'a de sens
      // que rapporté à UN ministère.
      expect(detenteurDuRoleDeTutelle(reseau, null), isNull);
      expect(detenteurDuRoleDeTutelle(reseau, ''), isNull);
    });

    test('un groupe ordinaire ne détient rien', () {
      expect(detenteurDuRoleDeTutelle([prive], 'mepsa'), isNull);
    });
  });

  group('La base refuse ce que l’écran annonce', () {
    test('un INDEX UNIQUE, pas seulement un déclencheur', () {
      // ⚠️ C'est la moitié qui manquait. Un déclencheur qui compte avec un
      // SELECT a une fenêtre de course : deux super_admins qui valident à la
      // même seconde passeraient tous les deux. L'index, lui, est tenu par le
      // moteur et survit à tout chemin d'écriture.
      final sql = _lire(_migration);
      expect(sql.contains('CREATE UNIQUE INDEX'), isTrue,
          reason: 'La garantie a été remplacée par un contrôle applicatif : '
              'deux groupes de tutelle redeviennent possibles.');
      expect(sql.contains('school_groups_un_seul_par_tutelle'), isTrue);
      expect(sql.contains('WHERE administre_referentiel_national'), isTrue,
          reason: 'Index non partiel : les six autres groupes ne pourraient '
              'plus partager un ministère.');
    });

    test('et un message écrit pour l’agent', () {
      // Seul, l'index rend un 23505 que `message_erreur.dart` traduit par
      // « Cet enregistrement existe déjà » — vrai, et inutilisable.
      final sql = _lire(_migration);
      expect(sql.contains('HINT'), isTrue,
          reason: 'Sans HINT, l’agent ne sait pas QUEL groupe détient le rôle '
              'ni qu’il faut le lui retirer d’abord.');
      expect(sql.contains('trg_une_seule_tutelle_par_ministere'), isTrue);
    });

    test('un admin_groupe ne peut pas se l’octroyer', () {
      // La liste blanche de 0154 dit ce qu'un admin_groupe règle sur SON
      // groupe. Le rôle de tutelle n'y est pas, et ne doit jamais y entrer :
      // il y gagnerait la lecture du réseau entier de son ministère.
      final sql = _lire('../database/migrations/'
          '0154_AVANT_LE_BUILD_admin_groupe_peut_regler_son_groupe.sql');
      final i = sql.indexOf('k NOT IN (');
      expect(i, greaterThan(0), reason: 'Liste blanche introuvable.');
      final liste = sql.substring(i, sql.indexOf(')', i));
      expect(liste.contains('administre_referentiel_national'), isFalse,
          reason: 'Le rôle de tutelle est entré dans la liste blanche : un '
              'admin_groupe pourrait se déclarer ministère.');
    });
  });

  group('Un ministère ne s’efface pas par mégarde', () {
    // ⚠️ 0178 a fermé l'ÉCRITURE, pas la SUPPRESSION. `delete_school_group`
    // efface une cinquantaine de tables puis le groupe et ne regarde jamais
    // `administre_referentiel_national` : supprimer le MEPSA était un clic
    // comme un autre, et il aurait laissé 25 établissements sans tutelle,
    // le référentiel national des examens sans personne pour l'écrire, et
    // l'écran aurait affiché « Groupe supprimé définitivement » en vert.
    const migration = '../database/migrations/'
        '0179_AVANT_LE_BUILD_un_ministere_ne_seffce_pas_par_megarde.sql';

    test('le refus est posé sur la TABLE, pas dans la RPC', () {
      // Un contrôle dans `delete_school_group` ne couvrirait que cette
      // fonction : un DELETE par PostgREST, psql ou une future RPC passerait
      // à côté.
      final sql = _lire(migration);
      expect(sql.contains('BEFORE DELETE ON public.school_groups'), isTrue,
          reason: 'Le garde a quitté la table : les autres chemins de '
              'suppression redeviennent ouverts.');
      expect(sql.contains('trg_ministere_ne_seffce_pas'), isTrue);
    });

    test('et il donne le chemin sûr au lieu de dire « non »', () {
      final sql = _lire(migration);
      expect(sql.contains('HINT'), isTrue);
      expect(sql.contains('puis supprimez le groupe'), isTrue,
          reason: 'Le refus n’indique plus quoi faire : retirer le rôle, '
              'puis supprimer.');
    });

    test('le dialogue le dit AVANT le clic', () {
      // Le dialogue faisait cocher « je comprends que cette action est
      // irréversible » pour finir sur un refus de la base.
      final src =
          _lire('lib/features/super_admin/screens/school_groups_screen.dart');
      expect(src.contains('_RefusMinistere('), isTrue,
          reason: 'Le dialogue propose de nouveau de supprimer un ministère.');
      expect(src.contains('_confirmed && !_estMinistere'), isTrue,
          reason: 'Le bouton « Supprimer » redevient cliquable sur un '
              'ministère : le refus n’arriverait qu’après le clic.');
    });
  });

  group('Ce que l’écran déclare', () {
    test('le formulaire envoie le rôle', () {
      final src = _lire(_formulaire);
      expect(src.contains("'administre_referentiel_national': _estTutelle"),
          isTrue,
          reason: 'Le formulaire n’écrit plus le rôle : l’interrupteur '
              'bougerait à l’écran sans rien changer en base.');
    });

    test('et il dit le conflit avant le clic sur « Enregistrer »', () {
      final src = _lire(_formulaire);
      expect(src.contains('detenteurDuRoleDeTutelle('), isTrue,
          reason: 'L’écran ne consulte plus les autres groupes : le conflit ne '
              'se découvrirait qu’au refus de la base.');
      expect(src.contains('saufId: widget.existing?.id'), isTrue,
          reason: 'Sans exclusion du groupe modifié, un ministère verrait son '
              'propre interrupteur bloqué en rouvrant sa fiche.');
    });

    test('retirer le rôle reste toujours possible', () {
      // ⚠️ Déplacer le rôle d'un groupe vers un autre impose de le retirer au
      // premier. Un blocage symétrique rendrait ce déplacement impossible —
      // et c'est la manœuvre pour laquelle cet écran existe.
      final src = _lire(_interrupteur);
      final i = src.indexOf('String? get _blocage {');
      expect(i, greaterThan(0), reason: 'La règle de blocage a été déplacée.');
      expect(src.substring(i, i + 120).contains('if (actif) return null;'),
          isTrue,
          reason: 'Le retrait est devenu blocable : le rôle serait irrévocable '
              'et ne pourrait plus changer de groupe.');
    });
  });
}
