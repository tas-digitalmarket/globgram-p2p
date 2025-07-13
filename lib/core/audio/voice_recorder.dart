import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

/// Voice recording service with cross-platform support
class VoiceRecorder {
  FlutterSoundRecorder? _recorder;
  StreamController<Uint8List>? _recordingStreamController;
  bool _isRecording = false;
  bool _isInitialized = false;

  Stream<Uint8List>? get recordingStream => _recordingStreamController?.stream;
  bool get isRecording => _isRecording;
  bool get isInitialized => _isInitialized;

  /// Initialize the recorder
  Future<bool> initialize() async {
    try {
      _recorder = FlutterSoundRecorder();
      
      // Request microphone permission
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        debugPrint('Microphone permission denied');
        return false;
      }

      await _recorder!.openRecorder();
      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('Failed to initialize voice recorder: $e');
      return false;
    }
  }

  /// Start recording voice
  Future<bool> startRecording() async {
    if (!_isInitialized || _isRecording) return false;

    try {
      _recordingStreamController = StreamController<Uint8List>();
      
      if (kIsWeb) {
        // For web, use opus in webm container
        await _recorder!.startRecorder(
          toStream: _recordingStreamController!.sink,
          codec: Codec.opusWebM,
          sampleRate: 16000,
        );
      } else {
        // For mobile, use AAC format
        await _recorder!.startRecorder(
          toStream: _recordingStreamController!.sink,
          codec: Codec.aacADTS,
          sampleRate: 16000,
        );
      }
      
      _isRecording = true;
      return true;
    } catch (e) {
      debugPrint('Failed to start recording: $e');
      return false;
    }
  }

  /// Stop recording and return the audio data
  Future<Uint8List?> stopRecording() async {
    if (!_isRecording) return null;

    try {
      await _recorder!.stopRecorder();
      _isRecording = false;
      
      // Collect all recorded data
      final recordedData = <int>[];
      await for (final chunk in _recordingStreamController!.stream) {
        recordedData.addAll(chunk);
      }
      
      await _recordingStreamController?.close();
      _recordingStreamController = null;
      
      return Uint8List.fromList(recordedData);
    } catch (e) {
      debugPrint('Failed to stop recording: $e');
      return null;
    }
  }

  /// Cancel current recording
  Future<void> cancelRecording() async {
    if (!_isRecording) return;

    try {
      await _recorder!.stopRecorder();
      _isRecording = false;
      
      await _recordingStreamController?.close();
      _recordingStreamController = null;
    } catch (e) {
      debugPrint('Failed to cancel recording: $e');
    }
  }

  /// Dispose of resources
  Future<void> dispose() async {
    if (_isRecording) {
      await cancelRecording();
    }
    
    if (_isInitialized) {
      await _recorder?.closeRecorder();
      _isInitialized = false;
    }
    
    _recorder = null;
  }
}
