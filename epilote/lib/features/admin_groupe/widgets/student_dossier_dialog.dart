import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/pdf_preview_dialog.dart';
import '../providers/admin_dashboard_provider.dart';
import '../providers/student_dossier_provider.dart';
import '../services/student_dossier_pdf_service.dart';
import 'student_avatar.dart';
import 'student_dossier_sections.dart';

// ════════════════════════════════════════════════════════════════════════════
//  DOSSIER DE L'ÉLÈVE — fiche complète, consultable depuis l'espace ministère.
//
//  Six blocs : identité · inscription · famille · équipe enseignante ·
//  établissement de rattachement · conduite. Imprimable et téléchargeable :
//  un cabinet qui traite un cas doit pouvoir emporter la pièce.
//
//  LECTURE SEULE, toujours. Le ministère consulte ; l'école saisit. Aucune
//  action d'écriture n'est offerte ici, y compris par mégarde.
// ════════════════════════════════════════════════════════════════════════════
Future<void> showStudentDossierDialog(BuildContext context, String studentId) {
  return showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => _DossierDialog(studentId: studentId),
  );
}

class _DossierDialog extends ConsumerWidget {
  const _DossierDialog({required this.studentId});
  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(studentDossierProvider(studentId));

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Container(
        width: 720,
        constraints: const BoxConstraints(maxHeight: 720),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: async.when(
          loading: () => const SizedBox(
            height: 260,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
          ),
          error: (e, _) => _ErrorBody(message: '$e'),
          data: (d) => _Body(dossier: d),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.dossier});
  final StudentDossier dossier;

