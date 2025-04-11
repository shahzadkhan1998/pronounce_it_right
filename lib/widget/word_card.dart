import 'package:flutter/material.dart';
import 'package:pronounce_it_right/model/word_model.dart';
import 'package:provider/provider.dart';
import '../provider/audio_provider.dart';
import '../services/ad_services.dart';

class WordCard extends StatefulWidget {
  final Word word;
  final bool isSelected;
  final bool showHints;

  WordCard({
    Key? key,
    required this.word,
    required this.isSelected,
    this.showHints = false,
  }) : super(key: key);

  @override
  State<WordCard> createState() => _WordCardState();
}

class _WordCardState extends State<WordCard> {
  bool _isPlaying = false;
  bool _isRecording = false;
  double? _similarityScore;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: widget.isSelected ? 8 : 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.word.french,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (widget.showHints)
                  IconButton(
                    icon: const Icon(Icons.help_outline),
                    onPressed: _showPronunciationHint,
                  ),
              ],
            ),
            if (widget.isSelected) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildPlayButton(),
                  _buildRecordButton(),
                ],
              ),
              if (_similarityScore != null) ...[
                const SizedBox(height: 16),
                _buildScoreIndicator(),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlayButton() {
    return ElevatedButton.icon(
      onPressed: _isPlaying ? null : _playPronunciation,
      icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
      label: Text(_isPlaying ? 'Playing...' : 'Listen'),
    );
  }

  Widget _buildRecordButton() {
    return ElevatedButton.icon(
      onPressed: _isRecording ? _stopRecording : _startRecording,
      icon: Icon(_isRecording ? Icons.stop : Icons.mic),
      label: Text(_isRecording ? 'Stop' : 'Record'),
    );
  }

  Widget _buildScoreIndicator() {
    final score = _similarityScore!;
    return Column(
      children: [
        LinearProgressIndicator(
          value: score,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(
            score > 0.7
                ? Colors.green
                : (score > 0.4 ? Colors.orange : Colors.red),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Similarity: ${(score * 100).toStringAsFixed(1)}%',
          style: TextStyle(
            color: score > 0.7
                ? Colors.green
                : (score > 0.4 ? Colors.orange : Colors.red),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  void _showPronunciationHint() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('How to pronounce "${widget.word}"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Phonetic: [phonetic representation]'),
            const SizedBox(height: 8),
            Text('Tips: [pronunciation tips]'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  Future<void> _playPronunciation() async {
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    setState(() => _isPlaying = true);

    await audioProvider.playReference(widget.word.french);
    setState(() => _isPlaying = false);
  }

  Future<void> _startRecording() async {
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    try {
      await audioProvider.startRecording();
      setState(() => _isRecording = true);
    } catch (e) {
      _showError('Could not start recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    try {
      await audioProvider.stopRecording(widget.word.french);
      setState(() {
        _isRecording = false;
        _similarityScore = audioProvider.lastScore;
      });

      // Show interstitial ad after every 5 recordings
      if (mounted && _similarityScore != null && _similarityScore! > 0.7) {
        AdServices.showInterstitialAd();
      }
    } catch (e) {
      _showError('Could not stop recording: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
