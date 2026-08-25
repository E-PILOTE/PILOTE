import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/message_erreur.dart';
import '../../../core/utils/passage_bareme.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/auth_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE BARÈME DE PASSAGE — réglé par le GROUPE, appliqué par ses écoles.
//
//  Même grammaire que les frais de scolarité : le groupe définit, l'école
//  constate. Une école ne fixe pas la barre au-dessus de laquelle ses élèves
//  passent — c'est une décision de politique éducative, elle se prend une fois
//  pour tout le réseau.
//
//  ⚠️ Écrit sur `school_groups`, PAS sur `group_settings`. La première table
//  descend en entier sur les postes (`by_group`, SELECT *) ; la seconde n'est
//  pas synchronisée du tout. Un barème rangé dans `group_settings` serait donc
//  visible ici, invisible sur les postes, et les écoles continueraient de
//  délibérer à 10/20 pendant que le ministère croirait avoir changé la règle.
//  Le même piège que les barèmes de frais avant la migration 0096.
// ════════════════════════════════════════════════════════════════════════════

/// Le barème du groupe tel qu'il est en base. `null` tant qu'il charge.
final groupBaremePassageProvider =
    FutureProvider.autoDispose<BaremePassage>((ref) async {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null) return BaremePassage.officiel;
  final g = await client
      .from('school_groups')
      .select('promotion_pass_mark, promotion_deliberation_floor')
      .eq('id', groupId)
      .maybeSingle();
  final barre = (g?['promotion_pass_mark'] as num?)?.toDouble();
  if (barre == null || barre <= 0 || barre > 20) return BaremePassage.officiel;
  return BaremePassage(
    barre: barre,
    plancher: (g?['promotion_deliberation_floor'] as num?)?.toDouble(),
  );
});

Future<void> _saveBareme(
  WidgetRef ref, {
  required double barre,
  required double? plancher,
}) async {
  final client = ref.read(supabaseClientProvider);
  final groupId = ref.read(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null) return;
  await client.from('school_groups').update({
    'promotion_pass_mark': barre,
    'promotion_deliberation_floor': plancher,
    'updated_at': DateTime.now().toIso8601String(),
  }).eq('id', groupId);
  ref.invalidate(groupBaremePassageProvider);
}

/// Carte de réglage du barème de passage.
class BaremePassageCard extends ConsumerStatefulWidget {
  const BaremePassageCard({super.key});

  @override
  ConsumerState<BaremePassageCard> createState() => _BaremePassageCardState();
}

class _BaremePassageCardState extends ConsumerState<BaremePassageCard> {
  double? _barre;
  double? _plancher;
  bool _zone = false;
  bool _saving = false;
  String? _error;

  /// Le barème chargé, tant que l'utilisateur n'a rien touché.
  void _amorcer(BaremePassage b) {
    _barre ??= b.barre;
    if (!_touche) {
      _plancher = b.plancher;
      _zone = b.aZoneDeliberation;
    }
  }

  bool _touche = false;

