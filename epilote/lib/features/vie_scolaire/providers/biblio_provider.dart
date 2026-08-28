import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../navigation/providers/permissions_provider.dart';

const _uuid = Uuid();

/// Le slug de CE module, declare a cote des requetes qu'il borne.
const kSlugBibliotheque = 'bibliotheque';

// ════════════════════════════════════════════════════════════════════════════
//  BIBLIOTHÈQUE (tables `library_items` + `library_loans`) — catalogue d'ouvrages
//  (titre, auteur, ISBN, catégorie, exemplaires) et prêts (emprunteur, dates,
//  statut). 100% offline.
//
//  ── ⚠️ LA DISPONIBILITÉ NE SE STOCKE PAS, ELLE SE CALCULE ──────────────────
//  `available_quantity` était tenu par INCRÉMENTS : `- 1` au prêt, `+ 1` au
//  retour. Faux ici, et silencieusement. Le connecteur ne rejoue pas le SQL, il
//  remonte la VALEUR RÉSULTANTE : deux postes hors ligne passent chacun 5 à 4 et
//  envoient « 4 » — deux prêts enregistrés, un exemplaire disparu du compte. Le
//  compteur ne se recalculait nulle part, donc il ne revenait jamais : tombé à
//  zéro, il refuse de prêter un livre posé sur l'étagère.
//
//  On lit désormais la disponibilité comme ce qu'elle est : `quantity` moins les
//  prêts en cours. Les lignes de prêt, elles, convergent — elles ne s'écrasent
//  pas. Le serveur tient la même formule par déclencheur (migration 0133) pour
//  les lecteurs SQL ; le client la recalcule localement parce que, hors ligne,
//  le déclencheur n'a pas encore tourné et l'écran doit dire vrai tout de suite.
//  Une seule formule, deux endroits, aucun incrément.
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
    '''
    SELECT i.*,
           MAX(0, COALESCE(i.quantity, 0) - (
             SELECT COUNT(*) FROM library_loans l
              WHERE l.item_id = i.id
                AND l.return_date IS NULL
                AND COALESCE(l.status, 'active') <> 'returned')) AS dispo
    FROM library_items i
    WHERE i.school_id = ? AND COALESCE(i.is_active, 1) <> 0
    ORDER BY i.title
    ''',
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
            available: (r['dispo'] as int?) ?? 0,
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

  // Perimetre de CE module (verrou 4). Un pret nomme un eleve : la liste
  // complete des emprunteurs est la liste complete des eleves.
  final scope = classScopeClause(ref, kSlugBibliotheque, column: 'c.id');

  return db.watch(
    '''
    SELECT l.*, it.title AS item_title,
           s.first_name AS bf, s.last_name AS bl
    FROM library_loans l
    LEFT JOIN library_items it ON it.id = l.item_id
    LEFT JOIN students s ON s.id = l.borrower_id
    LEFT JOIN classes c ON c.id = (
      SELECT ce.class_id FROM class_enrollments ce
       WHERE ce.student_id = l.borrower_id
       ORDER BY CASE WHEN ce.status = 'active' THEN 0 ELSE 1 END,
                ce.created_at DESC
       LIMIT 1)
    WHERE l.school_id = ?
    ${scope?.clause ?? ''}
    ORDER BY (l.return_date IS NOT NULL), l.due_date
    ''',
    parameters: [schoolId, ...?scope?.params],
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
  // `available_quantity` n'est PAS écrite : c'est une valeur dérivée. Le bloc
  // qui la « rattrapait » ici (ancienne dispo → nombre emprunté → nouvelle
  // dispo) reposait sur un compteur déjà faux, et propageait donc son erreur à
  // chaque modification de fiche. Seul `quantity` — le nombre d'exemplaires
  // physiques, saisi par un humain — s'écrit.
  final now = DateTime.now().toIso8601String();
  if (id != null) {
    await db.execute(
      'UPDATE library_items SET title = ?, author = ?, isbn = ?, category = ?, '
      'quantity = ?, location = ?, updated_at = ? WHERE id = ?',
      [title, author, isbn, category, quantity, location, now, id],
    );
  } else {
    await db.execute(
      '''
      INSERT INTO library_items (
        id, group_id, school_id, title, author, isbn, category, quantity,
        location, is_active, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?)
      ''',
      [_uuid.v4(), groupId, schoolId, title, author, isbn, category, quantity,
       location, now, now],
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
  // Le plafond se COMPTE, il ne se lit pas dans un compteur : voir l'en-tête.
  final ex = await db.getAll(
    '''
    SELECT COALESCE(quantity, 0) AS q,
           (SELECT COUNT(*) FROM library_loans l
             WHERE l.item_id = ?
               AND l.return_date IS NULL
               AND COALESCE(l.status, 'active') <> 'returned') AS sortis
      FROM library_items WHERE id = ?
    ''',
    [itemId, itemId],
  );
  final q = (ex.firstOrNull?['q'] as int?) ?? 0;
  final sortis = (ex.firstOrNull?['sortis'] as int?) ?? 0;
  if (q - sortis <= 0) return 'Aucun exemplaire disponible';

  // ⚠️ `UNIQUE (item_id, borrower_id) WHERE return_date IS NULL` (0134) : un
  // élève ne peut pas avoir deux fois le même ouvrage en cours. Le dire ici en
  // clair, plutôt que de laisser l'index le dire en 23505 — code fatal, lot
  // PowerSync entier jeté. Ce garde attrape aussi le double appui sur
  // « Enregistrer », qui insérait deux prêts pour un seul livre remis.
  final deja = await db.getAll(
    'SELECT id FROM library_loans '
    'WHERE item_id = ? AND borrower_id = ? AND return_date IS NULL '
    "AND COALESCE(status, 'active') <> 'returned' LIMIT 1",
    [itemId, borrowerId],
  );
  if (deja.isNotEmpty) return 'Cet emprunteur a déjà cet ouvrage en prêt';

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
  return null;
}

Future<void> returnLoan(LibraryLoan loan) async {
  final now = DateTime.now().toIso8601String();
  await db.execute(
    'UPDATE library_loans SET status = \'returned\', return_date = ?, '
    'updated_at = ? WHERE id = ?',
    [now.substring(0, 10), now, loan.id],
  );
}
