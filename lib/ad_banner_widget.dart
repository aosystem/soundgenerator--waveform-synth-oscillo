import 'package:flutter/cupertino.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:soundgenerator/ad_manager.dart';

class AdBannerWidget extends StatefulWidget {
  final AdManager adManager;
  const AdBannerWidget({super.key, required this.adManager});
  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  int _lastBannerWidthDp = 0;
  bool _isAdLoaded = false;
  bool _isLoading = false;
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final int width = constraints.maxWidth.isFinite ? constraints.maxWidth.truncate() : MediaQuery.of(context).size.width.truncate();
          final bannerAd = widget.adManager.bannerAd;
          if (width > 0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                final bannerAd = widget.adManager.bannerAd;
                final bool widthChanged = _lastBannerWidthDp != width;
                final bool sizeMismatch = bannerAd == null || bannerAd.size.width != width;
                if ((widthChanged || !_isAdLoaded || sizeMismatch) && !_isLoading) {
                  _lastBannerWidthDp = width;
                  setState(() { _isAdLoaded = false; _isLoading = true; });
                  widget.adManager.loadAdaptiveBannerAd(width, () {
                    if (mounted) {
                      setState(() { _isAdLoaded = true; _isLoading = false; });
                    }
                  });
                }
              }
            });
          }
          if (_isAdLoaded && bannerAd != null) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: bannerAd.size.width.toDouble(),
                      height: bannerAd.size.height.toDouble(),
                      child: AdWidget(ad: bannerAd),
                    ),
                  ],
                )
              ]
            );
          } else {
            return const SizedBox.shrink();
          }
        },
      ),
    );
  }
}
