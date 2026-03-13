import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdManager {
  //Test IDs
  //static const String _androidAdUnitId = "ca-app-pub-3940256099942544/6300978111";
  //static const String _iosAdUnitId     = "ca-app-pub-3940256099942544/2934735716";

  //Production IDs
  static const String _androidAdUnitId = "YOUR_AD_UNIT_ID";
  static const String _iosAdUnitId     = "YOUR_AD_UNIT_ID";

  static String get _adUnitId => Platform.isIOS ? _iosAdUnitId : _androidAdUnitId;

  BannerAd? _bannerAd;
  int _lastWidthPx = 0;
  VoidCallback? _onLoadedCb;
  Timer? _retryTimer;
  int _retryAttempt = 0;

  BannerAd? get bannerAd => _bannerAd;

  static Future<void> initForNPA() async {
    if (kIsWeb) {
      return;
    }
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(
      ),
    );
  }

  Future<void> loadAdaptiveBannerAd(
      int widthPx,
      VoidCallback onAdLoaded,
      ) async {
    if (kIsWeb) {
      return;
    }
    _onLoadedCb = onAdLoaded;
    _lastWidthPx = widthPx;
    _retryAttempt = 0;
    _retryTimer?.cancel();
    _startLoad(widthPx);
  }

  Future<void> _startLoad(int widthPx) async {
    if (kIsWeb) {
      return;
    }
    _bannerAd?.dispose();

    AnchoredAdaptiveBannerAdSize? adaptiveSize;
    try {
      adaptiveSize =
      await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
        widthPx,
      );
    } catch (_) {
      adaptiveSize = null;
    }
    final AdSize size = adaptiveSize ?? AdSize.fullBanner;

    const adRequest = AdRequest(
      nonPersonalizedAds: true,
    );

    _bannerAd = BannerAd(
      adUnitId: _adUnitId,
      request: adRequest,
      size: size,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _retryTimer?.cancel();
          _retryAttempt = 0;
          final cb = _onLoadedCb;
          if (cb != null) {
            cb();
          }
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          _scheduleRetry();
        },
      ),
    )..load();
  }

  void _scheduleRetry() {
    if (kIsWeb) {
      return;
    }
    _retryTimer?.cancel();
    _retryAttempt = (_retryAttempt + 1).clamp(1, 5);
    final seconds = _retryAttempt >= 4 ? 30 : (3 << (_retryAttempt - 1));
    _retryTimer = Timer(Duration(seconds: seconds), () {
      _startLoad(_lastWidthPx > 0 ? _lastWidthPx : 320);
    });
  }

  void dispose() {
    _bannerAd?.dispose();
    _retryTimer?.cancel();
  }
}
