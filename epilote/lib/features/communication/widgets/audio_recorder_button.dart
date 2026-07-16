import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/messages_provider.dart'
    show MessageAttachment, uploadMessageAttachment;

// ════════════════════════════════════════════════════════════════════════════
//  Note vocale façon WhatsApp : on MAINTIENT le micro pour enregistrer, on
//  RELÂCHE pour envoyer, on GLISSE à gauche pour annuler. Pendant l'enregistre-
//  ment, un bandeau (chrono + « glisser pour annuler ») recouvre la zone de
//  saisie. Upload Storage (bucket privé) → nécessite internet.
// ════════════════════════════════════════════════════════════════════════════

class AudioRecorderButton extends StatefulWidget {
  const AudioRecorderButton({
    super.key,
    required this.client,
    required this.groupId,
    required this.onRecorded,
    required this.onError,
    required this.onRecordingChanged,
    required this.onProgress,
  });

  final SupabaseClient client;
  final String groupId;
  final ValueChanged<MessageAttachment> onRecorded;
  final ValueChanged<String> onError;

  /// Notifie le parent (true = enregistrement en cours) → masque la barre de
  /// saisie et affiche le bandeau d'enregistrement.
  final ValueChanged<bool> onRecordingChanged;

  /// Progression (chrono + état d'annulation) → le parent rend le bandeau.
  final void Function(Duration elapsed, bool cancel) onProgress;

  @override
  State<AudioRecorderButton> createState() => _AudioRecorderButtonState();
}

class _AudioRecorderButtonState extends State<AudioRecorderButton> {
  final _rec = AudioRecorder();
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  bool _recording = false;
  bool _cancel = false;
  bool _busy = false;
  String? _path;

  @override
  void dispose() {
    _timer?.cancel();
    _rec.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_busy || _recording) return;
    setState(() => _busy = true);
    try {
      if (!await _rec.hasPermission()) {
        widget.onError('Micro indisponible (autorisez l\'accès au microphone).');
        return;
      }
      final dir = await getTemporaryDirectory();
      final p =
          '${dir.path}/note_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _rec.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 96000),
        path: p,
      );
      _path = p;
      _elapsed = Duration.zero;
      _cancel = false;
      _recording = true;
      widget.onRecordingChanged(true);
      widget.onProgress(_elapsed, _cancel);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() => _elapsed += const Duration(seconds: 1));
          widget.onProgress(_elapsed, _cancel);
        }
      });
      setState(() {});
    } catch (e) {
      widget.onError('Enregistrement vocal indisponible sur cet appareil.');
      _recording = false;
      widget.onRecordingChanged(false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop({required bool cancel}) async {
    if (!_recording) return;
    _timer?.cancel();
    final tooShort = _elapsed.inMilliseconds < 800;
    setState(() {
      _recording = false;
      _busy = true;
    });
    widget.onRecordingChanged(false);
    String? path;
    try {
      path = await _rec.stop();
    } catch (_) {}
    path ??= _path;
    if (cancel || tooShort || path == null) {
      if (path != null) {
        try {
          await File(path).delete();
        } catch (_) {}
      }
      if (mounted) setState(() => _busy = false);
      if (tooShort && !cancel) {
        widget.onError('Maintenez le micro pour enregistrer.');
      }
      return;
    }
    try {
      final bytes = await File(path).readAsBytes();
      // Garde-fou « capture vide » : un m4a sans flux audio fait ~40–300 octets
      // (micro muet / relâché avant le 1er buffer). Inutile (et trompeur) de
      // l'envoyer — il serait illisible. Un vrai enregistrement ≥0,8 s pèse
      // plusieurs Ko (AAC 96 kbps ≈ 12 Ko/s).
      if (bytes.length < 2000) {
        try {
          await File(path).delete();
        } catch (_) {}
        widget.onError(
            'Aucun son capté — vérifiez le micro et maintenez le bouton.');
        if (mounted) setState(() => _busy = false);
        return;
      }
      final att = await uploadMessageAttachment(
        client:   widget.client,
        groupId:  widget.groupId,
        fileName: 'Note vocale.m4a',
        bytes:    bytes,
        mime:     'audio/mp4',
        bucket:   'message-attachments',
      );
      widget.onRecorded(att);
      try {
        await File(path).delete();
      } catch (_) {}
    } catch (e) {
      widget.onError('Envoi de la note vocale impossible (connexion requise).');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Le bouton micro garde TOUJOURS le geste (stable pendant tout l'appui).
    // Le bandeau d'enregistrement est rendu par le parent via onProgress.
    final active = _recording || _busy;
    return GestureDetector(
      onLongPressStart: (_) => _start(),
      onLongPressEnd: (_) => _stop(cancel: _cancel),
      onLongPressMoveUpdate: (d) {
        final c = d.offsetFromOrigin.dx < -90;
        if (c != _cancel) {
          setState(() => _cancel = c);
          if (_recording) widget.onProgress(_elapsed, _cancel);
        }
      },
      child: Container(
        decoration: BoxDecoration(
            color: active ? kRed : const Color(0xFF00A884),
            shape: BoxShape.circle),
        padding: const EdgeInsets.all(12),
        child: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Icon(_recording ? Icons.mic : Icons.mic_rounded,
                size: 18, color: Colors.white),
      ),
    );
  }
}

/// Bandeau d'enregistrement (rendu par le parent au-dessus de la barre de
/// saisie) : point pulsant + chrono + indication « glisser pour annuler ».
class AudioRecordingBanner extends StatelessWidget {
  const AudioRecordingBanner(
      {super.key, required this.elapsed, required this.cancel});
  final Duration elapsed;
  final bool cancel;

  String get _fmt {
    final m = elapsed.inMinutes.remainder(60).toString();
    final s = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(22)),
        child: Row(children: [
          const _PulsingDot(),
          const SizedBox(width: 10),
          Text(_fmt,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary)),
          const Spacer(),
          Icon(Icons.chevron_left_rounded,
              size: 18, color: cancel ? kRed : kTextMuted),
          Text(cancel ? 'Relâchez pour annuler' : 'Glisser pour annuler',
              style: TextStyle(fontSize: 12, color: cancel ? kRed : kTextMuted)),
        ]),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: 0.35, end: 1.0).animate(_c),
        child: Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(color: kRed, shape: BoxShape.circle),
        ),
      );
}
