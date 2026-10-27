import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ui/chat_screen.dart';
import 'ui/theme/jarvis_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure status bar & navigation bar to match futuristic dark theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: JarvisTheme.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const JarvisApp());
}

class JarvisApp extends StatelessWidget {
  const JarvisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JARVIS',
      debugShowCheckedModeBanner: false,
      theme: JarvisTheme.darkTheme,
      home: const ChatScreen(),
    );
  }
}
