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

  runApp(const MickeyApp());
}

class MickeyApp extends StatelessWidget {
  const MickeyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mickey',
      debugShowCheckedModeBanner: false,
      theme: JarvisTheme.darkTheme,
      home: const ChatScreen(),
    );
  }
}

// Backward-compatible alias for existing tests
typedef JarvisApp = MickeyApp;
