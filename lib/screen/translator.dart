import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../provider/chat_provider.dart';
import '../services/audio_services.dart';

class TranslatorScreen extends StatefulWidget {
  const TranslatorScreen({super.key});

  @override
  State<TranslatorScreen> createState() => _TranslatorScreenState();
}

class _TranslatorScreenState extends State<TranslatorScreen> {
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _translatedController = TextEditingController();
  String _selectedSourceLanguage = 'Detect Language';
  String _selectedTargetLanguage = 'English';
  bool _isTranslating = false;
  final AudioService _audioService = AudioService();

  final List<String> _languages = [
    'Detect Language',
    'English',
    'French',
    'Spanish',
    'German',
    'Italian',
    'Portuguese',
    'Russian',
    'Chinese',
    'Japanese',
    'Korean',
    'Arabic',
    'Hindi'
  ];

  @override
  void initState() {
    super.initState();
    _audioService.initializeAudio(context);
  }

  @override
  void dispose() {
    _sourceController.dispose();
    _translatedController.dispose();
    _audioService.dispose();
    super.dispose();
  }

  Future<void> _handleTranslation() async {
    if (_sourceController.text.trim().isEmpty) return;

    setState(() {
      _isTranslating = true;
    });

    Future<void> attemptTranslation() async {
      try {
        final chatProvider = Provider.of<ChatProvider>(context, listen: false);
        final translation = await chatProvider.translate(
          _sourceController.text.trim(),
          _selectedSourceLanguage,
          _selectedTargetLanguage,
        );

        if (!mounted) return;

        setState(() {
          _translatedController.text = translation;
          _isTranslating = false;
        });
      } catch (e) {
        if (!mounted) return;

        // Handle empty translation specially
        if (e.toString().contains('empty translation')) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Translation Failed'),
                content: const Text(
                  'Received an empty translation. Would you like to try again?'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      attemptTranslation(); // Retry translation
                    },
                    child: const Text('Retry'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      setState(() {
                        _isTranslating = false;
                      });
                    },
                    child: const Text('Cancel'),
                  ),
                ],
              );
            },
          );
        } else {
          // Handle other errors
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Translation error: $e')),
          );
          setState(() {
            _isTranslating = false;
          });
        }
      }
    }

    // Start initial translation attempt
    await attemptTranslation();
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  Future<void> _playTTS(String text, String language) async {
    try {
      await _audioService.playMultiLanguageTTS(text, language);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error playing TTS: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Language Selection Row
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedSourceLanguage,
                          isExpanded: true,
                          items: _languages.map((String language) {
                            return DropdownMenuItem<String>(
                              value: language,
                              child: Text(language),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedSourceLanguage = newValue;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: IconButton(
                      icon: const Icon(Icons.swap_horiz),
                      onPressed: () {
                        if (_selectedSourceLanguage != 'Detect Language') {
                          setState(() {
                            final temp = _selectedSourceLanguage;
                            _selectedSourceLanguage = _selectedTargetLanguage;
                            _selectedTargetLanguage = temp;
                          });
                        }
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.primaryContainer,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedTargetLanguage,
                          isExpanded: true,
                          items: _languages
                              .where((lang) => lang != 'Detect Language')
                              .map((String language) {
                            return DropdownMenuItem<String>(
                              value: language,
                              child: Text(language),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedTargetLanguage = newValue;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Source Text Field
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _sourceController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    hintText: 'Enter text to translate',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.content_copy),
                    onPressed: () => _copyToClipboard(_sourceController.text),
                    tooltip: 'Copy text',
                  ),
                  IconButton(
                    icon: const Icon(Icons.volume_up),
                    onPressed: () => _playTTS(
                        _sourceController.text, _selectedSourceLanguage),
                    tooltip: 'Listen',
                  ),
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _sourceController.clear();
                      _translatedController.clear();
                    },
                    tooltip: 'Clear text',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Translate Button
              ElevatedButton.icon(
                onPressed: _isTranslating ? null : _handleTranslation,
                icon: _isTranslating
                    ? Container(
                        width: 24,
                        height: 24,
                        padding: const EdgeInsets.all(2.0),
                        child: const CircularProgressIndicator(strokeWidth: 3),
                      )
                    : const Icon(Icons.translate),
                label: Text(_isTranslating ? 'Translating...' : 'Translate'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                ),
              ),
              const SizedBox(height: 24),
              // Translation Result
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Translation',
                          style: theme.textTheme.titleMedium,
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.volume_up),
                              onPressed: _translatedController.text.isEmpty
                                  ? null
                                  : () => _playTTS(_translatedController.text,
                                      _selectedTargetLanguage),
                              tooltip: 'Listen',
                            ),
                            IconButton(
                              icon: const Icon(Icons.content_copy),
                              onPressed: _translatedController.text.isEmpty
                                  ? null
                                  : () => _copyToClipboard(
                                      _translatedController.text),
                              tooltip: 'Copy translation',
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: TextField(
                        controller: _translatedController,
                        maxLines: null,
                        expands: true,
                        readOnly: true,
                        style: _translatedController.text.isEmpty
                            ? const TextStyle(color: Colors.grey)
                            : null,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Translation will appear here',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
