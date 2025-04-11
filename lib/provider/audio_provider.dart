import 'package:flutter/material.dart';
import 'package:pronounce_it_right/services/audio_services.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioProvider with ChangeNotifier {
  final AudioService _audioService = AudioService();
  bool _isRecording = false;
  bool _isPlaying = false;
  double? _lastScore;
  bool _initializationFailedDueToPermission = false;
  final Map<String, double?> _wordScores =
      {}; // Map to store scores for each word

  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;
  double? get lastScore => _lastScore;
  bool get initializationFailedDueToPermission =>
      _initializationFailedDueToPermission;
  double? getScoreForWord(String word) => _wordScores[word];

  Future<void> initializeAudio(BuildContext context) async {
    print("AudioProvider: Initializing audio...");
    _initializationFailedDueToPermission =
        false; // Reset flag on re-initialization attempt

    // Check and request microphone permission
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      print("AudioProvider: Microphone permission denied.");
      _initializationFailedDueToPermission = true;
      notifyListeners(); // Notify UI about the failure state
      return;
    }

    try {
      await _audioService.initializeAudio(context);
      print("AudioProvider: Audio initialization successful.");
      notifyListeners(); // Notify listeners on success
    } catch (e) {
      print('AudioProvider: Audio initialization error: $e');
      if (e is RecordingPermissionException) {
        print(
            'AudioProvider: Initialization failed specifically due to permissions.');
        _initializationFailedDueToPermission = true;
      } else {
        _initializationFailedDueToPermission =
            false; // Ensure it's false for other errors
      }
      notifyListeners(); // Notify UI about the failure state
    }
  }

  Future<void> startRecording() async {
    print("AudioProvider: Attempting to start recording...");
    print(
        "AudioProvider: Current state: isPlaying=$_isPlaying, isRecording=$_isRecording, permFail=$_initializationFailedDueToPermission");

    if (_initializationFailedDueToPermission) {
      print(
          "AudioProvider: Cannot start recording due to initialization permission failure.");
      return;
    }

    if (_isPlaying) {
      print(
          "AudioProvider: Cannot start recording while playing reference. Returning.");
      return;
    }
    try {
      print("AudioProvider: Setting _isRecording = true");
      _isRecording = true;
      notifyListeners();
      print("AudioProvider: Calling _audioService.startRecording()...");
      await _audioService.startRecording();
      print(
          "AudioProvider: Recording started successfully (service call returned).");
    } catch (e) {
      print('AudioProvider: Start recording error: $e');
      print("AudioProvider: Setting _isRecording = false due to error");
      _isRecording = false;
      notifyListeners();
    }
  }

  Future<void> stopRecording(String word) async {
    print("AudioProvider: Attempting to stop recording for '$word'...");
    try {
      final score = await _audioService.stopRecordingAndCompare(word);
      _lastScore = score; // Store the last score
      print("AudioProvider: Recording stopped successfully. Score: $score");
      _wordScores[word] = score; // Store the score for the word
      print("AudioProvider: Recording stopped. Score: $score");
    } catch (e) {
      print('AudioProvider: Stop recording error: $e');
      _wordScores[word] = null; // Clear score on error
    } finally {
      if (_isRecording) {
        _isRecording = false;
        notifyListeners();
      }
    }
  }

  Future<void> playReference(String word) async {
    print("AudioProvider: Attempting to play reference for '$word'...");
    if (_isRecording) {
      print("AudioProvider: Cannot play reference while recording.");
      return;
    }
    if (_isPlaying) {
      print("AudioProvider: Already playing reference.");
      return;
    }

    try {
      _isPlaying = true;
      notifyListeners();

      await _audioService.playReferenceAudio(word, () {
        print(
            "AudioProvider: Playback finished callback received for '$word'.");
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_isPlaying) {
            _isPlaying = false;
            notifyListeners();
          }
        });
      });
      print("AudioProvider: playReferenceAudio call initiated for '$word'.");
    } catch (e) {
      print('AudioProvider: Playback error initiating playReference: $e');
      if (_isPlaying) {
        _isPlaying = false;
        notifyListeners();
      }
    }
  }

  Future<void> disposeAudio() async {
    print("AudioProvider: Disposing audio service.");
    if (_isPlaying) {
      await _audioService.stopPlaying();
      _isPlaying = false;
    }
    _isRecording = false;
    _initializationFailedDueToPermission = false;
    _lastScore = null;
    await _audioService.dispose();
    print("AudioProvider: Dispose complete.");
  }
}
