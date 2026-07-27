import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/auth_provider.dart';

// ══════════════════════════════════════════════════════════════════════════════
// ESPACE ADMIN_GROUPE — Paramètres (online / Supabase direct, scope group_id)
//
// Sources de données :
//   • school_groups   → infos groupe (LECTURE SEULE)
//   • group_settings  → 3 blobs jsonb (general / notifications / security)
//   • payment_configs → moyens de paiement (CRUD réel)
//   • support_tickets → demandes au support
//   • schools/profiles → statistiques temps réel
// ══════════════════════════════════════════════════════════════════════════════

// ─── Profil du groupe (lecture seule) ─────────────────────────────────────────
class GroupProfile {
  const GroupProfile({
    required this.name,
    required this.groupType,
    required this.planName,
    required this.subscriptionStatus,
    this.slug,
    this.department,
    this.adminEmail,
    this.phone,
    this.address,
    this.foundedYear,
    this.subscriptionEnd,
    this.subscriptionStart,
    this.logoUrl,
    this.isActive = true,
  });
  final String name;
  final String groupType;
  final String planName;
  final String subscriptionStatus;
  final String? slug;
  final String? department;
  final String? adminEmail;
  final String? phone;
  final String? address;
  final int? foundedYear;
  final DateTime? subscriptionEnd;
  final DateTime? subscriptionStart;
  final String? logoUrl;
  final bool isActive;
}

final adminGroupProfileProvider =
    FutureProvider.autoDispose<GroupProfile?>((ref) async {
  ref.keepAlive();
  final client  = ref.watch(supabaseClientProvider);
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null) return null;
  try {
    final g = await client.from('school_groups')
        .select('name, slug, group_type, department, admin_email, phone, address, '
            'founded_year, logo_url, subscription_status, subscription_start, '
            'subscription_end, is_active, subscription_plans!plan_id(name)')
        .eq('id', groupId)
        .maybeSingle();
    if (g == null) return null;
    final plan = g['subscription_plans'] as Map<String, dynamic>?;
    return GroupProfile(
      name:               g['name'] as String? ?? '—',
      groupType:          g['group_type'] as String? ?? '—',
      slug:               g['slug'] as String?,
      department:         g['department'] as String?,
      adminEmail:         g['admin_email'] as String?,
      phone:              g['phone'] as String?,
      address:            g['address'] as String?,
      foundedYear:        (g['founded_year'] as num?)?.toInt(),
      logoUrl:            g['logo_url'] as String?,
      planName:           plan?['name'] as String? ?? '—',
      subscriptionStatus: g['subscription_status'] as String? ?? 'trial',
      subscriptionStart:  DateTime.tryParse(g['subscription_start'] as String? ?? ''),
      subscriptionEnd:    DateTime.tryParse(g['subscription_end'] as String? ?? ''),
      isActive:           g['is_active'] as bool? ?? true,
    );
  } catch (_) {
    return null;
  }
});

// ─── Statistiques temps réel du groupe ────────────────────────────────────────
class GroupStats {
  const GroupStats({
    this.totalSchools = 0,
    this.activeSchools = 0,
    this.totalUsers = 0,
    this.activeUsers = 0,
    this.planMaxSchools = 0,
    this.planMaxUsers = 0,
  });
  final int totalSchools;
  final int activeSchools;
  final int totalUsers;
  final int activeUsers;
  final int planMaxSchools;
  final int planMaxUsers;

  double get schoolQuotaPct =>
      planMaxSchools > 0 ? (activeSchools / planMaxSchools).clamp(0.0, 1.0) : 0.0;
  double get userQuotaPct =>
      planMaxUsers > 0 ? (totalUsers / planMaxUsers).clamp(0.0, 1.0) : 0.0;
}

(int, int) _planQuotas(String planName) {
  final lower = planName.toLowerCase();
  if (lower.contains('starter') || lower.contains('démarrage')) return (3, 50);
  if (lower.contains('institution')) return (20, 500);
  if (lower.contains('enterprise') || lower.contains('entreprise')) return (100, 5000);
  if (lower.contains('premium')) return (50, 2000);
  return (10, 200);
}

