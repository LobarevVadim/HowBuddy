import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'async_resource_ownership.dart';
import 'ui_translations.dart';

/// AdMob's published test rewarded-ad units. Replace these with HowBuddy's
/// own units only after the AdMob apps and ad units have been created.
class RewardedAds {
  RewardedAds._();

  static const androidRewardedUnit = 'ca-app-pub-3940256099942544/5224354917';
  static const iosRewardedUnit = 'ca-app-pub-3940256099942544/1712485313';

  static bool get isWebDemo => kIsWeb;

  static Future<bool> show(BuildContext context) async {
    if (kIsWeb) return _showWebSimulation(context);

    final adUnitId = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => iosRewardedUnit,
      TargetPlatform.android => androidRewardedUnit,
      _ => null,
    };
    if (adUnitId == null) {
      throw UnsupportedError(
        'Rewarded ads are only configured for iOS and Android.',
      );
    }

    final ad = await loadOwnedResource<RewardedAd>(
      timeout: const Duration(seconds: 30),
      dispose: (ad) => unawaited(ad.dispose()),
      load: (onLoaded, onError) => RewardedAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: onLoaded,
          onAdFailedToLoad: onError,
        ),
      ),
    );
    if (!context.mounted) {
      await ad.dispose();
      return false;
    }
    final dismissed = Completer<void>();
    var earnedReward = false;
    var disposed = false;
    void disposeAd() {
      if (disposed) return;
      disposed = true;
      unawaited(ad.dispose());
    }

    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (ad) {
        disposeAd();
        if (!dismissed.isCompleted) dismissed.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        disposeAd();
        if (!dismissed.isCompleted) dismissed.completeError(error);
      },
    );
    try {
      await Future.wait<void>([
        Future<void>.sync(
          () => ad.show(
            onUserEarnedReward: (_, reward) {
              earnedReward = reward.amount > 0;
            },
          ),
        ),
        dismissed.future.timeout(const Duration(minutes: 3)),
      ], eagerError: true);
      return earnedReward;
    } finally {
      disposeAd();
    }
  }

  static Future<bool> _showWebSimulation(BuildContext context) async {
    final completed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.play_circle_outline_rounded, size: 42),
        title: Text(uiText(context, 'Simulated ad (web demo)')),
        content: Text(uiText(context,
          'This is a demo screen, not a real advertisement. Complete it to preview how an ad reward works.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(uiText(context, 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(uiText(context, 'Complete demo ad')),
          ),
        ],
      ),
    );
    return completed ?? false;
  }
}
