import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/booleen_offline.dart';
import '../../../services/powersync/powersync_service.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA VIE SCOLAIRE D'UN ÉLÈVE — assiduité, conduite, infirmerie, cantine
//
//  ── QUATRE REGISTRES, QUATRE PORTÉES DIFFÉRENTES ───────────────────────────
//  ⚠️ Ce n'est pas une inconséquence, c'est ce que chaque registre veut dire :
//
//   • ASSIDUITÉ — bornée à UNE année. Un élève porte une entrée par jour et par
//     séance : sur toute une scolarité, la table se compte en milliers de
//     lignes, relues à chaque tick de synchro. Et « 14 absences » ne veut rien
//     dire hors d'une année de référence.
//   • CANTINE — bornée à UNE année, pour la même raison de volume.
//   • CONDUITE — TOUTES les années. Trois avertissements en trois ans ne se
//     lisent que côte à côte ; c'est précisément ce qu'un conseil de discipline
//     cherche, et le borner à l'année en cours l'effacerait.
//   • INFIRMERIE — TOUTES les années. Un asthme signalé en sixième vaut encore
//     en terminale.
//
//  ── CE QU'ON NE FAIT PAS ICI ───────────────────────────────────────────────
//  ⚠️ Aucune écriture. Une absence porte l'agent qui l'a posée et l'heure à
//  laquelle il l'a fait ; une sanction engage celui qui la prononce. Les
//  corriger depuis la fiche effacerait cette responsabilité — la fiche renvoie
//  vers Présences et Discipline, qui savent qui écrit.
// ════════════════════════════════════════════════════════════════════════════

DateTime? _d(Object? v) =>
    (v is String && v.isNotEmpty) ? DateTime.tryParse(v) : null;

String _s(Object? v) => (v as String?)?.trim() ?? '';

bool _b(Object? v) => v == 1 || v == true;

/// Un manquement relevé : une absence, un retard.
class ManquementLigne {
  const ManquementLigne({
    required this.date,
    required this.statut,
    required this.periode,
    required this.classe,
    required this.justification,
    required this.parentPrevenu,
  });

  final DateTime? date;
  final String statut, periode, classe, justification;
  final bool parentPrevenu;

  bool get justifie => justification.isNotEmpty;
}

/// Le compte d'une année d'assiduité, et le détail de ce qui a manqué.
class Assiduite {
  const Assiduite({
    required this.seances,
    required this.absences,
    required this.retards,
    required this.justifiees,
    required this.manquements,
  });

  final int seances, absences, retards, justifiees;
  final List<ManquementLigne> manquements;

  /// Le taux de présence sur les séances RELEVÉES — pas sur l'année.
  ///
  /// ⚠️ Un taux calculé sur un nombre de jours théorique mentirait dès qu'une
  /// classe n'a pas fait l'appel : l'élève paraîtrait absent d'une séance qui
  /// n'a jamais été enregistrée.
  double? get tauxPresence => seances == 0
      ? null
      : ((seances - absences) / seances * 100).clamp(0, 100).toDouble();

  bool get vide => seances == 0;
}

/// L'assiduité d'une année : le compte, et chaque manquement.
final ficheAssiduiteProvider = StreamProvider.autoDispose
    .family<Assiduite, (String studentId, String anneeId)>((ref, args) {
  final (studentId, anneeId) = args;
  if (anneeId.isEmpty) {
    return Stream.value(
      const Assiduite(
          seances: 0, absences: 0, retards: 0, justifiees: 0, manquements: []),
    );
  }
  return db.watch(
    '''
    SELECT ae.status, ae.justification, ae.parent_notified,
           ar.record_date, ar.period,
           c.name AS class_name
      FROM attendance_entries ae
      JOIN attendance_records ar ON ar.id = ae.attendance_record_id
      LEFT JOIN classes c ON c.id = ar.class_id
     WHERE ae.student_id = ? AND ar.academic_year_id = ?
     ORDER BY ar.record_date DESC
    ''',
    parameters: [studentId, anneeId],
  ).map((rows) {
    final manquements = <ManquementLigne>[];
    var absences = 0, retards = 0, justifiees = 0;
    for (final r in rows) {
      final statut = _s(r['status']);
      if (statut == 'present') continue;
      if (statut == 'absent') absences++;
      if (statut == 'late') retards++;
      final justification = _s(r['justification']);
      if (justification.isNotEmpty) justifiees++;
      manquements.add(ManquementLigne(
        date: _d(r['record_date']),
        statut: statut,
        periode: _s(r['period']),
        classe: _s(r['class_name']),
        justification: justification,
        parentPrevenu: _b(r['parent_notified']),
      ));
    }
    return Assiduite(
      seances: rows.length,
      absences: absences,
      retards: retards,
      justifiees: justifiees,
      manquements: manquements,
    );
  });
});

/// Un fait de conduite et, le cas échéant, ce qui a été prononcé.
class IncidentLigne {
  const IncidentLigne({
    required this.date,
    required this.type,
    required this.description,
    required this.sanction,
    required this.dateSanction,
    required this.suivi,
    required this.parentPrevenu,
    required this.anneeLabel,
  });

