import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/discipline_vocab.dart';
import '../../../core/widgets/admin_ui.dart';
import '../providers/student_dossier_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  SECTIONS DU DOSSIER DE L'ÉLÈVE — blocs réutilisés par la fiche et le PDF.
//  Un bloc sans données affiche une phrase explicite plutôt que de disparaître :
//  « aucun responsable enregistré » est une information de pilotage ; un bloc
//  absent laisserait croire qu'on n'a pas cherché.
// ════════════════════════════════════════════════════════════════════════════

final _dateFmt = DateFormat('dd MMMM yyyy', 'fr');
String fmtDate(DateTime? d) => d == null ? '—' : _dateFmt.format(d);

// ⚠️ Ces libellés doivent suivre les valeurs RÉELLES en base, pas une
// traduction supposée. `class_enrollments.inscription_type` est contraint à
// ('new', 'reinscription', 'transfer') — viser « nouvelle »/« transfert »
// laissait passer le code brut « new » jusque sous les yeux du ministre.
String enrollmentStatusLabel(String? s) => switch (s) {
      'active' => 'Inscription active',
      'pending_validation' || 'pending' => 'En attente de validation',
      'validated' => 'Validée',
      'rejected' => 'Rejetée',
      'withdrawn' => 'Retiré',
      'transferred' => 'Transféré',
      null || '' => '—',
      _ => s,
    };

String inscriptionTypeLabel(String? t) => switch (t) {
      'new' => 'Nouvelle inscription',
      'reinscription' => 'Réinscription',
      'transfer' => 'Transfert',
      null || '' => '—',
      _ => t,
    };

/// Assemble une adresse sans répéter une localité déjà contenue dans la voie.
/// La ville est souvent recopiée dans le champ `address` : concaténer à l'aveugle
/// donnait « Avenue de l'École, Pointe-Noire, Pointe-Noire ».
String joinPlace(List<String?> parts) {
  final seen = <String>{};
  final out = <String>[];
  for (final p in parts) {
    for (final seg in (p ?? '').split(',')) {
      final s = seg.trim();
      if (s.isEmpty) continue;
      if (seen.add(s.toLowerCase())) out.add(s);
    }
  }
  return out.isEmpty ? '—' : out.join(', ');
}

String cycleLabel(String? c) => switch (c) {
      'maternelle' => 'Maternelle',
      'primaire' => 'Primaire',
      'college' => 'Collège',
      'lycee' => 'Lycée',
      null || '' => '—',
      _ => c,
    };

// ─── Titre + carte ──────────────────────────────────────────────────────────
class DossierSection extends StatelessWidget {
  const DossierSection({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 15, color: kNavy),
            const SizedBox(width: 7),
            Text(title.toUpperCase(),
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: kNavy,
                    letterSpacing: 0.6)),
            const Spacer(),
            ?trailing,
          ]),
          const SizedBox(height: 8),
          child,
          const SizedBox(height: 18),
        ],
      );
}

class DossierEmpty extends StatelessWidget {
  const DossierEmpty(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorder),
        ),
        child: Text(message,
            style: TextStyle(fontSize: 12, color: kTextMuted)),
      );
}

// ─── Famille ────────────────────────────────────────────────────────────────
class TutorCard extends StatelessWidget {
  const TutorCard({super.key, required this.tutor});
  final DossierTutor tutor;

  @override
  Widget build(BuildContext context) {
    final t = tutor;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Flexible(
            child: Text(t.fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary)),
          ),
          const SizedBox(width: 8),
          AdminBadge(t.relationshipLabel, color: kNavy, icon: Icons.people_alt_rounded),
          if (t.isEmergency) ...[
            const SizedBox(width: 6),
            AdminBadge('Urgence', color: kRed, icon: Icons.emergency_rounded),
          ],
        ]),
        const SizedBox(height: 9),
        _Line(Icons.phone_rounded, [
          t.phonePrimary,
          t.phoneSecondary,
        ].whereType<String>().join('  ·  ')),
        if (t.email != null && t.email!.isNotEmpty)
          _Line(Icons.mail_outline_rounded, t.email!),
        _Line(Icons.place_outlined, t.address ?? 'Adresse non renseignée'),
        if (t.profession != null && t.profession!.isNotEmpty)
          _Line(Icons.work_outline_rounded, t.profession!),
      ]),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 13, color: kTextMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text.isEmpty ? '—' : text,
                style: TextStyle(fontSize: 12, color: kTextPrimary)),
          ),
        ]),
      );
}

// ─── Équipe enseignante ─────────────────────────────────────────────────────
class TeacherRow extends StatelessWidget {
  const TeacherRow({super.key, required this.teacher, this.last = false});
  final DossierTeacher teacher;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: kBorder)),
        ),
        child: Row(children: [
          Expanded(
            flex: 4,
            child: Text(teacher.subject,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary)),
          ),
          Expanded(
            flex: 5,
            child: Text(teacher.fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: kTextMuted)),
          ),
          SizedBox(
            width: 58,
            child: Text(
              teacher.weeklyHours == null ? '—' : '${teacher.weeklyHours} h/sem',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 11.5, color: kTextMuted),
            ),
          ),
        ]),
      );
}

// ─── Conduite ───────────────────────────────────────────────────────────────
class IncidentCard extends StatelessWidget {
  const IncidentCard({super.key, required this.incident});
  final DossierIncident incident;

  @override
  Widget build(BuildContext context) {
    final i = incident;
    final color = i.hasSanction ? kRed : const Color(0xFFF59E0B);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Flexible(
            child: Text(incidentTypeLabel(i.type),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary)),
          ),
          const SizedBox(width: 8),
          Text(fmtDate(i.date),
              style: TextStyle(fontSize: 11.5, color: kTextMuted)),
        ]),
        const SizedBox(height: 7),
        // LE MOTIF : sans lui, la sanction n'est pas jugeable.
        Text(i.description,
            style: TextStyle(fontSize: 12, color: kTextPrimary, height: 1.4)),
        const SizedBox(height: 9),
        Wrap(spacing: 6, runSpacing: 4, children: [
          AdminBadge(
            i.hasSanction ? sanctionLabel(i.sanction) : 'Aucune sanction',
            color: i.hasSanction ? kRed : kTextMuted,
            icon: Icons.balance_rounded,
          ),
          AdminBadge(
            i.parentNotified ? 'Parents informés' : 'Parents non informés',
            color: i.parentNotified ? kGreen : const Color(0xFFF59E0B),
            icon: i.parentNotified
                ? Icons.mark_email_read_rounded
                : Icons.mark_email_unread_rounded,
          ),
        ]),
      ]),
    );
  }
}
