part of '../super_dashboard_screen.dart';

// En-tête de page et actions rapides.

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.profile});
  final dynamic profile;

  @override
  Widget build(BuildContext context) {
    final now       = DateTime.now();
    final day       = DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(now);
    final firstName = _first(profile?.fullName as String?);

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [_kNavy, const Color(0xFF2D5A8E)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(
            color: _kNavy.withValues(alpha: 0.28),
            blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Row(children: [
        Container(
          width: 50, height: 50,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
          ),
          child: const Icon(Icons.shield_rounded, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_greet(now.hour)}${firstName.isNotEmpty ? ', $firstName' : ''}',
                style: const TextStyle(color: Colors.white, fontSize: 18,
                    fontWeight: FontWeight.w800, letterSpacing: -0.2)),
            const SizedBox(height: 3),
            Row(children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 11, color: Color(0xFF93C5FD)),
              const SizedBox(width: 5),
              Text(day, style: const TextStyle(
                  color: Color(0xFF93C5FD), fontSize: 12)),
            ]),
          ],
        )),
        Row(children: [
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            ...[_kGreen, _kGold, _kRed].map((c) => Container(
              width: 28, height: 4,
              margin: const EdgeInsets.only(bottom: 2),
              decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(2)),
            )),
          ]),
          const SizedBox(width: 14),
          Consumer(builder: (_, ref, _) => Tooltip(
            message: 'Actualiser',
            child: InkWell(
              onTap: () => ref.invalidate(superDashboardProvider),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                ),
                child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
              ),
            ),
          )),
        ]),
      ]),
    );
  }

  String _first(String? n) =>
      n == null || n.isEmpty ? '' : n.trim().split(RegExp(r'\s+')).first;
  String _greet(int h) => h >= 5 && h < 12 ? 'Bonjour'
      : h >= 12 && h < 18 ? 'Bon après-midi'
      : h >= 18 && h < 22 ? 'Bonsoir' : 'Bonne nuit';
}

// ─── 2 · Actions rapides ──────────────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  _QuickActions();

  final _actions = [
    _QA('Nouveau groupe', Icons.add_business_rounded,  _kNavy,   Routes.superGroupes),
    const _QA('Nouvel admin',   Icons.person_add_rounded,    _kBlue,   Routes.superAdministrateurs),
    const _QA('Créer un plan',  Icons.inventory_2_rounded,   _kTeal,   Routes.superPlans),
    _QA('Abonnements',    Icons.verified_rounded,      _kGreen,  Routes.superAbonnements),
    const _QA('Factures',       Icons.receipt_long_rounded,  _kPurple, Routes.superFactures),
    const _QA('Rapports',       Icons.bar_chart_rounded,     _kOrange, Routes.superRapports),
  ];

  @override
  Widget build(BuildContext context) => _Card(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Icon(Icons.flash_on_rounded, size: 15, color: _kGold),
        const SizedBox(width: 7),
        Text('Actions rapides', style: TextStyle(
            color: _kText, fontSize: 13.5, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 12),
      Wrap(spacing: 10, runSpacing: 8,
          children: _actions.map((a) => _QaChip(action: a)).toList()),
    ],
  ));
}

class _QA {
  const _QA(this.label, this.icon, this.color, this.route);
  final String label; final IconData icon;
  final Color color;  final String route;
}

class _QaChip extends StatefulWidget {
  const _QaChip({required this.action});
  final _QA action;
  @override
  State<_QaChip> createState() => _QaChipState();
}
class _QaChipState extends State<_QaChip> {
  bool _hov = false;
  @override
  Widget build(BuildContext context) {
    final a = widget.action;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hov = true),
      onExit:  (_) => setState(() => _hov = false),
      child: GestureDetector(
        onTap: () => context.go(a.route),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: _hov ? a.color : a.color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: _hov ? a.color : a.color.withValues(alpha: 0.28)),
            boxShadow: _hov ? [BoxShadow(
                color: a.color.withValues(alpha: 0.30),
                blurRadius: 12, offset: const Offset(0, 4))] : [],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(a.icon, size: 15, color: _hov ? Colors.white : a.color),
            const SizedBox(width: 7),
            Text(a.label, style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w600,
                color: _hov ? Colors.white : a.color)),
          ]),
        ),
      ),
    );
  }
}

// ─── 3 · Alertes ─────────────────────────────────────────────────────────────
