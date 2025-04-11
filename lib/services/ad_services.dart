import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' as admob;
import 'package:easy_audience_network/easy_audience_network.dart' as fan;
import 'dart:io';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';

class AdServices {
  static admob.BannerAd? _bannerAd;
  static admob.InterstitialAd? _interstitialAd;
  static admob.RewardedAd? _rewardedAd;

  // Test Ad Unit IDs for AdMob
  static const String _testBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _testInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _testRewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';

  // Initialize ad services
  static Future<void> initialize() async {
    // Initialize AdMob
    await admob.MobileAds.instance.initialize();

    if (Platform.isIOS) {
      // Request tracking authorization for iOS 14+
      final status =
          await AppTrackingTransparency.requestTrackingAuthorization();
      print('Tracking authorization status: $status');

      // Wait for authorization before loading ads on iOS
      if (status == TrackingStatus.authorized) {
        await admob.MobileAds.instance.updateRequestConfiguration(
          admob.RequestConfiguration(
            tagForChildDirectedTreatment:
                admob.TagForChildDirectedTreatment.unspecified,
            testDeviceIds: ['kGADSimulatorID'],
          ),
        );
      }
    }

    // Initialize Facebook Audience Network
    await fan.EasyAudienceNetwork.init(
      testMode: true, // Set to false for production
    );
  }

  // Create and load a banner ad (AdMob)
  static admob.BannerAd createBannerAd() {
    _bannerAd = admob.BannerAd(
      adUnitId: _testBannerAdUnitId,
      size: admob.AdSize.banner,
      request: const admob.AdRequest(),
      listener: admob.BannerAdListener(
        onAdLoaded: (ad) {
          print('Banner Ad loaded.');
        },
        onAdFailedToLoad: (ad, error) {
          print('Banner Ad failed to load: $error');
          ad.dispose();
        },
      ),
    )..load();

    return _bannerAd!;
  }

  // Create and load a Facebook banner ad
  static Widget createFacebookBannerAd() {
    return fan.BannerAd(
      placementId: fan.BannerAd.testPlacementId,
      bannerSize: fan.BannerSize.STANDARD,
      listener: fan.BannerAdListener(
        onError: (code, message) =>
            print('Facebook banner ad error\ncode: $code\nmessage:$message'),
        onLoaded: () => print('Facebook banner ad loaded'),
      ),
    );
  }

  // Load an interstitial ad (AdMob)
  static void loadInterstitialAd() {
    admob.InterstitialAd.load(
      adUnitId: _testInterstitialAdUnitId,
      request: const admob.AdRequest(),
      adLoadCallback: admob.InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialAd!.setImmersiveMode(true);
        },
        onAdFailedToLoad: (error) {
          print('Interstitial Ad failed to load: $error');
        },
      ),
    );
  }

  // Load Facebook interstitial ad
  static void loadFacebookInterstitialAd() {
    final interstitialAd =
        fan.InterstitialAd(fan.InterstitialAd.testPlacementId);
    interstitialAd.listener = fan.InterstitialAdListener(
      onLoaded: () {
        print('Facebook interstitial ad loaded');
        interstitialAd.show();
      },
      onError: (code, message) {
        print(
            'Facebook interstitial ad error\ncode = $code\nmessage = $message');
      },
      onDismissed: () {
        // Load next ad
        loadFacebookInterstitialAd();
      },
    );
    interstitialAd.load();
  }

  // Show the interstitial ad if it's loaded
  static void showInterstitialAd() {
    if (_interstitialAd != null) {
      _interstitialAd!.show();
      _interstitialAd = null;
      loadInterstitialAd(); // Load the next interstitial
    } else {
      // Try Facebook interstitial as fallback
      loadFacebookInterstitialAd();
    }
  }

  // Load a rewarded ad (AdMob)
  static void loadRewardedAd() {
    admob.RewardedAd.load(
      adUnitId: _testRewardedAdUnitId,
      request: const admob.AdRequest(),
      rewardedAdLoadCallback: admob.RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
        },
        onAdFailedToLoad: (error) {
          print('Rewarded Ad failed to load: $error');
        },
      ),
    );
  }

  // Load Facebook rewarded ad
  static void loadFacebookRewardedAd() {
    final rewardedAd = fan.RewardedAd(fan.RewardedAd.testPlacementId);
    rewardedAd.listener = fan.RewardedAdListener(
      onLoaded: () {
        print('Facebook rewarded ad loaded');
        rewardedAd.show();
      },
      onError: (code, message) {
        print('Facebook rewarded ad error\ncode = $code\nmessage = $message');
      },
      onVideoClosed: () {
        // Load next ad
        loadFacebookRewardedAd();
      },
    );
    rewardedAd.load();
  }

  // Show the rewarded ad and return a Future that completes when the user earns a reward
  static Future<void> showRewardedAd() async {
    if (_rewardedAd == null) {
      throw Exception('Rewarded ad not loaded');
    }

    return _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        print('User earned reward: ${reward.amount} ${reward.type}');
      },
    ).then((_) {
      _rewardedAd = null;
      loadRewardedAd(); // Load the next rewarded ad
    });
  }

  // Clean up ads
  static void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
  }
}
