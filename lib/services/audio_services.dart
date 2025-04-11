import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_sound_platform_interface/flutter_sound_recorder_platform_interface.dart';
import 'package:flutter_sound_platform_interface/flutter_sound_platform_interface.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as pathProvider;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:pronounce_it_right/utils/audio_utils.dart';
import 'dart:io';

// Define RecordingPermissionException if it's not defined elsewhere
class RecordingPermissionException implements Exception {
  final String message;
  RecordingPermissionException(this.message);
  @override
  String toString() => 'RecordingPermissionException: $message';
}

class AudioService {
  // Keep flutter_sound for recording
  FlutterSoundRecorder? _mRecorder;
  String _mRecordingPath = 'recorded_audio.aac';
  bool _isRecorderInitialized = false;

  // --- TTS Specific ---
  late FlutterTts _flutterTts;
  bool _isTtsInitialized = false;

  // Store voices for each language
  final Map<String, List<Map<dynamic, dynamic>>> _languageVoices = {};
  final Map<String, int> _currentVoiceIndices = {};

  // Language code mapping
  final Map<String, String> _languageCodes = {
    'English': 'en-US',
    'French': 'fr-FR',
    'Spanish': 'es-ES',
    'German': 'de-DE',
    'Italian': 'it-IT',
    'Portuguese': 'pt-PT',
    'Russian': 'ru-RU',
    'Chinese': 'zh-CN',
    'Japanese': 'ja-JP',
    'Korean': 'ko-KR',
    'Arabic': 'ar-SA',
    'Hindi': 'hi-IN',
  };

  VoidCallback? _onPlaybackComplete;

  // --- Constructor ---
  AudioService() {
    _flutterTts = FlutterTts();
    _setupTtsListeners();
  }

  void _setupTtsListeners() {
    _flutterTts.setStartHandler(() {
      print("TTS: Playback Started");
    });

    _flutterTts.setCompletionHandler(() {
      print("TTS: Playback Completed");
      _onPlaybackComplete?.call();
      _onPlaybackComplete = null;
    });

    _flutterTts.setErrorHandler((msg) {
      print("TTS: Playback Error: $msg");
      _onPlaybackComplete?.call();
      _onPlaybackComplete = null;
    });

    _flutterTts.setCancelHandler(() {
      print("TTS: Playback Cancelled");
      _onPlaybackComplete?.call();
      _onPlaybackComplete = null;
    });
  }
  // --- END Constructor ---

  // --- MODIFIED: Async TTS Initialization (Stores French Voices) ---
  Future<void> _initializeTts() async {
    if (_isTtsInitialized) return;

    print("TTS: Initializing and discovering voices...");

    // Set initial parameters
    try {
      if (Platform.isIOS) {
        await _flutterTts.setSharedInstance(true);
        await _flutterTts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.ambient,
          [
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
            IosTextToSpeechAudioCategoryOptions.defaultToSpeaker
          ],
        );
      }

      await _flutterTts.setLanguage("fr-FR");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setVolume(1.0);
    } catch (e) {
      print("TTS: Error setting initial parameters: $e");
    }

    // Discover voices for all supported languages
    try {
      var voices = await _flutterTts.getVoices;
      if (voices != null && voices is List && voices.isNotEmpty) {
        print("TTS: Total available voices count: ${voices.length}");

        // Clear any previous voice data
        _languageVoices.clear();
        _currentVoiceIndices.clear();

        // Initialize voice lists for each language
        for (var langName in _languageCodes.keys) {
          _languageVoices[langName] = [];
          _currentVoiceIndices[langName] = 0;
        }

        // Categorize voices by language
        for (var voice in voices) {
          if (voice is Map) {
            final locale = voice['locale']?.toString().toLowerCase() ?? '';

            // Find matching language
            for (var entry in _languageCodes.entries) {
              if (locale.contains(entry.value.toLowerCase())) {
                _languageVoices[entry.key]?.add(voice);
                print("TTS: Added voice for ${entry.key}: ${voice['name']}");
                break;
              }
            }
          }
        }

        // Print summary of found voices
        _languageVoices.forEach((lang, voices) {
          print("TTS: Found ${voices.length} voices for $lang");
        });
      }
    } catch (e) {
      print("TTS: Error during voice discovery: $e");
    }

