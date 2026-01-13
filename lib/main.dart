import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';

import 'app/bindings/initial_binding.dart';
import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';
import 'app/ui/app_theme.dart';
import 'firebase_options.dart';

const bool _skipFirebase = bool.fromEnvironment(
  'SKIP_FIREBASE',
  defaultValue: false,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!_skipFirebase) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.skipFirebase = _skipFirebase});

  final bool skipFirebase;

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    if (skipFirebase) {
      return GetMaterialApp(
        title: 'Field Sales App (Preview)',
        theme: AppTheme.buildTheme(),
        initialBinding: InitialBinding(),
        debugShowCheckedModeBanner: false,
        home: const Scaffold(
          body: Center(
            child: Text(
              'Preview mode is enabled.\nRun without SKIP_FIREBASE to use full app.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return GetMaterialApp(
      title: 'Field Sales App',
      theme: AppTheme.buildTheme(),
      initialBinding: InitialBinding(),
      initialRoute: AppRoutes.splash,
      getPages: AppPages.pages,
    );
  }
}
