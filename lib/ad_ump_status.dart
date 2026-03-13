import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/widgets.dart';

import 'package:soundgenerator/l10n/app_localizations.dart';

class AdUmpState {
  final PrivacyOptionsRequirementStatus privacyStatus;
  final ConsentStatus consentStatus;
  final bool privacyOptionsRequired;
  final bool isChecking;
  const AdUmpState({
    required this.privacyStatus,
    required this.consentStatus,
    required this.privacyOptionsRequired,
    required this.isChecking,
  });

  AdUmpState copyWith({
    PrivacyOptionsRequirementStatus? privacyStatus,
    ConsentStatus? consentStatus,
    bool? privacyOptionsRequired,
    bool? isChecking,
  }) {
    return AdUmpState(
      privacyStatus: privacyStatus ?? this.privacyStatus,
      consentStatus: consentStatus ?? this.consentStatus,
      privacyOptionsRequired:
      privacyOptionsRequired ?? this.privacyOptionsRequired,
      isChecking: isChecking ?? this.isChecking,
    );
  }

  static const initial = AdUmpState(
    privacyStatus: PrivacyOptionsRequirementStatus.unknown,
    consentStatus: ConsentStatus.unknown,
    privacyOptionsRequired: false,
    isChecking: false,
  );
}

class UmpConsentController {
  final bool forceEeaForDebug = false;
  static const List<String> _testDeviceIds = [
    '',
  ];

  ConsentRequestParameters _buildParams() {
    if (forceEeaForDebug && _testDeviceIds.isNotEmpty) {
      return ConsentRequestParameters(
        consentDebugSettings: ConsentDebugSettings(
          debugGeography: DebugGeography.debugGeographyEea,
          testIdentifiers: _testDeviceIds,
        ),
      );
    }
    return ConsentRequestParameters();
  }

  Future<AdUmpState> updateConsentInfo({AdUmpState current = AdUmpState.initial}) async {
    if (kIsWeb) return current;
    var state = current.copyWith(isChecking: true);

    try {
      final params = _buildParams();
      final completer = Completer<AdUmpState>();

      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
            () async {
          final s = await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
          final c = await ConsentInformation.instance.getConsentStatus();
          completer.complete(
            state.copyWith(
              privacyStatus: s,
              consentStatus: c,
              privacyOptionsRequired: s == PrivacyOptionsRequirementStatus.required,
              isChecking: false,
            ),
          );
        },
            (FormError e) {
          completer.complete(
            state.copyWith(
              privacyStatus: PrivacyOptionsRequirementStatus.unknown,
              consentStatus: ConsentStatus.unknown,
              privacyOptionsRequired: false,
              isChecking: false,
            ),
          );
        },
      );

      state = await completer.future;
      return state;
    } catch (_) {
      return state.copyWith(isChecking: false);
    }
  }

  Future<FormError?> showPrivacyOptions() async {
    if (kIsWeb) return null;
    final completer = Completer<FormError?>();
    ConsentForm.showPrivacyOptionsForm((FormError? e) {
      completer.complete(e);
    });
    return completer.future;
  }
}

extension ConsentStatusL10n on ConsentStatus {
  String localized(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    switch (this) {
      case ConsentStatus.obtained:
        return l.cmpConsentStatusObtained;
      case ConsentStatus.required:
        return l.cmpConsentStatusRequired;
      case ConsentStatus.notRequired:
        return l.cmpConsentStatusNotRequired;
      case ConsentStatus.unknown:
        return l.cmpConsentStatusUnknown;
    }
  }
}