  void _openPdf(BuildContext context, WidgetRef ref) {
    final groupName = ref.read(adminDashboardProvider).valueOrNull?.groupName ??
        'Groupe scolaire';
    showPdfPreviewDialog(
      context,
      title: 'Dossier de l\'élève',
      subtitle: dossier.fullName,
      pdfFileName: 'dossier_eleve.pdf',
      build: (_) => StudentDossierPdfService.buildPdf(
          groupName: groupName, d: dossier),
      onDownload: () => StudentDossierPdfService.download(
          groupName: groupName, d: dossier),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = dossier;
    final e = d.enrollment;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      // ─ En-tête ────────────────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          border: Border(bottom: BorderSide(color: kBorder)),
        ),
        child: Row(children: [
          StudentAvatar(
            name: d.fullName,
            photoUrl: d.photoUrl,
            gender: d.gender,
            radius: 30,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: kTextPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(
                  [
                    if (e.className != null) e.className!,
                    if (e.filiere != null) e.filiere!,
                    d.school.name,
                  ].join('  ·  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: kTextMuted, fontSize: 12),
                ),
                const SizedBox(height: 7),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  AdminBadge(d.isActive ? 'Actif' : 'Inactif',
                      color: d.isActive ? kGreen : kTextMuted,
                      icon: d.isActive
                          ? Icons.check_circle
                          : Icons.pause_circle_outline),
                  if (d.hasScholarship)
                    AdminBadge('Boursier',
                        color: kGreen, icon: Icons.school_rounded),
                  if (d.isBoarder)
                    AdminBadge('Interne',
                        color: kNavy, icon: Icons.night_shelter_rounded),
                  if (e.isRepeating)
                    const AdminBadge('Redoublant',
                        color: Color(0xFFF59E0B), icon: Icons.replay_rounded),
                  if (e.className == null)
                    AdminBadge('Sans classe',
                        color: kRed, icon: Icons.help_outline_rounded),
                  if (d.incidents.isNotEmpty)
                    AdminBadge(
                        '${d.incidents.length} fait${d.incidents.length > 1 ? 's' : ''} de conduite',
                        color: kRed,
                        icon: Icons.gavel_rounded),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 10),
          AdminPdfButton(
            label: 'Imprimer',
            onTap: () => _openPdf(context, ref),
          ),
          const SizedBox(width: 8),
          AdminModalIconBtn(
            icon: Icons.close_rounded,
            color: kTextMuted,
            tooltip: 'Fermer',
            onTap: () => Navigator.of(context).pop(),
          ),
        ]),
      ),
      // ─ Corps ──────────────────────────────────────────────────────────────
      Flexible(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DossierSection(
                title: 'Identité',
                icon: Icons.badge_outlined,
                child: AdminDetailCard([
                  AdminDetailRow(Icons.badge_outlined, 'Matricule',
                      d.matricule ?? '—',
                      mono: d.matricule != null),
                  AdminDetailRow(
                      Icons.wc_rounded,
                      'Sexe',
                      switch (d.gender) {
                        'F' => 'Féminin',
                        'M' => 'Masculin',
                        _ => '—'
                      }),
                  AdminDetailRow(Icons.cake_outlined, 'Naissance',
                      '${fmtDate(d.dateOfBirth)}${d.placeOfBirth == null ? '' : ' à ${d.placeOfBirth}'}'),
                  AdminDetailRow(Icons.hourglass_bottom_rounded, 'Âge',
                      d.age == null ? '—' : '${d.age} ans'),
                  AdminDetailRow(Icons.flag_outlined, 'Nationalité',
                      d.nationality ?? '—'),
                  AdminDetailRow(Icons.home_outlined, 'Domicile',
                      joinPlace([d.address, d.city]),
                      last: true),
                ]),
              ),
              DossierSection(
                title: 'Inscription',
                icon: Icons.how_to_reg_outlined,
                child: e.isEmpty
                    ? const DossierEmpty(
                        'Aucune inscription pour l\'année scolaire en cours. '
                        'L\'élève est enregistré mais n\'est affecté à aucune classe.')
                    : AdminDetailCard([
                        AdminDetailRow(Icons.class_outlined, 'Classe',
                            e.className ?? '—'),
                        AdminDetailRow(Icons.layers_outlined, 'Cycle · niveau',
                            '${cycleLabel(e.cycleCode)}${e.levelCode == null ? '' : ' · ${e.levelCode}'}'),
                        AdminDetailRow(Icons.engineering_outlined, 'Filière',
                            e.filiere ?? '—'),
                        AdminDetailRow(Icons.event_available_outlined,
                            'Date d\'inscription', fmtDate(e.enrollmentDate)),
                        AdminDetailRow(Icons.category_outlined, 'Type',
                            inscriptionTypeLabel(e.inscriptionType)),
                        AdminDetailRow(Icons.verified_outlined, 'Statut',
                            enrollmentStatusLabel(e.status)),
                        AdminDetailRow(Icons.replay_rounded, 'Redoublement',
                            e.isRepeating ? 'Oui' : 'Non'),
                        AdminDetailRow(
                            Icons.history_edu_outlined,
                            'Établissement précédent',
                            e.previousSchool ?? '—',
                            last: true),
                      ]),
              ),
              DossierSection(
                title: 'Famille · responsables légaux',
                icon: Icons.family_restroom_rounded,
                child: d.tutors.isEmpty
                    ? const DossierEmpty(
                        'Aucun responsable légal enregistré pour cet élève.')
                    : Column(
                        children: [
                          for (final t in d.tutors) TutorCard(tutor: t),
                        ],
                      ),
              ),
              DossierSection(
                title: 'Équipe enseignante',
                icon: Icons.co_present_rounded,
                child: d.teachers.isEmpty
                    ? const DossierEmpty(
                        'Aucun enseignant affecté aux matières de cette classe.')
                    : Container(
                        decoration: BoxDecoration(
                          color: kCardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: kBorder),
                        ),
                        child: Column(children: [
                          for (var i = 0; i < d.teachers.length; i++)
                            TeacherRow(
                                teacher: d.teachers[i],
                                last: i == d.teachers.length - 1),
                        ]),
                      ),
              ),
              DossierSection(
                title: 'Établissement de rattachement',
                icon: Icons.account_balance_rounded,
                child: AdminDetailCard([
                  AdminDetailRow(
                      Icons.account_balance_rounded, 'Nom', d.school.name),
                  AdminDetailRow(Icons.map_outlined, 'Département',
                      d.school.department ?? '—'),
                  AdminDetailRow(Icons.place_outlined, 'Adresse',
                      joinPlace([d.school.address, d.school.city])),
                  AdminDetailRow(
                      Icons.phone_rounded, 'Téléphone', d.school.phone ?? '—'),
                  AdminDetailRow(
                      Icons.mail_outline_rounded, 'Courriel', d.school.email ?? '—'),
                  AdminDetailRow(
                      Icons.person_pin_rounded,
                      'Chef d\'établissement',
                      d.school.hasDirector
                          ? '${d.school.directorName}'
                              '${d.school.directorPhone == null ? '' : ' · ${d.school.directorPhone}'}'
                          : 'Non désigné',
                      valueColor: d.school.hasDirector ? null : kRed,
                      last: true),
                ]),
              ),
              DossierSection(
                title: 'Conduite',
                icon: Icons.gavel_rounded,
                child: d.incidents.isEmpty
                    ? const DossierEmpty(
                        'Aucun fait de conduite enregistré. Le parcours de '
                        'l\'élève ne présente aucun incident signalé.')
                    : Column(children: [
                        for (final i in d.incidents) IncidentCard(incident: i),
                      ]),
              ),
              _PrivacyFooter(),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    ]);
  }
}

class _PrivacyFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorder),
        ),
        child: Row(children: [
          Icon(Icons.shield_outlined, size: 17, color: kTextMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Consultation en lecture seule. Les données médicales et les '
              'notes de suivi internes de l\'établissement ne remontent pas au '
              'niveau du groupe.',
              style: TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.4),
            ),
          ),
        ]),
      );
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline_rounded, size: 36, color: kRed),
          const SizedBox(height: 12),
          Text('Dossier indisponible',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary)),
          const SizedBox(height: 6),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: kTextMuted)),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ]),
      );
}