final adminGroupStatsProvider =
    FutureProvider.autoDispose<GroupStats>((ref) async {
  ref.keepAlive();
  final client  = ref.watch(supabaseClientProvider);
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null) return const GroupStats();
  try {
    final schoolsRows = await client
        .from('schools')
        .select('id, is_active')
        .eq('group_id', groupId) as List;
    final totalSchools  = schoolsRows.length;
    final activeSchools = schoolsRows.where((r) => (r as Map)['is_active'] == true).length;

    final usersRows = await client
        .from('profiles')
        .select('id, is_active')
        .eq('group_id', groupId)
        .neq('role', 'super_admin')
        .neq('role', 'admin_groupe') as List;
    final totalUsers  = usersRows.length;
    final activeUsers = usersRows.where((r) => (r as Map)['is_active'] == true).length;

    final profile = await ref.read(adminGroupProfileProvider.future);
    final (maxS, maxU) = _planQuotas(profile?.planName ?? '');

    return GroupStats(
      totalSchools:   totalSchools,
      activeSchools:  activeSchools,
      totalUsers:     totalUsers,
      activeUsers:    activeUsers,
      planMaxSchools: maxS,
      planMaxUsers:   maxU,
    );
  } catch (_) {
    return const GroupStats();
  }
});

// ─── Connexions récentes (profiles.last_login) ─────────────────────────────────
class RecentLogin {
  const RecentLogin({
    required this.name,
    required this.role,
    required this.lastLogin,
  });
  final String name;
  final String role;
  final DateTime lastLogin;

  bool get isToday {
    final now = DateTime.now();
    return lastLogin.year == now.year &&
        lastLogin.month == now.month &&
        lastLogin.day == now.day;
  }
  bool get isThisWeek => DateTime.now().difference(lastLogin).inDays <= 7;
}

final adminRecentLoginsProvider =
    FutureProvider.autoDispose<List<RecentLogin>>((ref) async {
  ref.keepAlive();
  final client  = ref.watch(supabaseClientProvider);
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null) return [];
  try {
    final rows = await client
        .from('profiles')
        .select('first_name, last_name, role, last_login')
        .eq('group_id', groupId)
        .not('last_login', 'is', null)
        .order('last_login', ascending: false)
        .limit(10) as List;
    return [
      for (final r in rows)
        if (r['last_login'] != null)
          RecentLogin(
            name: '${r['first_name'] ?? ''} ${r['last_name'] ?? ''}'.trim(),
            role: r['role'] as String? ?? '—',
            lastLogin: DateTime.parse(r['last_login'] as String),
          ),
    ];
  } catch (_) {
    return [];
  }
});

// ══════════════════════════════════════════════════════════════════════════════
// group_settings — modèles fortement typés (3 blobs jsonb)
// ══════════════════════════════════════════════════════════════════════════════

bool _asBool(Object? v, bool fallback) => v is bool ? v : fallback;
int _asInt(Object? v, int fallback) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}
String _asStr(Object? v, String fallback) =>
    (v is String && v.isNotEmpty) ? v : fallback;

// ─── Préférences générales + pédagogie + politique de frais ───────────────────
class GeneralSettings {
  const GeneralSettings({
    // Régional
    this.defaultLanguage = 'fr',
    this.timezone = 'Africa/Brazzaville',
    this.dateFormat = 'dd/MM/yyyy',
    this.academicYearStartMonth = 9,
    this.currencyDisplay = 'XAF',
    this.weekStartsOn = 1,
    // Pédagogie
    this.gradingSystem = 'numeric_20',
    this.gradingMaxScore = 20,
    this.defaultCourseDurationMinutes = 55,
    this.trimesterCount = 3,
    // Politique de frais
    this.defaultInstallments = 3,
    this.lateFeeRatePercent = 5,
    this.lateGraceDays = 15,
    this.siblingDiscountPercent = 10,
    this.scholarshipMaxPercent = 100,
  });