  final DateTime? date, dateSanction;
  final String type, description, sanction, suivi, anneeLabel;
  final bool parentPrevenu;
}

/// La conduite, toutes années confondues.
final ficheDisciplineProvider = StreamProvider.autoDispose
    .family<List<IncidentLigne>, String>((ref, studentId) {
  return db.watch(
    '''
    SELECT di.incident_date, di.incident_type, di.description, di.sanction,
           di.sanction_date, di.follow_up_notes, di.parent_notified,
           ay.label AS year_label
      FROM discipline_incidents di
      LEFT JOIN academic_years ay ON ay.id = di.academic_year_id
     WHERE di.student_id = ?
     ORDER BY di.incident_date DESC
    ''',
    parameters: [studentId],
  ).map((rows) => [
        for (final r in rows)
          IncidentLigne(
            date: _d(r['incident_date']),
            type: _s(r['incident_type']),
            description: _s(r['description']),
            sanction: _s(r['sanction']),
            dateSanction: _d(r['sanction_date']),
            suivi: _s(r['follow_up_notes']),
            parentPrevenu: _b(r['parent_notified']),
            anneeLabel: _s(r['year_label']),
          ),
      ]);
});

/// Un passage à l'infirmerie.
class VisiteLigne {
  const VisiteLigne({
    required this.date,
    required this.heure,
    required this.symptomes,
    required this.diagnostic,
    required this.traitement,
    required this.medicament,
    required this.reposHeures,
    required this.suiviRequis,
    required this.suivi,
    required this.parentPrevenu,
  });

  final DateTime? date;
  final String heure, symptomes, diagnostic, traitement, medicament, suivi;
  final int? reposHeures;
  final bool suiviRequis, parentPrevenu;
}

/// L'infirmerie, toutes années confondues.
final ficheInfirmerieProvider = StreamProvider.autoDispose
    .family<List<VisiteLigne>, String>((ref, studentId) {
  return db.watch(
    '''
    SELECT visit_date, visit_time, symptoms, diagnosis, treatment, medication,
           rest_period_hours, follow_up_required, follow_up_notes,
           parent_notified
      FROM infirmary_visits
     WHERE student_id = ?
     ORDER BY visit_date DESC
    ''',
    parameters: [studentId],
  ).map((rows) => [
        for (final r in rows)
          VisiteLigne(
            date: _d(r['visit_date']),
            heure: _s(r['visit_time']),
            symptomes: _s(r['symptoms']),
            diagnostic: _s(r['diagnosis']),
            traitement: _s(r['treatment']),
            medicament: _s(r['medication']),
            reposHeures: (r['rest_period_hours'] as num?)?.toInt(),
            suiviRequis: _b(r['follow_up_required']),
            suivi: _s(r['follow_up_notes']),
            parentPrevenu: _b(r['parent_notified']),
          ),
      ]);
});

/// Ce que la cantine a servi, et ce qui a été manqué.
class Cantine {
  const Cantine({
    required this.services,
    required this.presences,
    required this.derniers,
  });

  final int services, presences;

  /// Les derniers services, dans l'ordre décroissant — de quoi vérifier une
  /// contestation récente sans dérouler l'année entière.
  final List<(DateTime? date, String repas, bool present)> derniers;

  int get absences => services - presences;
  bool get vide => services == 0;
}

/// La cantine sur UNE année.
final ficheCantineProvider = StreamProvider.autoDispose
    .family<Cantine, (String studentId, String anneeId)>((ref, args) {
  final (studentId, anneeId) = args;
  // ⚠️ `canteen_records` ne porte PAS d'année scolaire : elle date chaque
  // service. On borne donc sur les dates de l'année, passées par l'appelant
  // sous la forme « début|fin ». Une chaîne vide = pas de bornes connues, on
  // ne lit rien plutôt que de lire toute la scolarité.
  final bornes = anneeId.split('|');
  if (bornes.length != 2 || bornes[0].isEmpty || bornes[1].isEmpty) {
    return Stream.value(const Cantine(services: 0, presences: 0, derniers: []));
  }
  return db.watch(
    '''
    SELECT record_date, meal_type, is_present
      FROM canteen_records
     WHERE student_id = ? AND record_date >= ? AND record_date <= ?
     ORDER BY record_date DESC
    ''',
    parameters: [studentId, bornes[0], bornes[1]],
  ).map((rows) {
    // ⚠️ `is_present` a VRAI pour défaut en base : un service non renseigné
    // vaut PRÉSENT. Le lire avec `_b` (défaut faux) comptait l'élève absent
    // de la cantine sur la seule foi du silence. Voir `booleen_offline.dart`.
    final presences = rows.where((r) => actifOffline(r['is_present'])).length;
    return Cantine(
      services: rows.length,
      presences: presences,
      derniers: [
        for (final r in rows.take(12))
          (
            _d(r['record_date']),
            _s(r['meal_type']),
            actifOffline(r['is_present']),
          ),
      ],
    );
  });
});
