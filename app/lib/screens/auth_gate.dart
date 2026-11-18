import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'cadastro_screen.dart';
import 'login_screen.dart';
import 'perfil_equipe_screen.dart';
import 'tutor_shell.dart';

/// Aumente este valor para forçar o app a reler o perfil do usuário
/// (depois de registrarTutor + getIdToken(true)).
final ValueNotifier<int> sessaoVersao = ValueNotifier<int>(0);

/// Decide a tela inicial: login, completar cadastro, tutor ou equipe.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _Carregando();
        }
        final user = snap.data;
        if (user == null) return const LoginScreen();

        return ValueListenableBuilder<int>(
          valueListenable: sessaoVersao,
          builder: (context, _, _) {
            return FutureBuilder<IdTokenResult>(
              future: user.getIdTokenResult(),
              builder: (context, tokenSnap) {
                if (tokenSnap.hasError) {
                  return _TelaErro(
                    aoSair: () => FirebaseAuth.instance.signOut(),
                  );
                }
                if (!tokenSnap.hasData) return const _Carregando();

                final perfil = tokenSnap.data!.claims?['perfil'] as String?;
                if (perfil == null) {
                  // Conta criada no Firebase Auth, mas sem cadastro de tutor.
                  return const CadastroScreen(completar: true);
                }
                if (perfil == 'tutor') return const TutorShell();
                return PerfilEquipeScreen(perfil: perfil);
              },
            );
          },
        );
      },
    );
  }
}

class _Carregando extends StatelessWidget {
  const _Carregando();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _TelaErro extends StatelessWidget {
  final VoidCallback aoSair;
  const _TelaErro({required this.aoSair});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Não foi possível carregar sua conta.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: aoSair, child: const Text('Sair')),
            ],
          ),
        ),
      ),
    );
  }
}
