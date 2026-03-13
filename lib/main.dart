import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import "package:soundgenerator/home_page.dart";
import 'package:soundgenerator/l10n/app_localizations.dart';
import 'package:soundgenerator/loading_screen.dart';
import 'package:soundgenerator/model.dart';
import 'package:soundgenerator/parse_locale_tag.dart';
import 'package:soundgenerator/theme_mode_number.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarContrastEnforced: false,
    ),
  );
  MobileAds.instance.initialize();
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});
  @override
  State<MainApp> createState() => MainAppState();
}

class MainAppState extends State<MainApp> {
  ThemeMode themeMode = ThemeMode.light;
  Locale? locale;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _initState();
  }

  void _initState() async {
    await Model.ensureReady();
    themeMode = ThemeModeNumber.numberToThemeMode(Model.themeNumber);
    locale = parseLocaleTag(Model.languageCode);
    if (!mounted) {
      return;
    }
    setState(() {
      _isReady = true;
    });
  }

  Color _getRainbowAccentColor(int hue) {
    return HSVColor.fromAHSV(1.0, hue.toDouble(), 1.0, 1.0).toColor();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: LoadingScreen())),
      );
    }
    final seed = _getRainbowAccentColor(Model.schemeColor);
    final colorSchemeLight = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light);
    final colorSchemeDark = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark);
    IconThemeData buildIconTheme(ColorScheme colors) => IconThemeData(
      color: colors.primary,
      size: 24,
    );
    final commonElevatedButtonTheme = ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
    final commonSliderTheme = SliderThemeData(
      activeTrackColor: null,
      thumbColor: null,
      showValueIndicator: ShowValueIndicator.onDrag,
      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 10),
      valueIndicatorTextStyle: TextStyle(color: Colors.black),
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      themeMode: themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light),
        sliderTheme: commonSliderTheme,
        elevatedButtonTheme: commonElevatedButtonTheme,
        iconTheme: buildIconTheme(colorSchemeLight),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
        sliderTheme: commonSliderTheme,
        elevatedButtonTheme: commonElevatedButtonTheme,
        iconTheme: buildIconTheme(colorSchemeDark),
      ),
      home: const MainHomePage(),
    );
  }
}
