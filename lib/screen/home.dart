import 'package:flutter/material.dart';
import 'package:pronounce_it_right/screen/practice_screen.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:pronounce_it_right/services/ad_services.dart';
import 'chatAI.dart';
import 'translator.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  BannerAd? _bannerAd;
  int _interstitialLoadAttempts = 0;
  final int maxFailedLoadAttempts = 3;

  // List of screen builders to lazily load screens
  final List<WidgetBuilder> _screenBuilders = <WidgetBuilder>[
    (context) => const PracticeScreen(), // Practice screen
    (context) => const TranslatorScreen(), // Translator screen
    (context) => const ChatAiScreen(), // AI Chat screen
  ];

  @override
  void initState() {
    super.initState();
    _createBannerAd();
    AdServices.loadInterstitialAd();
  }

  void _createBannerAd() {
    _bannerAd = AdServices.createBannerAd();
  }

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      // Show interstitial ad every third tab change
      if (_selectedIndex % 3 == 2) {
        AdServices.showInterstitialAd();
      }
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitleForIndex(_selectedIndex)),
      ),
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children:
                  _screenBuilders.map((builder) => builder(context)).toList(),
            ),
          ),
          if (_bannerAd != null)
            Container(
              alignment: Alignment.center,
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.record_voice_over),
            label: 'Practice',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.translate),
            label: 'Translate',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.smart_toy_outlined),
            label: 'AI Chat',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        onTap: _onItemTapped,
      ),
    );
  }

  // Helper method to dynamically set the app bar title
  String _getTitleForIndex(int index) {
    switch (index) {
      case 0:
        return 'Practice';
      case 1:
        return 'Translate';
      case 2:
        return 'AI Chat';
      default:
        return 'Pronounce It Right';
    }
  }
}
