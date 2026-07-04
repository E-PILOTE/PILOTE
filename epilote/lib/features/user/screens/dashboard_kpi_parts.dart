part of 'user_dashboard_screen.dart';

// ─── Grille de KPIs (adaptative rôle+permissions) ─────────────────────────────
class _KpiGrid extends ConsumerWidget {
  const _KpiGrid({
    required this.showClasses,
    required this.showEleves,
    required this.showInscriptions,
  });
  final bool showClasses, showEleves, showInscriptions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classCount = ref.watch(classCountProvider).valueOrNull;
    final eleveCount = ref.watch(enrolledStudentCountProvider).valueOrNull;
    final pending = ref.watch(pendingEnrollmentCountProvider).valueOrNull ?? 0;
    final classes = ref.watch(classesProvider).valueOrNull ?? const <ClassModel>[];

    final totalCap = classes.fold<int>(0, (s, c) => s + (c.capacity ?? 0));
    final totalStu = classes.fold<int>(0, (s, c) => s + (c.studentCount ?? 0));
    final fillPct = totalCap > 0 ? ((totalStu / totalCap) * 100).round() : null;

    final cards = <Widget>[
      if (showClasses)
        AdminStatCard(
          label: 'Classes',
          value: classCount?.toString() ?? '—',
          icon: Icons.class_rounded,
          color: kNavy,
          onTap: () => context.push(Routes.classes),
        ),
      if (showEleves)
        AdminStatCard(
          label: 'Élèves inscrits',
          value: eleveCount?.toString() ?? '—',
          icon: Icons.people_rounded,
          color: kGreen,
          onTap: () => context.push(Routes.eleves),
        ),
      if (showInscriptions)
        AdminStatCard(
          label: 'En attente',
          value: pending.toString(),
          icon: Icons.pending_actions_rounded,
          color: pending > 0 ? kAccent : kTextMuted,
          onTap: () => context.push(Routes.inscriptions),
        ),
      if (showClasses && fillPct != null)
        AdminStatCard(
          label: 'Taux de remplissage',
          value: '$fillPct%',
          icon: Icons.donut_large_rounded,
          color: const Color(0xFF0EA5E9),
        ),
    ];

    return LayoutBuilder(builder: (context, c) {
      final cross = c.maxWidth > 720 ? 4 : 2;
      // Hauteur FIXE (mainAxisExtent) plutôt que childAspectRatio : le ratio
      // dépendait de la largeur (cartes étirées sur grand écran) et exposait à
      // l'overflow si le contenu grandit. 172px = contenu complet d'une
      // AdminStatCard (icône 44 + valeur + label + sous-titre). Cf. convention
      // KPI = GridView.builder + mainAxisExtent.
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cross,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 172,
        ),
        itemCount: cards.length,
        itemBuilder: (_, i) => cards[i],
      );
    });
  }
}

// ─── Grille de stats générique (responsive) ───────────────────────────────────
class _StatGrid extends StatelessWidget {
  const _StatGrid(this.cards);
  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cross = (c.maxWidth > 720
              ? (cards.length < 4 ? cards.length : 4)
              : 2)
          .clamp(1, 4);
      // Hauteur fixe (mainAxisExtent) : anti-overflow, aligné sur la convention
      // KPI (jamais childAspectRatio, dépendant de la largeur).
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cross,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 172,
        ),
        itemCount: cards.length,
        itemBuilder: (_, i) => cards[i],
      );
    });
  }
}

// ─── État vide compact (1 ligne) — pour blocs secondaires sans données ────────
class _EmptyMini extends StatelessWidget {
  const _EmptyMini({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => AdminCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(icon, size: 18, color: kTextMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 13, color: kTextMuted)),
          ),
        ]),
      );
}

/// Format compact XAF (7 750 000 → « 7,8 M » ; sous-titre « FCFA »).
/// Gère les valeurs négatives (ex. solde déficitaire) : le signe est préservé et
/// la magnitude formatée comme un positif (« -7,8 M »).
String _xaf(int v) {
  if (v < 0) return '-${_xaf(-v)}';
  if (v >= 1000000) {
    final m = v / 1000000;
    return '${m.toStringAsFixed(m % 1 == 0 ? 0 : 1).replaceAll('.', ',')} M';
  }
  if (v >= 1000) return NumberFormat.decimalPattern('fr_FR').format(v);
  return '$v';
}
