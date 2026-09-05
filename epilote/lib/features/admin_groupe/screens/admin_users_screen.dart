import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/widgets/annuaire_filter_bar.dart';
import '../../../core/widgets/app_shell.dart';
import '../../auth/providers/active_agent_provider.dart' show agentLockApplies;
import '../../../core/utils/mouvement_agent.dart';
import '../providers/admin_carriere_provider.dart' show ChargeLiberee;
import '../providers/admin_users_provider.dart';
import '../widgets/agent_carriere_panel.dart';
import 'agent_mouvement_dialogs.dart';
import '../providers/subscription_access_provider.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/photo_avatar.dart';
import '../../../core/utils/message_erreur.dart';
import '../../../core/widgets/capture_webcam.dart';
import '../../staff/services/agent_photo_service.dart' show kAvatarExtensions;
import '../services/photo_utilisateur_service.dart';
import 'users/champ_photo_agent.dart';

part 'users/users_kpis.dart';
part 'users/users_table.dart';
part 'users/users_badges.dart';
part 'users/users_cards.dart';
part 'users/user_detail_modal.dart';
part 'users/user_detail_tabs.dart';
part 'users/user_form_dialog.dart';
part 'users/user_form_fields.dart';
part 'users/user_form_layout.dart';
part 'users/reset_password_dialog.dart';

// ─── Couleurs locales ─────────────────────────────────────────────────────────
const _kOrange = Color(0xFFFF6B35);
const _kBlue   = Color(0xFF0EA5E9);
const _kPurple = Color(0xFF7C3AED);

// ─── Screen ───────────────────────────────────────────────────────────────────

class AdminUsersScreen extends ConsumerWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppShell(
      title: 'Utilisateurs',
      child: ref.watch(adminUsersProvider).when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const _ShimmerSkeleton(),
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: kTextMuted),
            const SizedBox(height: 12),
            Text(messageErreur(e), style: TextStyle(color: kTextMuted)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(adminUsersProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ]),
        ),
        data: (d) => _UsersBody(data: d),
      ),
    );
  }
}

// ─── Body (état filtres + tri + vue) ─────────────────────────────────────────

class _UsersBody extends ConsumerStatefulWidget {
  const _UsersBody({required this.data});
  final AdminUsersData data;

  @override
  ConsumerState<_UsersBody> createState() => _UsersBodyState();
}

class _UsersBodyState extends ConsumerState<_UsersBody> {
  final _searchCtrl  = TextEditingController();
  String? _roleFilter;
  String? _schoolFilter;
  String  _statusFilter = 'all'; // all | active | inactive
  bool    _isTableView  = true;
  String  _sortField    = 'name';
  bool    _sortAsc      = true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<AdminUser> _applyFilters(List<AdminUser> all) {
    final q = _searchCtrl.text.trim().toLowerCase();
    return all.where((u) {
      if (_roleFilter   != null && u.role     != _roleFilter)   return false;
      if (_schoolFilter != null && u.schoolId != _schoolFilter) return false;
      if (_statusFilter == 'active'   && !u.isActive) return false;
      if (_statusFilter == 'inactive' &&  u.isActive) return false;
      if (q.isEmpty) return true;
      return u.fullName.toLowerCase().contains(q)
          || u.email.toLowerCase().contains(q)
          || (u.employeeNumber?.toLowerCase().contains(q) ?? false);
    }).toList()
      ..sort((a, b) {
        int c;
        switch (_sortField) {
          case 'role':   c = a.role.compareTo(b.role);         break;
          case 'school': c = (a.schoolName ?? '').compareTo(b.schoolName ?? ''); break;
          case 'status': c = (a.isActive ? 0 : 1).compareTo(b.isActive ? 0 : 1); break;
          default:       c = a.fullName.compareTo(b.fullName);
        }
        return _sortAsc ? c : -c;
      });
  }

