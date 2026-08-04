// ════════════════════════════════════════════════════════════════════════════
//  IMPORTER UNE LISTE — CONFRONTATION À LA BASE, PUIS ÉCRITURE
//
//  La lecture du fichier (`services/import_liste_eleves.dart`) est pure : elle
//  ne sait rien de l'école. C'est ici qu'on confronte ce qu'elle a lu à ce qui
//  existe déjà : les classes ouvertes, les élèves déjà inscrits.
//
//  ── DEUX RÈGLES QUI COMMANDENT TOUT ───────────────────────────────────────
//  1. On n'écrit RIEN avant que l'utilisateur ait vu le tableau. Un import
//     silencieux de trois cents lignes qu'on découvre fausses ensuite ne se
//     défait pas : il faudrait retrouver et supprimer trois cents dossiers.
//  2. Une ligne douteuse est REJETÉE, jamais rapprochée d'office. Ranger un
//     enfant dans la mauvaise classe parce que son libellé ressemblait à une
//     autre, c'est une erreur qu'on ne découvre qu'au conseil de classe.
//
//  100 % hors ligne : `db.getAll` / `db.execute`, comme tout l'espace école.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/write_identity.dart';
import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../classes/providers/class_provider.dart';
import '../../structure/providers/academic_year_context.dart';
import '../services/import_liste_eleves.dart';
import 'students_provider.dart';

/// Une classe d'accueil possible.
class ClasseCible {
  const ClasseCible(this.id, this.nom);
  final String id;
  final String nom;
}

/// Les classes ouvertes pour l'année courante — les seules destinations
/// possibles d'un import.
final classesImportProvider =
    FutureProvider.autoDispose<List<ClasseCible>>((ref) async {
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final schoolId = profile?.schoolId;
  final yearId = ref.watch(activeYearIdProvider);
  if (schoolId == null || schoolId.isEmpty || yearId == null) return const [];

  final rows = await db.getAll(
    '''
    SELECT c.id, c.name, sl.order_index AS rang
      FROM classes c
      LEFT JOIN school_levels sl ON sl.id = c.level_id
     WHERE c.school_id = ? AND c.academic_year_id = ?
       AND COALESCE(c.is_active, 1) <> 0
     ORDER BY sl.order_index, c.name
    ''',
    [schoolId, yearId],
  );
  return [
    for (final r in rows)
      ClasseCible(r['id'] as String, (r['name'] as String?) ?? '—'),
  ];
});

/// Une ligne prête à écrire — ou prête à expliquer pourquoi elle ne le sera pas.
class LigneResolue {
  LigneResolue(this.ligne, {this.classeId, this.classeNom});
  final LigneImport ligne;

  /// La classe d'accueil, une fois résolue. Nulle si la ligne est rejetée.
  final String? classeId;
  final String? classeNom;

  bool get retenue => ligne.retenue && classeId != null;
}

/// Le bilan d'une préparation : ce qui entrera, ce qui ne le peut pas.
class PreparationImport {
  const PreparationImport({
    required this.lecture,
    required this.lignes,
    required this.classeParDefaut,
  });

  final LectureImport lecture;
  final List<LigneResolue> lignes;
  final String? classeParDefaut;

  List<LigneResolue> get retenues =>
      lignes.where((l) => l.retenue).toList(growable: false);
  List<LigneResolue> get rejetees =>
      lignes.where((l) => !l.retenue).toList(growable: false);

  /// Lignes coupées par la machine entre nom et prénom : à relire avant de
  /// valider. Elles ne bloquent pas, mais elles se signalent.
  List<LigneResolue> get aVerifier =>
      retenues.where((l) => l.ligne.nomDevine).toList(growable: false);
}

