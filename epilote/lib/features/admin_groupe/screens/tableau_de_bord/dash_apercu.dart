part of '../admin_dashboard_screen.dart';

// En-tête de page, actions rapides.

class _Overview extends StatelessWidget {
  const _Overview({required this.data});
  final AdminDashboardData data;

  @override
  Widget build(BuildContext context) {
    final showBanner = data.expireBientot || data.tauxOccupationEleves >= 90;
    // Le contenu occupe toute la largeur disponible pour les grands écrans
    // (27" et plus) ; la grille KPI s'adapte jusqu'à 8 colonnes.
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      children: [
        _PageHeader(data: data),
        const SizedBox(height: 18),
        const _QuickActions(),
        if (showBanner) ...[
          const SizedBox(height: 18),
          _CriticalBanner(data: data),
        ],
        const SizedBox(height: 22),
        _KpiSection(data: data),
        const SizedBox(height: 24),
        _ChartsRow(data: data),
        const SizedBox(height: 24),
        // Examens nationaux & Stages : le pouls du réseau (s'efface si le
        // groupe n'exploite pas le module). Cockpit complet sur /admin/examens.
        const AdminExamsDashboardSection(),
        _RhSection(data: data),
        const SizedBox(height: 24),
        _DeptSection(data: data),
        const SizedBox(height: 24),
        _Governance(data: data),
        const SizedBox(height: 24),
        _RiskCenter(data: data),
        const SizedBox(height: 24),
        _BottomRow(data: data),
      ],
    );
  }
}

// ─── En-tête de page (bandeau navy) ─────────────────────────────────────────
class _PageHeader extends ConsumerWidget {
  const _PageHeader({required this.data});
  final AdminDashboardData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        // Aplat MONO (pas de dégradé) — identique à la bannière de l'espace
        // école. `kNavyDeep` et non `kNavy` : `kNavy` s'éclaircit en thème
        // sombre (jeton de premier plan) et virerait au bleu clair sous le
        // texte blanc. `kNavyDeep` reste un fond sombre dans les 3 thèmes.
        color: kNavyDeep,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: kNavy.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (ctx, c) {
          final narrow = c.maxWidth < 660;
          final left = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${_greeting()} 👋',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
              const SizedBox(height: 5),
              Text(data.groupName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_rounded,
                      size: 12, color: Colors.white.withValues(alpha: 0.5)),
                  const SizedBox(width: 6),
                  Text(_frDate(),
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12.5)),
                ],
              ),
              const SizedBox(height: 3),
              Text('Pilotage stratégique de votre groupe scolaire',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12.5)),
            ],
          );
          final right = Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _HeaderChip(
                  label: statusLabel(data.subscriptionStatus),
                  color: statusColor(data.subscriptionStatus)),
              // Un ministère ne porte pas un « Plan » : il porte sa licence.
              // Le mot vient du slug, pas d'un drapeau de plus — c'est le plan
              // lui-même qui dit la nature de la relation (0182).
              _HeaderChip(
                  label: estPlanDeLicence(data.planSlug)
                      ? data.planName
                      : 'Plan ${data.planName}',
                  color: planColor(data.planSlug)),
              Tooltip(
                message: 'Actualiser',
                child: Material(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => ref.invalidate(adminDashboardProvider),
                    child: const Padding(
                      padding: EdgeInsets.all(9),
                      child: Icon(Icons.refresh_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ),
            ],
          );
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [left, const SizedBox(height: 16), right],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Expanded(child: left), const SizedBox(width: 16), right],
          );
        },
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ─── Actions rapides ────────────────────────────────────────────────────────
class _QuickActions extends ConsumerWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Même route, deux mots — un ministère n'a pas d'abonnement, il exécute un
    // marché (0182/0183). Le raccourci porte donc le nom de la page qu'il
    // ouvre réellement, comme la barre latérale.
    final estTutelle =
        ref.watch(groupeAdministreReferentielProvider).valueOrNull ?? false;
    final items = <(String, IconData, String)>[
      ('Mes écoles', Icons.account_balance_rounded, Routes.adminEcoles),
      ('Utilisateurs', Icons.people_alt_rounded, Routes.adminUtilisateurs),
      ("Profils d'accès", Icons.admin_panel_settings_rounded, Routes.adminProfils),
      ('Rapports', Icons.assessment_rounded, Routes.adminRapports),
      (estTutelle ? 'Licence' : 'Abonnement', Icons.workspace_premium_rounded,
          Routes.adminAbonnement),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final it in items)
          _QaChip(label: it.$1, icon: it.$2, onTap: () => context.go(it.$3)),
      ],
    );
  }
}

class _QaChip extends StatefulWidget {
  const _QaChip({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_QaChip> createState() => _QaChipState();
}

class _QaChipState extends State<_QaChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _hover ? kNavy.withValues(alpha: 0.06) : kCardBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _hover ? kNavy : kBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 16, color: kNavy),
              const SizedBox(width: 8),
              Text(widget.label,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: kTextPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Bannière critique ──────────────────────────────────────────────────────
