import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/messages_provider.dart' show MessageAttachment;

// ════════════════════════════════════════════════════════════════════════════
//  Lecteur de note vocale INLINE (façon WhatsApp) : bouton play/pause + barre de
//  progression + chrono, directement dans la bulle.
//
//  Lecture ROBUSTE multi-plateforme (notamment Linux/GStreamer) : on TÉLÉCHARGE
//  d'abord les octets depuis le Storage privé puis on lit depuis un fichier
//  temporaire local (DeviceFileSource) — plus fiable que le streaming HTTP
//  signé, et ça nous laisse détecter un fichier vide/corrompu (note ratée) pour
//  afficher un message clair au lieu de tourner dans le vide. Mise en cache du
//  fichier temp (par cacheKey) → relecture instantanée. Un seul lecteur à la
//  fois (statique).
// ════════════════════════════════════════════════════════════════════════════

/// Cache des notes déjà téléchargées : cacheKey → chemin de fichier temp local.
final _voiceFileCache = <String, String>{};

class AudioMessagePlayer extends StatefulWidget {
  const AudioMessagePlayer({super.key, required this.att, this.mine = false});
  final MessageAttachment att;
  final bool mine;

  @override
  State<AudioMessagePlayer> createState() => _AudioMessagePlayerState();
}

class _AudioMessagePlayerState extends State<AudioMessagePlayer> {
  static _AudioMessagePlayerState? _active; // un seul lecteur actif à la fois

  final _player = AudioPlayer();
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  bool _playing = false;
  bool _loading = false;
  bool _ready = false; // source chargée au moins une fois
  bool _error = false; // note illisible (vide / corrompue / hors-ligne)

  @override
  void initState() {
    super.initState();
    // ReleaseMode.stop : à la fin de lecture, le lecteur s'arrête MAIS conserve
    // la source (sinon `release` la libère → la relecture ne joue plus rien :
    // c'est LA cause du « ça ne marche qu'une fois »).
    _player.setReleaseMode(ReleaseMode.stop);
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _pos = p);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _dur = d);
    });
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
    });
    _player.onPlayerComplete.listen((_) async {
      // Remet la tête de lecture à zéro pour pouvoir relancer.
      try {
        await _player.seek(Duration.zero);
      } catch (_) {}
      if (mounted) {
        setState(() {
          _playing = false;
          _pos = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    if (_active == this) _active = null;
    _player.dispose();
    super.dispose();
  }

  /// Télécharge (si besoin) la note dans un fichier temp local et la charge.
  /// Lève si le fichier est vide/corrompu (note ratée) ou non résolvable.
  Future<void> _ensureLoaded() async {
    if (_ready) return;
    final att = widget.att;
    final key = att.cacheKey;

    // Déjà téléchargée → réutilise le fichier temp.
    final cached = _voiceFileCache[key];
    if (cached != null && File(cached).existsSync()) {
      await _player.setSourceDeviceFile(cached);
      _ready = true;
      return;
    }

    final bucket = att.resolvedBucket;
    final path = att.resolvedPath;
    Uint8List? bytes;
    final client = Supabase.instance.client;
    if (bucket != null && path != null) {
      bytes = await client.storage.from(bucket).download(path);
    } else if (att.url.isNotEmpty) {
      // Legacy (URL publique/signée complète) : on télécharge via le lecteur.
      await _player.setSourceUrl(att.url);
      _ready = true;
      return;
    }

    // Fichier vide/corrompu = note ratée (capture sans son). On ne joue pas.
    if (bytes == null || bytes.length < 1500) {
      throw const _EmptyVoiceNote();
    }

    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/voice_${key.hashCode}.m4a');
    await f.writeAsBytes(bytes, flush: true);
    _voiceFileCache[key] = f.path;
    await _player.setSourceDeviceFile(f.path);
    _ready = true;
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      return;
    }
    if (_error) {
      // Nouvelle tentative après une erreur (réseau revenu, etc.).
      setState(() => _error = false);
    }
    // Idempotent : garantit le mode « stop » (conserve la source pour rejouer)
    // même si l'instance a été créée avant ce réglage.
    await _player.setReleaseMode(ReleaseMode.stop);
    // Coupe le lecteur précédent.
    if (_active != null && _active != this) {
      await _active!._player.pause();
    }
    _active = this;
    if (!_ready) {
      setState(() => _loading = true);
      try {
        await _ensureLoaded();
      } on _EmptyVoiceNote {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = true;
          });
        }
        return;
      } catch (_) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = true;
          });
        }
        return;
      }
      if (mounted) setState(() => _loading = false);
    }
    // Si la lecture précédente est terminée (tête en fin de piste), on rembobine
    // avant de relancer — garantit que « rejouer » reparte bien du début.
    if (_dur > Duration.zero && _pos >= _dur - const Duration(milliseconds: 250)) {
      await _player.seek(Duration.zero);
      if (mounted) setState(() => _pos = Duration.zero);
    }
    await _player.resume();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.mine ? const Color(0xFF128C7E) : kNavy;

    // ── État « note illisible » (vide / corrompue) ─────────────────────────────
    if (_error) {
      return Container(
        constraints: const BoxConstraints(maxWidth: 260, minWidth: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.mic_off_rounded, size: 20, color: kRed),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Note vocale indisponible',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF667781))),
          ),
          IconButton(
            tooltip: 'Réessayer',
            visualDensity: VisualDensity.compact,
            onPressed: _toggle,
            icon: Icon(Icons.refresh_rounded, size: 18, color: accent),
          ),
        ]),
      );
    }

    final total = _dur.inMilliseconds == 0 ? 1.0 : _dur.inMilliseconds.toDouble();
    final value = _pos.inMilliseconds.clamp(0, total.toInt()).toDouble();
    final remaining = _playing || _pos > Duration.zero
        ? _fmt(_dur - _pos)
        : (_dur > Duration.zero ? _fmt(_dur) : '');

    return Container(
      constraints: const BoxConstraints(maxWidth: 260, minWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        // Play / pause / chargement
        GestureDetector(
          onTap: _loading ? null : _toggle,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white, size: 24),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3,
                  activeTrackColor: accent,
                  inactiveTrackColor: accent.withValues(alpha: 0.22),
                  thumbColor: accent,
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 12),
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 6),
                ),
                child: Slider(
                  value: value,
                  max: total,
                  onChanged: _ready
                      ? (v) => _player.seek(Duration(milliseconds: v.toInt()))
                      : null,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 1),
                child: Row(children: [
                  Icon(Icons.mic_rounded, size: 13, color: accent),
                  const SizedBox(width: 4),
                  Text(remaining.isEmpty ? 'Note vocale' : remaining,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF667781))),
                ]),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

/// Marqueur : la note vocale est vide/corrompue (capture ratée) → non jouable.
class _EmptyVoiceNote implements Exception {
  const _EmptyVoiceNote();
}
