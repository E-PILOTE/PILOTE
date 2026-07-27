import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  ARCHIVES DES PUBLICATIONS DE LA DEC — côté ministère (online, Supabase).
//
//  La plateforme ne calcule aucun résultat d'examen : elle transmet la liste
//  des candidats à la DEC, qui proclame les admis et publie ses documents. La
//  DSIC centralise ces publications — c'est elle qui dépose ici.
//
//  Deux familles de chiffres, tenues séparées jusque dans les types :
//   • OFFICIAL   (`OfficialFigure`)  — relevé sur la publication, fait autorité.
//   • PLATEFORME (`PlatformTally`)   — dérivé des saisies des écoles, TOUJOURS
//                                      accompagné de sa couverture.
//  Aucune fonction de ce fichier ne convertit l'une en l'autre.
// ════════════════════════════════════════════════════════════════════════════

/// Périmètre couvert par une publication, tel que la DEC le découpe.
enum PubScope {
  national('national', 'National'),
  departement('departement', 'Département'),
  etablissement('etablissement', 'Établissement');

  const PubScope(this.code, this.label);
  final String code;
  final String label;

  static PubScope from(String? code) =>
      PubScope.values.firstWhere((s) => s.code == code,
          orElse: () => PubScope.national);
}

class ExamPublication {
  const ExamPublication({
    required this.id,
    required this.sessionId,
    required this.scope,
    required this.title,
    required this.fileName,
    required this.filePath,
    required this.receivedAt,
    this.examShortName,
    this.yearLabel,
    this.department,
    this.schoolId,
    this.schoolName,
    this.decSchoolCode,
    this.filiereLabel,
    this.publishedAt,
    this.fileSize,
    this.sha256,
    this.notes,
  });

  final String id;
  final String sessionId;
  final PubScope scope;
  final String title;
  final String fileName;
  final String filePath;
  final DateTime receivedAt;
  final String? examShortName;
  final String? yearLabel;
  final String? department;
  final String? schoolId;
  final String? schoolName;
  final String? decSchoolCode;
  final String? filiereLabel;
  final DateTime? publishedAt;
  final int? fileSize;
  final String? sha256;
  final String? notes;

  /// Libellé du périmètre — un document d'archive sans périmètre lisible est
  /// un document qu'on ne retrouvera pas.
  String get scopeLabel => switch (scope) {
        PubScope.national => 'National',
        PubScope.departement => department ?? 'Département',
        PubScope.etablissement =>
          schoolName ?? decSchoolCode ?? 'Établissement',
      };
}

/// Chiffre OFFICIEL relevé sur une publication. Jamais calculé ici.
class OfficialFigure {
  const OfficialFigure({
    required this.id,
    required this.sessionId,
    required this.scope,
    this.department,
    this.schoolId,
    this.schoolName,
    this.filiereLabel,
    this.registered,
    this.present,
    this.admitted,
    this.storedRate,
    this.publicationId,
    this.sourceLabel,
    this.publishedAt,
    this.examShortName,
    this.yearLabel,
  });

  final String id;
  final String sessionId;
  final PubScope scope;
  final String? department;
  final String? schoolId;
  final String? schoolName;
  final String? filiereLabel;
  final int? registered;
  final int? present;
  final int? admitted;
  final double? storedRate;
  final String? publicationId;
  final String? sourceLabel;
  final DateTime? publishedAt;
  final String? examShortName;
  final String? yearLabel;

  /// ⚠️ Le taux officiel porte sur les PRÉSENTS, jamais sur les inscrits.
  /// BAC T&P 2025 : 7 681 / 15 843 = 48,48 % (pour 16 070 inscrits).
  /// Miroir exact de `official_pass_rate()` en base (migration 0062) — les
  /// deux ne doivent jamais pouvoir diverger.
  double? get passRate => officialPassRate(
      present: present, admitted: admitted, storedRate: storedRate);

  /// Une publication qui ne donne qu'un pourcentage reste exploitable, mais on
  /// doit pouvoir dire à l'écran que les effectifs manquent.
  bool get hasCounts => present != null && admitted != null;

  /// Un chiffre sans pièce jointe n'est pas opposable — l'écran le signale.
  bool get hasSource => publicationId != null;

