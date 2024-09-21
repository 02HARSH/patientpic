import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:permission_handler/permission_handler.dart'; // Import permission_handler package
import 'package:patientpic/screens/login_screen.dart'; // Ensure this path is correct
import 'firebase_options.dart';
import 'package:flutter_downloader/flutter_downloader.dart';


Future<void> _requestPermissions() async {
  if (await Permission.storage.request().isGranted) {
    print('Storage permission granted');
  } else {
    print('Storage permission denied');
    // Handle the case where permission is not granted
  }
}

void main() async {

  WidgetsFlutterBinding.ensureInitialized();
  FlutterDownloader.initialize();



  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
  appleProvider: AppleProvider.appAttest,);
  await _requestPermissions();
  debugPrint('Firebase Initialized and App Check activated');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('Building MyApp widget...');
    return MaterialApp(
      title: 'Image App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: LoginScreen(), // Ensure LoginScreen is defined and imported correctly
    );
  }
}
