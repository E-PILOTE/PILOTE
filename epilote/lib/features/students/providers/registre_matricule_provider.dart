// ══════════════════════════════════════════════════════════════════════════════
//  LE REGISTRE MATRICULE — le grand livre réglementaire
//
//  ── CE QUE C'EST, ET EN QUOI IL DIFFÈRE DE L'EFFECTIF ─────────────────────
//  L'écran Élèves montre qui est LÀ. Le registre matricule porte tous ceux qui
//  ONT ÉTÉ inscrits, dans l'ordre de leur matricule, avec leur état civil,
//  leur date d'entrée et — s'il y a lieu — leur date et leur motif de sortie.
//  C'est un document que l'inspection demande, et le seul dont l'exhaustivité
//  soit la propriété principale.
//
//  ── UN REGISTRE QUI PERD UNE LIGNE N'EST PAS UN REGISTRE ──────────────────
//  D'où le compte des LACUNES. Les inscriptions descendent sur le poste sans
//  filtre ; les élèves, eux, passaient par `WHERE is_active = true`. Un élève
//  archivé quittait donc le bucket et disparaissait de l'appareil, en laissant
//  derrière lui son inscription — une référence pendante.
//
//  Cette référence est la SIGNATURE du trou : une inscription dont l'élève est
//  introuvable en local. On la compte, et le document le dit. Les sync-rules
//  sont corrigées (le filtre est retiré) ; tant que le déploiement n'a pas eu
//  lieu, le registre annonce ce qu'il ne voit pas plutôt que de se prétendre
//  complet. C'est la seule attitude tenable pour une pièce réglementaire.
//
//  100 % local (`db.getAll`) : le registre s'imprime pour une inspection qui
//  est dans le bureau, pas quand le réseau revient.
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/auth_provider.dart';

/// Une ligne du grand livre.
class LigneRegistre {
  const LigneRegistre({
    required this.studentId,
    required this.matricule,
    required this.lastName,
    required this.firstName,
    this.ine,
    this.gender,
    this.dateOfBirth,
    this.placeOfBirth,
    this.address,
    this.tuteur,
    this.tuteurTel,
    this.entreeLe,
    this.classeEntree,
    this.sortieLe,
    this.motifSortie,
    this.archive = false,
  });

  final String studentId, matricule, lastName, firstName;
  final String? ine, gender, placeOfBirth, address, tuteur, tuteurTel;
  final String? classeEntree, motifSortie;
  final DateTime? dateOfBirth, entreeLe, sortieLe;

  /// `students.is_active = 0` : l'élève a été retiré du registre actif. Il
  /// reste au grand livre — c'est précisément sa raison d'être.
  final bool archive;

  String get nomComplet => '${lastName.toUpperCase()} $firstName'.trim();
  bool get sorti => sortieLe != null || (motifSortie?.isNotEmpty ?? false);
}

/// Le registre, plus ce qu'il ne peut pas voir.
class Registre {
  const Registre({required this.lignes, required this.lacunes});
  final List<LigneRegistre> lignes;

  /// Inscriptions dont l'élève est introuvable sur ce poste. Zéro = le registre
  /// est complet pour cette école.
  final int lacunes;

  bool get complet => lacunes == 0;
}

/// Ordre du grand livre : celui des matricules, lus comme les lit un humain.
///
/// ⚠️ Un tri de CHAÎNES place « M-10 » avant « M-9 ». Sur un registre, cela
/// déplace des lignes de plusieurs pages et fait échouer la recherche d'une
/// inscription précise — le geste même pour lequel on ouvre le livre. On
/// compare donc segment par segment, les suites de chiffres comme des nombres.
///
/// Fonction pure, isolée pour être testée : c'est l'ordre du document, et il
/// n'a pas de seconde chance une fois le registre relié.
int compareMatricule(String a, String b) {
  final ra = RegExp(r'\d+|\D+').allMatches(a.toLowerCase()).toList();
  final rb = RegExp(r'\d+|\D+').allMatches(b.toLowerCase()).toList();
  for (var i = 0; i < ra.length && i < rb.length; i++) {
    final sa = ra[i].group(0)!, sb = rb[i].group(0)!;
    final na = int.tryParse(sa), nb = int.tryParse(sb);
    final c = (na != null && nb != null)
        ? na.compareTo(nb)
        : sa.compareTo(sb);
    if (c != 0) return c;
  }
  return ra.length.compareTo(rb.length);
}

DateTime? _date(Object? v) =>
    v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;

