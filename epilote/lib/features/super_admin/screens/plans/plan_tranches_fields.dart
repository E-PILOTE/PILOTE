part of '../plans_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LES TRANCHES — ET LA SIMULATION QUI VA AVEC
//
//  ── POURQUOI UNE SIMULATION DANS UN FORMULAIRE ────────────────────────────
//  Quatre nombres saisis à la main décident du prix de tous les clients d'un
//  plan. Une erreur de saisie ne lève rien : elle facture. Le tableau ci-
//  dessous recalcule la grille À CHAQUE FRAPPE, aux mêmes paliers que ceux
//  vérifiés en base (migration 0159) — c'est le seul moment où l'erreur est
//  encore gratuite.
//
//  ⚠️ Le calcul passe par `tarifPourEcoles`, le miroir Dart de
//  `plan_price_xaf()`. Refaire l'addition ici « pour aller plus vite » ferait
//  du formulaire une troisième source de vérité.
// ════════════════════════════════════════════════════════════════════════════

class _TranchesEcoles extends StatelessWidget {
  const _TranchesEcoles({
    required this.base,
    required this.period,
    required this.t2a5,
    required this.t6a10,
    required this.t11a20,
    required this.t21p,
    required this.onChanged,
  });

  final int base;
  final String period;
  final TextEditingController t2a5, t6a10, t11a20, t21p;
  final VoidCallback onChanged;

  static int _n(TextEditingController c) =>
      int.tryParse(c.text.trim().replaceAll(' ', '')) ?? 0;

  int _prix(int ecoles) => tarifPourEcoles(
        base: base,
        tranche2a5: _n(t2a5),
        tranche6a10: _n(t6a10),
        tranche11a20: _n(t11a20),
        tranche21p: _n(t21p),
        ecoles: ecoles,
      );

  @override
  Widget build(BuildContext context) {
    final suffixe = billingPeriodSuffix(period);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionTitle('Prix par école supplémentaire'),
      const SizedBox(height: 6),
      Text(
        'Le tarif ci-dessus couvre la PREMIÈRE école. Chaque école suivante '
        'est facturée selon sa tranche — dégressive, pour qu\'un réseau qui '
        'grandit ne rencontre jamais de mur. Laisser à 0 pour un plan qui ne '
        'facture pas à l\'école.',
        style: TextStyle(fontSize: 11, color: _kMuted, height: 1.45),
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _FormField(
          controller: t2a5,
          label: 'Écoles 2 à 5',
          icon: Icons.filter_2_rounded,
          keyboardType: TextInputType.number,
          hint: 'FCFA / école',
          onChanged: (_) => onChanged(),
        )),
        const SizedBox(width: 12),
        Expanded(child: _FormField(
          controller: t6a10,
          label: 'Écoles 6 à 10',
          icon: Icons.filter_6_rounded,
          keyboardType: TextInputType.number,
          hint: 'FCFA / école',
          onChanged: (_) => onChanged(),
        )),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _FormField(
          controller: t11a20,
          label: 'Écoles 11 à 20',
          icon: Icons.filter_9_plus_rounded,
          keyboardType: TextInputType.number,
          hint: 'FCFA / école',
          onChanged: (_) => onChanged(),
        )),
        const SizedBox(width: 12),
        Expanded(child: _FormField(
          controller: t21p,
          label: 'Écoles 21 et +',
          icon: Icons.all_inclusive_rounded,
          keyboardType: TextInputType.number,
          hint: 'FCFA / école',
          onChanged: (_) => onChanged(),
        )),
      ]),
      const SizedBox(height: 12),
      _SimulationGrille(prix: _prix, suffixe: suffixe),
    ]);
  }
}

/// Ce que paiera réellement un groupe, palier par palier.
class _SimulationGrille extends StatelessWidget {
  const _SimulationGrille({required this.prix, required this.suffixe});

  final int Function(int) prix;
  final String suffixe;

  static const _paliers = [1, 2, 5, 10, 20, 50];

  @override
  Widget build(BuildContext context) {
    // Détection de falaise : un palier qui coûte d'un coup plus que le premier
    // saut est le défaut exact qu'on vient de supprimer de la grille.
    final saut2 = prix(2) - prix(1);
    var falaise = false;
    for (var n = 2; n <= 50 && !falaise; n++) {
      if (saut2 > 0 && prix(n) - prix(n - 1) > saut2) falaise = true;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _kSurface,
        border: Border.all(color: falaise ? _kOrange : _kBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.calculate_rounded, size: 14, color: _kMuted),
          const SizedBox(width: 6),
          Text('CE QUE PAIERA LE CLIENT',
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w800,
                  letterSpacing: .6, color: _kMuted)),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 18, runSpacing: 10, children: [
          for (final n in _paliers)
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$n école${n > 1 ? 's' : ''}',
                  style: TextStyle(fontSize: 10, color: _kMuted)),
              const SizedBox(height: 2),
              Text('${fmtXaf(prix(n))} / $suffixe',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: _kText)),
            ]),
        ]),
        if (falaise) ...[
          const SizedBox(height: 10),
          const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.warning_amber_rounded, size: 14, color: _kOrange),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Une tranche coûte plus cher que la précédente : le client qui '
                'grandit franchira un mur. C\'est le défaut qu\'avait l\'ancienne '
                'grille — il se contourne en déclarant moins d\'écoles.',
                style: TextStyle(fontSize: 11, color: _kOrange, height: 1.4),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}
