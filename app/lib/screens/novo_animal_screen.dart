import 'package:flutter/material.dart';

import '../core/erros.dart';
import '../core/tema.dart';
import '../services/api.dart';
import '../widgets/componentes.dart';

/// HU02 / RF04: cadastro do animal (nome, espécie, raça e idade).
class NovoAnimalScreen extends StatefulWidget {
  const NovoAnimalScreen({super.key});

  @override
  State<NovoAnimalScreen> createState() => _NovoAnimalScreenState();
}

class _NovoAnimalScreenState extends State<NovoAnimalScreen> {
  // rótulo na tela -> valor que a API espera
  static const _especies = {
    'Cachorro': 'cachorro',
    'Gato': 'gato',
    'Outro': 'outro',
  };

  final _nome = TextEditingController();
  final _raca = TextEditingController();
  final _idade = TextEditingController();
  String? _especie;
  Map<String, String> _erros = {};
  String? _erroGeral;
  bool _carregando = false;

  @override
  void dispose() {
    _nome.dispose();
    _raca.dispose();
    _idade.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final erros = <String, String>{};
    if (_nome.text.trim().isEmpty) erros['nome'] = 'Informe o nome do animal.';
    if (_especie == null) erros['especie'] = 'Escolha a espécie.';
    if (_raca.text.trim().isEmpty) erros['raca'] = 'Informe a raça.';
    final idade = int.tryParse(_idade.text);
    if (idade == null) {
      erros['idade'] = 'Informe a idade.';
    } else if (idade < 0 || idade > 40) {
      erros['idade'] = 'Idade inválida.';
    }
    setState(() {
      _erros = erros;
      _erroGeral = null;
    });
    if (erros.isNotEmpty) return;

    setState(() => _carregando = true);
    try {
      await Api.cadastrarAnimal(
        nome: _nome.text.trim(),
        especie: _especie!,
        raca: _raca.text.trim(),
        idade: idade!,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
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
      appBar: AppBar(
        backgroundColor: Cores.fundo,
        title: const Text('Novo animal'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            CampoTexto(
              rotulo: 'Nome do animal',
              controller: _nome,
              erro: _erros['nome'],
              dica: 'Thor',
              acao: TextInputAction.next,
            ),
            const Text('Espécie', style: Estilos.rotulo),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final e in _especies.entries)
                  ChoiceChip(
                    label: Text(e.key),
                    selected: _especie == e.value,
                    onSelected: (_) => setState(() => _especie = e.value),
                  ),
              ],
            ),
            if (_erros['especie'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_erros['especie']!, style: Estilos.erro),
              ),
            const SizedBox(height: 14),
            CampoTexto(
              rotulo: 'Raça',
              controller: _raca,
              erro: _erros['raca'],
              dica: 'Labrador',
              acao: TextInputAction.next,
            ),
            CampoTexto(
              rotulo: 'Idade (anos)',
              controller: _idade,
              erro: _erros['idade'],
              teclado: TextInputType.number,
              apenasDigitos: true,
              maxCaracteres: 2,
              dica: '3',
              acao: TextInputAction.done,
            ),
            if (_erroGeral != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_erroGeral!, style: Estilos.erro),
              ),
            BotaoPrimario(
              texto: 'Salvar animal',
              onPressed: _salvar,
              carregando: _carregando,
            ),
          ],
        ),
      ),
    );
  }
}
