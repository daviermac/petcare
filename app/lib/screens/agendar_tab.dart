import 'package:flutter/material.dart';

import '../core/erros.dart';
import '../core/formatadores.dart';
import '../core/tema.dart';
import '../models/animal.dart';
import '../services/api.dart';
import '../services/dados.dart';
import '../widgets/componentes.dart';
import 'confirmacao_screen.dart';

/// HU03 / RF06 / RF07: agendar consulta (animal -> dia -> horário -> confirmar).
class AgendarTab extends StatefulWidget {
  final VoidCallback aoConcluir;
  final VoidCallback irParaAnimais;

  const AgendarTab({
    super.key,
    required this.aoConcluir,
    required this.irParaAnimais,
  });

  @override
  State<AgendarTab> createState() => _AgendarTabState();
}

class _AgendarTabState extends State<AgendarTab> {
  late final Stream<List<Animal>> _animais = Dados.animais();
  final List<DateTime> _dias = proximosDiasUteis(20);

  String? _animalId;
  DateTime? _dia;
  String? _horario;
  List<HorarioDisponivel>? _horarios;
  bool _carregandoHorarios = false;
  String? _erroHorarios;
  bool _enviando = false;

  Future<void> _selecionarDia(DateTime dia) async {
    setState(() {
      _dia = dia;
      _horario = null;
      _horarios = null;
    });
    await _carregarHorarios();
  }

  Future<void> _carregarHorarios() async {
    final dia = _dia;
    if (dia == null) return;
    setState(() {
      _carregandoHorarios = true;
      _erroHorarios = null;
    });
    try {
      final lista = await Api.listarHorarios(dataIso(dia));
      if (!mounted || _dia != dia) return;
      setState(() => _horarios = lista);
    } catch (e) {
      if (!mounted || _dia != dia) return;
      setState(() => _erroHorarios = traduzirErro(e).mensagem);
    } finally {
      if (mounted && _dia == dia) {
        setState(() => _carregandoHorarios = false);
      }
    }
  }

  /// Horário de hoje que já passou não pode ser escolhido.
  bool _jaPassou(String horario) {
    final dia = _dia;
    if (dia == null) return false;
    final agora = DateTime.now();
    if (dataIso(dia) != dataIso(agora)) return false;
    return horario.compareTo(horaTexto(agora)) <= 0;
  }

  Future<void> _agendar() async {
    final animalId = _animalId;
    final dia = _dia;
    final horario = _horario;
    if (animalId == null || dia == null || horario == null) return;

    setState(() => _enviando = true);
    try {
      final resultado = await Api.agendarConsulta(
        animalId: animalId,
        data: dataIso(dia),
        horario: horario,
      );
      if (!mounted) return;
      setState(() {
        _animalId = null;
        _dia = null;
        _horario = null;
        _horarios = null;
        _enviando = false;
      });
      final verConsultas = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => ConfirmacaoScreen(dados: resultado),
        ),
      );
      if (verConsultas == true) widget.aoConcluir();
    } catch (e) {
      final erro = traduzirErro(e);
      if (!mounted) return;
      setState(() {
        _enviando = false;
        if (erro.codigo == 'HORARIO_INDISPONIVEL') _horario = null;
      });
      mostrarMensagem(context, erro.mensagem);
      // Horário ocupado: atualiza a lista para riscar o horário.
      if (erro.codigo == 'HORARIO_INDISPONIVEL') _carregarHorarios();
    }
  }

  Widget _blocoHorarios() {
    if (_dia == null) {
      return const Text('Escolha um dia para ver os horários.', style: Estilos.suave);
    }
    if (_carregandoHorarios) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_erroHorarios != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_erroHorarios!, style: Estilos.erro),
          TextButton(
            onPressed: _carregarHorarios,
            child: const Text('Tentar de novo'),
          ),
        ],
      );
    }
    final lista = _horarios ?? const <HorarioDisponivel>[];
    final algumLivre = lista.any((h) => h.disponivel && !_jaPassou(h.horario));
    if (!algumLivre) {
      return const Text(
        'Sem horários disponíveis neste dia. Escolha outra data.',
        style: Estilos.erro,
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final h in lista)
          Builder(
            builder: (context) {
              final indisponivel = !h.disponivel || _jaPassou(h.horario);
              return ChoiceChip(
                label: Text(
                  h.horario,
                  style: TextStyle(
                    decoration:
                        indisponivel ? TextDecoration.lineThrough : null,
                  ),
                ),
                selected: _horario == h.horario,
                onSelected: indisponivel
                    ? null
                    : (_) => setState(() => _horario = h.horario),
              );
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Animal>>(
      stream: _animais,
      builder: (context, snap) {
        if (snap.hasError) {
          return const Center(child: Text('Não foi possível carregar seus animais.'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final animais = snap.data!;
        if (animais.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              const Text('Agendar consulta', style: Estilos.titulo),
              const SizedBox(height: 16),
              EstadoVazio(
                icone: Icons.pets,
                texto: 'Cadastre um animal antes de agendar uma consulta.',
                textoBotao: 'Cadastrar animal',
                aoPressionar: widget.irParaAnimais,
              ),
            ],
          );
        }

        final pronto = _animalId != null && _dia != null && _horario != null;
        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text('Agendar consulta', style: Estilos.titulo),
            const SizedBox(height: 18),
            const Text('Qual animal será atendido?', style: Estilos.secao),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final a in animais)
                  ChoiceChip(
                    label: Text(a.nome),
                    selected: _animalId == a.id,
                    onSelected: (_) => setState(() => _animalId = a.id),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            const Text('Escolha o dia', style: Estilos.secao),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final d in _dias)
                  ChoiceChip(
                    label: Text(diaCurto(d)),
                    selected: _dia == d,
                    onSelected: (_) => _selecionarDia(d),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            const Text('Horários disponíveis', style: Estilos.secao),
            const SizedBox(height: 10),
            _blocoHorarios(),
            const SizedBox(height: 22),
            BotaoPrimario(
              texto: 'Confirmar agendamento',
              onPressed: pronto ? _agendar : null,
              carregando: _enviando,
            ),
          ],
        );
      },
    );
  }
}
