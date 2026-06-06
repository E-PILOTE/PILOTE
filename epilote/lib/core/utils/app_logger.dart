import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Logger applicatif partagé.
///
/// Conforme à CLAUDE.md : on n'utilise jamais `print()` directement.
/// En release, seuls les niveaux ≥ warning sont émis (les traces de debug
/// n'encombrent pas la sortie de production).
final Logger appLogger = Logger(
  level: kReleaseMode ? Level.warning : Level.debug,
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 5,
    lineLength: 80,
    colors: false,
    printEmojis: false,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
);
