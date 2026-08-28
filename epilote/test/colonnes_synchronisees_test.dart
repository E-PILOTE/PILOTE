import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  UNE COLONNE QU'ON ÉCRIT SANS L'AVOIR DÉCLARÉE N'ARRIVE NULLE PART
//
//  L'application n'écrit jamais dans Postgres : elle écrit dans le SQLite local
//  de PowerSync, et le connecteur remonte ensuite les lignes. Ce SQLite ne
//  contient QUE les colonnes déclarées dans `powersync_schema.dart`. Écrire une
//  colonne absente de cette déclaration, c'est écrire dans le vide — et rien ne
//  le dit : pas d'exception au moment de la saisie, pas d'erreur de synchro,
//  juste une valeur qui n'existe nulle part au moment de la relire.
//
//  ── CE QUI A AMENÉ CE GARDE (2026-08-28) ───────────────────────────────────
//  `notified_at` et `academic_year_id` ont dû être ajoutés à `infirmary_visits`
//  du côté serveur ET du côté schéma local. Oublier la seconde moitié aurait
//  donné exactement ce silence : un journal médical qui perd la date de la
//  notification aux parents et l'année du passage, sans un mot.
//
//  Le garde lit les deux sources et les confronte. Il ne coûte rien à faire
//  tourner, et il attrape une classe entière de défauts muets.
//
//  ⚠️ Il ne vérifie QUE le sens application → schéma local. Une colonne
//  déclarée en trop est inoffensive (elle reste vide) ; une colonne écrite en
//  trop est une perte de données.
// ════════════════════════════════════════════════════════════════════════════

const _kSchema = 'lib/services/powersync/powersync_schema.dart';

List<File> _dartsSous(String chemin) => Directory(chemin)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList()
  ..sort((a, b) => a.path.compareTo(b.path));

/// Les tables du schéma local, avec leurs colonnes. `id` est implicite dans
/// PowerSync (clé primaire de chaque table), il est ajouté partout.
Map<String, Set<String>> _schemaLocal() {
  final f = File(_kSchema);
  if (!f.existsSync()) fail('$_kSchema introuvable — tourner depuis `epilote/`.');
  final src = f.readAsStringSync();
  final tables = <String, Set<String>>{};
  final motif = RegExp(r"Table\(\s*'([a-z_0-9]+)'\s*,\s*\[(.*?)\]\s*\)",
      dotAll: true);
  final colonne = RegExp(r"Column\.\w+\(\s*'([a-z_0-9]+)'\s*\)");
  for (final m in motif.allMatches(src)) {
    tables[m.group(1)!] = {
      'id',
      for (final c in colonne.allMatches(m.group(2)!)) c.group(1)!,
    };
  }
  return tables;
}

String _relatif(File f) {
  final c = f.path.replaceAll(r'\', '/');
  return c.substring(c.indexOf('lib/') + 4);
}

void main() {
  final tables = _schemaLocal();

  test('le schéma local se lit (garde du garde)', () {
    // Si la lecture cassait — un changement de forme dans le fichier de
    // schéma — les deux tests suivants passeraient en ne vérifiant RIEN.
    expect(tables.length, greaterThan(50),
        reason: 'Le schéma local déclare des dizaines de tables ; en lire une '
            'poignée signifie que l\'analyse ne mord plus.');
    expect(tables['infirmary_visits'], contains('academic_year_id'));
    expect(tables['discipline_incidents'], contains('notified_at'));
  });

  test('toute colonne INSÉRÉE est déclarée dans le schéma local', () {
    final motif =
        RegExp(r'INSERT\s+INTO\s+([a-z_0-9]+)\s*\(([^)]*)\)', dotAll: true);
    final nom = RegExp(r'^[a-z_0-9]+$');
    final fautes = <String>[];
    for (final f in _dartsSous('lib')) {
      if (f.path.contains('powersync_schema')) continue;
      for (final m in motif.allMatches(f.readAsStringSync())) {
        final table = m.group(1)!;
        final connues = tables[table];
        if (connues == null) continue; // table non synchronisée : hors sujet
        final absentes = m
            .group(2)!
            .split(',')
            .map((c) => c.trim())
            .where(nom.hasMatch)
            .where((c) => !connues.contains(c))
            .toList();
        if (absentes.isNotEmpty) {
          fautes.add('${_relatif(f)} → $table : ${absentes.join(', ')}');
        }
      }
    }
    expect(fautes, isEmpty,
        reason: 'Ces colonnes sont écrites mais absentes de '
            '`powersync_schema.dart` : la valeur est perdue sans un mot. '
            'Déclarer la colonne, ou cesser de l\'écrire.\n\n'
            '${fautes.join('\n')}');
  });

  test('toute colonne MISE À JOUR est déclarée dans le schéma local', () {
    final motif = RegExp(r"UPDATE\s+([a-z_0-9]+)\s+SET\s+(.*?)(?:\bWHERE\b|''')",
        dotAll: true, caseSensitive: false);
    final affectation = RegExp(r'(?:^|,)\s*([a-z_0-9]+)\s*=');
    final fautes = <String>[];
    for (final f in _dartsSous('lib')) {
      if (f.path.contains('powersync_schema')) continue;
      for (final m in motif.allMatches(f.readAsStringSync())) {
        final table = m.group(1)!;
        final connues = tables[table];
        if (connues == null) continue;
        final absentes = affectation
            .allMatches(m.group(2)!)
            .map((a) => a.group(1)!)
            .where((c) => !connues.contains(c))
            .toSet()
            .toList()
          ..sort();
        if (absentes.isNotEmpty) {
          fautes.add('${_relatif(f)} → $table : ${absentes.join(', ')}');
        }
      }
    }
    expect(fautes, isEmpty,
        reason: 'Ces colonnes sont mises à jour mais absentes du schéma '
            'local.\n\n${fautes.join('\n')}');
  });
}
