// ══════════════════════════════════════════════════════════════════════════════
//  L'ÉTAT STATISTIQUE DE RENTRÉE
//
//  Le formulaire que chaque école remonte à sa circonscription en début
//  d'année : effectifs par niveau et par sexe, redoublants, nouveaux inscrits,
//  pyramide des âges, personnel. C'est de là que sortent les statistiques
//  nationales — et, plus concrètement, les dotations.
//
//  ── LE DÉFAUT D'UN DOCUMENT STATISTIQUE EST UN CHIFFRE FAUX AFFIRMÉ ───────
//  Un registre qui perd une ligne se remarque ; un total faux, non. Il a l'air
//  d'un total. Trois règles en découlent, et elles commandent tout le fichier :
//
//   1. **AUCUN ÉLÈVE N'EST JETÉ EN SILENCE.** Sexe absent, date de naissance
//      absente, inscription sans classe : chacun est COMPTÉ À PART et le
//      document l'écrit. Répartir « au mieux » un élève sans sexe entre deux
//      colonnes, c'est fabriquer la statistique qu'on prétend relever.
//
//   2. **L'ÂGE SE CALCULE À UNE DATE FIXE, PAS « AUJOURD'HUI ».** Sinon le même
//      état, réédité en juin, ne donne plus les chiffres remontés en octobre —
//      et c'est l'administration qui découvre l'écart. La référence est la DATE
//      D'OUVERTURE de l'année scolaire, et elle est imprimée sur le document.
//
//   3. **LE DÉNOMINATEUR EST L'INSCRIPTION, PAS L'ÉLÈVE.** Un état de rentrée
//      compte les inscriptions ACTIVES de l'année en cours. Un élève radié en
//      novembre n'a pas fait la rentrée.
//
//  100 % local : l'état se remplit le jour où l'inspecteur passe, pas le jour
//  où le réseau revient.
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../structure/providers/academic_year_context.dart';

/// Une ligne du tableau des effectifs : un niveau d'enseignement.
class LigneNiveau {
  LigneNiveau({
    required this.cycleName,
    required this.cycleOrder,
    required this.levelName,
    required this.levelOrder,
  });

  final String cycleName, levelName;
  final int cycleOrder, levelOrder;

  final Set<String> _classes = {};
  int garcons = 0, filles = 0, sexeInconnu = 0;
  int redoublantsG = 0, redoublantsF = 0;
  int nouveauxG = 0, nouveauxF = 0;

  int get classes => _classes.length;
  int get total => garcons + filles + sexeInconnu;
  int get redoublants => redoublantsG + redoublantsF;
  int get nouveaux => nouveauxG + nouveauxF;

  /// Effectif moyen par classe — le chiffre que l'administration regarde en
  /// premier, parce qu'il décide des ouvertures de classes.
  double get parClasse => classes == 0 ? 0 : total / classes;
}

/// Une tranche d'âge du tableau démographique.
class TrancheAge {
  TrancheAge(this.libelle, this.min, this.max);
  final String libelle;

  /// Bornes incluses. `max == null` = sans limite haute.
  final int min;
  final int? max;

  int garcons = 0, filles = 0;
  int get total => garcons + filles;

  bool contient(int age) => age >= min && (max == null || age <= max!);
}

/// Les tranches du formulaire, du plus jeune au plus âgé. La dernière est
/// ouverte : un élève de 25 ans existe, et le taire fausserait le total.
List<TrancheAge> tranchesAge() => [
      TrancheAge('Moins de 6 ans', 0, 5),
      TrancheAge('6 à 11 ans', 6, 11),
      TrancheAge('12 à 15 ans', 12, 15),
      TrancheAge('16 à 18 ans', 16, 18),
      TrancheAge('19 ans et plus', 19, null),
    ];

/// Un effectif de personnel, par sexe.
class LignePersonnel {
  LignePersonnel(this.role);
  final String role;
  int hommes = 0, femmes = 0, inconnu = 0;
  int get total => hommes + femmes + inconnu;
}

