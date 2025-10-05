import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:scalex_chat/src/landing/landing_screen.dart';
import 'auth/login_screen.dart';
import 'dart:ui' as ui;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Chat',
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      builder: (ctx, child) => Directionality(
        textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
        child: child!,
      ),
      home: const LandingScreen(),
    );
  }
}