/// Confronte le fichier lu à l'état réel de l'école.
///
/// [classeParDefaut] s'applique aux lignes sans colonne « Classe » — cas le
/// plus fréquent, une école tenant un tableau par classe.
Future<PreparationImport> preparerImport({
  required LectureImport lecture,
  required String schoolId,
  required String yearId,
  String? classeParDefaut,
}) async {
  marquerDoublonsInternes(lecture.lignes);

  // ── Les classes de l'école, indexées sur un libellé comparable ───────────
  // « 6e A », « 6ème A » et « 6EME A » désignent la même classe.
  final rows = await db.getAll(
    'SELECT id, name FROM classes '
    'WHERE school_id = ? AND academic_year_id = ? '
    'AND COALESCE(is_active, 1) <> 0',
    [schoolId, yearId],
  );
  final parNom = <String, ({String id, String nom})>{};
  for (final r in rows) {
    final nom = (r['name'] as String?) ?? '';
    parNom[cleClasse(nom)] = (id: r['id'] as String, nom: nom);
  }

  // ── Les élèves déjà présents dans l'école ────────────────────────────────
  final existants = await db.getAll(
    'SELECT first_name, last_name, date_of_birth, ine FROM students '
    'WHERE school_id = ? AND COALESCE(is_active, 1) <> 0',
    [schoolId],
  );
  final empreintes = <String>{};
  final ines = <String>{};
  for (final r in existants) {
    final dob = (r['date_of_birth'] as String?) ?? '';
    empreintes.add('${normaliserEntete((r['last_name'] as String?) ?? '')}|'
        '${normaliserEntete((r['first_name'] as String?) ?? '')}|'
        '${dob.length >= 10 ? dob.substring(0, 10) : dob}');
    final ine = (r['ine'] as String?)?.trim();
    if (ine != null && ine.isNotEmpty) ines.add(ine);
  }

  final resolues = <LigneResolue>[];
  for (final l in lecture.lignes) {
    if (!l.retenue) {
      resolues.add(LigneResolue(l));
      continue;
    }

    // Déjà dans l'école : on ne réinscrit pas, on le dit.
    if (empreintes.contains(l.empreinte)) {
      l.rejets.add(const MotifRejet(
          'Déjà inscrit dans l\'établissement — ligne ignorée'));
      resolues.add(LigneResolue(l));
      continue;
    }
    final ine = l.ine?.trim();
    if (ine != null && ine.isNotEmpty && ines.contains(ine)) {
      l.rejets.add(MotifRejet(
          'Un élève de l\'établissement porte déjà l\'identifiant $ine'));
      resolues.add(LigneResolue(l));
      continue;
    }

    // La classe : celle du fichier si elle est nommée, sinon celle choisie.
    final texte = l.classeTexte?.trim();
    if (texte != null && texte.isNotEmpty) {
      final trouvee = parNom[cleClasse(texte)];
      if (trouvee == null) {
        // On ne rapproche PAS d'une classe qui « ressemble » : mettre un
        // enfant en 6ᵉ B au lieu de 6ᵉ A ne se découvre qu'au conseil.
        l.rejets.add(MotifRejet('Classe « $texte » inconnue dans '
            'l\'établissement — créez-la, ou corrigez le fichier'));
        resolues.add(LigneResolue(l));
        continue;
      }
      resolues.add(
          LigneResolue(l, classeId: trouvee.id, classeNom: trouvee.nom));
      continue;
    }

    if (classeParDefaut == null) {
      l.rejets.add(const MotifRejet(
          'Aucune classe indiquée — choisissez une classe d\'accueil'));
      resolues.add(LigneResolue(l));
      continue;
    }
    final defaut = rows.where((r) => r['id'] == classeParDefaut);
    resolues.add(LigneResolue(l,
        classeId: classeParDefaut,
        classeNom: defaut.isEmpty
            ? null
            : (defaut.first['name'] as String?)));
  }

  return PreparationImport(
    lecture: lecture,
    lignes: resolues,
    classeParDefaut: classeParDefaut,
  );
}

