part of '../admin_settings_screen.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  ONGLET NOTIFICATIONS
//
//  ── CE QUI A ÉTÉ RETIRÉ, ET POURQUOI (2026-09-10) ──────────────────────────
//  Cet onglet proposait VINGT réglages : trois canaux (courriel, SMS, push),
//  quatre déclencheurs, un résumé quotidien avec son heure d'envoi, trois
//  seuils d'alerte, quatre paramètres de relance de facturation et quatre
//  destinataires par rôle. Ils s'enregistraient correctement, et **rien ne les
//  lisait**.
//
//  Vérifié des DEUX côtés, comme l'exige la règle du projet :
//   · `grep -rn "<champ>" lib/` en excluant cet écran, son provider et son
//     service → **0 lecteur, pour les 20 champs** ;
//   · `pg_get_functiondef` sur les colonnes correspondantes → **0 fonction**
//     en base ne les consulte.
//
//  Un premier temps avait rendu l'écran honnête : un bandeau prévenait que les
//  choix n'étaient pas appliqués. C'était le minimum, pas la réponse. Un
//  réglage qu'un directeur de réseau coche, qui affiche « enregistré » et qui
//  ne produit rien coûte plus cher en confiance qu'il ne rapporte — et il fait
//  renoncer à chercher une vraie alerte.
//
//  ⚠️ LES DONNÉES NE SONT PAS DÉTRUITES. Les colonnes de `group_settings`
//  restent en place et gardent ce que chaque groupe avait coché : le jour où
//  l'émetteur existera, les préférences déjà exprimées seront là. On retire
//  l'OFFRE, pas la mémoire. Le modèle `NotificationSettings`, son provider et
//  son service restent donc intacts et testés.
//
//  ── CE QUI EXISTE VRAIMENT, ET QUE CET ONGLET DIT MAINTENANT ───────────────
//  Les notifications DANS l'application fonctionnent, et ne se règlent pas :
//  dix fonctions en base écrivent la table `notifications` (message reçu,
//  annonce publiée, facture émise, échéance d'abonnement, année scolaire
//  publiée, rappel aux écoles en attente…). C'est la cloche de la barre du
//  haut, et elle est fiable. L'onglet l'énonce plutôt que de laisser croire
//  qu'il faut l'activer.
// ═════════════════════════════════════════════════════════════════════════════

class _NotificationsTab extends ConsumerWidget {
  const _NotificationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _TabScaffold(
      onRefresh: () async {
        ref.invalidate(adminGroupSettingsProvider);
        await ref.read(adminGroupSettingsProvider.future);
      },
      children: const [
        _CeQuiNotifieAujourdhui(),
        SizedBox(height: 20),
        _CeQuiNexistePasEncore(),
        SizedBox(height: 24),
      ],
    );
  }
}

/// Ce que la plateforme envoie réellement — et qui n'a pas de réglage.
class _CeQuiNotifieAujourdhui extends StatelessWidget {
  const _CeQuiNotifieAujourdhui();

  /// Les déclencheurs qui écrivent vraiment dans `notifications`.
  ///
  /// Relevé en base, pas supposé : dix fonctions y insèrent. La liste dit ce
  /// qu'un administrateur de réseau voit arriver dans sa cloche.
  static const _declencheurs = <(IconData, String, String)>[
    (Icons.mail_outline_rounded, 'Message reçu',
        'Dès qu\'un message vous est adressé dans la messagerie.'),
    (Icons.campaign_outlined, 'Annonce publiée',
        'Dès qu\'une annonce paraît dans votre périmètre.'),
    (Icons.receipt_long_outlined, 'Facture émise',
        'À chaque facture de renouvellement d\'abonnement.'),
    (Icons.event_busy_outlined, 'Échéance d\'abonnement',
        'À l\'approche de la fin de l\'abonnement du groupe.'),
    (Icons.calendar_month_outlined, 'Année scolaire publiée',
        'Quand le groupe publie une année à ses établissements.'),
    (Icons.pending_actions_outlined, 'École en attente',
        'Rappel aux établissements qui n\'ont pas adopté l\'année.'),
  ];

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const AdminSectionTitle(
          'Ce qui vous notifie aujourd\'hui',
          icon: Icons.notifications_active_outlined,
          subtitle: 'Dans l\'application — aucun réglage nécessaire',
        ),
        const SizedBox(height: 4),
        Text(
          'Ces notifications arrivent dans la cloche de la barre du haut. '
          'Elles sont émises par la base de données elle-même : rien ne peut '
          'les désactiver par erreur.',
          style: TextStyle(fontSize: 12.5, height: 1.45, color: kTextMuted),
        ),
        const SizedBox(height: 14),
        for (final (icone, titre, detail) in _declencheurs)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: kGreen.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icone, size: 17, color: kGreen),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titre,
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: kTextPrimary)),
                    const SizedBox(height: 2),
                    Text(detail,
                        style: TextStyle(
                            fontSize: 12, height: 1.4, color: kTextMuted)),
                  ],
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}

/// Dit ce que la plateforme n'envoie pas — au lieu d'offrir de le régler.
class _CeQuiNexistePasEncore extends StatelessWidget {
  const _CeQuiNexistePasEncore();

  @override
  Widget build(BuildContext context) {
    const or = Color(0xFFF59E0B);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: or.withValues(alpha: 0.07),
        border: Border.all(color: or.withValues(alpha: 0.32)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.schedule_rounded, size: 19, color: or),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Courriel, SMS et notifications mobiles : pas encore',
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary)),
            const SizedBox(height: 6),
            Text(
              'La plateforme n\'envoie aujourd\'hui aucun courriel, aucun SMS '
              'et aucune notification mobile. Il n\'y a donc ni résumé '
              'quotidien, ni alerte d\'assiduité, ni relance automatique de '
              'facturation.',
              style: TextStyle(fontSize: 12.5, height: 1.45, color: kTextMuted),
            ),
            const SizedBox(height: 8),
            Text(
              'Les réglages qui permettaient de les paramétrer ont été retirés '
              'de cet écran : ils s\'enregistraient sans que rien ne les lise. '
              'Vos choix précédents sont conservés et seront repris tels quels '
              'le jour où ces canaux existeront.',
              style: TextStyle(fontSize: 12.5, height: 1.45, color: kTextMuted),
            ),
            const SizedBox(height: 10),
            Text(
              'En attendant, une relance se fait depuis Recouvrement, et une '
              'consigne depuis Annonces ou Messagerie — les deux laissent une '
              'trace, ce qu\'un envoi automatique ne ferait pas.',
              style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: kTextMuted,
                  fontStyle: FontStyle.italic),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ONGLET 4 — SÉCURITÉ  (group_settings.security)
// ═════════════════════════════════════════════════════════════════════════════
