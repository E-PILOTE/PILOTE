// ════════════════════════════════════════════════════════════════════════════
//  LE PRIX SUIT LE NOMBRE D'ÉCOLES
//
//  ── LA FALAISE QU'ON A SUPPRIMÉE ───────────────────────────────────────────
//  Ancienne grille : Pro 220 000/mois jusqu'à 10 écoles, puis Institutionnel
//  2 500 000/mois. La 11ᵉ école coûtait ×11,4. Un groupe à 11 écoles n'avait
//  que trois issues : refuser, partir, ou déclarer 10 écoles.
//
//  ── LE MODÈLE ──────────────────────────────────────────────────────────────
//  Le PLAN vend des MODULES. Le NOMBRE D'ÉCOLES fait le PRIX.
//    prix = base + Σ (écoles de la tranche × tarif de la tranche)
//  Tranches : 2-5 · 6-10 · 11-20 · 21+, dégressives.
//
//  ⚠️ MIROIR EXACT de `plan_price_xaf()` (migration 0159). Toute modification
//  ici doit toucher le SQL, et réciproquement. Si les deux divergent, l'écran
//  annonce un prix que la facture contredit — et c'est le client qui découvre
//  l'écart, un mois plus tard, sur un document comptable.
//  `test/tarif_ecoles_test.dart` compare cette fonction aux valeurs de la base.
// ════════════════════════════════════════════════════════════════════════════

/// Bornes hautes des tranches. La dernière (21+) n'a pas de borne.
const kTarifTranches = <int>[5, 10, 20];

/// Tarif d'un plan pour [ecoles] écoles, dans la périodicité du plan.
///
/// [base] = prix de la PREMIÈRE école. Les quatre tarifs de tranche sont ceux
/// des colonnes `extra_school_*_xaf`.
///
/// Le plancher est à une école : un groupe qui n'en a pas encore déclaré vient
/// d'être créé, il n'est pas gratuit pour autant.
int tarifPourEcoles({
  required int base,
  required int tranche2a5,
  required int tranche6a10,
  required int tranche11a20,
  required int tranche21p,
  required int ecoles,
}) {
  final n = ecoles < 1 ? 1 : ecoles;
  int dans(int haut, int bas) {
    final v = (n < haut ? n : haut) - bas;
    return v < 0 ? 0 : v;
  }

  return base +
      dans(5, 1) * tranche2a5 +
      dans(10, 5) * tranche6a10 +
      dans(20, 10) * tranche11a20 +
      (n > 20 ? n - 20 : 0) * tranche21p;
}

/// Le tarif lu depuis une ligne `subscription_plans` déjà chargée.
///
/// Tolère les colonnes absentes (0) : une ancienne réponse en cache ne doit pas
/// faire planter un écran, elle doit afficher la base — visiblement fausse mais
/// pas destructrice.
int tarifPlanRow(Map? plan, int ecoles) {
  if (plan == null) return 0;
  int c(String k) => (plan[k] as num?)?.toInt() ?? 0;
  return tarifPourEcoles(
    base: c('price_xaf'),
    tranche2a5: c('extra_school_2_5_xaf'),
    tranche6a10: c('extra_school_6_10_xaf'),
    tranche11a20: c('extra_school_11_20_xaf'),
    tranche21p: c('extra_school_21p_xaf'),
    ecoles: ecoles,
  );
}

/// Ce que coûte UNE école de plus, à [ecoles] écoles déjà présentes.
///
/// C'est la seule question que pose vraiment un directeur de groupe au moment
/// d'ouvrir un établissement — et la réponse doit être immédiate, pas un devis.
int coutEcoleSuivante({
  required int base,
  required int tranche2a5,
  required int tranche6a10,
  required int tranche11a20,
  required int tranche21p,
  required int ecoles,
}) {
  int p(int n) => tarifPourEcoles(
        base: base,
        tranche2a5: tranche2a5,
        tranche6a10: tranche6a10,
        tranche11a20: tranche11a20,
        tranche21p: tranche21p,
        ecoles: n,
      );
  final n = ecoles < 1 ? 1 : ecoles;
  return p(n + 1) - p(n);
}
