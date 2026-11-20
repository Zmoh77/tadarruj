import 'package:flutter/material.dart';

class AppTr {
  static String lang(BuildContext context) =>
      Localizations.localeOf(context).languageCode;

  static String t(
    BuildContext context, {
    required String fr,
    required String en,
    required String ar,
  }) {
    final code = lang(context);
    if (code == 'ar') return ar;
    if (code == 'en') return en;
    return fr;
  }
}