  factory GeneralSettings.fromJson(Map<String, dynamic> j) => GeneralSettings(
        defaultLanguage:              _asStr(j['default_language'], 'fr'),
        timezone:                     _asStr(j['timezone'], 'Africa/Brazzaville'),
        dateFormat:                   _asStr(j['date_format'], 'dd/MM/yyyy'),
        academicYearStartMonth:       _asInt(j['academic_year_start_month'], 9),
        currencyDisplay:              _asStr(j['currency_display'], 'XAF'),
        weekStartsOn:                 _asInt(j['week_starts_on'], 1),
        gradingSystem:                _asStr(j['grading_system'], 'numeric_20'),
        gradingMaxScore:              _asInt(j['grading_max_score'], 20),
        defaultCourseDurationMinutes: _asInt(j['default_course_duration_minutes'], 55),
        trimesterCount:               _asInt(j['trimester_count'], 3),
        defaultInstallments:          _asInt(j['default_installments'], 3),
        lateFeeRatePercent:           _asInt(j['late_fee_rate_percent'], 5),
        lateGraceDays:                _asInt(j['late_grace_days'], 15),
        siblingDiscountPercent:       _asInt(j['sibling_discount_percent'], 10),
        scholarshipMaxPercent:        _asInt(j['scholarship_max_percent'], 100),
      );

  // Régional
  final String defaultLanguage;
  final String timezone;
  final String dateFormat;
  final int academicYearStartMonth;
  final String currencyDisplay;
  final int weekStartsOn;
  // Pédagogie
  final String gradingSystem; // 'numeric_20' | 'numeric_10' | 'letter' | 'competence'
  final int gradingMaxScore;
  final int defaultCourseDurationMinutes;
  final int trimesterCount;
  // Politique de frais
  final int defaultInstallments;
  final int lateFeeRatePercent;
  final int lateGraceDays;
  final int siblingDiscountPercent;
  final int scholarshipMaxPercent;

  Map<String, dynamic> toJson() => {
        'default_language':                defaultLanguage,
        'timezone':                        timezone,
        'date_format':                     dateFormat,
        'academic_year_start_month':       academicYearStartMonth,
        'currency_display':                currencyDisplay,
        'week_starts_on':                  weekStartsOn,
        'grading_system':                  gradingSystem,
        'grading_max_score':               gradingMaxScore,
        'default_course_duration_minutes': defaultCourseDurationMinutes,
        'trimester_count':                 trimesterCount,
        'default_installments':            defaultInstallments,
        'late_fee_rate_percent':           lateFeeRatePercent,
        'late_grace_days':                 lateGraceDays,
        'sibling_discount_percent':        siblingDiscountPercent,
        'scholarship_max_percent':         scholarshipMaxPercent,
      };

  GeneralSettings copyWith({
    String? defaultLanguage,
    String? timezone,
    String? dateFormat,
    int? academicYearStartMonth,
    String? currencyDisplay,
    int? weekStartsOn,
    String? gradingSystem,
    int? gradingMaxScore,
    int? defaultCourseDurationMinutes,
    int? trimesterCount,
    int? defaultInstallments,
    int? lateFeeRatePercent,
    int? lateGraceDays,
    int? siblingDiscountPercent,
    int? scholarshipMaxPercent,
  }) =>
      GeneralSettings(
        defaultLanguage:              defaultLanguage ?? this.defaultLanguage,
        timezone:                     timezone ?? this.timezone,
        dateFormat:                   dateFormat ?? this.dateFormat,
        academicYearStartMonth:       academicYearStartMonth ?? this.academicYearStartMonth,
        currencyDisplay:              currencyDisplay ?? this.currencyDisplay,
        weekStartsOn:                 weekStartsOn ?? this.weekStartsOn,
        gradingSystem:                gradingSystem ?? this.gradingSystem,
        gradingMaxScore:              gradingMaxScore ?? this.gradingMaxScore,
        defaultCourseDurationMinutes: defaultCourseDurationMinutes ?? this.defaultCourseDurationMinutes,
        trimesterCount:               trimesterCount ?? this.trimesterCount,
        defaultInstallments:          defaultInstallments ?? this.defaultInstallments,
        lateFeeRatePercent:           lateFeeRatePercent ?? this.lateFeeRatePercent,
        lateGraceDays:                lateGraceDays ?? this.lateGraceDays,
        siblingDiscountPercent:       siblingDiscountPercent ?? this.siblingDiscountPercent,
        scholarshipMaxPercent:        scholarshipMaxPercent ?? this.scholarshipMaxPercent,
      );
}

