import 'package:flutter/material.dart';

import '../core/erros.dart';
import '../core/formatadores.dart';
import '../core/tema.dart';
import '../core/validacoes.dart';
import '../services/api.dart';
import '../services/notificacoes_medicacao.dart';
import '../services/prescricao_medicacao.dart';
import '../widgets/componentes.dart';

// Formulários do perfil Veterinário: atendimento (RF14/RF30), prescrição (RF15/RF21)
// e vacina (RF16). Cada tela aceita uma função `enviar` opcional para os testes de widget
// rodarem sem Firebase; no app, ela chama a API.

/// Dados do formulário de atendimento.
class DadosAtendimentoForm {
  final String animalId;
  final String? consultaId;
  final String motivo;
  final String diagnostico;
  final String tratamento;
  final String observacoes;
  final double? valor;

  const DadosAtendimentoForm({
    required this.animalId,
    this.consultaId,
    required this.motivo,
    required this.diagnostico,
    required this.tratamento,
    required this.observacoes,
    this.valor,
  });
}

class DadosPrescricaoForm {
  final String animalId;
  final String animalNome;
  final String medicamento;
  final String dosagem;
  final int frequenciaHoras;
  final int duracaoDias;
  final String orientacoes;

  const DadosPrescricaoForm({
    required this.animalId,
    required this.animalNome,
    required this.medicamento,
    required this.dosagem,
    required this.frequenciaHoras,
    required this.duracaoDias,
    required this.orientacoes,
  });
}

class DadosVacinaForm {
  final String animalId;
  final String nome;
  final String dataAplicacao; // AAAA-MM-DD
  final String? proximaDose; // AAAA-MM-DD
  final String lote;

  const DadosVacinaForm({
    required this.animalId,
    required this.nome,
    required this.dataAplicacao,
    this.proximaDose,
    required this.lote,
  });
}

