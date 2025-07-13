import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';

/// Voice playback service for playing received audio messages
class VoicePlayer {
  FlutterSoundPlayer? _player;
  bool _isInitialized = false;
  bool _isPlaying = false;

  bool get isInitialized => _isInitialized;
  bool get isPlaying => _isPlaying;

  /// Initialize the player
  Future<bool> initialize() async {
    try {
      _player = FlutterSoundPlayer();
      await _player!.openPlayer();
      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('Failed to initialize voice player: $e');
      return false;
    }
  }

  /// Play audio data from memory
  Future<void> playAudio(Uint8List audioData) async {
    if (!_isInitialized || _isPlaying) return;

    try {
      _isPlaying = true;
      
      if (kIsWeb) {
        // For web, play Opus WebM data
        await _player!.startPlayer(
          fromDataBuffer: audioData,
          codec: Codec.opusWebM,
          whenFinished: () {
            _isPlaying = false;
          },
        );
      } else {
        // For mobile, play AAC data
        await _player!.startPlayer(
          fromDataBuffer: audioData,
          codec: Codec.aacADTS,
          whenFinished: () {
            _isPlaying = false;
          },
        );
      }
    } catch (e) {
      debugPrint('Failed to play audio: $e');
      _isPlaying = false;
    }
  }

  /// Stop current playback
  Future<void> stopPlayback() async {
    if (!_isPlaying) return;

    try {
      await _player!.stopPlayer();
      _isPlaying = false;
    } catch (e) {
      debugPrint('Failed to stop playback: $e');
    }
  }

  /// Dispose of resources
  Future<void> dispose() async {
    if (_isPlaying) {
      await stopPlayback();
    }
    
    if (_isInitialized) {
      await _player?.closePlayer();
      _isInitialized = false;
    }
    
    _player = null;
  }
}
