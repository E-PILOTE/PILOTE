// ══════════════════════════════════════════════════════════════════════════════
//  LIRE LE REGISTRE DES DOCUMENTS DÉLIVRÉS
//
//  100 % local (`db.watch`) comme tout l'espace école : le registre se consulte
//  au guichet, souvent sans réseau, et souvent pour répondre à quelqu'un qui
//  attend — « la carte de mon fils, on l'a déjà refaite ? ».
//
//  ⚠️ Exige que `issued_documents` figure dans les sync-rules (bucket
//  `by_school`, migration 0149). Sans ce déploiement, les écritures remontent
//  bien vers Postgres mais ne redescendent nulle part : l'écran resterait vide
//  alors que la donnée existe.
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/powersync/powersync_service.dart';

class DocumentEmis {
  const DocumentEmis({
    required this.id,
    required this.documentType,
    required this.recipientName,
    required this.issuedAt,
    this.recipientRef,
    this.issuedByName,
    this.purpose,
    this.studentId,
  });

  final String id, documentType, recipientName;
  final DateTime issuedAt;
  final String? recipientRef, issuedByName, purpose, studentId;
}

DocumentEmis _vers(Map<String, dynamic> r) => DocumentEmis(
      id: r['id'] as String,
      documentType: (r['document_type'] as String?) ?? '',
      recipientName: (r['recipient_name'] as String?) ?? '—',
      recipientRef: r['recipient_ref'] as String?,
      issuedByName: r['issued_by_name'] as String?,
      purpose: r['purpose'] as String?,
      studentId: r['student_id'] as String?,
      issuedAt:
          DateTime.tryParse((r['issued_at'] as String?) ?? '')?.toLocal() ??
              DateTime.fromMillisecondsSinceEpoch(0),
    );

/// Les 500 dernières délivrances, du plus récent au plus ancien.
///
/// Le plafond n'est pas une pagination : c'est ce qu'un écran de consultation
/// peut rendre utilement. Les recherches ciblées passent par le filtre, qui
/// s'applique en mémoire sur cette fenêtre — une école délivre quelques
/// milliers de pièces par an, et le registre sert à répondre à « et la semaine
/// dernière ? », pas à archiver.
final registreDocumentsProvider =
    StreamProvider.autoDispose<List<DocumentEmis>>((ref) {
  return db
      .watch(
        'SELECT id, document_type, student_id, recipient_name, recipient_ref, '
        '       issued_by_name, issued_at, purpose '
        '  FROM issued_documents '
        ' ORDER BY issued_at DESC LIMIT 500',
      )
      .map((rows) => rows.map(_vers).toList());
});

/// Les documents déjà délivrés à un élève — la question des duplicatas.
final registreEleveProvider = StreamProvider.autoDispose
    .family<List<DocumentEmis>, String>((ref, studentId) {
  return db
      .watch(
        'SELECT id, document_type, student_id, recipient_name, recipient_ref, '
        '       issued_by_name, issued_at, purpose '
        '  FROM issued_documents WHERE student_id = ? '
        ' ORDER BY issued_at DESC',
        parameters: [studentId],
      )
      .map((rows) => rows.map(_vers).toList());
});