/// Le grand livre de l'école, assemblé en trois lectures locales.
///
/// Trois requêtes plutôt qu'une jointure : la version SQL tenait en une
/// expression de trente lignes avec deux sous-requêtes corrélées et un MAX sur
/// clé composite. Elle était juste, et illisible — donc invérifiable. Le coût
/// est de quelques milliers de lignes en mémoire, pour une école.
final registreMatriculeProvider =
    FutureProvider.autoDispose<Registre>((ref) async {
  final schoolId = ref.watch(authNotifierProvider).valueOrNull?.schoolId;
  if (schoolId == null || schoolId.isEmpty) {
    return const Registre(lignes: [], lacunes: 0);
  }

  final eleves = await db.getAll(
    'SELECT id, matricule, ine, last_name, first_name, gender, date_of_birth, '
    '       place_of_birth, address, is_active '
    '  FROM students WHERE school_id = ?',
    [schoolId],
  );

  final inscriptions = await db.getAll(
    'SELECT e.student_id, e.enrollment_date, e.created_at, e.status, '
    '       e.withdrawal_date, e.withdrawal_motif, c.name AS class_name '
    '  FROM class_enrollments e '
    '  LEFT JOIN classes c ON c.id = e.class_id '
    ' WHERE e.school_id = ? '
    ' ORDER BY COALESCE(e.enrollment_date, e.created_at)',
    [schoolId],
  );

  // ⚠️ PAS de `WHERE is_primary_contact <> 0`. La case se décochait librement
  // dans l'éditeur du registre : des dossiers portent plusieurs numéros et
  // AUCUN principal. Filtrer dessus laisserait leur colonne « tuteur » vide sur
  // un document réglementaire — alors que le nom est là, dans la base. On trie
  // donc pour que le contact principal passe devant, et on prend le premier
  // venu à défaut.
  final tuteurs = await db.getAll(
    'SELECT student_id, last_name, first_name, phone_primary '
    '  FROM student_tutors WHERE school_id = ? '
    ' ORDER BY COALESCE(is_primary_contact, 0) DESC, last_name',
    [schoolId],
  );

  // ── Première inscription et dernière sortie, par élève ────────────────────
  final entree = <String, (DateTime?, String?)>{};
  final sortie = <String, (DateTime?, String?)>{};
  for (final r in inscriptions) {
    final sid = r['student_id'] as String?;
    if (sid == null) continue;

    // Les inscriptions arrivent triées : la première vue est la première.
    entree.putIfAbsent(
      sid,
      () => (
        _date(r['enrollment_date']) ?? _date(r['created_at']),
        r['class_name'] as String?,
      ),
    );

    final statut = (r['status'] as String?) ?? '';
    if (statut != 'active' && statut.isNotEmpty) {
      // La dernière sortie l'emporte : un élève parti, revenu, reparti a pour
      // sortie la plus récente.
      sortie[sid] = (
        _date(r['withdrawal_date']),
        (r['withdrawal_motif'] as String?) ?? statut,
      );
    } else if (statut == 'active') {
      // Réinscrit : il n'est plus sorti.
      sortie.remove(sid);
    }
  }

  final tuteur = <String, (String, String?)>{};
  for (final t in tuteurs) {
    final sid = t['student_id'] as String?;
    if (sid == null) continue;
    final nom =
        '${t['last_name'] ?? ''} ${t['first_name'] ?? ''}'.trim();
    if (nom.isEmpty) continue;
    tuteur.putIfAbsent(sid, () => (nom, t['phone_primary'] as String?));
  }

  final lignes = <LigneRegistre>[
    for (final e in eleves)
      LigneRegistre(
        studentId: e['id'] as String,
        matricule: (e['matricule'] as String?) ?? '',
        lastName: (e['last_name'] as String?) ?? '',
        firstName: (e['first_name'] as String?) ?? '',
        ine: e['ine'] as String?,
        gender: e['gender'] as String?,
        dateOfBirth: _date(e['date_of_birth']),
        placeOfBirth: e['place_of_birth'] as String?,
        address: e['address'] as String?,
        tuteur: tuteur[e['id']]?.$1,
        tuteurTel: tuteur[e['id']]?.$2,
        entreeLe: entree[e['id']]?.$1,
        classeEntree: entree[e['id']]?.$2,
        sortieLe: sortie[e['id']]?.$1,
        motifSortie: sortie[e['id']]?.$2,
        archive: e['is_active'] == 0 || e['is_active'] == false,
      ),
  ]..sort((a, b) => compareMatricule(a.matricule, b.matricule));

  // ── Les lacunes : inscriptions dont l'élève manque sur ce poste ───────────
  final connus = {for (final e in eleves) e['id'] as String};
  final manquants = <String>{};
  for (final r in inscriptions) {
    final sid = r['student_id'] as String?;
    if (sid != null && !connus.contains(sid)) manquants.add(sid);
  }

  return Registre(lignes: lignes, lacunes: manquants.length);
});
