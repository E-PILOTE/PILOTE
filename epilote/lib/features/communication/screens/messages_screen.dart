import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/app_shell.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/communication_scope.dart';
import '../providers/messages_provider.dart';

part 'messages_sidebar.dart';
part 'messages_list.dart';
part 'messages_reader.dart';
part 'messages_compose.dart';
part 'messages_states.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
const _kNavy   = Color(0xFF1E3A5F);
const _kGreen  = Color(0xFF009A44);
const _kRed    = Color(0xFFEF4444);
const _kCard   = Colors.white;
const _kText   = Color(0xFF0F172A);
const _kSub    = Color(0xFF64748B);
const _kBg     = Color(0xFFF0F4F8);
const _kBorder = Color(0xFFE2E8F0);

final _fmtFull = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR');
final _fmtDay  = DateFormat('dd MMM', 'fr_FR');
final _fmtTime = DateFormat('HH:mm', 'fr_FR');

// ─── Local state ──────────────────────────────────────────────────────────────
final _searchProv   = StateProvider.autoDispose<String>((ref) => '');
final _selectedProv = StateProvider.autoDispose<MessageModel?>((ref) => null);

/// Messagerie scope-aware (super_admin = plateforme · admin_groupe = son groupe).
/// Le périmètre école/offline sera branché sur PowerSync lors du lot école.
class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(messagesProvider);

    return AppShell(
      title: 'Messagerie',
      child: async.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const _Skeleton(),
        error: (e, _) =>
            _Err(error: e.toString(), onRetry: () => ref.invalidate(messagesProvider)),
        data: (data) => _MailLayout(data: data),
      ),
    );
  }
}

// ─── Layout principal 3 panneaux ─────────────────────────────────────────────
class _MailLayout extends ConsumerWidget {
  const _MailLayout({required this.data});
  final MessagesData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_selectedProv);

    return Row(
      children: [
        _Sidebar(data: data),
        Container(width: 1, color: _kBorder),
        SizedBox(width: 360, child: _MessageList(data: data)),
        Container(width: 1, color: _kBorder),
        Expanded(
          child: selected == null
              ? _NoSelection()
              : _MessageReader(msg: selected),
        ),
      ],
    );
  }
}
