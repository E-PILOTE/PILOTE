import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/safe_file_name.dart';
import '../providers/admin_academic_year_provider.dart';
import '../providers/admin_year_analytics_provider.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  ANNÉES SCOLAIRES — export tableur.
//
//  Le PDF est un document : il se signe, se dépose, se classe. Le CSV est une
//  matière première : la direction des statistiques du MEPSA le recroise avec
//  ses propres tableaux. Les deux sont nécessaires, aucun ne remplace l'autre.
//
//  Séparateur « ; » et BOM UTF-8 : c'est ce qu'attend Excel en locale française.
//  Sans le BOM, « Kimbembé » s'affiche avec un losange noir — vu sur des listes
//  déjà déposées au ministère.
// ══════════════════════════════════════════════════════════════════════════════
class AcademicYearCsvService {
  static final _fmt = DateFormat('dd/MM/yyyy');

  static String _esc(Object? v) =>
      '"${(v?.toString() ?? '').replaceAll('"', '""')}"';

  static String _typeLabel(String t) => switch (t) {
        'public' => 'Public',
        'prive' => 'Prive',
        _ => t.isEmpty ? 'Autre' : t,
      };

  /// Bilan d'une année, une ligne par établissement.
  static Future<String?> downloadYearReport({
    required AdminYear year,
    required AdminYearAnalytics analytics,
  }) async {
    final b = StringBuffer()
      // En-tête de contexte : un CSV qui circule par courriel doit dire de
      // quelle année il parle sans qu'on ait à demander.
      ..writeln('${_esc('Annee scolaire')};${_esc(year.label)}')
      ..writeln('${_esc('Periode')};${_esc('${_fmt.format(year.startDate)} - ${_fmt.format(year.endDate)}')}')
      ..writeln('${_esc('Ecoles preparees')};${_esc('${analytics.ecolesPreparees}/${analytics.ecolesTotal}')}')
      ..writeln('${_esc('Edite le')};${_esc(_fmt.format(DateTime.now()))}')
      ..writeln()
      ..writeln([
        'Etablissement',
        'Departement',
        'Type',
        'Classes',
        'Eleves',
        'Etat',
      ].map(_esc).join(';'));

    for (final s in analytics.bySchool) {
      b.writeln([
        _esc(s.name),
        _esc(s.department),
        _esc(_typeLabel(s.type)),
        _esc(s.classes),
        _esc(s.eleves),
        _esc(s.adopted ? 'Preparee' : 'En attente'),
      ].join(';'));
    }

    b
      ..writeln()
      ..writeln([
        _esc('TOTAL'),
        _esc(''),
        _esc(''),
        _esc(analytics.classes),
        _esc(analytics.eleves),
        _esc(''),
      ].join(';'));

    return _save(b.toString(), 'Annee_${year.label}.csv',
        "Exporter le bilan de l'année");
  }

  /// Comparatif pluriannuel — une ligne par année du groupe.
  static Future<String?> downloadYearsOverview(List<AdminYear> years) async {
    final b = StringBuffer()
      ..writeln([
        'Annee',
        'Debut',
        'Fin',
        'Statut',
        'Classes',
        'Eleves',
        'Ecoles preparees',
        'Ecoles totales',
        'Taux adoption %',
      ].map(_esc).join(';'));

    for (final y in years) {
      b.writeln([
        _esc(y.label),
        _esc(_fmt.format(y.startDate)),
        _esc(_fmt.format(y.endDate)),
        _esc(y.isLocked
            ? 'Archivee'
            : y.isCurrent
                ? 'En cours'
                : y.isFuture
                    ? 'A venir'
                    : 'Passee'),
        _esc(y.classes),
        _esc(y.eleves),
        _esc(y.schoolsAdopted),
        _esc(y.schoolsTotal),
        _esc((y.adoptionRate * 100).round()),
      ].join(';'));
    }

    return _save(b.toString(), 'Annees_scolaires.csv',
        'Exporter le comparatif pluriannuel');
  }

  static Future<String?> _save(
      String contenu, String fileName, String dialogTitle) async {
    final bytes = Uint8List.fromList(
      [0xEF, 0xBB, 0xBF, ...utf8.encode(contenu)],
    );
    final path = await FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: safeFileName(fileName.replaceAll(' ', '_')),
      bytes: bytes,
    );
    if (path == null) return null;
    final file = File(path);
    if (!await file.exists() || await file.length() == 0) {
      await file.writeAsBytes(bytes);
    }
    return path;
  }
}
