import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../audit/providers/audit_models.dart';
import '../../auth/providers/auth_provider.dart';
import 'mon_profil_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  MES DERNIÈRES ACTIONS — ce que le journal retient de moi
//
//  ── POURQUOI SUR CETTE PAGE ───────────────────────────────────────────────
//  Le journal d'audit existe et il est bon, mais il s'ouvre depuis un écran
//  d'administration, filtré sur tout le monde. Personne ne peut répondre à la
//  question la plus simple qu'on se pose sur son compte : « qu'est-ce que j'ai
//  fait la dernière fois ? » — et sa sœur, plus sérieuse : « est-ce que
//  quelqu'un a agi SOUS MON NOM ? » Un poste partagé rend la seconde réelle.
//
//  ── ⚠️ CE QUE CHAQUE ESPACE PEUT EN VOIR ──────────────────────────────────
//  Le personnel scolaire lit sa base LOCALE, et les sync-rules n'y descendent
//  que le journal de l'EMPLOI DU TEMPS : sa liste est donc un EXTRAIT, ce que
//  la page dit au lieu de le laisser croire complet. Les deux espaces en ligne
//  interrogent Supabase, où la RLS `audit_logs_select` fait le reste du tri.
//
//  Aucune de ces listes n'est une preuve : le journal n'enregistre que ce que
//  les déclencheurs écrivent. La page ne prétend pas l'inverse.
// ════════════════════════════════════════════════════════════════════════════

/// Combien d'actions on montre — assez pour reconnaître sa propre journée,
/// pas assez pour transformer la page de profil en écran d'audit.
const int kMesActionsAffichees = 8;

/// Une action portée à mon nom, la plus récente d'abord.
///
/// Liste VIDE (jamais d'erreur) quand le journal n'est pas lisible : cette
/// carte est un complément, elle n'a pas à faire échouer la page.
final mesDernieresActionsProvider =
    FutureProvider.autoDispose<List<AuditEntry>>((ref) async {
  final moi = ref.watch(monProfilProvider).valueOrNull;
  if (moi == null) return const [];
  final id = moi.profil.id;

  try {
    if (moi.profil.isSchoolStaff) {
      final rows = await db.getAll(
        '''
        SELECT id, action, table_name, record_id, user_role, created_at
        FROM   audit_logs
        WHERE  user_id = ?
        ORDER  BY created_at DESC
        LIMIT  ?
        ''',
        [id, kMesActionsAffichees],
      );
      return rows.map(_versEntree).toList();
    }

    final client = ref.read(supabaseClientProvider);
    final rows = await client
        .from('audit_logs')
        .select('id, action, table_name, record_id, user_role, created_at')
        .eq('user_id', id)
        .order('created_at', ascending: false)
        .limit(kMesActionsAffichees);
    return (rows as List)
        .map((r) => _versEntree(Map<String, dynamic>.from(r as Map)))
        .toList();
  } catch (_) {
    return const [];
  }
});

/// Vrai quand la liste affichée n'est qu'un extrait du journal.
/// Le personnel ne reçoit hors ligne que l'audit de l'emploi du temps.
final mesActionsSontUnExtraitProvider = Provider.autoDispose<bool>((ref) {
  final moi = ref.watch(monProfilProvider).valueOrNull;
  return moi?.profil.isSchoolStaff ?? false;
});

AuditEntry _versEntree(Map<String, dynamic> r) => AuditEntry(
      id: r['id'] as String? ?? '',
      action: r['action'] as String? ?? '',
      tableName: r['table_name'] as String? ?? '',
      userName: '',
      userRole: r['user_role'] as String? ?? '',
      createdAt: DateTime.tryParse(r['created_at'] as String? ?? ''),
      recordId: r['record_id'] as String?,
    );