  Future<void> _save() async {
    final barre = _barre ?? BaremePassage.officiel.barre;
    final plancher = _zone ? (_plancher ?? barre - 1.5) : null;

    // Le CHECK serveur refuse déjà un plancher au-dessus de la barre — mais un
    // refus serveur arrive après coup et n'explique rien. Le dire ici, c'est le
    // dire à temps.
    if (plancher != null && plancher >= barre) {
      setState(() => _error =
          'Le plancher doit rester sous la barre : sinon un élève à '
          '${_fmt(barre)} attendrait le conseil pendant qu\'un élève plus '
          'faible serait admis.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _saveBareme(ref, barre: barre, plancher: plancher);
      if (mounted) {
        setState(() => _touche = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Barème de passage enregistré — il s\'applique '
              'à toutes les écoles du groupe.'),
          backgroundColor: kGreen,
        ));
      }
    } catch (e) {
      if (mounted) setState(() => _error = messageErreur(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static String _fmt(double v) => v
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'[.,]$'), '')
      .replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(groupBaremePassageProvider);
    final charge = async.valueOrNull;
    if (charge != null) _amorcer(charge);
    final barre = _barre ?? BaremePassage.officiel.barre;
    final plancher = _plancher ?? (barre - 1.5).clamp(0, barre - 0.5);

    return AdminCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const AdminSectionTitle('Barème de passage',
            icon: Icons.rule_rounded,
            subtitle: 'La barre au-dessus de laquelle un élève passe en '
                'classe supérieure'),
        const SizedBox(height: 6),
        Text(
          'Ce réglage vaut pour toutes les écoles du groupe. Un niveau peut y '
          'déroger depuis la structure académique. La moyenne comparée est '
          'celle des trois trimestres, à poids égal — exactement celle qui '
          'figure sur les bulletins remis aux familles.',
          style: TextStyle(fontSize: 12.5, color: kTextMuted, height: 1.5),
        ),
        const SizedBox(height: 16),

        _NoteSlider(
          label: 'Barre de passage',
          value: barre,
          min: 5,
          max: 15,
          color: kGreen,
          aide: 'Moyenne annuelle à atteindre. Le barème officiel du METP est '
              'de 10/20.',
          onChanged: (v) => setState(() {
            _touche = true;
            _barre = v;
            if (_zone && plancher >= v) _plancher = (v - 0.5).clamp(0, 20);
          }),
        ),

        const SizedBox(height: 6),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _zone,
          activeThumbColor: kAccent,
          onChanged: (v) => setState(() {
            _touche = true;
            _zone = v;
            if (v) _plancher ??= (barre - 1.5).clamp(0, barre - 0.5);
          }),
          title: Text('Ouvrir une zone de délibération',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary)),
          subtitle: Text(
            // Ce que le réglage change VRAIMENT, en une phrase — pas ce qu'il
            // active. Un chef d'établissement doit pouvoir décider sans avoir
            // à imaginer le comportement du logiciel.
            'Entre le plancher et la barre, la plateforme ne propose aucun '
            'verdict : le conseil examine ces élèves un par un. Sans zone, la '
            'barre fait couperet et un élève à ${_fmt(barre - 0.02)} redouble '
            'sans discussion.',
            style: TextStyle(fontSize: 12, color: kTextMuted, height: 1.45),
          ),
        ),

        if (_zone) ...[
          const SizedBox(height: 8),
          _NoteSlider(
            label: 'Plancher de délibération',
            value: plancher.toDouble(),
            min: 0,
            max: (barre - 0.5).clamp(0.5, 19.5),
            color: kAccent,
            aide: 'Sous cette moyenne, le redoublement se propose sans '
                'discussion.',
            onChanged: (v) => setState(() {
              _touche = true;
              _plancher = v;
            }),
          ),
        ],

        const SizedBox(height: 14),
        _Apercu(
          bareme: BaremePassage(barre: barre, plancher: _zone ? plancher.toDouble() : null),
        ),

        if (_error != null) ...[
          const SizedBox(height: 12),
          AdminErrorBanner(message: _error!),
        ],
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          if (_touche)
            TextButton(
              onPressed: _saving
                  ? null
                  : () => setState(() {
                        _touche = false;
                        _barre = charge?.barre;
                        _plancher = charge?.plancher;
                        _zone = charge?.aZoneDeliberation ?? false;
                        _error = null;
                      }),
              child: const Text('Annuler'),
            ),
          const SizedBox(width: 8),
          // `AdminPrimaryButton.onTap` n'est pas nullable : c'est `saving` qui
          // porte l'état inactif. On garde donc l'entrée à l'intérieur — un
          // double-clic pendant l'enregistrement écrirait deux fois.
          AdminPrimaryButton(
            label: _saving ? 'Enregistrement…' : 'Enregistrer le barème',
            icon: Icons.save_rounded,
            saving: _saving || !_touche,
            onTap: () {
              if (_saving || !_touche) return;
              _save();
            },
          ),
        ]),
      ]),
    );
  }
}

/// Curseur de note sur 20, au demi-point.
///
/// Le demi-point n'est pas un détail de confort : les barèmes réels d'Afrique
/// francophone se posent à 8,5 ou 9,5, jamais à 8,37.
class _NoteSlider extends StatelessWidget {
  const _NoteSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.color,
    required this.aide,
    required this.onChanged,
  });

  final String label, aide;
  final double value, min, max;
  final Color color;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(min, max).toDouble();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Text(label,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text('${_BaremePassageCardState._fmt(v)}/20',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ),
      ]),
      Slider(
        value: v,
        min: min,
        max: max,
        // Le demi-point : (max - min) * 2 crans.
        divisions: (((max - min) * 2).round()).clamp(1, 1000),
        activeColor: color,
        label: '${_BaremePassageCardState._fmt(v)}/20',
        onChanged: onChanged,
      ),
      Text(aide, style: TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.4)),
    ]);
  }
}

/// Ce que le barème donnerait sur quelques moyennes réelles.
///
/// ── Pourquoi un aperçu ─────────────────────────────────────────────────────
/// Deux nombres abstraits décident du sort de milliers d'enfants. Les voir
/// appliqués à une poignée de moyennes rend le réglage concret AVANT
/// l'enregistrement — c'est le seul moment où l'erreur est encore gratuite.
class _Apercu extends StatelessWidget {
  const _Apercu({required this.bareme});
  final BaremePassage bareme;

  static const _echantillon = [7.0, 8.5, 9.5, 10.0, 12.0];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Ce que ce barème donnerait',
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: kTextMuted)),
        const SizedBox(height: 9),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final m in _echantillon) _Puce(moyenne: m, bareme: bareme),
        ]),
      ]),
    );
  }
}

class _Puce extends StatelessWidget {
  const _Puce({required this.moyenne, required this.bareme});
  final double moyenne;
  final BaremePassage bareme;

  @override
  Widget build(BuildContext context) {
    final (texte, couleur) = switch (propositionPour(moyenne, bareme)) {
      PropositionPassage.passe => ('passe', kGreen),
      PropositionPassage.redouble => ('redouble', kRed),
      PropositionPassage.deliberation => ('conseil', kAccent),
      PropositionPassage.sansMoyenne => ('—', kTextMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: couleur.withValues(alpha: 0.30)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(_BaremePassageCardState._fmt(moyenne),
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: kTextPrimary,
                fontFeatures: const [FontFeature.tabularFigures()])),
        const SizedBox(width: 6),
        Text('→ $texte',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: couleur)),
      ]),
    );
  }
}