/// Ce que l'état ne sait PAS — imprimé, jamais dissimulé.
class LacunesEtat {
  const LacunesEtat({
    required this.sansSexe,
    required this.sansDateNaissance,
    required this.sansClasse,
    required this.sansEleve,
  });

  final int sansSexe, sansDateNaissance, sansClasse, sansEleve;

  int get total => sansSexe + sansDateNaissance + sansClasse + sansEleve;
  bool get aucune => total == 0;
}

class EtatRentree {
  const EtatRentree({
    required this.niveaux,
    required this.tranches,
    required this.personnel,
    required this.lacunes,
    required this.dateReference,
    required this.internes,
    required this.boursiers,
    required this.aideSociale,
    required this.affectes,
  });

  final List<LigneNiveau> niveaux;
  final List<TrancheAge> tranches;
  final List<LignePersonnel> personnel;
  final LacunesEtat lacunes;

  /// Date à laquelle les âges ont été calculés — imprimée sur le document.
  final DateTime dateReference;

  final int internes, boursiers, aideSociale, affectes;

  int get totalEleves =>
      niveaux.fold(0, (s, n) => s + n.total);
  int get totalGarcons => niveaux.fold(0, (s, n) => s + n.garcons);
  int get totalFilles => niveaux.fold(0, (s, n) => s + n.filles);
  int get totalClasses => niveaux.fold(0, (s, n) => s + n.classes);
  int get totalRedoublants => niveaux.fold(0, (s, n) => s + n.redoublants);
  int get totalNouveaux => niveaux.fold(0, (s, n) => s + n.nouveaux);
  int get totalPersonnel => personnel.fold(0, (s, p) => s + p.total);

  /// Part de filles, en points de pourcentage. `null` si aucun effectif — un
  /// « 0 % » sur une école vide serait une affirmation, pas une absence.
  double? get partFilles =>
      totalEleves == 0 ? null : totalFilles * 100 / totalEleves;
}

/// Âge révolu à la date de référence.
///
/// Fonction pure : c'est le seul calcul du document dont une erreur d'un an
/// déplacerait des élèves entiers d'une tranche à l'autre.
int ageA(DateTime naissance, DateTime reference) {
  var age = reference.year - naissance.year;
  final anniversairePasse = reference.month > naissance.month ||
      (reference.month == naissance.month && reference.day >= naissance.day);
  if (!anniversairePasse) age -= 1;
  return age;
}

DateTime? _date(Object? v) =>
    v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;

bool _vrai(Object? v) => v == 1 || v == true;

