// ══════════════════════════════════════════════════════════════════════════════
//  CARTES SCOLAIRES — la campagne de rentrée, classe par classe
//
//  ── LE VRAI SUJET N'EST PAS LE PDF, C'EST LA PHOTO ─────────────────────────
//  Fabriquer la carte est l'affaire d'un service d'export. Ce qui décide du
//  succès du module, c'est que sur les 9 106 élèves de la base, ZÉRO avait une
//  photo au moment où il a été écrit. Un module qui se contenterait d'imprimer
//  produirait neuf mille silhouettes grises et se ferait juger inutile.
//
//  L'écran compte donc les visages AVANT de proposer d'imprimer, classe par
//  classe, et le dit en toutes lettres. La carte se fabrique quand même — une
//  école peut vouloir des cartes sans photo pour la cantine — mais jamais sans
//  que l'agent sache ce qu'il va découper.
//
//  ── OFFLINE-FIRST, SANS EXCEPTION ──────────────────────────────────────────
//  Tout se lit par `db.watch` / `db.getAll` : c'est l'espace école. Les octets
//  des photos viennent de la file d'envoi puis du cache disque
//  (`core/utils/photo_octets.dart`), et le réseau n'est que le dernier recours.
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/photo_octets.dart';
import '../../../services/powersync/powersync_service.dart';
import '../../../services/powersync/upload_outbox.dart';
import '../../students/services/carte_scolaire_pdf_service.dart';

// ─── Les classes de l'année, avec leur avancement photo ──────────────────────

class CarteClasse {
  const CarteClasse({
    required this.classId,
    required this.className,
    required this.cycleName,
    required this.eleves,
    required this.avecPhoto,
    this.cycleCode,
    this.levelCode,
    this.levelOrder = 999,
    this.filiereLabel,
  });

  final String classId, className, cycleName;

  /// Codes de la hiérarchie — ce que `ScopeDrilldownPanel` attend pour bâtir
  /// ses KPI par cycle et ses déroulants Niveau / Classe.
  final String? cycleCode, levelCode;
  final int levelOrder;

  /// Filière de la classe. `null` quand la voie n'en définit pas — c'est une
  /// ABSENCE, pas un « Non renseigné » à corriger.
  ///
  /// ⚠️ Ne pas la déduire du NIVEAU : le collège technique (CET, tutelle METP)
  /// est organisé par métier dès le premier cycle et mène au CAP. Le
  /// référentiel `education_programs` porte `college_technique` au cycle
  /// `college`.
  final String? filiereLabel;

  /// Inscriptions ACTIVES. Une carte ne se délivre qu'à qui est présent
  /// ([peutDelivrerCarte]) : compter les autres donnerait une planche plus
  /// longue que la classe.
  final int eleves;
  final int avecPhoto;

  int get sansPhoto => eleves - avecPhoto;
  bool get complet => eleves > 0 && sansPhoto == 0;
}

/// Classes de l'année, triées comme la scolarité les ordonne : par cycle
/// d'abord — `level_order` REPART À 1 à chaque cycle, trier dessus seul
/// entrelacerait CP1, 6ème et 2nde.
final cartesClassesProvider = StreamProvider.autoDispose
    .family<List<CarteClasse>, String>((ref, yearId) {
  return db
      .watch(
        '''
        SELECT c.id, c.name, c.cycle_code, c.level_order, c.filiere_label,
               c.level_code,
               COALESCE(ec.name, 'Autres') AS cycle_name,
               COALESCE(ec.order_index, 9) AS cycle_order,
               COUNT(e.id) AS eleves,
               SUM(CASE WHEN s.photo_url IS NOT NULL AND s.photo_url <> ''
                        THEN 1 ELSE 0 END) AS avec_photo
          FROM classes c
          LEFT JOIN education_cycles ec ON ec.code = c.cycle_code
          LEFT JOIN class_enrollments e
                 ON e.class_id = c.id AND e.status = 'active'
          LEFT JOIN students s ON s.id = e.student_id
         WHERE c.academic_year_id = ? AND COALESCE(c.is_active, 1) <> 0
         GROUP BY c.id, c.name, c.cycle_code, c.level_code, c.level_order,
                  c.filiere_label, ec.name, ec.order_index
         ORDER BY cycle_order, c.level_order, c.name
        ''',
        parameters: [yearId],
      )
      .map((rows) => [
            for (final r in rows)
              CarteClasse(
                classId: r['id'] as String,
                className: r['name'] as String? ?? '—',
                cycleName: r['cycle_name'] as String? ?? 'Autres',
                cycleCode: r['cycle_code'] as String?,
                levelCode: r['level_code'] as String?,
                levelOrder: (r['level_order'] as int?) ?? 999,
                filiereLabel: (r['filiere_label'] as String?)?.trim().isEmpty ??
                        true
                    ? null
                    : (r['filiere_label'] as String).trim(),
                eleves: (r['eleves'] as int?) ?? 0,
                avecPhoto: (r['avec_photo'] as int?) ?? 0,
              ),
          ]);
});

