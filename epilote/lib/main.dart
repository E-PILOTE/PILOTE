import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/supabase_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_shell.dart';
import 'services/powersync/powersync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── 0. Initialiser les locales intl ───────────────────────────────────────
  await initializeDateFormatting('fr_FR', null);

  // ── 1. Initialiser Supabase ────────────────────────────────────────────
  await Supabase.initialize(
    url: SupabaseConstants.url,
    anonKey: SupabaseConstants.anonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  // ── 2. Initialiser PowerSync (offline-first SQLite) ────────────────────
  await initPowerSync();

  runApp(
    const ProviderScope(
      child: EpiloteApp(),
    ),
  );
}

class EpiloteApp extends ConsumerWidget {
  const EpiloteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'E-PILOTE CONGO',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      locale: const Locale('fr'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr'), Locale('en')],
    );
  }
}
