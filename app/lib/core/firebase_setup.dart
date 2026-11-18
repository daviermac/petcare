import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// IP do computador que roda os emuladores.
/// Emulador Android: 10.0.2.2 (padrão). Simulador iOS: localhost.
/// Celular físico: flutter run --dart-define=EMULADOR_HOST=192.168.0.15
const _hostConfigurado = String.fromEnvironment('EMULADOR_HOST');

String get emuladorHost {
  if (_hostConfigurado.isNotEmpty) return _hostConfigurado;
  return defaultTargetPlatform == TargetPlatform.android
      ? '10.0.2.2'
      : 'localhost';
}

/// Região das Cloud Functions do Davi (ver docs/api.md).
final FirebaseFunctions functions =
    FirebaseFunctions.instanceFor(region: 'southamerica-east1');

Future<void> iniciarFirebase() async {
  await Firebase.initializeApp(
    // Valores fictícios: com o projeto "demo-petcare" tudo roda nos emuladores.
    options: const FirebaseOptions(
      apiKey: 'AIzaSyDemoPetcareEmuladorLocal000000000',
      appId: '1:000000000000:android:0000000000000000',
      messagingSenderId: '000000000000',
      projectId: 'demo-petcare',
      storageBucket: 'demo-petcare.appspot.com',
    ),
  );
  await FirebaseAuth.instance.useAuthEmulator(emuladorHost, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(emuladorHost, 8081);
  functions.useFunctionsEmulator(emuladorHost, 5001);
}