  int? get absent =>
      registered == null || present == null ? null : registered! - present!;
}

/// Règle de taux officielle, isolée pour être testable sans base.
double? officialPassRate({int? present, int? admitted, double? storedRate}) {
  if (present != null && present > 0 && admitted != null) {
    return admitted / present * 100;
  }
  // Effectifs absents ou dénominateur nul : c'est le pourcentage publié qui
  // fait foi. On ne fabrique pas les effectifs manquants.
  return storedRate;
}

/// Ce que la PLATEFORME sait, à partir des saisies des écoles.
///
/// Ne jamais afficher `passRate` sans `coverage` à côté : une école ayant
/// saisi 3 résultats sur 40 sortirait « 100 % de réussite ».
class PlatformTally {
  const PlatformTally({
    required this.candidates,
    required this.known,
    required this.admitted,
    required this.rejected,
    required this.absent,
  });

  final int candidates;
  final int known;
  final int admitted;
  final int rejected;
  final int absent;

  /// Présents = ceux dont on sait qu'ils ont composé. Les absents sortent du
  /// dénominateur, comme dans les statistiques publiées par la DEC.
  int get present => admitted + rejected;

  /// `null` tant que personne n'a composé : 0 % dirait « tous recalés ».
  double? get passRate => present == 0 ? null : admitted / present * 100;

  /// Part des candidats dont le résultat est connu. C'est la mesure de
  /// confiance du chiffre au-dessus.
  double get coverage => candidates == 0 ? 0 : known / candidates * 100;

  /// En dessous, un taux ne veut rien dire et ne doit pas être présenté comme
  /// tel. Seuil délibérément haut : un pilotage national se trompe plus
  /// souvent par excès de confiance que par prudence.
  bool get isReliable => coverage >= 80 && present >= 5;
}

PlatformTally tallyOf(Iterable<String?> results) {
  var candidates = 0, known = 0, admitted = 0, rejected = 0, absent = 0;
  for (final r in results) {
    candidates++;
    if (r == null || r == 'en_attente') continue;
    known++;
    switch (r) {
      case 'admis':
        admitted++;
      case 'absent':
        absent++;
      // Une fraude a composé : elle compte parmi les présents, jamais parmi
      // les admis. L'exclure du dénominateur gonflerait le taux de l'école.
      case 'ajourne' || 'fraude':
        rejected++;
    }
  }
  return PlatformTally(
    candidates: candidates,
    known: known,
    admitted: admitted,
    rejected: rejected,
    absent: absent,
  );
}

// ─── Sessions disponibles au dépôt ──────────────────────────────────────────
class ArchiveSession {
  const ArchiveSession({
    required this.id,
    required this.yearLabel,
    required this.examShortName,
    this.cycleCode,
  });

  final String id;
  final String yearLabel;
  final String examShortName;
  final String? cycleCode;

  String get label => '$examShortName · $yearLabel';
}

final archiveSessionsProvider =
    FutureProvider.autoDispose<List<ArchiveSession>>((ref) async {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);
  final rows = await client
      .from('exam_sessions')
      .select('id, year_label, national_exams!inner(short_name, cycle_code)')
      // ⚠️ `ascending:` explicite — `.order()` de supabase-dart trie en
      // DESCENDANT par défaut. Ici on veut la session la plus récente d'abord,
      // donc le descendant est VOULU, et écrit.
      .order('year_label', ascending: false);

  return [
    for (final r in rows as List)
      ArchiveSession(
        id: r['id'] as String,
        yearLabel: (r['year_label'] as String?) ?? '—',
        examShortName:
            ((r['national_exams'] as Map?)?['short_name'] as String?) ?? '—',
        cycleCode: (r['national_exams'] as Map?)?['cycle_code'] as String?,
      ),
  ];
});

// ─── Publications archivées ─────────────────────────────────────────────────
final examPublicationsProvider =
    FutureProvider.autoDispose<List<ExamPublication>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null) return const [];

  final rows = await client
      .from('exam_publications')
      .select('id, session_id, scope, department, school_id, dec_school_code, '
          'filiere_label, title, published_at, received_at, file_path, '
          'file_name, file_size, file_sha256, notes, '
          'schools(name), '
          'exam_sessions!inner(year_label, national_exams!inner(short_name))')
      .eq('group_id', groupId)
      // La dernière pièce reçue en tête : c'est celle qu'on vient chercher.
      .order('received_at', ascending: false);

  return [
    for (final r in rows as List) _toPublication(r as Map<String, dynamic>),
  ];
});

