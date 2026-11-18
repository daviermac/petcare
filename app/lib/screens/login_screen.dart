import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/erros.dart';
import '../core/tema.dart';
import '../core/validacoes.dart';
import '../widgets/componentes.dart';
import 'cadastro_screen.dart';

/// RF02: login.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _senha = TextEditingController();
  Map<String, String> _erros = {};
  String? _erroGeral;
  bool _carregando = false;

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    final erros = <String, String>{};
    if (!emailValido(_email.text)) erros['email'] = 'Informe um e-mail válido.';
    if (_senha.text.isEmpty) erros['senha'] = 'Informe sua senha.';
    setState(() {
      _erros = erros;
      _erroGeral = null;
    });
    if (erros.isNotEmpty) return;

    setState(() => _carregando = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _senha.text,
      );
      // O AuthGate troca de tela sozinho.
    } catch (e) {
      final erro = traduzirErro(e);
      if (!mounted) return;
      setState(() {
        _erros = erro.campos;
        _erroGeral = erro.campos.isEmpty ? erro.mensagem : null;
        _carregando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: LogoPetConnect(),
            ),
            const SizedBox(height: 28),
            const Text('Entre na sua conta', style: Estilos.titulo),
            const SizedBox(height: 6),
            const Text(
              'Agende consultas e acompanhe seus animais no Hospital Veterinário PetConnect.',
              style: Estilos.suave,
            ),
            const SizedBox(height: 22),
            CampoTexto(
              rotulo: 'E-mail',
              controller: _email,
              erro: _erros['email'],
              teclado: TextInputType.emailAddress,
              acao: TextInputAction.next,
              dica: 'maria@email.com',
            ),
            CampoTexto(
              rotulo: 'Senha',
              controller: _senha,
              erro: _erros['senha'],
              senha: true,
              acao: TextInputAction.done,
            ),
            if (_erroGeral != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_erroGeral!, style: Estilos.erro),
              ),
            BotaoPrimario(
              texto: 'Entrar',
              onPressed: _entrar,
              carregando: _carregando,
            ),
            const SizedBox(height: 10),
            BotaoSecundario(
              texto: 'Criar conta de tutor',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const CadastroScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
