import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'login.dart';
import 'home.dart';
import 'admin_home.dart';
import 'faturino_home.dart';
import 'services/notification_service.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

// ✅ Global language notifier — accessible from anywhere in the app
final ValueNotifier<String> languageNotifier = ValueNotifier<String>('sq');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (!kIsWeb) {
    Stripe.publishableKey = 'pk_test_51TVHitCjFYQTV39X5YWklXUzYzQOm1L0WkSKmfKW9OX1GB6ojiItMkHnv2x19o8WbomgWGxYDAPsSENuJAjSvtac00LjTgp87S';
    await Stripe.instance.applySettings();
    await NotificationService.initialize();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ Rebuild entire app when language changes
    return ValueListenableBuilder<String>(
      valueListenable: languageNotifier,
      builder: (context, lang, _) {
        return const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: _AuthGate(),
        );
      },
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!authSnap.hasData || authSnap.data == null) {
          return const LoginPage();
        }

        final uid = authSnap.data!.uid;
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
          builder: (context, userSnap) {
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (!userSnap.hasData || !userSnap.data!.exists) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final data = userSnap.data!.data() as Map<String, dynamic>;
            final role = data['role'] ?? 'passenger';
            final status = data['status'] ?? 'active';

            if (status == 'inactive') {
              FirebaseAuth.instance.signOut();
              return const LoginPage();
            }

            // ✅ Load saved language preference from Firestore
            final savedLang = data['language'] as String?;
            if (savedLang != null && savedLang != languageNotifier.value) {
              Future.microtask(() => languageNotifier.value = savedLang);
            }

            if (!kIsWeb) NotificationService.saveFcmToken();

            if (role == 'super_admin' || role == 'line_admin') return const AdminHomePage();
            if (role == 'faturino') return const FatorinoHomePage();
            return const HomePage();
          },
        );
      },
    );
  }
}