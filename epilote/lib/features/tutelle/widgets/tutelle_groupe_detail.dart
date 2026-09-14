import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/message_erreur.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/pdf_preview_dialog.dart';
import '../providers/tutelle_filtres.dart';
import '../providers/tutelle_reseau_provider.dart';
import '../services/tutelle_fiche_pdf_service.dart';
import 'tutelle_ecole_detail.dart';

// ════════════════════════════════════════════════════════════════════════════
//  FICHE DE GROUPE SCOLAIRE — le dossier d'un opérateur du réseau
//
//  ── LA QUESTION ───────────────────────────────────────────────────────────
//  « Qui est ce groupe privé que j'agrée, combien d'établissements tient-il,
//  qui joindre ? » Pour un ministère, un groupe privé est une PERSONNE MORALE
//  agréée, pas une ligne de tableau : il la convoque, lui écrit, lui demande
//  des comptes. Il lui faut donc une fiche, et une fiche imprimable.
//
//  ── ⚠️ DEUX NIVEAUX DE CHIFFRES, ET ILS NE SE CONFONDENT PAS ─────────────
//  La carte affiche le bilan de la SÉLECTION (les écoles retenues par les
//  filtres de la page) ET le total du groupe sous tutelle, rendu par la RPC.
//  Confondre les deux, c'est annoncer « 2 écoles » pour un groupe qui en tient
//  cinq parce qu'un filtre de département était resté actif. Les deux nombres
//  sont donc montrés côte à côte, nommés, et jamais l'un à la place de l'autre.
// ════════════════════════════════════════════════════════════════════════════

/// Ouvre la fiche du groupe [g] en feuille montante.
///
/// [ecoles] : les écoles de ce groupe RETENUES par les filtres de la page.
Future<void> ouvrirFicheGroupe(
  BuildContext context,
  TutelleGroupe g, {
  required List<TutelleEcole> ecoles,
  String? tutelle,
  VoidCallback? onVoirDansLaListe,
  VoidCallback? onEcrire,
}) =>
    showAdminBottomModal(
      context,
      builder: (_) => TutelleGroupeDetail(
        groupe: g,
        ecoles: ecoles,
        tutelle: tutelle,
        onVoirDansLaListe: onVoirDansLaListe,
        onEcrire: onEcrire,
      ),
    );

class TutelleGroupeDetail extends StatelessWidget {
  const TutelleGroupeDetail({
    super.key,
    required this.groupe,
    required this.ecoles,
    this.tutelle,
    this.onVoirDansLaListe,
    this.onEcrire,
  });

  final TutelleGroupe groupe;
  final List<TutelleEcole> ecoles;
  final String? tutelle;
  final VoidCallback? onVoirDansLaListe;

  /// ⚠️ La seule action d'écriture d'une tutelle sur un groupe tiers : lui
  /// adresser une circulaire. `groups_select` lui interdit jusqu'à la LECTURE
  /// directe de la ligne `school_groups` d'un autre groupe — tout ce que cette
  /// fiche affiche vient des RPC `SECURITY DEFINER` de 0158.
  final VoidCallback? onEcrire;

  @override
  Widget build(BuildContext context) {
    final g = groupe;
    final couleur = g.estPublic ? kNavy : kAccent;
    final bilan = BilanReseau.de(ecoles);
    final partiel = ecoles.length != g.nbEcoles;

    return AdminBottomModal(
      icon: g.estPublic
          ? Icons.account_balance_rounded
          : Icons.business_rounded,
      title: g.nom,
      subtitle: [
        g.estPublic ? 'Groupe public' : 'Groupe privé',
        if (g.departement != null) g.departement!,
        if (!g.actif) 'inactif',
      ].join(' · '),
      accent: couleur,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            AdminBadge(g.estPublic ? 'Public' : 'Privé', color: couleur),
            if (g.aDeclareUnAgrement)
              AdminBadge(
                g.agrementType == 'definitif'
                    ? 'Agrément définitif'
                    : 'Agrément provisoire',
                color: g.agrementType == 'definitif' ? kGreen : kAccent,
                icon: Icons.verified_outlined,
              )
            else
              AdminBadge('Agrément non déclaré',
                  color: kTextMuted, icon: Icons.help_outline_rounded),
            if (!g.actif) AdminBadge('Groupe inactif', color: kRed),
          ]),
          const SizedBox(height: 16),

