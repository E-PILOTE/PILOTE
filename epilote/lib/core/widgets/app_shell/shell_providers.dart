import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// État d'expansion de la sidebar (réservé : la largeur réelle est gérée
/// localement par l'AppShell pour permettre le drag-resize).
final sidebarExpandedProvider = StateProvider<bool>((_) => true);

/// Thème clair / sombre de l'application.
final themeModeProvider = StateProvider<ThemeMode>((_) => ThemeMode.light);

// ─── Visionneuse confinée au contenu ────────────────────────────────────────
// Une visionneuse (image / PDF) rendue dans la zone de contenu plutôt que via le
// Navigator racine occupe uniquement cette zone → la sidebar reste visible ET
// cliquable.
final contentOverlayProvider = StateProvider<Widget?>((_) => null);

/// Affiche [builder] par-dessus le contenu (sidebar préservée). [close] est
/// passé au builder pour refermer. Lisible depuis n'importe quel BuildContext.
void showContentOverlay(
  BuildContext context,
  Widget Function(VoidCallback close) builder,
) {
  final container = ProviderScope.containerOf(context, listen: false);
  void close() {
    if (container.read(contentOverlayProvider) != null) {
      container.read(contentOverlayProvider.notifier).state = null;
    }
  }

  container.read(contentOverlayProvider.notifier).state = builder(close);
}

void closeContentOverlay(BuildContext context) {
  final container = ProviderScope.containerOf(context, listen: false);
  container.read(contentOverlayProvider.notifier).state = null;
}