// ─── Notifications (+ seuils d'alerte + rappels + destinataires) ──────────────
class NotificationSettings {
  const NotificationSettings({
    // Canaux
    this.emailEnabled = true,
    this.smsEnabled = false,
    this.pushEnabled = true,
    // Événements
    this.notifyNewEnrollment = true,
    this.notifyPaymentReceived = true,
    this.notifyAbsence = true,
    this.notifyLowAttendance = false,
    // Digest
    this.dailyDigest = false,
    this.digestHour = 7,
    // Seuils d'alerte
    this.attendanceAlertThreshold = 80,
    this.gradeAlertThreshold = 8,
    this.unpaidAlertDays = 30,
    // Rappels automatiques de paiement
    this.billingReminderEnabled = false,
    this.billingReminderDay1 = 7,
    this.billingReminderDay2 = 15,
    this.billingReminderDay3 = 30,
    // Destinataires par rôle
    this.notifyDirectorOnPayment = true,
    this.notifyDirectorOnAbsence = true,
    this.notifyAccountantOnPayment = true,
    this.notifyTeacherOnAbsence = false,
  });

  factory NotificationSettings.fromJson(Map<String, dynamic> j) =>
      NotificationSettings(
        emailEnabled:              _asBool(j['email_enabled'], true),
        smsEnabled:                _asBool(j['sms_enabled'], false),
        pushEnabled:               _asBool(j['push_enabled'], true),
        notifyNewEnrollment:       _asBool(j['notify_new_enrollment'], true),
        notifyPaymentReceived:     _asBool(j['notify_payment_received'], true),
        notifyAbsence:             _asBool(j['notify_absence'], true),
        notifyLowAttendance:       _asBool(j['notify_low_attendance'], false),
        dailyDigest:               _asBool(j['daily_digest'], false),
        digestHour:                _asInt(j['digest_hour'], 7),
        attendanceAlertThreshold:  _asInt(j['attendance_alert_threshold'], 80),
        gradeAlertThreshold:       _asInt(j['grade_alert_threshold'], 8),
        unpaidAlertDays:           _asInt(j['unpaid_alert_days'], 30),
        billingReminderEnabled:    _asBool(j['billing_reminder_enabled'], false),
        billingReminderDay1:       _asInt(j['billing_reminder_day_1'], 7),
        billingReminderDay2:       _asInt(j['billing_reminder_day_2'], 15),
        billingReminderDay3:       _asInt(j['billing_reminder_day_3'], 30),
        notifyDirectorOnPayment:   _asBool(j['notify_director_on_payment'], true),
        notifyDirectorOnAbsence:   _asBool(j['notify_director_on_absence'], true),
        notifyAccountantOnPayment: _asBool(j['notify_accountant_on_payment'], true),
        notifyTeacherOnAbsence:    _asBool(j['notify_teacher_on_absence'], false),
      );

  // Canaux
  final bool emailEnabled;
  final bool smsEnabled;
  final bool pushEnabled;
  // Événements
  final bool notifyNewEnrollment;
  final bool notifyPaymentReceived;
  final bool notifyAbsence;
  final bool notifyLowAttendance;
  // Digest
  final bool dailyDigest;
  final int digestHour;
  // Seuils
  final int attendanceAlertThreshold; // % en dessous duquel alerter
  final int gradeAlertThreshold;       // note en dessous de laquelle alerter
  final int unpaidAlertDays;           // jours de retard avant alerte
  // Rappels automatiques
  final bool billingReminderEnabled;
  final int billingReminderDay1;
  final int billingReminderDay2;
  final int billingReminderDay3;
  // Destinataires
  final bool notifyDirectorOnPayment;
  final bool notifyDirectorOnAbsence;
  final bool notifyAccountantOnPayment;
  final bool notifyTeacherOnAbsence;

  Map<String, dynamic> toJson() => {
        'email_enabled':               emailEnabled,
        'sms_enabled':                 smsEnabled,
        'push_enabled':                pushEnabled,
        'notify_new_enrollment':       notifyNewEnrollment,
        'notify_payment_received':     notifyPaymentReceived,
        'notify_absence':              notifyAbsence,
        'notify_low_attendance':       notifyLowAttendance,
        'daily_digest':                dailyDigest,
        'digest_hour':                 digestHour,
        'attendance_alert_threshold':  attendanceAlertThreshold,
        'grade_alert_threshold':       gradeAlertThreshold,
        'unpaid_alert_days':           unpaidAlertDays,
        'billing_reminder_enabled':    billingReminderEnabled,
        'billing_reminder_day_1':      billingReminderDay1,
        'billing_reminder_day_2':      billingReminderDay2,
        'billing_reminder_day_3':      billingReminderDay3,
        'notify_director_on_payment':  notifyDirectorOnPayment,
        'notify_director_on_absence':  notifyDirectorOnAbsence,
        'notify_accountant_on_payment': notifyAccountantOnPayment,
        'notify_teacher_on_absence':   notifyTeacherOnAbsence,
      };

