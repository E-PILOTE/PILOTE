import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/auth_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  ÉMETTRE LA FACTURE D'UN GROUPE — la main du fondateur sur le cycle mensuel
//
//  ── POURQUOI CET ÉCRAN EXISTE ─────────────────────────────────────────────
//  Depuis 0190 la facture du mois suivant part toute seule, chaque nuit, sept
//  jours avant l'échéance. Mais une automatisation sans commande manuelle est
//  une automatisation qu'on subit : il faut pouvoir dire « celui-là, sa
//  facture, maintenant » — un client qui appelle, une école ajoutée en cours
//  de mois qui change l'assiette, une échéance qu'on vient de corriger.
//
//  Jusqu'ici le fondateur n'avait AUCUN moyen d'émettre quoi que ce soit :
//  son écran ne savait que marquer PAYÉE une facture déjà existante. Le seul
//  bouton qui en créait une était celui du client, dans son propre espace.
//
//  ── CE QUE CE GESTE N'EST PAS ─────────────────────────────────────────────
//  Il émet une SOMME DUE, jamais un encaissement. Le paiement reste un second
//  geste, explicite, dans l'écran Factures (`mark_invoice_paid`). Confondre
//  les deux ferait entrer de l'argent qui n'est pas arrivé.
//
//  ── CE QUI LE REND SANS DANGER ────────────────────────────────────────────
//  `create_renewal_invoice` refuse d'en créer une deuxième tant que la
//  précédente attend : cliquer dix fois ne produit pas dix factures, cela
//  réaffiche la même. C'est la même garantie qui rend la tâche de nuit
//  rejouable. Un ministère est refusé net — sa licence se renégocie.
// ════════════════════════════════════════════════════════════════════════════

/// Émet (ou retrouve) la facture de renouvellement du groupe, puis montre le
/// résultat. Renvoie `true` si une facture NEUVE a été créée — l'appelant
/// rafraîchit alors ses listes.
Future<bool> emettreFactureDeRenouvellement(
  BuildContext context,
  WidgetRef ref, {
  required String groupId,
  required String groupName,
}) async {
  final client = ref.read(supabaseClientProvider);
  Map<String, dynamic>? res;
  Object? erreur;

  try {
    final r = await client
        .rpc('create_renewal_invoice', params: {'p_group_id': groupId});
    res = r is Map ? Map<String, dynamic>.from(r) : <String, dynamic>{};
  } catch (e) {
    erreur = e;
  }

  if (!context.mounted) return false;

  final neuve = erreur == null && res?['already_pending'] != true;
  await showDialog<void>(
    context: context,
    builder: (_) => _ResultatDialog(
      groupName: groupName,
      resultat: res,
      erreur: erreur,
    ),
  );
  return neuve && erreur == null;
}

class _ResultatDialog extends StatelessWidget {
  const _ResultatDialog({
    required this.groupName,
    required this.resultat,
    required this.erreur,
  });

  final String groupName;
  final Map<String, dynamic>? resultat;
  final Object? erreur;

  static String _jour(Object? iso) {
    final d = DateTime.tryParse('$iso');
    if (d == null) return '$iso';
    String deux(int n) => n.toString().padLeft(2, '0');
    return '${deux(d.day)}/${deux(d.month)}/${d.year}';
  }

  /// Les messages de la base sont écrits pour un développeur. Ceux-ci sont
  /// écrits pour quelqu'un qui vend.
  String get _messageErreur {
    final brut = erreur.toString();
    if (brut.contains('ministere de tutelle')) {
      return 'Ce groupe est un ministère de tutelle : son marché se renégocie '
          "par avenant, il ne se renouvelle pas d'un clic. Passez par sa fiche "
          'de licence.';
    }
    if (brut.contains('Aucun plan')) {
      return "Aucun plan n'est attribué à ce groupe : il n'y a rien à "
          "facturer. Attribuez-lui un plan d'abord.";
    }
    if (brut.contains('Acces refuse') || brut.contains('Accès refusé')) {
      return "Vous n'êtes pas autorisé à émettre une facture pour ce groupe.";
    }
    return "L'émission a échoué. Réessayez, ou vérifiez le plan et l'échéance "
        'de ce groupe.';
  }

  @override
  Widget build(BuildContext context) {
    final r = resultat;
    final echec = erreur != null;
    final gratuit = r?['free'] == true;
    final deja = r?['already_pending'] == true;

    final couleur = echec ? kRed : (deja ? kAccent : kGreen);
    final titre = echec
        ? 'Facture non émise'
        : gratuit
            ? 'Abonnement prolongé'
            : deja
                ? 'Une facture attend déjà'
                : 'Facture émise';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: couleur.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                      echec
                          ? Icons.error_outline_rounded
                          : Icons.receipt_long_rounded,
                      color: couleur,
                      size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titre,
                          style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: kTextPrimary)),
                      Text(groupName,
                          style: TextStyle(fontSize: 12, color: kTextMuted),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 18),
              if (echec)
                Text(_messageErreur,
                    style:
                        TextStyle(fontSize: 13, color: kTextMuted, height: 1.5))
              else if (gratuit)
                Text(
                    'Ce groupe est sur un plan gratuit : il n’y a pas de '
                    'facture. Sa période court désormais jusqu’au '
                    '${_jour(r?['period_end'])}.',
                    style:
                        TextStyle(fontSize: 13, color: kTextMuted, height: 1.5))
              else ...[
                _ligne('Facture', '${r?['invoice_number'] ?? '—'}'),
                _ligne('Montant', fmtXaf((r?['amount_xaf'] as num?)?.toInt() ?? 0)),
                _ligne('Période',
                    '${_jour(r?['period_start'])} → ${_jour(r?['period_end'])}'),
                if (r?['schools'] != null)
                  _ligne('Assiette', '${r?['schools']} école(s)'),
                const SizedBox(height: 12),
                Text(
                    deja
                        ? 'Elle était déjà en attente : aucune seconde facture '
                            'n’a été créée. Le règlement s’enregistre depuis '
                            'l’écran Factures.'
                        : 'Le groupe est notifié. Le règlement s’enregistre '
                            'depuis l’écran Factures — émettre n’encaisse pas.',
                    style: TextStyle(
                        fontSize: 12.5, color: kTextMuted, height: 1.5)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: kNavy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text('Compris'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ligne(String label, String valeur) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(
            width: 92,
            child:
                Text(label, style: TextStyle(fontSize: 12.5, color: kTextMuted)),
          ),
          Expanded(
            child: Text(valeur,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary)),
          ),
        ]),
      );
}
