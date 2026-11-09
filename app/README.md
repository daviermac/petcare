# App Flutter (PetConnect)

Pasta reservada para o app. Para criar o projeto aqui dentro:

```bash
cd app
flutter create --org br.com.petconnect --project-name petcare --platforms android,ios .
flutter pub add firebase_core firebase_auth cloud_firestore cloud_functions firebase_messaging firebase_storage
dart pub global activate flutterfire_cli
flutterfire configure
```

Para usar os emuladores locais durante o desenvolvimento:

```dart
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
if (kDebugMode) {
  const host = '10.0.2.2'; // emulador Android; use 'localhost' no simulador iOS
  await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  FirebaseFunctions.instanceFor(region: 'southamerica-east1').useFunctionsEmulator(host, 5001);
}
```

Como chamar a API: ver `../docs/api.md`. Telas de referência: documentação do PetConnect (Telas 01–05).