          // ── Le double compte, dit explicitement ──────────────────────────
          if (partiel) ...[
            _Bandeau(
              couleur: kAccent,
              icone: Icons.filter_alt_rounded,
              texte: 'Vue filtrée : ${ecoles.length} établissement'
                  '${ecoles.length > 1 ? 's' : ''} affiché'
                  '${ecoles.length > 1 ? 's' : ''} sur les '
                  '${g.nbEcoles} que ce groupe tient sous votre tutelle. '
                  'Les totaux ci-dessous portent sur la sélection.',
            ),
            const SizedBox(height: 12),
          ],
          Row(children: [
            Expanded(
                child: _Chiffre('Établissements', fmtInt(bilan.nbEcoles),
                    'sur ${fmtInt(g.nbEcoles)} sous tutelle', couleur)),
            const SizedBox(width: 10),
            Expanded(
                child: _Chiffre('Élèves', fmtInt(bilan.nbEleves),
                    _partFilles(bilan), kGreen)),
            const SizedBox(width: 10),
            Expanded(
                child: _Chiffre('Personnel', fmtInt(bilan.nbPersonnel),
                    '${fmtInt(bilan.nbClasses)} classes',
                    const Color(0xFF0EA5E9))),
            const SizedBox(width: 10),
            Expanded(
                child: _Chiffre(
                    'Agrément',
                    '${fmtInt(bilan.nbAgrementDeclare)} / '
                        '${fmtInt(bilan.nbEcoles)}',
                    'écoles ayant saisi un numéro',
                    const Color(0xFF7C3AED))),
          ]),
          const SizedBox(height: 18),

          const AdminModalSectionTitle('Le groupe'),
          const SizedBox(height: 8),
          AdminDetailCard([
            AdminDetailRow(Icons.mail_outline_rounded, 'Courriel',
                _ou(g.email, '—')),
            AdminDetailRow(
                Icons.phone_rounded, 'Téléphone', _ou(g.telephone, '—')),
            AdminDetailRow(
                Icons.map_rounded, 'Département', _ou(g.departement, '—')),
            AdminDetailRow(Icons.history_edu_rounded, 'Année de création',
                g.anneeCreation?.toString() ?? '—'),
            AdminDetailRow(Icons.tag_rounded, 'Numéro d’agrément',
                _ou(g.agrementNumero, 'Non déclaré'),
                mono: g.aDeclareUnAgrement,
                valueColor: g.aDeclareUnAgrement ? null : kTextMuted),
            AdminDetailRow(Icons.event_rounded, 'Date d’agrément',
                g.agrementDate == null
                    ? '—'
                    : DateFormat('dd MMMM yyyy', 'fr').format(g.agrementDate!),
                last: true),
          ]),
          const SizedBox(height: 18),