final etatRentreeProvider =
    FutureProvider.autoDispose<EtatRentree?>((ref) async {
  final schoolId = ref.watch(authNotifierProvider).valueOrNull?.schoolId;
  final year = ref.watch(activeYearProvider);
  if (schoolId == null || schoolId.isEmpty || year == null) return null;

  // Règle 2 : la date de référence est l'OUVERTURE DE L'ANNÉE, pas le jour de
  // l'édition. Le même état réédité en juin doit donner les chiffres remontés
  // en octobre — sinon c'est l'administration qui découvre l'écart. Elle est
  // imprimée sur le document : le lecteur doit toujours savoir à quand se
  // rapportent les âges.
  final reference = year.startDate;

  final rows = await db.getAll(
    '''
    SELECT e.id, e.is_repeating, e.inscription_type, e.class_id,
           c.level_id, c.level_code, c.level_order, c.cycle_code,
           sl.name AS level_name,
           ec.name AS cycle_name, ec.order_index AS cycle_order,
           s.id AS student_id, s.gender, s.date_of_birth,
           s.is_boarder, s.has_scholarship, s.has_social_aid, s.is_affecte
      FROM class_enrollments e
      LEFT JOIN classes c        ON c.id = e.class_id
      LEFT JOIN school_levels sl ON sl.id = c.level_id
      LEFT JOIN education_cycles ec ON ec.code = c.cycle_code
      LEFT JOIN students s       ON s.id = e.student_id
     WHERE e.school_id = ? AND e.academic_year_id = ? AND e.status = 'active'
    ''',
    [schoolId, year.id],
  );

  final parNiveau = <String, LigneNiveau>{};
  final tranches = tranchesAge();
  var sansSexe = 0, sansDdn = 0, sansClasse = 0, sansEleve = 0;
  var internes = 0, boursiers = 0, aideSociale = 0, affectes = 0;

  for (final r in rows) {
    if (r['student_id'] == null) {
      sansEleve++;
      continue;
    }

    final classId = r['class_id'] as String?;
    if (classId == null || classId.isEmpty) sansClasse++;

    // Un niveau introuvable ne fait pas disparaître l'élève : il est rangé sous
    // « Non précisé », visible dans le tableau, et son total reste juste.
    final niveau = (r['level_name'] as String?) ??
        (r['level_code'] as String?) ??
        'Non précisé';
    final cle = '${r['cycle_order'] ?? 9}|${r['level_order'] ?? 99}|$niveau';
    final ligne = parNiveau.putIfAbsent(
      cle,
      () => LigneNiveau(
        cycleName: (r['cycle_name'] as String?) ?? 'Autres',
        cycleOrder: (r['cycle_order'] as int?) ?? 9,
        levelName: niveau,
        levelOrder: (r['level_order'] as int?) ?? 99,
      ),
    );
    if (classId != null && classId.isNotEmpty) ligne._classes.add(classId);

    final sexe = (r['gender'] as String?)?.trim().toUpperCase();
    final estF = sexe == 'F';
    final estM = sexe == 'M';
    if (estF) {
      ligne.filles++;
    } else if (estM) {
      ligne.garcons++;
    } else {
      // Règle 1 : compté, jamais réparti au hasard.
      ligne.sexeInconnu++;
      sansSexe++;
    }

    if (_vrai(r['is_repeating'])) {
      if (estF) {
        ligne.redoublantsF++;
      } else if (estM) {
        ligne.redoublantsG++;
      }
    }
    if ((r['inscription_type'] as String?) == 'new') {
      if (estF) {
        ligne.nouveauxF++;
      } else if (estM) {
        ligne.nouveauxG++;
      }
    }

    final ddn = _date(r['date_of_birth']);
    if (ddn == null) {
      sansDdn++;
    } else {
      final age = ageA(ddn, reference);
      for (final t in tranches) {
        if (t.contient(age)) {
          if (estF) {
            t.filles++;
          } else {
            t.garcons++;
          }
          break;
        }
      }
    }

    if (_vrai(r['is_boarder'])) internes++;
    if (_vrai(r['has_scholarship'])) boursiers++;
    if (_vrai(r['has_social_aid'])) aideSociale++;
    if (_vrai(r['is_affecte'])) affectes++;
  }

  // ── Personnel de l'établissement ──────────────────────────────────────────
  final agents = await db.getAll(
    'SELECT role, gender FROM profiles '
    ' WHERE school_id = ? AND COALESCE(is_active, 1) <> 0',
    [schoolId],
  );
  final parRole = <String, LignePersonnel>{};
  for (final a in agents) {
    final role = (a['role'] as String?) ?? 'non précisé';
    final p = parRole.putIfAbsent(role, () => LignePersonnel(role));
    final sexe = (a['gender'] as String?)?.trim().toUpperCase();
    if (sexe == 'F') {
      p.femmes++;
    } else if (sexe == 'M') {
      p.hommes++;
    } else {
      p.inconnu++;
    }
  }

  final niveaux = parNiveau.values.toList()
    ..sort((a, b) {
      final c = a.cycleOrder.compareTo(b.cycleOrder);
      if (c != 0) return c;
      final l = a.levelOrder.compareTo(b.levelOrder);
      return l != 0 ? l : a.levelName.compareTo(b.levelName);
    });

  final personnel = parRole.values.toList()
    ..sort((a, b) => b.total.compareTo(a.total));

  return EtatRentree(
    niveaux: niveaux,
    tranches: tranches,
    personnel: personnel,
    dateReference: reference,
    internes: internes,
    boursiers: boursiers,
    aideSociale: aideSociale,
    affectes: affectes,
    lacunes: LacunesEtat(
      sansSexe: sansSexe,
      sansDateNaissance: sansDdn,
      sansClasse: sansClasse,
      sansEleve: sansEleve,
    ),
  );
});
