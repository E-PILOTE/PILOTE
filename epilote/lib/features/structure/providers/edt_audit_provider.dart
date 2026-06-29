import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/auth_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  HISTORIQUE EDT (table `audit_logs`, synchro offline limitée aux tables EDT)
//  — journal « qui a modifié quoi, quand » de l'emploi du temps. Alimenté par le
//  trigger serveur `log_edt_audit()` (migration 0022), y compris pour les
//  écritures offline (remontées dans le contexte JWT de l'agent). Lecture seule.
// ════════════════════════════════════════════════════════════════════════════

const _frDays = ['', 'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi',
    'samedi', 'dimanche'];

class EdtAuditEntry {
  const EdtAuditEntry({
    required this.id,
    required this.action,
    required this.tableName,
    required this.actorName,
    required this.at,
    required this.summary,
  });
  final String id, action, tableName, summary;
  final String? actorName;
  final DateTime? at;

  bool get isDelete => action == 'DELETE';
  bool get isInsert => action == 'INSERT';

  String get actionLabel => switch (action) {
        'INSERT' => 'Ajout',
        'UPDATE' => 'Modification',
        'DELETE' => 'Suppression',
        _ => action,
      };
}

DateTime? _dt(Object? v) =>
    (v is String && v.isNotEmpty) ? DateTime.tryParse(v) : null;

Map<String, dynamic> _json(Object? v) {
  if (v is! String || v.isEmpty) return const {};
  try {
    final d = jsonDecode(v);
    return d is Map<String, dynamic> ? d : const {};
  } catch (_) {
    return const {};
  }
}

String _hhmm(Object? t) {
  final s = t?.toString() ?? '';
  return s.length >= 5 ? s.substring(0, 5) : s;
}

/// Construit une description lisible depuis le contenu jsonb capturé.
String _summarize(String table, String action, Map<String, dynamic> body) {
  switch (table) {
    case 'timetable_slots':
      final d = (body['day_of_week'] as num?)?.toInt() ?? 0;
      final day = (d >= 1 && d <= 7) ? _frDays[d] : '';
      final time = '${_hhmm(body['start_time'])}–${_hhmm(body['end_time'])}';
      return 'Créneau${day.isNotEmpty ? ' du $day' : ''}'
          '${time.length > 1 ? ' $time' : ''}';
    case 'timetable_exceptions':
      final kind = switch (body['kind']) {
        'cancelled' => 'Séance annulée',
        'moved' => 'Séance déplacée',
        'extra' => 'Séance exceptionnelle',
        _ => 'Exception',
      };
      final date = body['exception_date']?.toString() ?? '';
      return '$kind${date.isNotEmpty ? ' le $date' : ''}';
    case 'timetable_versions':
      final status = body['status']?.toString() ?? '';
      return 'Version d\'emploi du temps'
          '${status.isNotEmpty ? ' ($status)' : ''}';
    default:
      return table;
  }
}

/// Les 200 dernières modifications EDT de l'école, plus récentes d'abord.
final edtAuditProvider =
    StreamProvider.autoDispose<List<EdtAuditEntry>>((ref) {
  ref.keepAlive();
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final schoolId = profile?.schoolId;
  if (schoolId == null || schoolId.isEmpty) return Stream.value(const []);
  return db
      .watch(
        '''
        SELECT a.id, a.action, a.table_name, a.new_values, a.old_values,
               a.created_at,
               TRIM(COALESCE(p.first_name,'') || ' ' || COALESCE(p.last_name,'')) AS actor_name
        FROM   audit_logs a
        LEFT JOIN profiles p ON p.id = a.user_id
        WHERE  a.school_id = ?
          AND  a.table_name IN ('timetable_slots','timetable_exceptions','timetable_versions')
        ORDER  BY a.created_at DESC
        LIMIT  200
        ''',
        parameters: [schoolId],
      )
      .map((rows) => [
            for (final r in rows)
              () {
                final action = (r['action'] as String?) ?? '';
                final table = (r['table_name'] as String?) ?? '';
                // En suppression, le détail est dans old_values.
                final body = action == 'DELETE'
                    ? _json(r['old_values'])
                    : _json(r['new_values']);
                final actor = (r['actor_name'] as String?)?.trim();
                return EdtAuditEntry(
                  id: r['id'] as String,
                  action: action,
                  tableName: table,
                  actorName: (actor == null || actor.isEmpty) ? null : actor,
                  at: _dt(r['created_at']),
                  summary: _summarize(table, action, body),
                );
              }(),
          ]);
});
