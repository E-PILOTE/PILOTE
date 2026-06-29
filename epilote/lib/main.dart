import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:media_kit/media_kit.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/supabase_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_shell.dart';
import 'features/auth/screens/widgets/agent_lock_gate.dart';
import 'services/powersync/powersync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── 0. Lecteur vidéo natif multi-plateforme (Linux/Windows/Android/iOS/
  //      macOS/Web via libmpv) — remplace video_player qui ne couvre pas le
  //      desktop Linux/Windows. Doit précéder runApp.
  MediaKit.ensureInitialized();

  // ── 0·bis. Backend SQLite (FFI) pour desktop Linux/Windows — `sqflite` n'a
  //   aucune implémentation native sur ces cibles, ce qui faisait échouer le
  //   cache de `cached_network_image` → tous les avatars/logos tombaient sur
  //   leur repli (initiales). On branche `databaseFactoryFfi` pour le rendre
  //   fonctionnel en dev desktop. Sans effet sur mobile (déjà supporté).
  if (!kIsWeb && (Platform.isLinux || Platform.isWindows)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // ── 0a. Moteur PDF (pdfium via pdfrx) — requis pour rendre l'aperçu 1re
  //       page des PDF DANS le fil (PdfDocument.openUri direct). Sans cet
  //       appel, l'init n'est déclenchée que par les widgets pdfrx → l'appel
  //       direct échoue silencieusement (repli icône). Doit précéder runApp.
  await pdfrxFlutterInitialize();

  // ── 0b. Initialiser les locales intl ──────────────────────────────────────
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
      builder: (context, child) =>
          AgentLockGate(child: child ?? const SizedBox.shrink()),
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
