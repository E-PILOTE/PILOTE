import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/message_erreur.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/pdf_preview_dialog.dart';
import '../providers/tutelle_reseau_provider.dart';
import '../services/tutelle_fiche_pdf_service.dart';

// ════════════════════════════════════════════════════════════════════════════
//  FICHE D'ÉTABLISSEMENT — ce que la tutelle sait d'une école de son réseau
//
//  ── POURQUOI CETTE FICHE EXISTE ───────────────────────────────────────────
//  La RPC `tutelle_ecoles` (migration 0158) rend depuis le premier jour le
//  chef d'établissement, le téléphone, le courriel, les coordonnées et la
//  capacité. La liste n'en affichait AUCUN : la donnée traversait le réseau
//  pour être jetée à l'arrivée.
//
//  Le cas du chef d'établissement est le plus net. C'est la SEULE donnée
//  nominative que 0158 laisse sortir, et elle est justifiée en toutes lettres :
//  « l'interlocuteur officiel de la tutelle ; un ministère qui ne sait pas qui
//  dirige une école de son réseau ne peut ni la convoquer ni lui écrire ». On
//  payait le risque de la donnée sans en tirer l'usage.
//
//  ── ⚠️ CE QUE CETTE FICHE N'AURA JAMAIS ──────────────────────────────────
//  Aucun élève, aucune note, aucune absence, aucun paiement, aucun abonnement.
//  Ce n'est pas une limite d'affichage : la RPC ne les rend pas. Toute demande
//  d'ajout ici commence par une modification de 0158 — et par la question de
//  savoir si un ministère a besoin de tenir le registre nominatif du pays.
// ════════════════════════════════════════════════════════════════════════════

/// Ouvre la fiche de [e] en panneau latéral.
Future<void> ouvrirFicheEcole(
  BuildContext context,
  TutelleEcole e, {
  String? tutelle,
}) =>
    showAdminSidePanel(
      context,
      builder: (_) => TutelleEcoleDetail(ecole: e, tutelle: tutelle),
    );

class TutelleEcoleDetail extends StatelessWidget {
  const TutelleEcoleDetail({super.key, required this.ecole, this.tutelle});

  final TutelleEcole ecole;
  final String? tutelle;

  @override
  Widget build(BuildContext context) {
    final e = ecole;
    final couleur = e.estPublic ? kNavy : kAccent;
    return AdminSidePanel(
      icon: Icons.account_balance_rounded,
      title: e.nom,
      subtitle: [
        e.groupeNom,
        if (e.typeEtablissementCourt != null) e.typeEtablissementCourt!,
      ].join(' · '),
      accent: couleur,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            AdminBadge(e.estPublic ? 'Public' : 'Privé', color: couleur),
            if (!e.actif)
              AdminBadge('Inactif', color: kRed, icon: Icons.pause_rounded),
            if (e.aDeclareUnAgrement)
              AdminBadge(
                e.agrementType == 'definitif'
                    ? 'Agrément définitif'
                    : 'Agrément provisoire',
                color: e.agrementType == 'definitif' ? kGreen : kAccent,
                icon: Icons.verified_outlined,
              ),
          ]),
          const SizedBox(height: 18),

          // ── La direction en premier : c'est la raison d'être de la fiche ──
          const AdminModalSectionTitle('Direction et contacts'),
          const SizedBox(height: 8),
          AdminDetailCard([
            AdminDetailRow(Icons.person_rounded, 'Chef d’établissement',
                _ou(e.chefEtablissement, 'Non désigné'),
                valueColor: e.chefEtablissement == null ? kTextMuted : null),
            AdminDetailRow(
                Icons.phone_rounded, 'Téléphone', _ou(e.telephone, '—')),
            AdminDetailRow(Icons.mail_outline_rounded, 'Courriel',
                _ou(e.courriel, '—'),
                last: true),
          ]),
          const SizedBox(height: 18),

