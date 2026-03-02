import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'models/adherence_log_model.dart'; // includes AdherenceLogModelAdapter via part
import 'providers/auth_provider.dart' as app_auth;
import 'providers/chatbot_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/member_provider.dart';
import 'screens/splash/splash_screen.dart';
import 'backend/services/notification_service.dart';
import 'backend/services/gemini_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase
  await Firebase.initializeApp();

  // Hive for offline adherence logs
  await Hive.initFlutter();
  Hive.registerAdapter(AdherenceLogModelAdapter());
  await Hive.openBox<AdherenceLogModel>('adherence_logs');

  // Notifications (daily reminders with actions)
  await NotificationService.initialize();

  // Gemini AI
  await GeminiService.initialize();

  // Localization
  await EasyLocalization.ensureInitialized();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('hi'), Locale('kn')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: const MediTrackApp(),
    ),
  );
}

class MediTrackApp extends StatelessWidget {
  const MediTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => app_auth.AuthProvider()),
        ChangeNotifierProvider(create: (_) => MemberProvider()),
        ChangeNotifierProvider(create: (_) => ChatbotProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'MediTrack',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}