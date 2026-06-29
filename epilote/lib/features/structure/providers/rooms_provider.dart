import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/auth_provider.dart';

const _uuid = Uuid();

// ════════════════════════════════════════════════════════════════════════════
//  SALLES / RESSOURCES (table `rooms`) — registre des locaux de l'école.
//  Remplace le `timetable_slots.room` texte libre : une salle référencée rend
//  la détection des conflits de salle FIABLE (égalité d'id), porte la capacité
//  (vs effectif) et le type requis par un cours. 100% offline (db.watch/execute).
// ════════════════════════════════════════════════════════════════════════════

/// Catalogue des types de salle (clé technique → libellé FR). Le type reste un
/// varchar libre en base (souplesse Congo) ; l'app propose ce catalogue.
const kRoomTypes = <(String, String)>[
  ('ordinaire', 'Salle ordinaire'),
  ('labo_physique', 'Labo · Physique'),
  ('labo_chimie', 'Labo · Chimie'),
  ('labo_svt', 'Labo · SVT'),
  ('informatique', 'Salle informatique'),
  ('multimedia', 'Multimédia / langues'),
  ('atelier', 'Atelier technique'),
  ('sport', 'Gymnase / terrain'),
  ('amphitheatre', 'Amphithéâtre'),
  ('bibliotheque', 'Bibliothèque / CDI'),
  ('autre', 'Autre'),
];

String roomTypeLabel(String? code) => kRoomTypes
    .firstWhere((t) => t.$1 == code, orElse: () => ('autre', 'Autre'))
    .$2;

/// Une salle est « spécialisée » (≠ ordinaire) — utile pour les KPI et, plus
/// tard, la contrainte « ce cours exige tel type de salle ».
bool roomTypeIsSpecialized(String? code) =>
    code != null && code != 'ordinaire' && code != 'autre';

class Room {
  const Room({
    required this.id,
    required this.name,
    required this.roomType,
    this.code,
    this.capacity,
    this.building,
    this.isActive = true,
  });

  final String id, name, roomType;
  final String? code, building;
  final int? capacity;
  final bool isActive;

  String get typeLabel => roomTypeLabel(roomType);
  bool get isSpecialized => roomTypeIsSpecialized(roomType);
}

/// Toutes les salles actives de l'école, triées par type puis nom.
final roomsProvider = StreamProvider.autoDispose<List<Room>>((ref) {
  ref.keepAlive();
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final schoolId = profile?.schoolId;
  if (schoolId == null || schoolId.isEmpty) return Stream.value(const []);
  return db.watch(
    '''
    SELECT id, code, name, room_type, capacity, building, is_active
    FROM   rooms
    WHERE  school_id = ? AND is_active = 1
    ORDER  BY room_type, name
    ''',
    parameters: [schoolId],
  ).map((rows) => [
        for (final r in rows)
          Room(
            id: r['id'] as String,
            code: r['code'] as String?,
            name: (r['name'] as String?) ?? 'Salle',
            roomType: (r['room_type'] as String?) ?? 'ordinaire',
            capacity: (r['capacity'] as num?)?.toInt(),
            building: r['building'] as String?,
            isActive: (r['is_active'] as int? ?? 1) == 1,
          ),
      ]);
});

// ─── Mutations (offline-first) ───────────────────────────────────────────────
Future<void> createRoom({
  required String groupId,
  required String schoolId,
  String? code,
  required String name,
  required String roomType,
  int? capacity,
  String? building,
}) async {
  final id = _uuid.v4();
  final now = DateTime.now().toIso8601String();
  await db.execute(
    '''
    INSERT INTO rooms (id, group_id, school_id, code, name, room_type,
                       capacity, building, is_active, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?)
    ''',
    [id, groupId, schoolId, code?.trim(), name.trim(), roomType, capacity,
     building?.trim(), now, now],
  );
}

Future<void> updateRoom({
  required String id,
  String? code,
  required String name,
  required String roomType,
  int? capacity,
  String? building,
}) async {
  final now = DateTime.now().toIso8601String();
  await db.execute(
    '''
    UPDATE rooms SET code = ?, name = ?, room_type = ?, capacity = ?,
                     building = ?, updated_at = ?
    WHERE id = ?
    ''',
    [code?.trim(), name.trim(), roomType, capacity, building?.trim(), now, id],
  );
}

/// Suppression DOUCE (is_active=0) : ne casse pas l'historique des créneaux qui
/// référencent la salle, et la retire de la synchro (sync-rule is_active=true).
Future<void> deactivateRoom(String id) async {
  final now = DateTime.now().toIso8601String();
  await db.execute(
    'UPDATE rooms SET is_active = 0, updated_at = ? WHERE id = ?',
    [now, id],
  );
}
