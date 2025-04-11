import 'package:flutter/material.dart';
import 'package:pronounce_it_right/provider/audio_provider.dart';
import 'package:pronounce_it_right/widget/word_card.dart';
import 'package:provider/provider.dart';
import 'package:pronounce_it_right/services/ad_services.dart';
import '../provider/word_provider.dart';

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  int? _selectedIndex;
  bool _hasUnlockedPremiumFeatures = false;

  @override
  void initState() {
    super.initState();
    Provider.of<AudioProvider>(context, listen: false).initializeAudio(context);
    AdServices.loadRewardedAd(); // Load rewarded ad
  }

  Future<void> _showUnlockPremiumDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unlock Premium Features'),
        content: const Text(
            'Watch a short video to unlock pronunciation hints and premium words!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _watchRewardedAd();
            },
            child: const Text('Watch Ad'),
          ),
        ],
      ),
    );
  }

  Future<void> _watchRewardedAd() async {
    await AdServices.showRewardedAd().then((_) {
      setState(() {
        _hasUnlockedPremiumFeatures = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Premium features unlocked! Enjoy pronunciation hints and new words!'),
        ),
      );
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load ad. Please try again later.'),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildFilters(),
            if (!_hasUnlockedPremiumFeatures)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ElevatedButton(
                  onPressed: _showUnlockPremiumDialog,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(40),
                  ),
                  child: const Text('Unlock Premium Features'),
                ),
              ),
            Expanded(
              child: _buildWordsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'French Pronunciation',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Practice your accent',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Consumer<WordsProvider>(
      builder: (context, wordsProvider, child) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  value: wordsProvider.selectedCategory,
                  items: ['All', 'Food', 'Greetings', 'Numbers']
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c),
                          ))
                      .toList(),
                  onChanged: (value) =>
                      wordsProvider.setCategory(value ?? 'All'),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: DropdownButton<String>(
                  value: wordsProvider.difficulty,
                  items: ['All', 'Easy', 'Medium', 'Hard']
                      .map((d) => DropdownMenuItem(
                            value: d,
                            child: Text(d),
                          ))
                      .toList(),
                  onChanged: (value) =>
                      wordsProvider.setDifficulty(value ?? 'All'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWordsList() {
    return Consumer<WordsProvider>(
      builder: (context, wordsProvider, child) {
        final words = _hasUnlockedPremiumFeatures
            ? wordsProvider.words
            : wordsProvider.words
                .take(5)
                .toList(); // Show limited words for free users

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: words.length,
          itemBuilder: (context, index) {
            final word = words[index];
            final isSelected = _selectedIndex == index;

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedIndex = index;
                });
              },
              child: WordCard(
                word: word,
                isSelected: isSelected,
                showHints:
                    _hasUnlockedPremiumFeatures, // Pass premium status to WordCard
              ),
            );
          },
        );
      },
    );
  }
}