/// Réduit un nom de classe à sa forme comparable : « 6ᵉ A », « 6ème A » et
/// « 6EME A » désignent la même classe et doivent se rejoindre.
///
/// On n'enlève que les suffixes d'ordinal — jamais une lettre isolée, qui
/// distingue précisément 6ᵉ A de 6ᵉ B.
String cleClasse(String nom) => normaliserEntete(nom)
    // L'ordinal ne se retire QUE s'il suit un chiffre. Un « e » isolé peut
    // être la section : effacer celui de « 6 E » le confondrait avec « 6ᵉ ».
    .replaceAllMapped(
        RegExp(r'(\d+)\s*(?:eme|ere|er|nde|nd|e)\b'), (m) => m[1]!)
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Ce qu'a donné l'écriture.
class BilanImport {
  const BilanImport({
    required this.importes,
    required this.echecs,
  });

  final int importes;

  /// Lignes que la base a refusées malgré la préparation — numéro et cause.
  final List<({int ligne, String nom, String cause})> echecs;

  bool get parfait => echecs.isEmpty;
}

/// Écrit les élèves retenus et leur inscription.
///
/// Ligne par ligne, volontairement : un échec isolé ne doit pas emporter les
/// deux cent quatre-vingt-dix-neuf autres. [progression] est appelée après
/// chaque ligne pour que l'écran reste vivant sur un gros fichier.
Future<BilanImport> executerImport({
  required PreparationImport preparation,
  required String schoolId,
  required String groupId,
  required String yearId,
  String? saisiPar,
  void Function(int faites, int total)? progression,
}) async {
  final aFaire = preparation.retenues;
  final echecs = <({int ligne, String nom, String cause})>[];
  var faites = 0;

  // Les colonnes NOT NULL du serveur, vérifiées une dernière fois ici.
  //
  // L'invariant existe déjà : une ligne sans date, sans sexe ou sans classe
  // porte un rejet, donc n'est pas « retenue ». Mais cet invariant se lit dans
  // TROIS fichiers, et il suffit qu'un futur appelant construise une
  // PreparationImport autrement pour qu'un NULL parte vers une colonne NOT
  // NULL — et le refus serveur emporterait le lot PowerSync entier, pas la
  // ligne. On le revérifie donc au bord de l'écriture, où la conséquence est.
  if (!isUsableId(groupId) || !isUsableId(schoolId) || !isUsableId(yearId)) {
    throw ArgumentError(writeIdentityMessage(missingWriteIds(
      groupId: groupId,
      schoolId: schoolId,
      actorId: saisiPar,
    )));
  }

  for (final r in aFaire) {
    final l = r.ligne;
    try {
      final date = l.dateNaissance;
      final sexe = l.sexe;
      final classe = r.classeId;
      if (date == null || sexe == null || classe == null) {
        echecs.add((
          ligne: l.numero,
          nom: l.nomAffiche,
          cause: 'Ligne incomplète — non enregistrée',
        ));
        faites++;
        progression?.call(faites, aFaire.length);
        continue;
      }

      // ⚠️ L'INE du fichier n'est PAS repris. Il sert à repérer les doublons,
      // rien de plus : c'est le serveur qui attribue l'identifiant national
      // (migration 0080), et un numéro recopié d'un ancien cahier
      // rattacherait le dossier au parcours de quelqu'un d'autre.
      final studentId = await createStudent(
        schoolId: schoolId,
        groupId: groupId,
        firstName: l.prenom,
        lastName: l.nom,
        dateOfBirth: date,
        gender: sexe,
        placeOfBirth: l.lieuNaissance,
        nationality: l.nationalite,
        address: l.adresse,
      );
      // Statut `pending_validation`, comme toute inscription saisie à la main :
      // un import ne court-circuite pas le regard du chef d'établissement.
      await enrollStudent(
        groupId: groupId,
        schoolId: schoolId,
        studentId: studentId,
        classId: classe,
        academicYearId: yearId,
        isRepeating: l.redoublant,
        inscriptionType: 'new',
        notes: 'Importé depuis un fichier',
        createdBy: saisiPar,
      );
    } catch (e) {
      echecs.add((ligne: l.numero, nom: l.nomAffiche, cause: '$e'));
    }
    faites++;
    progression?.call(faites, aFaire.length);
  }

  return BilanImport(importes: aFaire.length - echecs.length, echecs: echecs);
}
