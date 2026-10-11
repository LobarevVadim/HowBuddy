import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob's published test rewarded-ad units. Replace these with HowBuddy's
/// own units only after the AdMob apps and ad units have been created.
class RewardedAds {
  RewardedAds._();

  static const androidRewardedUnit =
      'ca-app-pub-3940256099942544/5224354917';
  static const iosRewardedUnit =
      'ca-app-pub-3940256099942544/1712485313';

  static bool get isWebDemo => kIsWeb;

  static Future<bool> show(BuildContext context) async {
    if (kIsWeb) return _showWebSimulation(context);

    final adUnitId = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => iosRewardedUnit,
      TargetPlatform.android => androidRewardedUnit,
      _ => null,
    };
    if (adUnitId == null) {
      throw UnsupportedError('Rewarded ads are only configured for iOS and Android.');
    }

    final loadedAd = Completer<RewardedAd>();
    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: loadedAd.complete,
        onAdFailedToLoad: loadedAd.completeError,
      ),
    );
    final ad = await loadedAd.future.timeout(const Duration(seconds: 30));
    final dismissed = Completer<void>();
    var earnedReward = false;
    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!dismissed.isCompleted) dismissed.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        if (!dismissed.isCompleted) dismissed.completeError(error);
      },
    );
    ad.show(
      onUserEarnedReward: (_, reward) {
        earnedReward = reward.amount > 0;
      },
    );
    await dismissed.future.timeout(const Duration(minutes: 3));
    return earnedReward;
  }

  static Future<bool> _showWebSimulation(BuildContext context) async {
    final completed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.play_circle_outline_rounded, size: 42),
        title: const Text('Simulated ad (web demo)'),
        content: const Text(
          'This is a demo screen, not a real advertisement. Complete it to '
          'preview how an ad reward works.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Complete demo ad'),
          ),
        ],
      ),
    );
    return completed ?? false;
  }
}
