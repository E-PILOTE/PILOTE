/// Constantes de connexion Supabase — E-PILOTE CONGO
/// Projet: PILOTE | Region: eu-central-2
class SupabaseConstants {
  SupabaseConstants._();

  static const String projectId = 'wqpdamlnrwgozfvzjjpo';
  static const String url = 'https://wqpdamlnrwgozfvzjjpo.supabase.co';

  // Clé anon (publique) — sûre à embarquer dans l'app Flutter
  // ⚠️ La clé service_role ne doit JAMAIS être ici (réservée aux Edge Functions)
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
      '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndxcGRhbWxucndnb3pmdnpqanBvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk0MTQwMTgsImV4cCI6MjA5NDk5MDAxOH0'
      '.W6JEoj9Hs3Ll3IDQ1GkYJDO1hW-HBrvbhOXALW4z5wQ';

  // Tables
  static const String profilesTable = 'profiles';
  static const String schoolGroupsTable = 'school_groups';
  static const String schoolsTable = 'schools';
  static const String subscriptionsTable = 'subscriptions';
  static const String subscriptionPlansTable = 'subscription_plans';
  static const String studentsTable = 'students';
  static const String classesTable = 'classes';
  static const String enrollmentsTable = 'enrollments';
  static const String gradesTable = 'grades';
  static const String reportCardsTable = 'report_cards';
  static const String attendanceTable = 'attendance_records';
  static const String studentPaymentsTable = 'student_payments';
  static const String announcementsTable = 'announcements';
  static const String notificationsTable = 'notifications';
  static const String auditLogsTable = 'audit_logs';

  // Storage buckets
  static const String avatarsBucket = 'avatars';
  static const String documentsBucket = 'documents';
  static const String bulletinsBucket = 'bulletins';
}
