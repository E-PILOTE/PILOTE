import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/auth_provider.dart';

const _uuid = Uuid();

// ════════════════════════════════════════════════════════════════════════════
//  BIBLIOTHÈQUE (tables `library_items` + `library_loans`) — catalogue d'ouvrages
//  (titre, auteur, ISBN, catégorie, exemplaires) et prêts (emprunteur, dates,
//  statut). Disponibilité gérée à l'emprunt/retour. 100% offline.
// ════════════════════════════════════════════════════════════════════════════
class LibraryItem {
  const LibraryItem({
    required this.id,
    required this.title,
    required this.author,
    required this.isbn,
    required this.category,
    required this.quantity,
    required this.available,
    required this.location,
  });
  final String id, title;
  final String? author, isbn, category, location;
  final int quantity, available;

  int get borrowed => quantity - available;
}

class LibraryLoan {
  const LibraryLoan({
    required this.id,
    required this.itemId,
    required this.itemTitle,
    required this.borrowerId,
    required this.borrowerName,
    required this.borrowDate,
    required this.dueDate,
    required this.returnDate,
    required this.status,
  });
  final String id, itemId;
  final String? itemTitle, borrowerId, borrowerName, borrowDate, dueDate, returnDate;
  final String status; // active | returned

  bool get returned => status == 'returned' || returnDate != null;
  bool get overdue {
    if (returned || dueDate == null) return false;
    return dueDate!.compareTo(DateTime.now().toIso8601String().substring(0, 10)) < 0;
  }
}

final libraryItemsProvider =
    StreamProvider.autoDispose<List<LibraryItem>>((ref) {
  ref.keepAlive();
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final schoolId = profile?.schoolId;
  if (schoolId == null || schoolId.isEmpty) return Stream.value(const []);
  return db.watch(
    'SELECT * FROM library_items WHERE school_id = ? AND is_active = 1 '
    'ORDER BY title',
    parameters: [schoolId],
  ).map((rows) => [
        for (final r in rows)
          LibraryItem(
            id: r['id'] as String,
            title: (r['title'] as String?) ?? '—',
            author: r['author'] as String?,
            isbn: r['isbn'] as String?,
            category: r['category'] as String?,
            quantity: (r['quantity'] as int?) ?? 0,
            available: (r['available_quantity'] as int?) ?? 0,
            location: r['location'] as String?,
          ),
      ]);
});

final libraryLoansProvider =
    StreamProvider.autoDispose<List<LibraryLoan>>((ref) {
  ref.keepAlive();
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final schoolId = profile?.schoolId;
  if (schoolId == null || schoolId.isEmpty) return Stream.value(const []);
  return db.watch(
    '''
    SELECT l.*, it.title AS item_title,
           s.first_name AS bf, s.last_name AS bl
    FROM library_loans l
    LEFT JOIN library_items it ON it.id = l.item_id
    LEFT JOIN students s ON s.id = l.borrower_id
    WHERE l.school_id = ?
    ORDER BY (l.return_date IS NOT NULL), l.due_date
    ''',
    parameters: [schoolId],
  ).map((rows) => [
        for (final r in rows)
          LibraryLoan(
            id: r['id'] as String,
            itemId: (r['item_id'] as String?) ?? '',
            itemTitle: r['item_title'] as String?,
            borrowerId: r['borrower_id'] as String?,
            borrowerName: '${(r['bl'] as String?) ?? ''} '
                    '${(r['bf'] as String?) ?? ''}'
                .trim(),
            borrowDate: r['borrow_date'] as String?,
            dueDate: r['due_date'] as String?,
            returnDate: r['return_date'] as String?,
            status: (r['status'] as String?) ?? 'active',
          ),
      ]);
});

// ─── Mutations catalogue ─────────────────────────────────────────────────────
Future<void> saveItem({
  String? id,
  required String groupId,
  required String schoolId,
  required String title,
  String? author,
  String? isbn,
  String? category,
  required int quantity,
  String? location,
}) async {
  final now = DateTime.now().toIso8601String();
  if (id != null) {
    // Ajuste la dispo en gardant le nombre déjà emprunté.
    final ex = await db.getAll(
      'SELECT quantity, available_quantity FROM library_items WHERE id = ?',
      [id],
    );
    final oldQty = (ex.firstOrNull?['quantity'] as int?) ?? quantity;
    final oldAvail = (ex.firstOrNull?['available_quantity'] as int?) ?? quantity;
    final borrowed = oldQty - oldAvail;
    final newAvail = (quantity - borrowed).clamp(0, quantity);
    await db.execute(
      'UPDATE library_items SET title = ?, author = ?, isbn = ?, category = ?, '
      'quantity = ?, available_quantity = ?, location = ?, updated_at = ? '
      'WHERE id = ?',
      [title, author, isbn, category, quantity, newAvail, location, now, id],
    );
  } else {
    await db.execute(
      '''
      INSERT INTO library_items (
        id, group_id, school_id, title, author, isbn, category, quantity,
        available_quantity, location, is_active, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?)
      ''',
      [_uuid.v4(), groupId, schoolId, title, author, isbn, category, quantity,
       quantity, location, now, now],
    );
  }
}

/// Désactive un ouvrage (soft delete — conserve l'historique des prêts).
Future<void> deleteItem(String id) async {
  await db.execute(
    'UPDATE library_items SET is_active = 0, updated_at = ? WHERE id = ?',
    [DateTime.now().toIso8601String(), id],
  );
}

// ─── Mutations prêts ─────────────────────────────────────────────────────────
Future<String?> createLoan({
  required String groupId,
  required String schoolId,
  required String itemId,
  required String borrowerId,
  required String borrowDate,
  required String dueDate,
}) async {
  final ex = await db.getAll(
    'SELECT available_quantity FROM library_items WHERE id = ?', [itemId]);
  final avail = (ex.firstOrNull?['available_quantity'] as int?) ?? 0;
  if (avail <= 0) return 'Aucun exemplaire disponible';
  final now = DateTime.now().toIso8601String();
  await db.execute(
    '''
    INSERT INTO library_loans (
      id, group_id, school_id, item_id, borrower_id, borrow_date, due_date,
      status, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, 'active', ?, ?)
    ''',
    [_uuid.v4(), groupId, schoolId, itemId, borrowerId, borrowDate, dueDate,
     now, now],
  );
  await db.execute(
    'UPDATE library_items SET available_quantity = available_quantity - 1, '
    'updated_at = ? WHERE id = ?',
    [now, itemId],
  );
  return null;
}

Future<void> returnLoan(LibraryLoan loan) async {
  final now = DateTime.now().toIso8601String();
  await db.execute(
    'UPDATE library_loans SET status = \'returned\', return_date = ?, '
    'updated_at = ? WHERE id = ?',
    [now.substring(0, 10), now, loan.id],
  );
  await db.execute(
    'UPDATE library_items SET available_quantity = '
    'MIN(quantity, available_quantity + 1), updated_at = ? WHERE id = ?',
    [now, loan.itemId],
  );
}
