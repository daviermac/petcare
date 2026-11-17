import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/tema.dart';
import '../widgets/componentes.dart';

/// Perfis da equipe (atendente, veterinário, auxiliar, gestor) ainda não têm telas.
class PerfilEquipeScreen extends StatelessWidget {
  final String perfil;
  const PerfilEquipeScreen({super.key, required this.perfil});

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const LogoPetConnect(),
              const SizedBox(height: 24),
              Text('Perfil: $perfil', style: Estilos.titulo),
              const SizedBox(height: 8),
              Text(email, style: Estilos.suave),
              const SizedBox(height: 16),
              const Text(
                'As telas deste perfil ainda estão em desenvolvimento. '
                'Por enquanto, o app está completo para o perfil Tutor.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              BotaoPrimario(
                texto: 'Sair',
                onPressed: () => FirebaseAuth.instance.signOut(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