ExamPublication _toPublication(Map<String, dynamic> r) {
  final session = r['exam_sessions'] as Map<String, dynamic>?;
  final exam = session?['national_exams'] as Map<String, dynamic>?;
  return ExamPublication(
    id: r['id'] as String,
    sessionId: r['session_id'] as String,
    scope: PubScope.from(r['scope'] as String?),
    title: (r['title'] as String?) ?? 'Publication',
    fileName: (r['file_name'] as String?) ?? 'document.pdf',
    filePath: (r['file_path'] as String?) ?? '',
    receivedAt:
        DateTime.tryParse('${r['received_at']}')?.toLocal() ?? DateTime.now(),
    examShortName: exam?['short_name'] as String?,
    yearLabel: session?['year_label'] as String?,
    department: r['department'] as String?,
    schoolId: r['school_id'] as String?,
    schoolName: (r['schools'] as Map?)?['name'] as String?,
    decSchoolCode: r['dec_school_code'] as String?,
    filiereLabel: r['filiere_label'] as String?,
    publishedAt: DateTime.tryParse('${r['published_at']}'),
    fileSize: (r['file_size'] as num?)?.toInt(),
    sha256: r['file_sha256'] as String?,
    notes: r['notes'] as String?,
  );
}

// ─── Chiffres officiels ─────────────────────────────────────────────────────
final officialFiguresProvider =
    FutureProvider.autoDispose<List<OfficialFigure>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null) return const [];

  final rows = await client
      .from('exam_official_results')
      .select('id, session_id, scope, department, school_id, filiere_label, '
          'registered, present, admitted, pass_rate, publication_id, '
          'source_label, published_at, schools(name), '
          'exam_sessions!inner(year_label, national_exams!inner(short_name))')
      .eq('group_id', groupId);

  final out = [
    for (final r in rows as List) _toFigure(r as Map<String, dynamic>),
  ];
  // Tri côté client : national d'abord, puis départements par taux
  // décroissant — le format même dont le ministère se sert pour publier.
  out.sort((a, b) {
    if (a.scope != b.scope) return a.scope.index.compareTo(b.scope.index);
    return (b.passRate ?? -1).compareTo(a.passRate ?? -1);
  });
  return out;
});

OfficialFigure _toFigure(Map<String, dynamic> r) {
  final session = r['exam_sessions'] as Map<String, dynamic>?;
  final exam = session?['national_exams'] as Map<String, dynamic>?;
  return OfficialFigure(
    id: r['id'] as String,
    sessionId: r['session_id'] as String,
    scope: PubScope.from(r['scope'] as String?),
    department: r['department'] as String?,
    schoolId: r['school_id'] as String?,
    schoolName: (r['schools'] as Map?)?['name'] as String?,
    filiereLabel: r['filiere_label'] as String?,
    registered: (r['registered'] as num?)?.toInt(),
    present: (r['present'] as num?)?.toInt(),
    admitted: (r['admitted'] as num?)?.toInt(),
    storedRate: (r['pass_rate'] as num?)?.toDouble(),
    publicationId: r['publication_id'] as String?,
    sourceLabel: r['source_label'] as String?,
    publishedAt: DateTime.tryParse('${r['published_at']}'),
    examShortName: exam?['short_name'] as String?,
    yearLabel: session?['year_label'] as String?,
  );
}

// ─── Écritures ──────────────────────────────────────────────────────────────
class ArchiveActions {
  const ArchiveActions(this._ref);
  final Ref _ref;

