import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'config/routes.dart';
import 'core/theme/app_theme.dart';
import 'injection.dart';
import 'l10n/app_languages.dart';
import 'l10n/localization_service.dart';

/// الجذر الرئيسي للتطبيق
class AlArabiApp extends StatefulWidget {
  const AlArabiApp({super.key});

  @override
  State<AlArabiApp> createState() => _AlArabiAppState();
}

class _AlArabiAppState extends State<AlArabiApp> {
  final LocalizationService _localizationService = sl<LocalizationService>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'العربية للكريستال',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: AppRouter.router,
      scaffoldMessengerKey: AppRouter.scaffoldMessengerKey,
      locale: _localizationService.currentLocale,
      supportedLocales: AppLanguages.supportedLocales
          .map((code) => AppLanguages.localeFromCode(code))
          .toList(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.0),
          ),
          child: child!,
        );
      },
    );
  }
}
