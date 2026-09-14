part of '../admin_users_screen.dart';

// Vue tableau : en-tête, lignes, bouton d’action.

class _TableView extends StatelessWidget {
  const _TableView({
    required this.users, required this.sortField, required this.sortAsc,
    required this.onSort, required this.onView, required this.onEdit, required this.onPassword,
    required this.onToggle, required this.onMuter, required this.onResetPin,
    required this.data,
  });
  final List<AdminUser>  users;
  final String sortField;
  final bool   sortAsc;
  final ValueChanged<String>    onSort;
  final ValueChanged<AdminUser> onView, onEdit, onPassword, onToggle, onMuter,
      onResetPin;
  final AdminUsersData data;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return const AdminEmptyState(
        icon: Icons.search_off_rounded,
        title: 'Aucun résultat',
        message: 'Aucun utilisateur ne correspond à vos filtres.',
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 8, offset: const Offset(0, 2),
        )],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(children: [
          _TableHeader(sortField: sortField, sortAsc: sortAsc, onSort: onSort),
          ...users.asMap().entries.map((e) => _TableRow(
            user:       e.value,
            isOdd:      e.key.isOdd,
            data:       data,
            onView:     () => onView(e.value),
            onEdit:     () => onEdit(e.value),
            onPassword: () => onPassword(e.value),
            onToggle:   () => onToggle(e.value),
            onMuter:    () => onMuter(e.value),
            onResetPin: () => onResetPin(e.value),
          )),
        ]),
      ),
    );
  }
}

// ─── Géométrie de la colonne ACTIONS ─────────────────────────────────────────
// La largeur était figée à 150 px — juste au moment où la rangée comptait cinq
// boutons. L'ajout de « Muter » en a porté certaines à six (les rôles soumis au
// verrou de poste, qui ont en plus le bouton PIN) : 176 px de contenu dans une
// boîte de 150, d'où la bande rayée « OVERFLOWED BY 26 PIXELS » en travers de
// la colonne, sur ces rangées-là seulement.
//
// On dérive donc la largeur du NOMBRE MAXIMAL de boutons au lieu de la deviner.
// Ajouter un bouton demain ne redéborde plus : il suffit d'incrémenter le
// compteur, et l'en-tête suit la rangée puisque les deux lisent la même valeur.
const double _kActionBtnSize = 26; // Icon(size: 16) + Padding(all: 5) × 2
const double _kActionGap = 4;
const int _kMaxActionBtns = 6; // voir · modifier · mot de passe · PIN · muter · fin de service
const double _kActionsColW =
    _kMaxActionBtns * _kActionBtnSize + (_kMaxActionBtns - 1) * _kActionGap;

class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.sortField, required this.sortAsc, required this.onSort});
  final String sortField;
  final bool   sortAsc;
  final ValueChanged<String> onSort;

  Widget _col(String label, String field, {int flex = 1}) => Expanded(
    flex: flex,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onSort(field),
        child: Row(children: [
          Flexible(child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: kTextMuted, fontSize: 11, fontWeight: FontWeight.w700))),
          const SizedBox(width: 3),
          Icon(
            sortField == field
                ? (sortAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                : Icons.unfold_more_rounded,
            size: 12,
            color: sortField == field ? kNavy : kTextMuted,
          ),
        ]),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    color: kSurface,
    child: Row(children: [
      const SizedBox(width: 42),
      const SizedBox(width: 12),
      _col('NOM / EMAIL',       'name',   flex: 3),
      _col('RÔLE',              'role',   flex: 2),
      _col('ÉCOLE',             'school', flex: 2),
      _col('STATUT',            'status'),
      _col('DERNIÈRE CONNEXION','login',  flex: 2),
      SizedBox(width: _kActionsColW,
          child: Text('ACTIONS', textAlign: TextAlign.end,
              style: TextStyle(color: kTextMuted, fontSize: 11, fontWeight: FontWeight.w700))),
    ]),
  );
}