  NotificationSettings copyWith({
    bool? emailEnabled,
    bool? smsEnabled,
    bool? pushEnabled,
    bool? notifyNewEnrollment,
    bool? notifyPaymentReceived,
    bool? notifyAbsence,
    bool? notifyLowAttendance,
    bool? dailyDigest,
    int? digestHour,
    int? attendanceAlertThreshold,
    int? gradeAlertThreshold,
    int? unpaidAlertDays,
    bool? billingReminderEnabled,
    int? billingReminderDay1,
    int? billingReminderDay2,
    int? billingReminderDay3,
    bool? notifyDirectorOnPayment,
    bool? notifyDirectorOnAbsence,
    bool? notifyAccountantOnPayment,
    bool? notifyTeacherOnAbsence,
  }) =>
      NotificationSettings(
        emailEnabled:              emailEnabled ?? this.emailEnabled,
        smsEnabled:                smsEnabled ?? this.smsEnabled,
        pushEnabled:               pushEnabled ?? this.pushEnabled,
        notifyNewEnrollment:       notifyNewEnrollment ?? this.notifyNewEnrollment,
        notifyPaymentReceived:     notifyPaymentReceived ?? this.notifyPaymentReceived,
        notifyAbsence:             notifyAbsence ?? this.notifyAbsence,
        notifyLowAttendance:       notifyLowAttendance ?? this.notifyLowAttendance,
        dailyDigest:               dailyDigest ?? this.dailyDigest,
        digestHour:                digestHour ?? this.digestHour,
        attendanceAlertThreshold:  attendanceAlertThreshold ?? this.attendanceAlertThreshold,
        gradeAlertThreshold:       gradeAlertThreshold ?? this.gradeAlertThreshold,
        unpaidAlertDays:           unpaidAlertDays ?? this.unpaidAlertDays,
        billingReminderEnabled:    billingReminderEnabled ?? this.billingReminderEnabled,
        billingReminderDay1:       billingReminderDay1 ?? this.billingReminderDay1,
        billingReminderDay2:       billingReminderDay2 ?? this.billingReminderDay2,
        billingReminderDay3:       billingReminderDay3 ?? this.billingReminderDay3,
        notifyDirectorOnPayment:   notifyDirectorOnPayment ?? this.notifyDirectorOnPayment,
        notifyDirectorOnAbsence:   notifyDirectorOnAbsence ?? this.notifyDirectorOnAbsence,
        notifyAccountantOnPayment: notifyAccountantOnPayment ?? this.notifyAccountantOnPayment,
        notifyTeacherOnAbsence:    notifyTeacherOnAbsence ?? this.notifyTeacherOnAbsence,
      );
}

// ─── Sécurité (+ politique de données) ────────────────────────────────────────
class SecuritySettings {
  const SecuritySettings({
    // Mot de passe
    this.minPasswordLength = 8,
    this.requireStrongPassword = true,
    // Sessions
    this.require2fa = false,
    this.sessionTimeoutMinutes = 60,
    this.allowMultipleSessions = true,
    this.lockAfterFailedAttempts = 5,
    // Politique de données
    this.dataRetentionMonths = 60,
    this.auditRetentionMonths = 24,
    this.autoArchiveInactive = false,
    this.archiveAfterMonths = 12,
  });

  factory SecuritySettings.fromJson(Map<String, dynamic> j) => SecuritySettings(
        minPasswordLength:       _asInt(j['min_password_length'], 8),
        requireStrongPassword:   _asBool(j['require_strong_password'], true),
        require2fa:              _asBool(j['require_2fa'], false),
        sessionTimeoutMinutes:   _asInt(j['session_timeout_minutes'], 60),
        allowMultipleSessions:   _asBool(j['allow_multiple_sessions'], true),
        lockAfterFailedAttempts: _asInt(j['lock_after_failed_attempts'], 5),
        dataRetentionMonths:     _asInt(j['data_retention_months'], 60),
        auditRetentionMonths:    _asInt(j['audit_retention_months'], 24),
        autoArchiveInactive:     _asBool(j['auto_archive_inactive'], false),
        archiveAfterMonths:      _asInt(j['archive_after_months'], 12),
      );