          AdminModalSectionTitle(
              'Ses établissements (${ecoles.length})'),
          const SizedBox(height: 8),
          if (ecoles.isEmpty)
            _Bandeau(
              couleur: kTextMuted,
              icone: Icons.search_off_rounded,
              texte: 'Aucun établissement de ce groupe ne passe les filtres '
                  'actuels de la page.',
            )
          else
            AdminCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (var i = 0; i < ecoles.length; i++)
                  _LigneEcoleGroupe(
                    e: ecoles[i],
                    derniere: i == ecoles.length - 1,
                    onTap: () =>
                        ouvrirFicheEcole(context, ecoles[i], tutelle: tutelle),
                  ),
              ]),
            ),
        ],
      ),
      footer: Row(children: [
        if (onVoirDansLaListe != null)
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              onVoirDansLaListe!();
            },
            icon: const Icon(Icons.list_alt_rounded, size: 16),
            label: const Text('Filtrer la page sur ce groupe'),
            style: TextButton.styleFrom(foregroundColor: kNavy),
          ),
        const Spacer(),
        if (onEcrire != null) ...[
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              onEcrire!();
            },
            icon: const Icon(Icons.mark_as_unread_outlined, size: 16),
            label: const Text('Écrire une circulaire'),
            style: TextButton.styleFrom(foregroundColor: couleur),
          ),
          const SizedBox(width: 8),
        ],
        AdminPrimaryButton(
          label: 'Fiche de groupe (PDF)',
          icon: Icons.picture_as_pdf_outlined,
          color: couleur,
          onTap: () => _exporter(context, bilan),
        ),
      ]),
    );
  }

  Future<void> _exporter(BuildContext context, BilanReseau bilan) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final octets = await TutelleFichePdfService.buildGroupe(
        groupe: groupe,
        ecoles: ecoles,
        bilan: bilan,
        tutelle: tutelle,
      );
      if (!context.mounted) return;
      await showPdfPreviewDialog(
        context,
        title: 'Fiche de groupe scolaire',
        subtitle: '${groupe.nom} · ${ecoles.length} établissement(s)',
        pdfFileName: 'Fiche_groupe.pdf',
        accent: groupe.estPublic ? kNavy : kAccent,
        build: (_) async => octets,
        onDownload: () => TutelleFichePdfService.enregistrerGroupe(
          groupe: groupe,
          ecoles: ecoles,
          bilan: bilan,
          tutelle: tutelle,
          bytes: octets,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(messageErreur(e, contexte: 'Fiche de groupe')),
        backgroundColor: kRed,
      ));
    }
  }
}

// ─── Pièces ──────────────────────────────────────────────────────────────────

class _LigneEcoleGroupe extends StatelessWidget {
  const _LigneEcoleGroupe({
    required this.e,
    required this.derniere,
    required this.onTap,
  });

  final TutelleEcole e;
  final bool derniere;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
          decoration: BoxDecoration(
            border: derniere
                ? null
                : Border(
                    bottom: BorderSide(color: kBorder.withValues(alpha: 0.6))),
          ),
          child: Row(children: [
            Expanded(
                flex: 5,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.nom,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: kTextPrimary)),
                      Text(
                        [
                          if (e.typeEtablissementCourt != null)
                            e.typeEtablissementCourt!,
                          if (e.ville != null) e.ville!,
                          if (!e.actif) 'inactif',
                        ].join(' · '),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10.5, color: kTextMuted),
                      ),
                    ])),
            Expanded(
                flex: 3,
                child: Text(_ou(e.chefEtablissement, 'Chef non désigné'),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11.5,
                        color: e.chefEtablissement == null
                            ? kTextMuted
                            : kTextPrimary))),
            Expanded(
                flex: 2,
                child: Text('${fmtInt(e.nbEleves)} él.',
                    style: TextStyle(fontSize: 12, color: kTextPrimary))),
            Icon(Icons.chevron_right_rounded, size: 18, color: kTextMuted),
          ]),
        ),
      );
}

class _Chiffre extends StatelessWidget {
  const _Chiffre(this.label, this.valeur, this.sous, this.couleur);
  final String label, valeur, sous;
  final Color couleur;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: couleur.withValues(alpha: 0.18)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(valeur,
              maxLines: 1,
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800, color: couleur)),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 1,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary)),
          Text(sous,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: kTextMuted, height: 1.3)),
        ]),
      );
}

class _Bandeau extends StatelessWidget {
  const _Bandeau({
    required this.couleur,
    required this.icone,
    required this.texte,
  });
  final Color couleur;
  final IconData icone;
  final String texte;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: couleur.withValues(alpha: 0.22)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icone, size: 16, color: couleur),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texte,
                style: TextStyle(
                    fontSize: 11.5, color: kTextPrimary, height: 1.45)),
          ),
        ]),
      );
}

String _ou(String? v, String defaut) =>
    (v ?? '').trim().isEmpty ? defaut : v!.trim();

String _partFilles(BilanReseau b) =>
    b.partFilles == null ? 'aucun effectif' : '${b.partFilles!.round()} % de filles';