  /// Dépose une publication : le fichier d'abord, la ligne ensuite.
  ///
  /// L'ordre n'est pas indifférent — une ligne pointant vers un fichier absent
  /// donnerait une archive qui ment. Si le téléversement échoue, rien n'est
  /// écrit.
  Future<String> deposit({
    required String sessionId,
    required PubScope scope,
    required String title,
    required String fileName,
    required Uint8List bytes,
    String? department,
    String? schoolId,
    String? decSchoolCode,
    String? filiereLabel,
    DateTime? publishedAt,
    String? notes,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    final profile = _ref.read(authNotifierProvider).valueOrNull;
    final groupId = profile?.groupId;
    if (groupId == null) throw StateError('Groupe introuvable');

    // Empreinte calculée sur les octets déposés : c'est elle qui permettra,
    // des années plus tard, de prouver que la pièce n'a pas bougé.
    final digest = sha256.convert(bytes).toString();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final path = '$groupId/$sessionId/${stamp}_${_safeName(fileName)}';

    await client.storage.from('exam-publications').uploadBinary(path, bytes);

    final String id;
    try {
      final row = await client.from('exam_publications').insert({
        'group_id': groupId,
        'session_id': sessionId,
        'scope': scope.code,
        'department': scope == PubScope.departement ? department : null,
        'school_id': scope == PubScope.etablissement ? schoolId : null,
        'dec_school_code':
            scope == PubScope.etablissement ? _trimOrNull(decSchoolCode) : null,
        'filiere_label': _trimOrNull(filiereLabel),
        'title': title.trim(),
        'published_at': publishedAt?.toIso8601String().split('T').first,
        'file_path': path,
        'file_name': fileName,
        'file_size': bytes.length,
        'file_sha256': digest,
        'notes': _trimOrNull(notes),
        'deposited_by': profile?.id,
      }).select('id').single();
      id = row['id'] as String;
    } catch (_) {
      // Ne pas laisser un fichier orphelin derrière une insertion refusée.
      await client.storage.from('exam-publications').remove([path]);
      rethrow;
    }

    _ref.invalidate(examPublicationsProvider);
    return id;
  }

  /// Prévient les établissements concernés qu'une publication les touche.
  ///
  /// C'est le maillon qui manquait : la DEC proclame, la DSIC archive — et
  /// personne ne prévenait les écoles. Leurs résultats restaient « en attente »
  /// non par négligence mais faute de savoir qu'il y avait quelque chose à
  /// saisir. Sans cette notification, la couverture des résultats dépend du
  /// hasard des coups de téléphone.
  ///
  /// Destinataires : chefs d'établissement (directeur, proviseur) — ceux qui
  /// décident de la saisie. Prévenir tout le personnel noierait l'information.
  ///
  /// Renvoie le nombre de destinataires. L'échec n'annule PAS le dépôt : une
  /// pièce archivée sans notification reste archivée, l'inverse serait absurde.
  Future<int> notify({
    required String publicationId,
    required PubScope scope,
    required String title,
    String? department,
    String? schoolId,
    String? examShortName,
    String? yearLabel,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    final groupId = _ref.read(authNotifierProvider).valueOrNull?.groupId;
    if (groupId == null) return 0;

    // Périmètre des écoles touchées, déduit du périmètre du document.
    var q = client.from('schools').select('id').eq('group_id', groupId);
    if (scope == PubScope.etablissement && schoolId != null) {
      q = q.eq('id', schoolId);
    } else if (scope == PubScope.departement && department != null) {
      q = q.eq('department', department);
    }
    final schools = [
      for (final r in await q) r['id'] as String,
    ];
    if (schools.isEmpty) return 0;

    final heads = await client
        .from('profiles')
        .select('id')
        .eq('group_id', groupId)
        .inFilter('school_id', schools)
        .inFilter('role', ['directeur', 'proviseur']);

    final rows = [
      for (final h in heads as List)
        {
          'group_id': groupId,
          'recipient_id': (h as Map<String, dynamic>)['id'],
          'type': 'exam_publication',
          'title': 'Résultats publiés — ${examShortName ?? 'examen d\'État'}'
              '${yearLabel == null ? '' : ' · $yearLabel'}',
          'body': 'La DEC a publié « $title ». Saisissez les résultats de vos '
              'candidats depuis la session concernée.',
          'data': {
            'publication_id': publicationId,
            'scope': scope.code,
            'department': ?department,
          },
        },
    ];
    if (rows.isEmpty) return 0;

    await client.from('notifications').insert(rows);
    return rows.length;
  }

  /// Rapatrie les octets d'une pièce — pour l'enregistrer hors de la
  /// plateforme, ou en vérifier l'empreinte.
  Future<Uint8List> fileBytes(ExamPublication p) => _ref
      .read(supabaseClientProvider)
      .storage
      .from('exam-publications')
      .download(p.filePath);

  /// Recalcule l'empreinte du fichier stocké et la compare à celle enregistrée
  /// au dépôt. C'est ce qui fait la différence entre « on a un fichier » et
  /// « on a LA pièce ».
  Future<bool> verifyIntegrity(ExamPublication p) async {
    if (p.sha256 == null) return false;
    final bytes = await fileBytes(p);
    return sha256.convert(bytes).toString() == p.sha256;
  }

  /// Enregistre (ou corrige) un chiffre officiel relevé sur une publication.
  Future<void> recordFigure({
    required String sessionId,
    required PubScope scope,
    String? department,
    String? schoolId,
    String? filiereLabel,
    int? registered,
    int? present,
    int? admitted,
    double? passRate,
    String? publicationId,
    String? sourceLabel,
    DateTime? publishedAt,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    final profile = _ref.read(authNotifierProvider).valueOrNull;
    final groupId = profile?.groupId;
    if (groupId == null) throw StateError('Groupe introuvable');

    await client.from('exam_official_results').upsert({
      'group_id': groupId,
      'session_id': sessionId,
      'scope': scope.code,
      'department': scope == PubScope.departement ? department : null,
      'school_id': scope == PubScope.etablissement ? schoolId : null,
      'filiere_label': _trimOrNull(filiereLabel),
      'registered': registered,
      'present': present,
      'admitted': admitted,
      // Quand les effectifs sont là, le taux se déduit : le stocker en double
      // ouvrirait la porte à deux vérités contradictoires.
      'pass_rate': (present != null && admitted != null) ? null : passRate,
      'publication_id': publicationId,
      'source_label': _trimOrNull(sourceLabel),
      'published_at': publishedAt?.toIso8601String().split('T').first,
      'recorded_by': profile?.id,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'session_id, scope, department, school_id, filiere_label');

    _ref.invalidate(officialFiguresProvider);
  }

  /// Retire une publication ET son fichier — une archive à moitié effacée
  /// laisserait croire que la pièce existe encore.
  Future<void> removePublication(ExamPublication p) async {
    final client = _ref.read(supabaseClientProvider);
    await client.from('exam_publications').delete().eq('id', p.id);
    if (p.filePath.isNotEmpty) {
      await client.storage.from('exam-publications').remove([p.filePath]);
    }
    _ref.invalidate(examPublicationsProvider);
    _ref.invalidate(officialFiguresProvider);
  }

  /// URL signée de courte durée : le bucket est privé, une publication
  /// nominative ne doit pas vivre derrière une adresse devinable.
  Future<String> signedUrl(ExamPublication p) => _ref
      .read(supabaseClientProvider)
      .storage
      .from('exam-publications')
      .createSignedUrl(p.filePath, 300);
}

final archiveActionsProvider =
    Provider.autoDispose<ArchiveActions>(ArchiveActions.new);

String? _trimOrNull(String? s) {
  final v = s?.trim();
  return (v == null || v.isEmpty) ? null : v;
}

/// Nom de fichier assaini : un chemin Storage n'accepte pas n'importe quoi, et
/// les publications arrivent avec des noms accentués et espacés.
String _safeName(String name) {
  const from = 'àâäéèêëîïôöùûüçÀÂÄÉÈÊËÎÏÔÖÙÛÜÇ';
  const to = 'aaaeeeeiioouuucAAAEEEEIIOOUUUC';
  final buf = StringBuffer();
  for (final ch in name.characters()) {
    final i = from.indexOf(ch);
    buf.write(i >= 0 ? to[i] : ch);
  }
  return buf
      .toString()
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_');
}

extension _Chars on String {
  Iterable<String> characters() sync* {
    for (var i = 0; i < length; i++) {
      yield this[i];
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  HISTORIQUE — ce que les chiffres officiels racontent une fois empilés.
//
//  Rien n'est calculé ici au sens où la DEC calcule : on RANGE des chiffres
//  publiés. La seule opération est l'écart d'une année à l'autre, exprimé en
//  POINTS — jamais en pourcentage de pourcentage, qui ne veut rien dire.
// ════════════════════════════════════════════════════════════════════════════

/// Un point de la série : une session, un taux, son évolution.
class HistoryPoint {
  const HistoryPoint({
    required this.yearLabel,
    required this.rate,
    required this.present,
    required this.admitted,
    this.deltaPoints,
  });

  final String yearLabel;
  final double rate;
  final int present;
  final int admitted;

  /// Écart en points avec la session précédente. `null` sur la première :
  /// afficher « +0,0 » y ferait croire à une stagnation mesurée.
  final double? deltaPoints;
}

/// Série nationale d'un examen, du plus ancien au plus récent.
class ExamHistory {
  const ExamHistory({required this.examShortName, required this.points});
  final String examShortName;
  final List<HistoryPoint> points;

  HistoryPoint? get latest => points.isEmpty ? null : points.last;

  /// Progression totale sur la période couverte — l'argument d'un ministre.
  double? get totalGain => points.length < 2
      ? null
      : points.last.rate - points.first.rate;
}

/// Empile les chiffres NATIONAUX par examen. Les départements sont ignorés
/// ici : mélanger les deux échelles produirait des séries dont chaque point
/// mesurerait autre chose.
List<ExamHistory> buildNationalHistory(List<OfficialFigure> figures) {
  final byExam = <String, List<OfficialFigure>>{};
  for (final f in figures) {
    if (f.scope != PubScope.national) continue;
    if (f.passRate == null || f.yearLabel == null) continue;
    byExam.putIfAbsent(f.examShortName ?? '—', () => []).add(f);
  }

  final out = <ExamHistory>[];
  for (final entry in byExam.entries) {
    // Chronologique : une courbe qui remonte le temps se lit à l'envers.
    final rows = entry.value..sort((a, b) => a.yearLabel!.compareTo(b.yearLabel!));
    final points = <HistoryPoint>[];
    double? previous;
    for (final f in rows) {
      final rate = f.passRate!;
      points.add(HistoryPoint(
        yearLabel: f.yearLabel!,
        rate: rate,
        present: f.present ?? 0,
        admitted: f.admitted ?? 0,
        deltaPoints: previous == null ? null : rate - previous,
      ));
      previous = rate;
    }
    out.add(ExamHistory(examShortName: entry.key, points: points));
  }
  out.sort((a, b) => a.examShortName.compareTo(b.examShortName));
  return out;
}

/// Ligne du classement départemental — le format même dont le ministère se
/// sert pour publier ses résultats.
class DepartmentStanding {
  const DepartmentStanding({
    required this.rank,
    required this.department,
    required this.rate,
    this.present,
    this.admitted,
    this.deltaPoints,
  });

  final int rank;
  final String department;
  final double rate;
  final int? present;
  final int? admitted;
  final double? deltaPoints;
}

/// Classe les départements d'une session, et situe chacun par rapport à la
/// session précédente du même examen.
List<DepartmentStanding> departmentStandings(
  List<OfficialFigure> figures, {
  required String examShortName,
  required String yearLabel,
  String? previousYearLabel,
}) {
  double? rateOf(String dep, String year) {
    for (final f in figures) {
      if (f.scope != PubScope.departement) continue;
      if (f.examShortName != examShortName || f.yearLabel != year) continue;
      if (f.department != dep) continue;
      return f.passRate;
    }
    return null;
  }

  final current = [
    for (final f in figures)
      if (f.scope == PubScope.departement &&
          f.examShortName == examShortName &&
          f.yearLabel == yearLabel &&
          f.passRate != null &&
          f.department != null)
        f,
  ]..sort((a, b) => b.passRate!.compareTo(a.passRate!));

  return [
    for (var i = 0; i < current.length; i++)
      DepartmentStanding(
        rank: i + 1,
        department: current[i].department!,
        rate: current[i].passRate!,
        present: current[i].present,
        admitted: current[i].admitted,
        deltaPoints: previousYearLabel == null
            ? null
            : switch (rateOf(current[i].department!, previousYearLabel)) {
                final double p => current[i].passRate! - p,
                _ => null,
              },
      ),
  ];
}