  // Mot de passe
  final int minPasswordLength;
  final bool requireStrongPassword;
  // Sessions
  final bool require2fa;
  final int sessionTimeoutMinutes;
  final bool allowMultipleSessions;
  final int lockAfterFailedAttempts;
  // Politique de données
  final int dataRetentionMonths;
  final int auditRetentionMonths;
  final bool autoArchiveInactive;
  final int archiveAfterMonths;

  Map<String, dynamic> toJson() => {
        'min_password_length':        minPasswordLength,
        'require_strong_password':    requireStrongPassword,
        'require_2fa':                require2fa,
        'session_timeout_minutes':    sessionTimeoutMinutes,
        'allow_multiple_sessions':    allowMultipleSessions,
        'lock_after_failed_attempts': lockAfterFailedAttempts,
        'data_retention_months':      dataRetentionMonths,
        'audit_retention_months':     auditRetentionMonths,
        'auto_archive_inactive':      autoArchiveInactive,
        'archive_after_months':       archiveAfterMonths,
      };

  SecuritySettings copyWith({
    int? minPasswordLength,
    bool? requireStrongPassword,
    bool? require2fa,
    int? sessionTimeoutMinutes,
    bool? allowMultipleSessions,
    int? lockAfterFailedAttempts,
    int? dataRetentionMonths,
    int? auditRetentionMonths,
    bool? autoArchiveInactive,
    int? archiveAfterMonths,
  }) =>
      SecuritySettings(
        minPasswordLength:       minPasswordLength ?? this.minPasswordLength,
        requireStrongPassword:   requireStrongPassword ?? this.requireStrongPassword,
        require2fa:              require2fa ?? this.require2fa,
        sessionTimeoutMinutes:   sessionTimeoutMinutes ?? this.sessionTimeoutMinutes,
        allowMultipleSessions:   allowMultipleSessions ?? this.allowMultipleSessions,
        lockAfterFailedAttempts: lockAfterFailedAttempts ?? this.lockAfterFailedAttempts,
        dataRetentionMonths:     dataRetentionMonths ?? this.dataRetentionMonths,
        auditRetentionMonths:    auditRetentionMonths ?? this.auditRetentionMonths,
        autoArchiveInactive:     autoArchiveInactive ?? this.autoArchiveInactive,
        archiveAfterMonths:      archiveAfterMonths ?? this.archiveAfterMonths,
      );
}

// ─── Agrégat group_settings ───────────────────────────────────────────────────
class GroupSettings {
  const GroupSettings({
    required this.general,
    required this.notifications,
    required this.security,
  });

  factory GroupSettings.defaults() => const GroupSettings(
        general: GeneralSettings(),
        notifications: NotificationSettings(),
        security: SecuritySettings(),
      );

  factory GroupSettings.fromRow(Map<String, dynamic> row) => GroupSettings(
        general: GeneralSettings.fromJson(
            (row['general'] as Map?)?.cast<String, dynamic>() ?? const {}),
        notifications: NotificationSettings.fromJson(
            (row['notifications'] as Map?)?.cast<String, dynamic>() ?? const {}),
        security: SecuritySettings.fromJson(
            (row['security'] as Map?)?.cast<String, dynamic>() ?? const {}),
      );

  final GeneralSettings general;
  final NotificationSettings notifications;
  final SecuritySettings security;

  GroupSettings copyWith({
    GeneralSettings? general,
    NotificationSettings? notifications,
    SecuritySettings? security,
  }) =>
      GroupSettings(
        general: general ?? this.general,
        notifications: notifications ?? this.notifications,
        security: security ?? this.security,
      );
}

final adminGroupSettingsProvider =
    FutureProvider.autoDispose<GroupSettings>((ref) async {
  ref.keepAlive();
  final client  = ref.watch(supabaseClientProvider);
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null) return GroupSettings.defaults();
  final row = await client.from('group_settings')
      .select('general, notifications, security')
      .eq('group_id', groupId)
      .maybeSingle();
  if (row == null) return GroupSettings.defaults();
  return GroupSettings.fromRow(row);
});