  void _openCreate() {
    if (!ensureSubscriptionWritable(ref, context)) return;
    final data = widget.data;
    if (data.schools.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: kRed,
        content: const Text("Vous devez d'abord créer au moins une école."),
      ));
      return;
    }
    showDialog(context: context, builder: (_) => UserFormDialog(data: data));
  }

  void _openEdit(AdminUser u) =>
      showDialog(context: context, builder: (_) => UserFormDialog(data: widget.data, user: u));

  void _openResetPwd(AdminUser u) =>
      showDialog(context: context, builder: (_) => ResetPasswordDialog(user: u));

  Future<void> _resetPin(AdminUser u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Réinitialiser le code du poste'),
        content: Text('${u.fullName} devra créer un nouveau code PIN à sa '
            'prochaine ouverture de session sur un poste partagé. Continuer ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Réinitialiser')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(adminUsersServiceProvider).resetAgentPin(u.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: kGreen,
            content: const Text('Code du poste réinitialisé')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: kRed, content: Text(messageErreur(e))));
      }
    }
  }

  void _openDetail(AdminUser u) => showDialog(
        context: context,
        builder: (_) => _UserDetailModal(
          user: u,
          onEdit:     () { Navigator.of(context).pop(); _openEdit(u); },
          onPassword: () { Navigator.of(context).pop(); _openResetPwd(u); },
          onToggle:   () { Navigator.of(context).pop(); _mouvementCarriere(u); },
        ),
      );

  /// Muter, radier ou réintégrer — jamais « basculer un booléen ».
  ///
  /// L'ancien bouton Actif/Inactif confondait huit situations et désactivait
  /// un agent MUTÉ, qu'on attendait pourtant dans une autre école. Chaque geste
  /// a désormais son motif, sa date d'effet et la référence de son acte
  /// (migration 0083).
  Future<void> _mouvementCarriere(AdminUser u) async {
    if (!ensureSubscriptionWritable(ref, context)) return;
    final charge = u.isActive
        ? await showRadiationDialog(context, user: u)
        : await showReintegrationDialog(context, user: u, schools: widget.data.schools);
    if (charge == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: kGreen,
      content: Text(u.isActive
          ? 'Fin de service enregistrée — le dossier reste consultable'
          : 'Agent réintégré'),
    ));
    await _annoncerCharge(u, charge);
  }

  Future<void> _muter(AdminUser u) async {
    if (!ensureSubscriptionWritable(ref, context)) return;
    if (!u.isActive) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        backgroundColor: _kOrange,
        content: Text('Cet agent a quitté le service : le réintégrer d\'abord.'),
      ));
      return;
    }
    final charge =
        await showMutationDialog(context, user: u, schools: widget.data.schools);
    if (charge == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: kGreen,
      content: Text('${u.fullName} muté — ancienneté conservée'),
    ));
    await _annoncerCharge(u, charge);
  }

  /// Ce que le départ a libéré, et surtout CE QUI RESTE À FAIRE.
  ///
  /// L'emploi du temps n'est jamais modifié par un mouvement administratif :
  /// qui remplace un enseignant est une décision de l'établissement. Taire les
  /// créneaux restés à son nom se lirait « tout est réglé » — d'où cette
  /// modale, et non un message qui s'efface.
  Future<void> _annoncerCharge(AdminUser u, ChargeLiberee charge) async {
    final texte = charge.resume;
    if (texte == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
            charge.creneauxAReattribuer > 0
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline,
            color: charge.creneauxAReattribuer > 0 ? _kOrange : kGreen,
            size: 34),
        title: Text('Charge de ${u.fullName}'),
        content: Text('$texte\n\nLes cours faits, les paies et les congés '
            'déjà enregistrés restent au dossier : ils disent ce qui a été.'),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Compris')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data     = widget.data;
    final filtered = _applyFilters(data.users);
    final roles    = {for (final u in data.users) u.role}.toList()..sort();

    return RefreshIndicator(
      onRefresh: () => ref.refresh(adminUsersProvider.future),
      child: LayoutBuilder(builder: (ctx, constraints) {
        final double w = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(ctx).size.width - 80;

        return SingleChildScrollView(
          child: SizedBox(
            width: w,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // ── KPIs ─────────────────────────────────────────────────────
                _KpiGrid(data: data),
                const SizedBox(height: 20),
                // ── Filtres ──────────────────────────────────────────────────
                // Kit partagé avec l'annuaire Personnel de l'école : mêmes
                // widgets, mêmes gestes d'un espace à l'autre.
                AnnuaireFilterBar(
                  width:          w - 48,
                  searchCtrl:     _searchCtrl,
                  searchHint:     'Rechercher (nom, email, matricule)…',
                  onSearchChange: (_) => setState(() {}),
                  isTableView:    _isTableView,
                  onToggleView:   ()  => setState(() => _isTableView  = !_isTableView),
                  hasActiveFilters: _roleFilter != null ||
                      _schoolFilter != null || _statusFilter != 'all',
                  onReset: () => setState(() {
                    _searchCtrl.clear();
                    _roleFilter = _schoolFilter = null;
                    _statusFilter = 'all';
                  }),
                  primaryAction: AnnuairePrimaryAction(
                    icon: Icons.person_add_rounded,
                    label: 'Nouvel utilisateur',
                    onTap: _openCreate,
                  ),
                  filters: [
                    AnnuaireDropdown<String?>(
                      icon: Icons.badge_outlined, label: 'Rôle',
                      value: _roleFilter, active: _roleFilter != null,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Tous les rôles')),
                        ...roles.map((r) => DropdownMenuItem(
                            value: r,
                            child: Text(roleLabel(r), overflow: TextOverflow.ellipsis))),
                      ],
                      onChanged: (v) => setState(() => _roleFilter = v),
                    ),
                    AnnuaireDropdown<String?>(
                      icon: Icons.account_balance_outlined, label: 'École',
                      value: _schoolFilter, active: _schoolFilter != null,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Toutes les écoles')),
                        ...data.schools.map((s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(s.name, overflow: TextOverflow.ellipsis))),
                      ],
                      onChanged: (v) => setState(() => _schoolFilter = v),
                    ),
                    AnnuaireStatusSegment(
                      value: _statusFilter,
                      onChanged: (v) => setState(() => _statusFilter = v),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // ── Résultat ──────────────────────────────────────────────────
                AnnuaireResultHeader(
                    total: data.users.length, filtered: filtered.length),
                const SizedBox(height: 12),
                // ── Vue principale ───────────────────────────────────────────
                if (data.users.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: AdminEmptyState(
                      icon: Icons.person_add_alt_1_rounded,
                      title: 'Aucun utilisateur',
                      message: data.schools.isEmpty
                          ? "Créez d'abord une école, puis ajoutez les comptes du personnel."
                          : 'Ajoutez les comptes du personnel de vos établissements pour leur donner accès à la plateforme.',
                      actionLabel: data.schools.isEmpty ? null : 'Ajouter un utilisateur',
                      onAction: data.schools.isEmpty ? null : _openCreate,
                    ),
                  )
                else if (_isTableView)
                  _TableView(
                    users:     filtered,
                    sortField: _sortField,
                    sortAsc:   _sortAsc,
                    onSort: (f) => setState(() {
                      if (_sortField == f) { _sortAsc = !_sortAsc; }
                      else { _sortField = f; _sortAsc = true; }
                    }),
                    onView:     _openDetail,
                    onEdit:     _openEdit,
                    onPassword: _openResetPwd,
                    onToggle:   _mouvementCarriere,
                    onMuter:    _muter,
                    onResetPin: _resetPin,
                    data:       data,
                  )
                else
                  _CardGrid(
                    users:      filtered,
                    data:       data,
                    onView:     _openDetail,
                    onEdit:     _openEdit,
                    onPassword: _openResetPwd,
                    onToggle:   _mouvementCarriere,
                    onMuter:    _muter,
                    onResetPin: _resetPin,
                  ),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        );
      }),
    );
  }
}

// ─── KPI Grid ─────────────────────────────────────────────────────────────────