          const AdminModalSectionTitle('Effectifs'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: AdminMetaChip(
                    icon: Icons.groups_rounded,
                    label: '${fmtInt(e.nbEleves)}\nélèves',
                    color: kGreen)),
            const SizedBox(width: 8),
            Expanded(
                child: AdminMetaChip(
                    icon: Icons.badge_rounded,
                    label: '${fmtInt(e.nbPersonnel)}\npersonnel',
                    color: const Color(0xFF0EA5E9))),
            const SizedBox(width: 8),
            Expanded(
                child: AdminMetaChip(
                    icon: Icons.meeting_room_rounded,
                    label: '${fmtInt(e.nbClasses)}\nclasses',
                    color: kNavy)),
          ]),
          const SizedBox(height: 10),
          AdminDetailCard([
            AdminDetailRow(Icons.female_rounded, 'Filles', _filles(e)),
            AdminDetailRow(Icons.male_rounded, 'Garçons',
                fmtInt(e.nbEleves - e.nbFilles)),
            AdminDetailRow(Icons.event_seat_rounded, 'Capacité d’accueil',
                e.capacite == null ? 'Non renseignée' : fmtInt(e.capacite!),
                valueColor: e.capacite == null ? kTextMuted : null),
            AdminDetailRow(
              Icons.speed_rounded,
              'Taux d’occupation',
              e.occupation == null
                  ? 'Incalculable'
                  : '${(e.occupation! * 100).round()} %',
              // ⚠️ Jamais « 0 % » faute de capacité : un taux absent n'est pas
              // une école vide. Cf. `TutelleEcole.occupation`.
              valueColor: e.occupation == null
                  ? kTextMuted
                  : (e.occupation! > 1 ? kRed : null),
              last: true,
            ),
          ]),
          const SizedBox(height: 18),

          const AdminModalSectionTitle('Implantation'),
          const SizedBox(height: 8),
          AdminDetailCard([
            AdminDetailRow(
                Icons.map_rounded, 'Département', _ou(e.departement, '—')),
            AdminDetailRow(
                Icons.location_city_rounded, 'Ville', _ou(e.ville, '—')),
            AdminDetailRow(Icons.signpost_rounded, 'Arrondissement',
                _ou(e.arrondissement, '—')),
            AdminDetailRow(Icons.my_location_rounded, 'Coordonnées',
                _coordonnees(e),
                mono: e.latitude != null,
                valueColor: e.latitude == null ? kTextMuted : null,
                last: true),
          ]),
          const SizedBox(height: 18),

          const AdminModalSectionTitle('Agrément'),
          const SizedBox(height: 8),
          AdminDetailCard([
            AdminDetailRow(Icons.tag_rounded, 'Numéro',
                _ou(e.agrementNumero, 'Non déclaré'),
                mono: e.aDeclareUnAgrement,
                valueColor: e.aDeclareUnAgrement ? null : kTextMuted),
            AdminDetailRow(Icons.workspace_premium_outlined, 'Type',
                _typeAgrement(e.agrementType)),
            AdminDetailRow(Icons.event_rounded, 'Date',
                e.agrementDate == null
                    ? '—'
                    : DateFormat('dd MMMM yyyy', 'fr').format(e.agrementDate!),
                last: true),
          ]),
          // ⚠️ « Non déclaré » n'est pas « non agréé ». La plateforme
          // n'instruit aucun dossier : elle n'affiche que ce qu'on lui a saisi.
          if (!e.aDeclareUnAgrement) ...[
            const SizedBox(height: 8),
            const _Note(
              'Aucun numéro saisi. Ce n’est pas un défaut d’agrément : '
              'E-PILOTE enregistre une mention administrative, il n’instruit '
              'aucun dossier.',
            ),
          ],
          const SizedBox(height: 18),

          const AdminModalSectionTitle('Identité administrative'),
          const SizedBox(height: 8),
          AdminDetailCard([
            AdminDetailRow(Icons.qr_code_2_rounded, 'Code établissement',
                _ou(e.code, '—'),
                mono: e.code != null),
            AdminDetailRow(Icons.school_rounded, 'Type',
                _ou(e.typeEtablissement, '—')),
            AdminDetailRow(Icons.corporate_fare_rounded, 'Groupe scolaire',
                e.groupeNom),
            AdminDetailRow(Icons.history_edu_rounded, 'Année de création',
                e.anneeCreation?.toString() ?? '—',
                last: true),
          ]),
          const SizedBox(height: 14),
          const _Note(
            'Effectifs agrégés au jour de consultation. Aucun nom d’élève, '
            'aucune note, aucune absence, aucun paiement ne transite par cette '
            'fiche — la supervision n’est pas la gestion.',
          ),
          const SizedBox(height: 10),
        ],
      ),
      footer: Row(children: [
        Expanded(
          child: AdminPrimaryButton(
            label: 'Fiche d’établissement (PDF)',
            icon: Icons.picture_as_pdf_outlined,
            color: couleur,
            onTap: () => _exporter(context),
          ),
        ),
      ]),
    );
  }

  Future<void> _exporter(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Construit UNE FOIS : les mêmes octets servent à l'aperçu et au fichier
      // déposé, donc la référence lue à l'écran est celle du document remis.
      final octets = await TutelleFichePdfService.buildEcole(
        ecole: ecole,
        tutelle: tutelle,
      );
      if (!context.mounted) return;
      await showPdfPreviewDialog(
        context,
        title: 'Fiche d’établissement',
        subtitle: '${ecole.nom} · ${ecole.groupeNom}',
        pdfFileName: 'Fiche_etablissement.pdf',
        accent: ecole.estPublic ? kNavy : kAccent,
        build: (_) async => octets,
        onDownload: () => TutelleFichePdfService.enregistrerEcole(
            ecole: ecole, tutelle: tutelle, bytes: octets),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(messageErreur(e, contexte: 'Fiche d’établissement')),
        backgroundColor: kRed,
      ));
    }
  }
}

String _ou(String? v, String defaut) =>
    (v ?? '').trim().isEmpty ? defaut : v!.trim();

String _filles(TutelleEcole e) => e.nbEleves == 0
    ? '—'
    : '${fmtInt(e.nbFilles)}  ·  ${(e.nbFilles * 100 / e.nbEleves).round()} %';

String _coordonnees(TutelleEcole e) => (e.latitude == null || e.longitude == null)
    ? 'Non géolocalisée'
    : '${e.latitude!.toStringAsFixed(5)}, ${e.longitude!.toStringAsFixed(5)}';

String _typeAgrement(String? t) => switch (t) {
      'definitif' => 'Définitif',
      'provisoire' => 'Provisoire',
      _ => '—',
    };

/// Encart d'avertissement sobre — la nuance qu'une fiche officielle doit porter.
class _Note extends StatelessWidget {
  const _Note(this.texte);
  final String texte;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: kBorder),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline_rounded, size: 15, color: kTextMuted),
          const SizedBox(width: 9),
          Expanded(
            child: Text(texte,
                style:
                    TextStyle(fontSize: 11, color: kTextMuted, height: 1.45)),
          ),
        ]),
      );
}
