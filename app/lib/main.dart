import 'package:flutter/material.dart';

import 'core/firebase_setup.dart';
import 'core/tema.dart';
import 'screens/auth_gate.dart';
import 'services/notificacoes_medicacao.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await iniciarFirebase();
  await NotificacoesMedicacao.inicializar();

  runApp(const PetCareApp());
}

class PetCareApp extends StatelessWidget {
  const PetCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PetConnect',
      debugShowCheckedModeBanner: false,
      theme: criarTema(),
      home: const AuthGate(),
    );
  }
}
