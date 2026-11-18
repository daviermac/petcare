import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/erros.dart';
import '../core/tema.dart';
import '../core/validacoes.dart';
import '../services/api.dart';
import '../widgets/componentes.dart';
import 'auth_gate.dart';

/// HU01 / RF01: cadastro do tutor.
///
/// Com [completar] = true, a conta já existe no Firebase Auth e só falta o
/// cadastro de tutor (nome, CPF e telefone).
class CadastroScreen extends StatefulWidget {
  final bool completar;
  const CadastroScreen({super.key, this.completar = false});

  @override
  State<CadastroScreen> createState() => _CadastroScreenState();
}

class _CadastroScreenState extends State<CadastroScreen> {
  final _nome = TextEditingController();
  final _cpf = TextEditingController();
  final _telefone = TextEditingController();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  Map<String, String> _erros = {};
  String? _erroGeral;
  bool _carregando = false;

  bool get _contaJaCriada => FirebaseAuth.instance.currentUser != null;

  @override
  void dispose() {
    _nome.dispose();
    _cpf.dispose();
    _telefone.dispose();
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final erros = <String, String>{};
    if (!nomeCompletoValido(_nome.text)) {
      erros['nome'] = 'Informe nome e sobrenome.';
    }
    if (!cpfValido(_cpf.text)) erros['cpf'] = 'CPF inválido. Digite os 11 números.';
    if (!telefoneValido(_telefone.text)) {
      erros['telefone'] = 'Telefone inválido. Use DDD + número.';
    }
    if (!_contaJaCriada) {
      if (!emailValido(_email.text)) {
        erros['email'] = 'E-mail inválido. Exemplo: nome@email.com';
      }
      if (_senha.text.length < 6) {
        erros['senha'] = 'A senha precisa ter pelo menos 6 caracteres.';
      }
    }
    setState(() {
      _erros = erros;
      _erroGeral = null;
    });
    if (erros.isNotEmpty) return;

    setState(() => _carregando = true);
    try {
      var user = FirebaseAuth.instance.currentUser;
      user ??= (await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _senha.text,
      ))
          .user;

      await Api.registrarTutor(
        nome: _nome.text.trim().replaceAll(RegExp(r'\s+'), ' '),
        cpf: soDigitos(_cpf.text),
        telefone: soDigitos(_telefone.text),
      );

      // Atualiza o token para o app receber o perfil "tutor".
      await user!.getIdToken(true);
      sessaoVersao.value++;
      if (!mounted) return;
      Navigator.of(context).popUntil((rota) => rota.isFirst);
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
    final emailAtual = FirebaseAuth.instance.currentUser?.email;
    return Scaffold(
      appBar: widget.completar
          ? null
          : AppBar(
              backgroundColor: Cores.fundo,
              title: const Text('Cadastro do tutor'),
            ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            if (widget.completar) ...[
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: LogoPetConnect(),
              ),
              const SizedBox(height: 20),
            ],
            Text(
              widget.completar ? 'Complete seu cadastro' : 'Crie sua conta de tutor',
              style: Estilos.titulo,
            ),
            const SizedBox(height: 6),
            Text(
              widget.completar
                  ? 'Falta pouco para usar o app. Conta: ${emailAtual ?? ''}'
                  : 'Cadastre-se para agendar consultas no Hospital Veterinário PetConnect.',
              style: Estilos.suave,
            ),
            const SizedBox(height: 20),
            CampoTexto(
              rotulo: 'Nome completo',
              controller: _nome,
              erro: _erros['nome'],
              dica: 'Maria Souza',
              acao: TextInputAction.next,
            ),
            CampoTexto(
              rotulo: 'CPF (só números)',
              controller: _cpf,
              erro: _erros['cpf'],
              teclado: TextInputType.number,
              apenasDigitos: true,
              maxCaracteres: 11,
              dica: '00000000000',
              acao: TextInputAction.next,
            ),
            CampoTexto(
              rotulo: 'Telefone com DDD',
              controller: _telefone,
              erro: _erros['telefone'],
              teclado: TextInputType.phone,
              apenasDigitos: true,
              maxCaracteres: 11,
              dica: '11999998888',
              acao: TextInputAction.next,
            ),
            if (!_contaJaCriada) ...[
              CampoTexto(
                rotulo: 'E-mail',
                controller: _email,
                erro: _erros['email'],
                teclado: TextInputType.emailAddress,
                dica: 'maria@email.com',
                acao: TextInputAction.next,
              ),
              CampoTexto(
                rotulo: 'Senha (mínimo 6 caracteres)',
                controller: _senha,
                erro: _erros['senha'],
                senha: true,
                acao: TextInputAction.done,
              ),
            ],
            if (_erroGeral != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_erroGeral!, style: Estilos.erro),
              ),
            BotaoPrimario(
              texto: widget.completar ? 'Concluir cadastro' : 'Criar conta',
              onPressed: _enviar,
              carregando: _carregando,
            ),
            if (widget.completar) ...[
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => FirebaseAuth.instance.signOut(),
                child: const Text('Sair'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