class _TableRow extends StatefulWidget {
  const _TableRow({
    required this.user, required this.isOdd, required this.data,
    required this.onView, required this.onEdit, required this.onPassword, required this.onToggle,
    required this.onMuter, required this.onResetPin,
  });
  final AdminUser user;
  final bool isOdd;
  final AdminUsersData data;
  final VoidCallback onView, onEdit, onPassword, onToggle, onMuter, onResetPin;

  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    return MouseRegion(
      onEnter: (_) => setState(() => _hov = true),
      onExit:  (_) => setState(() => _hov = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onView,
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _hov
              ? kNavy.withValues(alpha: 0.04)
              : widget.isOdd ? kSurface.withValues(alpha: 0.5) : kCardBg,
          border: Border(bottom: BorderSide(color: kBorder.withValues(alpha: 0.6))),
        ),
        child: Row(children: [
          // Avatar
          PhotoAvatar(
            name: u.fullName,
            photoUrl: u.avatarUrl,
            size: 42,
            background: (u.isActive ? kNavy : kTextMuted).withValues(alpha: 0.12),
            foreground: u.isActive ? kNavy : kTextMuted,
          ),
          const SizedBox(width: 12),
          // Nom + email
          Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(u.fullName,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary),
                overflow: TextOverflow.ellipsis),
            Text(u.email,
                style: TextStyle(fontSize: 11, color: kTextMuted),
                overflow: TextOverflow.ellipsis),
          ])),
          // Rôle + profil
          Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _RoleBadge(role: u.role),
            if (u.accessProfileName != null) ...[
              const SizedBox(height: 4),
              _SmallBadge(label: u.accessProfileName!, color: _kPurple, icon: Icons.shield_outlined),
            ],
          ])),
          // École
          Expanded(flex: 2, child: u.schoolName != null
              ? _SmallBadge(label: u.schoolName!, color: _kBlue, icon: Icons.account_balance_outlined)
              : Text('—', style: TextStyle(color: kTextMuted, fontSize: 12))),
          // Statut
          Expanded(child: Row(children: [
            Icon(
              u.isActive ? Icons.check_circle_rounded : Icons.cancel_rounded,
              size: 16, color: u.isActive ? kGreen : kRed,
            ),
            const SizedBox(width: 5),
            Flexible(child: Text(u.isActive ? 'Actif' : 'Inactif',
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: u.isActive ? kGreen : kRed,
                ), overflow: TextOverflow.ellipsis)),
          ])),
          // Dernière connexion
          Expanded(flex: 2, child: Text(u.lastLoginLabel,
              style: TextStyle(fontSize: 11.5, color: kTextMuted),
              overflow: TextOverflow.ellipsis)),
          // Actions
          SizedBox(width: _kActionsColW, child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            _ActionBtn(icon: Icons.visibility_outlined, color: _kBlue, tooltip: 'Voir les détails', onTap: widget.onView),
            const SizedBox(width: _kActionGap),
            _ActionBtn(icon: Icons.edit_rounded, color: kNavy, tooltip: 'Modifier', onTap: widget.onEdit),
            const SizedBox(width: _kActionGap),
            _ActionBtn(icon: Icons.key_rounded, color: kAccent, tooltip: 'Réinitialiser le mot de passe', onTap: widget.onPassword),
            if (agentLockApplies(u.role)) ...[
              const SizedBox(width: _kActionGap),
              _ActionBtn(icon: Icons.pin_rounded, color: kNavy, tooltip: 'Réinitialiser le code du poste', onTap: widget.onResetPin),
            ],
            const SizedBox(width: _kActionGap),
            // Muter n'est PAS désactiver : l'agent change d'école et reste en
            // service. Les deux gestes ont donc deux boutons.
            _ActionBtn(
              icon: Icons.swap_horiz_rounded, color: _kPurple,
              tooltip: 'Muter vers un autre établissement',
              onTap: widget.onMuter,
            ),
            const SizedBox(width: _kActionGap),
            _ActionBtn(
              icon: u.isActive ? Icons.logout_rounded : Icons.person_add_alt_1_rounded,
              color: u.isActive ? kRed : kGreen,
              tooltip: u.isActive ? 'Enregistrer une fin de service' : 'Réintégrer',
              onTap: widget.onToggle,
            ),
          ])),
        ]),
      ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({required this.icon, required this.color, required this.tooltip, required this.onTap});
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    ),
  );
}