// ══════════════════════════════════════════════════════════════════════════════
// payment_configs — moyens de paiement (CRUD réel par l'admin_groupe)
// ══════════════════════════════════════════════════════════════════════════════

enum PaymentProvider { mtnMoney, airtelMoney, visa, especes }

extension PaymentProviderX on PaymentProvider {
  String get dbValue => switch (this) {
        PaymentProvider.mtnMoney    => 'mtn_money',
        PaymentProvider.airtelMoney => 'airtel_money',
        PaymentProvider.visa        => 'visa',
        PaymentProvider.especes     => 'especes',
      };

  String get label => switch (this) {
        PaymentProvider.mtnMoney    => 'MTN Mobile Money',
        PaymentProvider.airtelMoney => 'Airtel Money',
        PaymentProvider.visa        => 'Carte bancaire (Visa)',
        PaymentProvider.especes     => 'Espèces',
      };

  bool get isApiBased => this != PaymentProvider.especes;

  static PaymentProvider fromDb(String v) => switch (v) {
        'mtn_money'   => PaymentProvider.mtnMoney,
        'airtel_money' => PaymentProvider.airtelMoney,
        'visa'        => PaymentProvider.visa,
        'especes'     => PaymentProvider.especes,
        _             => PaymentProvider.especes,
      };
}

class PaymentConfig {
  const PaymentConfig({
    this.id,
    required this.provider,
    required this.displayName,
    this.apiKey,
    this.apiSecret,
    this.merchantId,
    this.webhookUrl,
    this.isActive = false,
    this.isTestMode = true,
    this.notes,
  });

  factory PaymentConfig.fromRow(Map<String, dynamic> r) => PaymentConfig(
        id:          r['id'] as String?,
        provider:    PaymentProviderX.fromDb(r['provider'] as String? ?? 'especes'),
        displayName: r['display_name'] as String? ?? '',
        apiKey:      r['api_key'] as String?,
        apiSecret:   r['api_secret'] as String?,
        merchantId:  r['merchant_id'] as String?,
        webhookUrl:  r['webhook_url'] as String?,
        isActive:    r['is_active'] as bool? ?? false,
        isTestMode:  r['is_test_mode'] as bool? ?? true,
        notes:       r['notes'] as String?,
      );

  final String? id;
  final PaymentProvider provider;
  final String displayName;
  final String? apiKey;
  final String? apiSecret;
  final String? merchantId;
  final String? webhookUrl;
  final bool isActive;
  final bool isTestMode;
  final String? notes;

  bool get isNew => id == null;
}

final adminPaymentConfigsProvider =
    FutureProvider.autoDispose<List<PaymentConfig>>((ref) async {
  ref.keepAlive();
  final client  = ref.watch(supabaseClientProvider);
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null) return const [];
  final rows = await client.from('payment_configs')
      .select('id, provider, display_name, api_key, api_secret, merchant_id, '
          'webhook_url, is_active, is_test_mode, notes')
      .eq('group_id', groupId)
      .order('created_at', ascending: false) as List;
  return rows
      .map((r) => PaymentConfig.fromRow(r as Map<String, dynamic>))
      .toList();
});

// ══════════════════════════════════════════════════════════════════════════════
// Service d'écriture — toutes les mutations
// ══════════════════════════════════════════════════════════════════════════════
class AdminSettingsService {
  AdminSettingsService(this._ref);
  final Ref _ref;

  ({String groupId, String uid}) _session() {
    final client  = _ref.read(supabaseClientProvider);
    final groupId = _ref.read(authNotifierProvider).valueOrNull?.groupId;
    final uid     = client.auth.currentUser?.id;
    if (groupId == null || uid == null) throw Exception('Session invalide');
    return (groupId: groupId, uid: uid);
  }

  Future<void> saveGeneral(GeneralSettings general) =>
      _upsertSettings(general: general);

  Future<void> saveNotifications(NotificationSettings n) =>
      _upsertSettings(notifications: n);

  Future<void> saveSecurity(SecuritySettings s) =>
      _upsertSettings(security: s);

