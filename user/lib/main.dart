import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'splashscreen/splash_screen.dart';
import 'features/near_me/Screen/nearme_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PasaHero',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        // Set Figtree as the default font family for all text
        fontFamily: 'Figtree',
        // Configure text themes - all using Figtree
        textTheme: const TextTheme(
          // Display styles - use Figtree with bold weight
          displayLarge: TextStyle(
            fontFamily: 'Figtree',
            fontWeight: FontWeight.bold,
          ),
          displayMedium: TextStyle(
            fontFamily: 'Figtree',
            fontWeight: FontWeight.bold,
          ),
          displaySmall: TextStyle(
            fontFamily: 'Figtree',
            fontWeight: FontWeight.bold,
          ),
          // Headline styles - use Figtree with semi-bold weight
          headlineLarge: TextStyle(
            fontFamily: 'Figtree',
            fontWeight: FontWeight.w600,
          ),
          headlineMedium: TextStyle(
            fontFamily: 'Figtree',
            fontWeight: FontWeight.w600,
          ),
          headlineSmall: TextStyle(
            fontFamily: 'Figtree',
            fontWeight: FontWeight.w600,
          ),
          // Title styles - use Figtree with semi-bold weight
          titleLarge: TextStyle(
            fontFamily: 'Figtree',
            fontWeight: FontWeight.w600,
          ),
          titleMedium: TextStyle(
            fontFamily: 'Figtree',
            fontWeight: FontWeight.w600,
          ),
          titleSmall: TextStyle(
            fontFamily: 'Figtree',
            fontWeight: FontWeight.w600,
          ),
          // Body styles - use Figtree regular
          bodyLarge: TextStyle(
            fontFamily: 'Figtree',
            fontWeight: FontWeight.normal,
          ),
          bodyMedium: TextStyle(
            fontFamily: 'Figtree',
            fontWeight: FontWeight.normal,
          ),
          bodySmall: TextStyle(
            fontFamily: 'Figtree',
            fontWeight: FontWeight.normal,
          ),
          // Label styles - use Figtree medium
          labelLarge: TextStyle(
            fontFamily: 'Figtree',
            fontWeight: FontWeight.w500,
          ),
          labelMedium: TextStyle(
            fontFamily: 'Figtree',
            fontWeight: FontWeight.w500,
          ),
          labelSmall: TextStyle(
            fontFamily: 'Figtree',
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // If user is logged in, show near me screen
        if (snapshot.hasData && snapshot.data != null) {
          // User is logged in - navigate to near me screen
          return const NearMeScreen();
        }

        // User is not logged in - show splash screen
        return const SplashScreen();
      },
    );
  }
}
