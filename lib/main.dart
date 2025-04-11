import 'package:flutter/material.dart';
import 'package:pronounce_it_right/provider/word_provider.dart';
import 'package:pronounce_it_right/screen/splash.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:pronounce_it_right/services/ad_services.dart';

import 'provider/audio_provider.dart';
import 'provider/chat_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await AdServices.initialize(); // Initialize ad services
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AudioProvider()),
        ChangeNotifierProvider(create: (_) => WordsProvider()),
        ChangeNotifierProvider(
            create: (_) => ChatProvider()), // Add ChatProvider here
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Pronounce It Right',
        theme: ThemeData(
          // Consider using ColorScheme for modern theming
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
          useMaterial3: true, // Recommended for new projects
          // primarySwatch: Colors.blue, // Keep if you prefer Material 2 look
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
