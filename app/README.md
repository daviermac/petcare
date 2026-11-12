# App Flutter (PetConnect)

O app roda contra os **emuladores do Firebase** no computador (não há projeto em produção). Por isso **não precisa** de `flutterfire configure` nem de projeto no console do Firebase.

## Criar o projeto

```bash
cd app
flutter create --org br.com.petconnect --project-name petcare --platforms android,ios .
flutter pub add firebase_core firebase_auth cloud_firestore cloud_functions firebase_storage flutter_local_notifications
```

## Inicializar o Firebase apontando para os emuladores

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// IP do computador que roda os emuladores.
/// Emulador Android: 10.0.2.2 (padrão). Simulador iOS: localhost.
/// Celular físico: IP do notebook na rede, ex.: flutter run --dart-define=EMULADOR_HOST=192.168.0.15
const emuladorHost = String.fromEnvironment('EMULADOR_HOST', defaultValue: '10.0.2.2');

final functions = FirebaseFunctions.instanceFor(region: 'southamerica-east1');

Future<void> iniciarFirebase() async {
  await Firebase.initializeApp(
    // Valores fictícios: com o projeto "demo-petcare" tudo roda só nos emuladores.
    options: const FirebaseOptions(
      apiKey: 'demo-key',
      appId: '1:000000000000:android:0000000000000000',
      messagingSenderId: '000000000000',
      projectId: 'demo-petcare',
      storageBucket: 'demo-petcare.appspot.com',
    ),
  );
  await FirebaseAuth.instance.useAuthEmulator(emuladorHost, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(emuladorHost, 8080);
  functions.useFunctionsEmulator(emuladorHost, 5001);
  await FirebaseStorage.instance.useStorageEmulator(emuladorHost, 9199);
}
```

Chame `await iniciarFirebase();` no `main()` antes do `runApp`.

### Android: liberar HTTP para os emuladores

Os emuladores usam `http://` (sem TLS) e o Android bloqueia isso por padrão. Em `android/app/src/debug/AndroidManifest.xml`, adicione no `<application>`:

```xml
<application android:usesCleartextTraffic="true" />
```

## Chamando a API

```dart
final res = await functions.httpsCallable('agendarConsulta').call({
  'animalId': animalId,
  'data': '2026-11-16',
  'horario': '11:00',
});
```

Erros chegam como `FirebaseFunctionsException`. Em `invalid-argument`, `e.details['campos']` traz uma mensagem por campo para mostrar abaixo de cada input. Contrato completo: `../docs/api.md` ou o Swagger (com os emuladores rodando): http://localhost:5001/demo-petcare/southamerica-east1/docs

## Notificações (lembretes)

O emulador não envia push de verdade. Os lembretes de consulta e vacina são gravados na coleção `notificacoes`. O app escuta essa coleção e mostra uma notificação local com `flutter_local_notifications`:

```dart
FirebaseFirestore.instance
    .collection('notificacoes')
    .where('tutorId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
    .where('lida', isEqualTo: false)
    .snapshots()
    .listen((snap) {
  for (final mudanca in snap.docChanges.where((m) => m.type == DocumentChangeType.added)) {
    final n = mudanca.doc.data()!;
    // mostrar notificação local com n['titulo'] e n['corpo'],
    // depois: mudanca.doc.reference.update({'lida': true});
  }
});
```

Na apresentação, para gerar os lembretes na hora, abra no navegador: http://localhost:5001/demo-petcare/southamerica-east1/dispararLembretes

Para os lembretes de **medicamento** (RF21), `registrarPrescricao` devolve `horariosMedicacao`. Agende uma notificação local para cada horário.

## Contas de teste

Depois de `npm run seed` (pasta `api/`), todas com a senha `Pet@1234`:

| Perfil | E-mail |
|---|---|
| Gestor | gestor@petconnect.dev |
| Veterinário | vet@petconnect.dev / vet2@petconnect.dev |
| Atendente | atendente@petconnect.dev |
| Auxiliar | auxiliar@petconnect.dev |
| Tutor | ana@email.dev (Thor e Mia) / bruno@email.dev (Apolo) |

O perfil do usuário logado está no token: `(await user.getIdTokenResult()).claims?['perfil']`. Use para decidir quais telas mostrar.