/// Cabeçalho comum dos formulários: nome do animal.
class _CabecalhoAnimal extends StatelessWidget {
  final String animalNome;
  final String texto;
  const _CabecalhoAnimal({required this.animalNome, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          AvatarInicial(nome: animalNome),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(animalNome, style: Estilos.secao),
                Text(texto, style: Estilos.suave),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Atendimento

class AtendimentoFormScreen extends StatefulWidget {
  final String animalId;
  final String animalNome;
  final String? consultaId;
  final Future<void> Function(DadosAtendimentoForm dados)? enviar;

  const AtendimentoFormScreen({
    super.key,
    required this.animalId,
    required this.animalNome,
    this.consultaId,
    this.enviar,
  });

  @override
  State<AtendimentoFormScreen> createState() => _AtendimentoFormScreenState();
}

class _AtendimentoFormScreenState extends State<AtendimentoFormScreen> {
  final _motivo = TextEditingController();
  final _diagnostico = TextEditingController();
  final _tratamento = TextEditingController();
  final _observacoes = TextEditingController();
  final _valor = TextEditingController();
  Map<String, String> _erros = {};
  bool _enviando = false;

  @override
  void dispose() {
    for (final c in [_motivo, _diagnostico, _tratamento, _observacoes, _valor]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _salvar() async {
    final erros = <String, String>{};
    if (_diagnostico.text.trim().isEmpty) erros['diagnostico'] = 'Informe o diagnóstico.';
    if (_tratamento.text.trim().isEmpty) erros['tratamento'] = 'Informe o tratamento.';
    final valor = lerValorReais(_valor.text);
    if (_valor.text.trim().isNotEmpty && valor == null) {
      erros['valor'] = 'Valor inválido. Ex.: 150,00';
    }
    setState(() => _erros = erros);
    if (erros.isNotEmpty) return;

    final dados = DadosAtendimentoForm(
      animalId: widget.animalId,
      consultaId: widget.consultaId,
      motivo: _motivo.text.trim(),
      diagnostico: _diagnostico.text.trim(),
      tratamento: _tratamento.text.trim(),
      observacoes: _observacoes.text.trim(),
      valor: valor,
    );

    setState(() => _enviando = true);
    try {
      await (widget.enviar ?? _enviarApi)(dados);
      if (!mounted) return;
      mostrarMensagem(context, 'Atendimento registrado e cobrança gerada.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final erro = traduzirErro(e);
      setState(() => _erros = erro.campos);
      mostrarMensagem(context, erro.mensagem);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  static Future<void> _enviarApi(DadosAtendimentoForm d) async {
    await Api.registrarAtendimento(
      animalId: d.animalId,
      consultaId: d.consultaId,
      motivo: d.motivo,
      diagnostico: d.diagnostico,
      tratamento: d.tratamento,
      observacoes: d.observacoes,
      valor: d.valor,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar atendimento')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _CabecalhoAnimal(
            animalNome: widget.animalNome,
            texto: widget.consultaId == null
                ? 'Atendimento avulso'
                : 'A consulta será marcada como realizada',
          ),
          CampoTexto(rotulo: 'Motivo da consulta', controller: _motivo, erro: _erros['motivo']),
          CampoTexto(rotulo: 'Diagnóstico *', controller: _diagnostico, erro: _erros['diagnostico']),
          CampoTexto(rotulo: 'Tratamento *', controller: _tratamento, erro: _erros['tratamento']),
          CampoTexto(rotulo: 'Observações', controller: _observacoes, erro: _erros['observacoes']),
          CampoTexto(
            rotulo: 'Valor da consulta (R\$)',
            dica: 'Em branco = ${moeda(15000)}',
            controller: _valor,
            erro: _erros['valor'],
            teclado: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 8),
          BotaoPrimario(texto: 'Salvar atendimento', carregando: _enviando, onPressed: _salvar),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Prescrição

class PrescricaoFormScreen extends StatefulWidget {
  final String animalId;
  final String animalNome;

  /// Devolve a resposta da API (com `horariosMedicacao` e `lembretesAgendados`).
  final Future<Map<String, dynamic>> Function(DadosPrescricaoForm dados)? enviar;

  const PrescricaoFormScreen({
    super.key,
    required this.animalId,
    required this.animalNome,
    this.enviar,
  });

  @override
  State<PrescricaoFormScreen> createState() => _PrescricaoFormScreenState();
}

class _PrescricaoFormScreenState extends State<PrescricaoFormScreen> {
  final _medicamento = TextEditingController();
  final _dosagem = TextEditingController();
  final _frequencia = TextEditingController(text: '8');
  final _duracao = TextEditingController(text: '7');
  final _orientacoes = TextEditingController();
  Map<String, String> _erros = {};
  bool _enviando = false;

  @override
  void dispose() {
    for (final c in [_medicamento, _dosagem, _frequencia, _duracao, _orientacoes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _salvar() async {
    final erros = <String, String>{};
    if (_medicamento.text.trim().isEmpty) erros['medicamento'] = 'Informe o medicamento.';
    if (_dosagem.text.trim().isEmpty) erros['dosagem'] = 'Informe a dosagem.';
    final freq = lerInteiro(_frequencia.text, 1, 168);
    if (freq == null) erros['frequenciaHoras'] = 'De 1 a 168 horas.';
    final dias = lerInteiro(_duracao.text, 1, 365);
    if (dias == null) erros['duracaoDias'] = 'De 1 a 365 dias.';
    setState(() => _erros = erros);
    if (erros.isNotEmpty) return;

    final dados = DadosPrescricaoForm(
      animalId: widget.animalId,
      animalNome: widget.animalNome,
      medicamento: _medicamento.text.trim(),
      dosagem: _dosagem.text.trim(),
      frequenciaHoras: freq!,
      duracaoDias: dias!,
      orientacoes: _orientacoes.text.trim(),
    );

    setState(() => _enviando = true);
    try {
      final resposta = await (widget.enviar ?? _enviarApi)(dados);
      if (!mounted) return;
      await _mostrarResultado(dados, resposta);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final erro = traduzirErro(e);
      setState(() => _erros = erro.campos);
      mostrarMensagem(context, erro.mensagem);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  /// RF21: integra o serviço que registra na API e agenda os lembretes no aparelho.
  static Future<Map<String, dynamic>> _enviarApi(DadosPrescricaoForm d) {
    return PrescricaoMedicacaoService.registrar(
      animalId: d.animalId,
      animalNome: d.animalNome,
      medicamento: d.medicamento,
      dosagem: d.dosagem,
      frequenciaHoras: d.frequenciaHoras,
      duracaoDias: d.duracaoDias,
      orientacoes: d.orientacoes,
    );
  }

  Future<void> _mostrarResultado(
    DadosPrescricaoForm dados,
    Map<String, dynamic> resposta,
  ) {
    final horarios = ((resposta['horariosMedicacao'] as List?) ?? const [])
        .map((e) => DateTime.tryParse(e.toString()))
        .whereType<DateTime>()
        .where((h) => h.isAfter(DateTime.now()))
        .toList();
    final agendados = (resposta['lembretesAgendados'] as num?)?.toInt() ?? 0;

    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Prescrição registrada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$agendados lembrete(s) de medicamento agendado(s) neste aparelho.'),
            if (horarios.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Próximo: ${dataHoraBr(horarios.first)}', style: Estilos.rotulo),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await NotificacoesMedicacao.agendarTeste(
                  animal: dados.animalNome,
                  medicamento: dados.medicamento,
                );
                if (ctx.mounted) mostrarMensagem(ctx, 'Lembrete de teste em 1 minuto.');
              } catch (_) {
                if (ctx.mounted) mostrarMensagem(ctx, 'Não foi possível agendar o teste.');
              }
            },
            child: const Text('Testar lembrete (1 min)'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nova prescrição')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _CabecalhoAnimal(
            animalNome: widget.animalNome,
            texto: 'Os lembretes dos horários são agendados no aparelho',
          ),
          CampoTexto(rotulo: 'Medicamento *', controller: _medicamento, erro: _erros['medicamento']),
          CampoTexto(rotulo: 'Dosagem *', dica: 'Ex.: 1 comprimido', controller: _dosagem, erro: _erros['dosagem']),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CampoTexto(
                  rotulo: 'A cada (horas) *',
                  controller: _frequencia,
                  erro: _erros['frequenciaHoras'],
                  teclado: TextInputType.number,
                  apenasDigitos: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CampoTexto(
                  rotulo: 'Por (dias) *',
                  controller: _duracao,
                  erro: _erros['duracaoDias'],
                  teclado: TextInputType.number,
                  apenasDigitos: true,
                ),
              ),
            ],
          ),
          CampoTexto(rotulo: 'Orientações', controller: _orientacoes, erro: _erros['orientacoes']),
          const SizedBox(height: 8),
          BotaoPrimario(texto: 'Salvar prescrição', carregando: _enviando, onPressed: _salvar),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Vacina

class VacinaFormScreen extends StatefulWidget {
  final String animalId;
  final String animalNome;
  final Future<void> Function(DadosVacinaForm dados)? enviar;

  const VacinaFormScreen({
    super.key,
    required this.animalId,
    required this.animalNome,
    this.enviar,
  });

  @override
  State<VacinaFormScreen> createState() => _VacinaFormScreenState();
}

class _VacinaFormScreenState extends State<VacinaFormScreen> {
  final _nome = TextEditingController();
  final _aplicacao = TextEditingController(text: dataBr(dataIso(DateTime.now())));
  final _proxima = TextEditingController();
  final _lote = TextEditingController();
  Map<String, String> _erros = {};
  bool _enviando = false;

  @override
  void dispose() {
    for (final c in [_nome, _aplicacao, _proxima, _lote]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _escolherData(TextEditingController alvo, {bool futuro = false}) async {
    final hoje = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: futuro ? hoje.add(const Duration(days: 30)) : hoje,
      firstDate: futuro ? hoje : DateTime(2015),
      lastDate: futuro ? DateTime(hoje.year + 5) : hoje,
    );
    if (d != null) setState(() => alvo.text = dataBr(dataIso(d)));
  }

  Future<void> _salvar() async {
    final erros = <String, String>{};
    if (_nome.text.trim().isEmpty) erros['nome'] = 'Informe a vacina.';
    final aplicacao = lerDataBr(_aplicacao.text);
    if (aplicacao == null) {
      erros['dataAplicacao'] = 'Data inválida (dd/mm/aaaa).';
    } else if (aplicacao.compareTo(dataIso(DateTime.now())) > 0) {
      erros['dataAplicacao'] = 'A aplicação não pode ser no futuro.';
    }
    String? proxima;
    if (_proxima.text.trim().isNotEmpty) {
      proxima = lerDataBr(_proxima.text);
      if (proxima == null) {
        erros['proximaDose'] = 'Data inválida (dd/mm/aaaa).';
      } else if (aplicacao != null && proxima.compareTo(aplicacao) <= 0) {
        erros['proximaDose'] = 'Deve ser depois da aplicação.';
      }
    }
    setState(() => _erros = erros);
    if (erros.isNotEmpty) return;

    final dados = DadosVacinaForm(
      animalId: widget.animalId,
      nome: _nome.text.trim(),
      dataAplicacao: aplicacao!,
      proximaDose: proxima,
      lote: _lote.text.trim(),
    );

    setState(() => _enviando = true);
    try {
      await (widget.enviar ?? _enviarApi)(dados);
      if (!mounted) return;
      mostrarMensagem(
        context,
        proxima == null
            ? 'Vacina registrada.'
            : 'Vacina registrada. O tutor será lembrado da próxima dose.',
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final erro = traduzirErro(e);
      setState(() => _erros = erro.campos);
      mostrarMensagem(context, erro.mensagem);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  static Future<void> _enviarApi(DadosVacinaForm d) async {
    await Api.registrarVacina(
      animalId: d.animalId,
      nome: d.nome,
      dataAplicacao: d.dataAplicacao,
      proximaDose: d.proximaDose,
      lote: d.lote,
    );
  }

  Widget _campoData(String rotulo, TextEditingController c, String campo, {bool futuro = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: CampoTexto(
            rotulo: rotulo,
            dica: 'dd/mm/aaaa',
            controller: c,
            erro: _erros[campo],
            teclado: TextInputType.datetime,
          ),
        ),
        IconButton(
          tooltip: 'Escolher data',
          icon: const Icon(Icons.calendar_month),
          onPressed: () => _escolherData(c, futuro: futuro),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar vacina')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _CabecalhoAnimal(
            animalNome: widget.animalNome,
            texto: 'Com a próxima dose, o tutor recebe lembrete 7 dias antes',
          ),
          CampoTexto(rotulo: 'Vacina *', dica: 'Ex.: V10, Antirrábica', controller: _nome, erro: _erros['nome']),
          _campoData('Data da aplicação *', _aplicacao, 'dataAplicacao'),
          _campoData('Próxima dose', _proxima, 'proximaDose', futuro: true),
          CampoTexto(rotulo: 'Lote', controller: _lote, erro: _erros['lote']),
          const SizedBox(height: 8),
          BotaoPrimario(texto: 'Salvar vacina', carregando: _enviando, onPressed: _salvar),
        ],
      ),
    );
  }
}
