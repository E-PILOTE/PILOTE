import '../../students/widgets/scope_drilldown_panel.dart';
import 'cartes_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  FILTRER LA CAMPAGNE DE CARTES
//
//  ── POURQUOI FILTRER, SUR UN ÉCRAN QUI IMPRIME ────────────────────────────
//  Une école de mille élèves ne fabrique pas ses cartes d'un bloc : elle les
//  fait classe par classe, et souvent filière par filière — au METP, la
//  Comptabilité et l'Électrotechnique ne passent pas au même moment, parce que
//  ce ne sont pas les mêmes ateliers ni les mêmes emplois du temps.
//
//  Le filtre n'est donc pas un confort de lecture : c'est le découpage réel du
//  travail. Et il commande AUSSI l'impression — ce qu'on voit à l'écran est ce
//  qui sortira sur la planche, sans quoi l'agent croirait imprimer sa filière
//  et sortirait l'école entière.
//
//  ── ⚠️ LA FILIÈRE NE DÉPEND PAS DU NIVEAU, MAIS DE LA VOIE ────────────────
//  Une première version de ce fichier affirmait « au primaire et au collège la
//  notion n'existe pas ». C'est FAUX, et c'est faux précisément pour l'un des
//  deux ministères qui commandent la plateforme.
//
//  En enseignement GÉNÉRAL (MEPSA) : pas de filière au collège, séries A/C/D au
//  lycée. En enseignement TECHNIQUE (METP) : le collège technique — le CET —
//  est organisé PAR MÉTIER dès le premier cycle (menuiserie, maçonnerie,
//  électricité, soudure, couture, secrétariat…), s'entre après le CEPE et mène
//  au CAP. Le référentiel de la plateforme le dit lui-même : au cycle
//  `college`, `education_programs` porte `college_general` ET
//  `college_technique`. Et 12 des 37 écoles de la base sont sous tutelle METP.
//
//  Le code, lui, était juste : il n'a jamais regardé que `filiere_label`,
//  jamais le cycle. Une classe de CET avec sa filière est donc comptée
//  correctement. C'était la JUSTIFICATION qui était fausse — le genre d'erreur
//  qui ne casse rien aujourd'hui et qui fait « optimiser » de travers demain.
//
//  La règle juste : une classe sans filière n'est pas une classe à compléter,
//  non pas parce que « son niveau n'en a pas », mais parce que toutes les voies
//  n'en définissent pas.
// ════════════════════════════════════════════════════════════════════════════

/// L'état des photos d'une classe, tel qu'on filtre dessus.
enum EtatPhoto {
  toutes('Toutes'),
  completes('Complètes'),
  incompletes('Photos manquantes');

  const EtatPhoto(this.libelle);
  final String libelle;
}

/// Ce que l'agent regarde en ce moment.
class FiltreCartes {
  const FiltreCartes({
    this.scope = const ScopeSel(),
    this.filiere,
    this.photo = EtatPhoto.toutes,
  });

  /// Cycle / niveau / classe — le panneau partagé du dépôt.
  final ScopeSel scope;

  /// Libellé exact de la filière, `null` = toutes.
  final String? filiere;

  final EtatPhoto photo;

  bool get actif =>
      scope.active || filiere != null || photo != EtatPhoto.toutes;

  FiltreCartes avecScope(ScopeSel s) =>
      FiltreCartes(scope: s, filiere: filiere, photo: photo);

  /// `null` remet « toutes les filières » — le même clic ferme ce qu'il a
  /// ouvert, comme partout ailleurs dans l'application.
  FiltreCartes avecFiliere(String? f) =>
      FiltreCartes(scope: scope, filiere: f, photo: photo);

  FiltreCartes avecPhoto(EtatPhoto p) =>
      FiltreCartes(scope: scope, filiere: filiere, photo: p);

  static const aucun = FiltreCartes();
}

/// Applique le filtre à la liste des classes.
///
/// ⚠️ L'ordre des critères n'a aucune importance ici (ils se cumulent), mais
/// leur LECTURE en a une : `photo` porte sur l'état de la CLASSE, pas de
/// l'élève. « Photos manquantes » retient les classes où il en manque au moins
/// une — c'est la liste du travail qui reste, pas la liste des élèves sans
/// visage.
List<CarteClasse> filtrerClasses(
  List<CarteClasse> classes,
  FiltreCartes f,
) =>
    classes.where((c) {
      if (c.eleves == 0) return false;
      final s = f.scope;
      if (s.cycle != null && c.cycleCode != s.cycle) return false;
      if (s.level != null && c.levelCode != s.level) return false;
      if (s.classId != null && c.classId != s.classId) return false;
      if (f.filiere != null && c.filiereLabel != f.filiere) return false;
      return switch (f.photo) {
        EtatPhoto.toutes => true,
        EtatPhoto.completes => c.complet,
        EtatPhoto.incompletes => c.sansPhoto > 0,
      };
    }).toList();

/// Une unité par ÉLÈVE, pour `ScopeDrilldownPanel`.
///
/// ⚠️ On développe les compteurs plutôt que de relire les 9 000 lignes
/// d'élèves : le panneau ne fait que compter, et charger l'effectif entier
/// d'une école pour dessiner cinq cartes de cycle serait payer très cher un
/// chiffre qu'on a déjà.
List<ScopeUnit> unitesDepuisClasses(List<CarteClasse> classes) => [
      for (final c in classes)
        for (var i = 0; i < c.eleves; i++)
          ScopeUnit(
            cycleCode: c.cycleCode,
            levelCode: c.levelCode,
            levelOrder: c.levelOrder,
            classId: c.classId,
            className: c.className,
            ok: i < c.avecPhoto,
          ),
    ];

/// Le décompte d'une filière — ce qu'affiche sa pastille.
class BilanFiliere {
  BilanFiliere(this.libelle);

  /// `null` pour « Sans filière » — une voie qui n'en définit pas.
  final String? libelle;
  int classes = 0, eleves = 0, avecPhoto = 0;

  int get sansPhoto => eleves - avecPhoto;
  bool get complet => eleves > 0 && sansPhoto == 0;
}

/// Les filières présentes, triées par effectif décroissant.
///
/// Rend une liste VIDE quand aucune classe ne porte de filière — l'écran
/// n'affiche alors pas la section du tout, plutôt qu'une rangée vide qui
/// laisserait croire à une donnée absente.
List<BilanFiliere> bilansFilieres(List<CarteClasse> classes) {
  final parLibelle = <String?, BilanFiliere>{};
  var auMoinsUne = false;

  for (final c in classes) {
    if (c.eleves == 0) continue;
    if (c.filiereLabel != null) auMoinsUne = true;
    final b = parLibelle.putIfAbsent(
        c.filiereLabel, () => BilanFiliere(c.filiereLabel));
    b.classes++;
    b.eleves += c.eleves;
    b.avecPhoto += c.avecPhoto;
  }

  if (!auMoinsUne) return const [];

  final out = parLibelle.values.toList()
    // « Sans filière » ferme la marche : c'est un reste, pas une filière.
    ..sort((a, b) {
      if ((a.libelle == null) != (b.libelle == null)) {
        return a.libelle == null ? 1 : -1;
      }
      return b.eleves.compareTo(a.eleves);
    });
  return out;
}