    _isTtsInitialized = true;
    print("TTS: Initialization complete");
  }
  // --- END MODIFIED: Async TTS Initialization ---

  Future<void> initializeAudio(BuildContext context) async {
    print("AudioService: Initializing audio (Recorder & TTS)...");

    // Initialize TTS first
    try {
      await _initializeTts();
    } catch (e) {
      print("AudioService: Error during TTS initialization: $e");
    }

    _mRecorder = FlutterSoundRecorder();

    // --- Permission checks (Keep for Recorder) ---
    if (!kIsWeb) {
      // Request both microphone and speech permissions for iOS
      if (Platform.isIOS) {
        var speechStatus = await Permission.speech.status;
        if (!speechStatus.isGranted) {
          speechStatus = await _requestPermission(
              context, Permission.speech, 'Speech Recognition');
          if (!speechStatus.isGranted) {
            throw RecordingPermissionException('Speech permission denied');
          }
        }
      }

      var microphoneStatus = await Permission.microphone.status;
      print("AudioService: Microphone status: $microphoneStatus");
      if (!microphoneStatus.isGranted) {
        microphoneStatus = await _requestPermission(
            context, Permission.microphone, 'Microphone');
        print(
            "AudioService: Microphone status after request: $microphoneStatus");
      }

      if (microphoneStatus != PermissionStatus.granted) {
        throw RecordingPermissionException('Microphone permission not granted');
      }

      try {
        final tempDir = await getTemporaryDirectory();
        _mRecordingPath = pathProvider.join(tempDir.path, 'recorded_audio.aac');
        print("AudioService: Recording path set to: $_mRecordingPath");
      } catch (e) {
        print("AudioService: Error getting directory path: $e");
      }
    }

    // --- Initialize recorder ---
    try {
      print("AudioService: Opening recorder...");
      await _mRecorder!.openRecorder();

      _isRecorderInitialized = true;
      print("AudioService: Recorder opened successfully.");
    } catch (e) {
      print("AudioService: Error opening recorder: $e");
      _isRecorderInitialized = false;
      rethrow;
    }

    print(
        "AudioService: Initialization finished. Recorder init: $_isRecorderInitialized");
  }

  // --- startRecording / stopRecording / stopRecordingAndCompare remain the same ---
  Future<void> startRecording() async {
    print(
        "AudioService: startRecording called. Initialized: $_isRecorderInitialized");
    if (!_isRecorderInitialized || _mRecorder == null) {
      throw Exception('Recorder not initialized or null');
    }
    try {
      print("AudioService: Starting recorder to file: $_mRecordingPath");
      await _mRecorder!.startRecorder(
        toFile: _mRecordingPath,
        codec: Codec.aacADTS,
      );
      print("AudioService: Recorder started.");
    } catch (e) {
      print("AudioService: Error starting recorder: $e");
      rethrow;
    }
  }

  Future<void> stopRecording() async {
    print(
        "AudioService: stopRecording called. Initialized: $_isRecorderInitialized");
    if (!_isRecorderInitialized || _mRecorder == null) {
      throw Exception('Recorder not initialized or null');
    }
    try {
      print("AudioService: Stopping recorder...");
      final path = await _mRecorder!.stopRecorder();
      print("AudioService: Recorder stopped. File at: $path");
    } catch (e) {
      print("AudioService: Error stopping recorder: $e");
      rethrow;
    }
  }

  Future<double> stopRecordingAndCompare(String word) async {
    print("AudioService: stopRecordingAndCompare called for '$word'.");
    if (!_isRecorderInitialized) {
      throw Exception('Recorder not initialized');
    }

    try {
      // Stop the recording
      await stopRecording();
      print(
          "AudioService: Recording stopped. File saved at '$_mRecordingPath'.");

      // Generate TTS audio for the reference word
      final ttsFilePath = await _generateTtsAudio(word);
      print("AudioService: TTS audio generated at '$ttsFilePath'.");

      // Read and parse audio samples from both files
      final recordedBytes = await File(_mRecordingPath).readAsBytes();
      final ttsBytes = await File(ttsFilePath).readAsBytes();

      final recordedSamples =
          AudioUtils.trimSilence(AudioUtils.parseWavBytes(recordedBytes), 0.01);
      final ttsSamples =
          AudioUtils.trimSilence(AudioUtils.parseWavBytes(ttsBytes), 0.01);

      // Extract MFCC features
      final recordedMFCC = await AudioUtils.extractMFCC(recordedSamples, 16000);
      final ttsMFCC = await AudioUtils.extractMFCC(ttsSamples, 16000);

      // Calculate similarity score using MFCC and DTW
      final score =
          AudioUtils.calculateSimilarityWithMFCC(recordedMFCC, ttsMFCC);
      print("AudioService: Comparison complete. Score: $score");

      return score;
    } catch (e) {
      print('AudioService: Error during recording and comparison: $e');
      rethrow;
    }
  }

  Future<String> _generateTtsAudio(String word) async {
    final tempDir = await getTemporaryDirectory();
    final ttsFilePath = '${tempDir.path}/tts_audio.wav';

    // Generate TTS audio and save it as a WAV file
    await _flutterTts.setLanguage("fr-FR"); // Set language to French
    await _flutterTts.synthesizeToFile(word, ttsFilePath);

    return ttsFilePath;
  }

  // --- MODIFIED: Plays reference audio using TTS with cycling voice ---
  Future<void> playReferenceAudio(String word, VoidCallback onFinished) async {
    _onPlaybackComplete = onFinished;
    await playMultiLanguageTTS(word, 'French');
  }

  Future<void> playMultiLanguageTTS(String text, String language) async {
    print("TTS: Starting multi-language TTS for $language");

    if (!_isTtsInitialized) {
      int waitCount = 0;
      while (!_isTtsInitialized && waitCount < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        waitCount++;
      }
      if (!_isTtsInitialized) {
        throw Exception("TTS not initialized");
      }
    }

    try {
      // Get language code
      final languageCode = _languageCodes[language];
      if (languageCode == null) {
        throw Exception("Unsupported language: $language");
      }

      // Stop any ongoing playback
      await _flutterTts.stop();

      // Set language and voice if available
      await _flutterTts.setLanguage(languageCode);

      final voices = _languageVoices[language] ?? [];
      if (voices.isNotEmpty) {
        final currentIndex = _currentVoiceIndices[language] ?? 0;
        final voiceToUse = voices[currentIndex];

        try {
          final voiceMap = Map<String, String>.from(voiceToUse
              .map((key, value) => MapEntry(key.toString(), value.toString())));
          await _flutterTts.setVoice(voiceMap);

          // Update index for next time
          _currentVoiceIndices[language] = (currentIndex + 1) % voices.length;
        } catch (e) {
          print("TTS: Error setting voice for $language: $e");
          // Continue with default voice
        }
      }

      // Speak the text
      var result = await _flutterTts.speak(text);
      if (result != 1) {
        throw Exception("Failed to start TTS playback");
      }
    } catch (e) {
      print("TTS: Error during multi-language playback: $e");
      rethrow;
    }
  }

  // --- MODIFIED: Stop TTS playback ---
  Future<void> stopPlaying() async {
    print("AudioService: stopPlaying (TTS) called.");
    try {
      var result = await _flutterTts.stop();
      if (result == 1) {
        print("AudioService: TTS stopped successfully.");
      } else {
        print("AudioService: TTS stop command failed.");
      }
      _onPlaybackComplete = null; // Clear callback on manual stop
    } catch (e) {
      print('AudioService: TTS stop error: $e');
      _onPlaybackComplete = null; // Clear on error too
    }
  }

  // --- MODIFIED: Dispose recorder and potentially stop TTS ---
  dispose() {
    print("AudioService: Disposing recorder and stopping TTS...");
    _flutterTts.stop();

    try {
      _mRecorder?.closeRecorder();
    } catch (e) {
      print("AudioService: Error closing recorder: $e");
    }
    _mRecorder = null;
    _isRecorderInitialized = false;
    _onPlaybackComplete = null;
    _isTtsInitialized = false; // Reset TTS init flag
    _languageVoices.clear(); // Clear stored voices
    _currentVoiceIndices.clear(); // Reset indices

    print("AudioService: Dispose finished.");
  }

  // --- Permission helpers remain the same ---
  Future<PermissionStatus> _requestPermission(BuildContext context,
      Permission permission, String permissionName) async {
    final status = await permission.status;
    if (status.isPermanentlyDenied) {
      print("AudioService: Permission '$permissionName' permanently denied.");
      _showPermissionRationale(context,
          "This app needs $permissionName access to function. Please enable it in the app settings.");
      return status;
    }
    if (status.isDenied || status.isRestricted || status.isLimited) {
      print("AudioService: Requesting permission '$permissionName'...");
      return await permission.request();
    }
    return status;
  }

  void _showPermissionRationale(BuildContext context, String message) {
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Permission Required'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Open Settings'),
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
            ),
          ],
        );
      },
    );
  }
} // End AudioService