/// Bilan de l'école entière — l'en-tête de campagne.
final cartesBilanProvider = Provider.autoDispose
    .family<({int eleves, int avecPhoto, int classes}), String>((ref, yearId) {
  final classes = ref.watch(cartesClassesProvider(yearId)).valueOrNull ?? [];
  var e = 0, p = 0;
  for (final c in classes) {
    e += c.eleves;
    p += c.avecPhoto;
  }
  return (eleves: e, avecPhoto: p, classes: classes.length);
});

// ─── Les élèves d'une classe ─────────────────────────────────────────────────

class CarteEleveRow {
  const CarteEleveRow({
    required this.studentId,
    required this.firstName,
    required this.lastName,
    required this.matricule,
    required this.className,
    required this.status,
    this.ine,
    this.gender,
    this.dateOfBirth,
    this.placeOfBirth,
    this.bloodGroup,
    this.isBoarder = false,
    this.photoUrl,
  });

  final String studentId, firstName, lastName, matricule, className, status;
  final String? ine, gender, placeOfBirth, bloodGroup, photoUrl;
  final DateTime? dateOfBirth;
  final bool isBoarder;

  String get fullName => '${lastName.toUpperCase()} $firstName'.trim();
  bool get aUnePhoto => photoUrl != null && photoUrl!.isNotEmpty;
}

const String _selectEleves = '''
  SELECT s.id, s.first_name, s.last_name, s.matricule, s.ine, s.gender,
         s.date_of_birth, s.place_of_birth, s.blood_group, s.is_boarder,
         s.photo_url, c.name AS class_name, e.status
    FROM class_enrollments e
    JOIN students s ON s.id = e.student_id
    JOIN classes  c ON c.id = e.class_id
   WHERE e.class_id = ? AND e.status = 'active'
   ORDER BY s.last_name COLLATE NOCASE, s.first_name COLLATE NOCASE
''';

CarteEleveRow _rowVers(Map<String, dynamic> r) => CarteEleveRow(
      studentId: r['id'] as String,
      firstName: (r['first_name'] as String?) ?? '',
      lastName: (r['last_name'] as String?) ?? '',
      matricule: (r['matricule'] as String?) ?? '—',
      className: (r['class_name'] as String?) ?? '—',
      status: (r['status'] as String?) ?? '',
      ine: r['ine'] as String?,
      gender: r['gender'] as String?,
      dateOfBirth: DateTime.tryParse((r['date_of_birth'] as String?) ?? ''),
      placeOfBirth: r['place_of_birth'] as String?,
      bloodGroup: r['blood_group'] as String?,
      isBoarder: r['is_boarder'] == 1 || r['is_boarder'] == true,
      photoUrl: r['photo_url'] as String?,
    );

final cartesElevesProvider = StreamProvider.autoDispose
    .family<List<CarteEleveRow>, String>((ref, classId) {
  return db
      .watch(_selectEleves, parameters: [classId])
      .map((rows) => rows.map(_rowVers).toList());
});

// ─── Préparer les cartes : les lignes, PUIS les visages ──────────────────────

/// Résultat d'une préparation : les cartes prêtes à imprimer et le nombre de
/// visages qui manquaient réellement à l'impression.
///
/// ⚠️ [sansPhoto] n'est PAS le compte de `photo_url` vides. Une photo peut
/// avoir une URL et rester introuvable sur ce poste (jamais affichée ici, pas
/// de réseau). C'est ce chiffre-là — celui de la planche réelle — qu'il faut
/// annoncer, pas celui de la base.
typedef PreparationCartes = ({List<CarteEleve> cartes, int sansPhoto});

/// Construit les cartes d'une liste d'élèves, visages compris.
///
/// [enAttente] est la file d'envoi lue une seule fois par l'appelant.
Future<PreparationCartes> preparerCartes(
  List<CarteEleveRow> eleves, {
  Map<String, String>? enAttente,
  bool reseau = true,
}) async {
  final cartes = <CarteEleve>[];
  var manquants = 0;

  for (final e in eleves) {
    // Le refus vit dans le service : on ne fabrique pas une carte pour une
    // inscription qui n'est plus active, même si l'appelant l'a demandée.
    if (!peutDelivrerCarte(e.status)) continue;

    final octets =
        await octetsPhoto(e.photoUrl, enAttente: enAttente, reseau: reseau);
    if (octets == null) manquants++;

    cartes.add(CarteEleve(
      firstName: e.firstName,
      lastName: e.lastName,
      className: e.className,
      matricule: e.matricule,
      ine: e.ine,
      gender: e.gender,
      dateOfBirth: e.dateOfBirth,
      placeOfBirth: e.placeOfBirth,
      bloodGroup: e.bloodGroup,
      isBoarder: e.isBoarder,
      photo: octets,
    ));
  }

  return (cartes: cartes, sansPhoto: manquants);
}

/// La file d'envoi, prête à être passée à [preparerCartes].
Map<String, String>? filePhotosEnAttente(WidgetRef ref) =>
    ref.read(pendingUploadPathsProvider).valueOrNull;