  Future<void> _upsertSettings({
    GeneralSettings? general,
    NotificationSettings? notifications,
    SecuritySettings? security,
  }) async {
    final s = _session();
    final client = _ref.read(supabaseClientProvider);
    final current = await _ref.read(adminGroupSettingsProvider.future);
    final payload = {
      'group_id':     s.groupId,
      'general':      (general ?? current.general).toJson(),
      'notifications': (notifications ?? current.notifications).toJson(),
      'security':     (security ?? current.security).toJson(),
      'updated_by':   s.uid,
      'updated_at':   DateTime.now().toUtc().toIso8601String(),
    };
    await client.from('group_settings').upsert(payload, onConflict: 'group_id');
    _ref.invalidate(adminGroupSettingsProvider);
  }

  Future<void> savePaymentConfig(PaymentConfig cfg) async {
    final s = _session();
    final client = _ref.read(supabaseClientProvider);
    final values = <String, dynamic>{
      'group_id':     s.groupId,
      'provider':     cfg.provider.dbValue,
      'display_name': cfg.displayName.trim(),
      'api_key':      _nullIfBlank(cfg.apiKey),
      'api_secret':   _nullIfBlank(cfg.apiSecret),
      'merchant_id':  _nullIfBlank(cfg.merchantId),
      'webhook_url':  _nullIfBlank(cfg.webhookUrl),
      'is_active':    cfg.isActive,
      'is_test_mode': cfg.isTestMode,
      'notes':        _nullIfBlank(cfg.notes),
      'configured_by': s.uid,
      'configured_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (cfg.isNew) {
      await client.from('payment_configs').insert(values);
    } else {
      await client.from('payment_configs')
          .update(values)
          .eq('id', cfg.id!)
          .eq('group_id', s.groupId);
    }
    _ref.invalidate(adminPaymentConfigsProvider);
  }

  Future<void> setPaymentActive(String id, bool active) async {
    final s = _session();
    final client = _ref.read(supabaseClientProvider);
    await client.from('payment_configs').update({
      'is_active':     active,
      'configured_by': s.uid,
      'configured_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id).eq('group_id', s.groupId);
    _ref.invalidate(adminPaymentConfigsProvider);
  }

  Future<void> deletePaymentConfig(String id) async {
    final s = _session();
    final client = _ref.read(supabaseClientProvider);
    await client.from('payment_configs')
        .delete()
        .eq('id', id)
        .eq('group_id', s.groupId);
    _ref.invalidate(adminPaymentConfigsProvider);
  }

  Future<void> requestGroupUpdate(String message) async {
    final s = _session();
    final client = _ref.read(supabaseClientProvider);
    await client.from('support_tickets').insert({
      'group_id':     s.groupId,
      'submitted_by': s.uid,
      'subject':      'Demande de modification des informations du groupe',
      'body':         message,
      'category':     'modification_groupe',
      'priority':     'medium',
      'status':       'open',
    });
  }

  static String? _nullIfBlank(String? v) {
    final t = v?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }
}

final adminSettingsServiceProvider =
    Provider<AdminSettingsService>((ref) => AdminSettingsService(ref));

// ─── Historique des demandes au support ──────────────────────────────────────
class SupportTicketItem {
  const SupportTicketItem({
    required this.id,
    required this.subject,
    required this.status,
    this.body,
    this.response,
    this.createdAt,
  });

  factory SupportTicketItem.fromRow(Map<String, dynamic> r) => SupportTicketItem(
        id:        r['id'] as String,
        subject:   r['subject'] as String? ?? '—',
        status:    r['status']  as String? ?? 'open',
        body:      r['body']    as String?,
        response:  r['response'] as String?,
        createdAt: DateTime.tryParse(r['created_at'] as String? ?? ''),
      );

  final String id;
  final String subject;
  final String status;
  final String? body;
  final String? response;
  final DateTime? createdAt;
}

final adminSupportTicketsProvider =
    FutureProvider.autoDispose<List<SupportTicketItem>>((ref) async {
  ref.keepAlive();
  final client  = ref.watch(supabaseClientProvider);
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null) return [];
  try {
    final rows = await client
        .from('support_tickets')
        .select('id, subject, body, status, response, created_at')
        .eq('group_id', groupId)
        .order('created_at', ascending: false)
        .limit(20) as List;
    return [for (final r in rows) SupportTicketItem.fromRow(r as Map<String, dynamic>)];
  } catch (_) {
    return [];
  }
});
