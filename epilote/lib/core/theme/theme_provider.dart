import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/active_agent_provider.dart';
import '../widgets/admin_ui.dart' show applyPalette;
import 'palette.dart';
import 'theme_prefs.dart';

/// Thème de l'agent au clavier.
///
/// Calqué sur `DeviceModeNotifier` : `build()` rend une valeur synchrone
/// (Clair) puis la préférence remonte du disque. La bascule d'agent
/// ré-interroge les préférences — chacun retrouve son thème après le PIN.
class ThemeIdNotifier extends Notifier<EpiloteThemeId> {
  @override
  EpiloteThemeId build() {
    final agentId = ref.watch(activeAgentIdProvider);
    _load(agentId);
    return EpiloteThemeId.clair;
  }

  Future<void> _load(String? agentId) async {
    final id = await loadThemeFor(agentId);
    applyPalette(EpilotePalette.of(id));
    state = id;
  }

  /// Choix de l'agent : applique, persiste, et laisse `main.dart` reconstruire
  /// l'arbre (la clé du `MaterialApp` change avec l'état).
  Future<void> set(EpiloteThemeId id) async {
    applyPalette(EpilotePalette.of(id));
    state = id;
    await saveThemeFor(ref.read(activeAgentIdProvider), id);
  }
}

final themeIdProvider =
    NotifierProvider<ThemeIdNotifier, EpiloteThemeId>(ThemeIdNotifier.new);
