import 'dart:ui';

Locale? parseLocaleTag(String tag) {
  if (tag.isEmpty) {
    return null;
  }
  final parts = tag.split('-');
  final language = parts[0];
  String? script, country;
  if (parts.length >= 2) {
    parts[1].length == 4 ? script = parts[1] : country = parts[1];
  }
  if (parts.length >= 3) {
    parts[2].length == 4 ? script = parts[2] : country = parts[2];
  }
  return Locale.fromSubtags(
    languageCode: language,
    scriptCode: script,
    countryCode: country,
  );
}
