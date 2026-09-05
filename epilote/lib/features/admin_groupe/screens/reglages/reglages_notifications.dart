part of '../admin_settings_screen.dart';

// Onglet Notifications.

class _NotificationsTab extends ConsumerWidget {
  const _NotificationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(adminGroupSettingsProvider);
    return _TabScaffold(
      onRefresh: () async {
        ref.invalidate(adminGroupSettingsProvider);
        await ref.read(adminGroupSettingsProvider.future);
      },
      children: [
        settings.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => const _CardLoader(),
          error: (e, _) => AdminCard(child: AdminErrorBanner(message: messageErreur(e))),
          data: (s) => _NotificationsCard(initial: s.notifications),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _NotificationsCard extends ConsumerStatefulWidget {
  const _NotificationsCard({required this.initial});
  final NotificationSettings initial;

  @override
  ConsumerState<_NotificationsCard> createState() => _NotificationsCardState();
}

class _NotificationsCardState extends ConsumerState<_NotificationsCard> {
  late NotificationSettings _s = widget.initial;
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      await ref.read(adminSettingsServiceProvider).saveNotifications(_s);
      if (mounted) _toast(context, 'Préférences de notification enregistrées.');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AdminCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const AdminSectionTitle('Canaux de notification',
              icon: Icons.campaign_outlined,
              subtitle: 'Comment le groupe est notifié'),
          const SizedBox(height: 8),
          _ToggleRow(
            icon: Icons.email_outlined,
            title: 'Email',
            subtitle: 'Notifications par courriel',
            value: _s.emailEnabled,
            onChanged: (v) => setState(() => _s = _s.copyWith(emailEnabled: v)),
          ),
          _ToggleRow(
            icon: Icons.sms_outlined,
            title: 'SMS',
            subtitle: 'Notifications par message texte',
            value: _s.smsEnabled,
            onChanged: (v) => setState(() => _s = _s.copyWith(smsEnabled: v)),
          ),
          _ToggleRow(
            icon: Icons.notifications_active_outlined,
            title: 'Push',
            subtitle: "Notifications dans l'application mobile",
            value: _s.pushEnabled,
            onChanged: (v) => setState(() => _s = _s.copyWith(pushEnabled: v)),
          ),
        ]),
      ),
      const SizedBox(height: 20),
      AdminCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const AdminSectionTitle('Événements suivis',
              icon: Icons.event_note_outlined,
              subtitle: 'Déclencheurs envoyant une notification'),
          const SizedBox(height: 8),
          _ToggleRow(
            icon: Icons.how_to_reg_outlined,
            title: 'Nouvelle inscription',
            subtitle: 'À chaque élève inscrit',
            value: _s.notifyNewEnrollment,
            onChanged: (v) => setState(() => _s = _s.copyWith(notifyNewEnrollment: v)),
          ),
          _ToggleRow(
            icon: Icons.payments_outlined,
            title: 'Paiement reçu',
            subtitle: 'À chaque encaissement de frais',
            value: _s.notifyPaymentReceived,
            onChanged: (v) => setState(() => _s = _s.copyWith(notifyPaymentReceived: v)),
          ),
          _ToggleRow(
            icon: Icons.person_off_outlined,
            title: 'Absence',
            subtitle: "À chaque absence d'élève signalée",
            value: _s.notifyAbsence,
            onChanged: (v) => setState(() => _s = _s.copyWith(notifyAbsence: v)),
          ),
          _ToggleRow(
            icon: Icons.trending_down_rounded,
            title: 'Assiduité faible',
            subtitle: "Alerte quand l'assiduité chute",
            value: _s.notifyLowAttendance,
            onChanged: (v) => setState(() => _s = _s.copyWith(notifyLowAttendance: v)),
          ),
        ]),
      ),
      const SizedBox(height: 20),
      AdminCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const AdminSectionTitle('Résumé quotidien',
              icon: Icons.summarize_outlined),
          const SizedBox(height: 8),
          _ToggleRow(
            icon: Icons.schedule_send_outlined,
            title: 'Activer le résumé quotidien',
            subtitle: 'Un récapitulatif envoyé chaque jour',
            value: _s.dailyDigest,
            onChanged: (v) => setState(() => _s = _s.copyWith(dailyDigest: v)),
          ),
          if (_s.dailyDigest)
            _NumberStepper(
              icon: Icons.access_time_rounded,
              title: "Heure d'envoi",
              subtitle: 'Heure locale du résumé',
              value: _s.digestHour,
              min: 0,
              max: 23,
              suffix: 'h',
              onChanged: (v) => setState(() => _s = _s.copyWith(digestHour: v)),
            ),
        ]),
      ),
      const SizedBox(height: 20),
      // ── Seuils d'alerte ────────────────────────────────────────────────────
      AdminCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const AdminSectionTitle("Seuils d'alerte",
              icon: Icons.warning_amber_rounded,
              subtitle: 'Déclenchent une alerte automatique au franchissement'),
          const SizedBox(height: 4),
          _NumberStepper(
            icon: Icons.event_available_outlined,
            title: "Seuil d'assiduité",
            subtitle: 'Alerter sous ce taux de présence',
            value: _s.attendanceAlertThreshold,
            min: 50,
            max: 100,
            step: 5,
            suffix: '%',
            onChanged: (v) => setState(() => _s = _s.copyWith(attendanceAlertThreshold: v)),
          ),
          _NumberStepper(
            icon: Icons.trending_down_rounded,
            title: 'Seuil de note',
            subtitle: 'Alerter sous cette moyenne (sur 20)',
            value: _s.gradeAlertThreshold,
            min: 0,
            max: 20,
            suffix: '/20',
            onChanged: (v) => setState(() => _s = _s.copyWith(gradeAlertThreshold: v)),
          ),
          _NumberStepper(
            icon: Icons.money_off_csred_rounded,
            title: 'Retard de paiement',
            subtitle: "Alerter après ce délai d'impayé",
            value: _s.unpaidAlertDays,
            min: 7,
            max: 120,
            suffix: 'jours',
            onChanged: (v) => setState(() => _s = _s.copyWith(unpaidAlertDays: v)),
          ),
        ]),
      ),
      const SizedBox(height: 20),
      // ── Rappels automatiques de paiement ───────────────────────────────────
      AdminCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const AdminSectionTitle('Rappels automatiques de paiement',
              icon: Icons.notification_important_outlined,
              subtitle: 'Relances envoyées aux familles ayant un solde dû'),
          const SizedBox(height: 8),
          _ToggleRow(
            icon: Icons.autorenew_rounded,
            title: 'Activer les rappels',
            subtitle: "Programme jusqu'à trois relances échelonnées",
            value: _s.billingReminderEnabled,
            onChanged: (v) => setState(() => _s = _s.copyWith(billingReminderEnabled: v)),
          ),
          if (_s.billingReminderEnabled) ...[
            _NumberStepper(
              icon: Icons.looks_one_outlined,
              title: 'Premier rappel',
              subtitle: "Jours après l'émission de la facture",
              value: _s.billingReminderDay1,
              min: 1,
              max: 90,
              suffix: 'j',
              onChanged: (v) => setState(() => _s = _s.copyWith(billingReminderDay1: v)),
            ),
            _NumberStepper(
              icon: Icons.looks_two_outlined,
              title: 'Deuxième rappel',
              subtitle: "Jours après l'émission de la facture",
              value: _s.billingReminderDay2,
              min: 1,
              max: 120,
              suffix: 'j',
              onChanged: (v) => setState(() => _s = _s.copyWith(billingReminderDay2: v)),
            ),
            _NumberStepper(
              icon: Icons.looks_3_outlined,
              title: 'Dernier rappel',
              subtitle: "Jours après l'émission de la facture",
              value: _s.billingReminderDay3,
              min: 1,
              max: 180,
              suffix: 'j',
              onChanged: (v) => setState(() => _s = _s.copyWith(billingReminderDay3: v)),
            ),
          ],
        ]),
      ),
      const SizedBox(height: 20),
      // ── Destinataires par rôle ─────────────────────────────────────────────
      AdminCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const AdminSectionTitle('Destinataires par rôle',
              icon: Icons.groups_2_outlined,
              subtitle: 'Qui reçoit chaque type de notification'),
          const SizedBox(height: 8),
          _ToggleRow(
            icon: Icons.account_balance_outlined,
            title: 'Directeur — paiements',
            subtitle: 'Notifier le directeur à chaque encaissement',
            value: _s.notifyDirectorOnPayment,
            onChanged: (v) => setState(() => _s = _s.copyWith(notifyDirectorOnPayment: v)),
          ),
          _ToggleRow(
            icon: Icons.person_off_outlined,
            title: 'Directeur — absences',
            subtitle: 'Notifier le directeur des absences signalées',
            value: _s.notifyDirectorOnAbsence,
            onChanged: (v) => setState(() => _s = _s.copyWith(notifyDirectorOnAbsence: v)),
          ),
          _ToggleRow(
            icon: Icons.calculate_outlined,
            title: 'Comptable — paiements',
            subtitle: 'Notifier le comptable à chaque encaissement',
            value: _s.notifyAccountantOnPayment,
            onChanged: (v) => setState(() => _s = _s.copyWith(notifyAccountantOnPayment: v)),
          ),
          _ToggleRow(
            icon: Icons.co_present_outlined,
            title: 'Enseignant — absences',
            subtitle: "Notifier l'enseignant des absences de sa classe",
            value: _s.notifyTeacherOnAbsence,
            onChanged: (v) => setState(() => _s = _s.copyWith(notifyTeacherOnAbsence: v)),
          ),
        ]),
      ),
      const SizedBox(height: 20),
      _SaveBar(saving: _saving, onSave: _save, error: _error),
      const SizedBox(height: 24),
    ]);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ONGLET 4 — SÉCURITÉ  (group_settings.security)
// ═════════════════════════════════════════════════════════════════════════════
