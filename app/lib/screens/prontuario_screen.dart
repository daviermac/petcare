import 'package:flutter/material.dart';

import '../core/erros.dart';
import '../core/formatadores.dart';
import '../core/tema.dart';
import '../models/registro_medico.dart';
import '../services/api.dart';
import '../widgets/componentes.dart';
import 'formularios_veterinario.dart';

/// Prontuário do animal para o veterinário (RF13): histórico em ordem cronológica
/// e atalhos para registrar atendimento, prescrição e vacina.
class ProntuarioScreen extends StatefulWidget {
  final String animalId;
  final String animalNome;

  /// Consulta que está sendo atendida (vinda da agenda). Opcional.
  final String? consultaId;

  const ProntuarioScreen({
    super.key,
    required this.animalId,
    required this.animalNome,
    this.consultaId,
  });

  @override
  State<ProntuarioScreen> createState() => _ProntuarioScreenState();
}

class _ProntuarioScreenState extends State<ProntuarioScreen> {
  late Future<HistoricoAnimal> _historico;
  String? _consultaId;

  @override
  void initState() {
    super.initState();
    _consultaId = widget.consultaId;
    _historico = Api.historicoDoAnimal(widget.animalId);
  }

  void _recarregar() {
    setState(() => _historico = Api.historicoDoAnimal(widget.animalId));
  }

  Future<void> _abrir(Widget tela, {bool atendimento = false}) async {
    final salvou = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => tela),
    );
    if (salvou == true && mounted) {
      // Depois do atendimento a consulta já está realizada: não usa de novo.
      if (atendimento) setState(() => _consultaId = null);
      _recarregar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Prontuário — ${widget.animalNome}'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _recarregar,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _recarregar();
          await _historico.catchError((_) => _historicoVazio);
        },
        child: FutureBuilder<HistoricoAnimal>(
          future: _historico,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  EstadoVazio(
                    icone: Icons.error_outline,
                    texto: traduzirErro(snap.error!).mensagem,
                    textoBotao: 'Tentar novamente',
                    aoPressionar: _recarregar,
                  ),
                ],
              );
            }
            final h = snap.data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                _CabecalhoPaciente(historico: h),
                const SizedBox(height: 16),
                _Acoes(
                  aoAtender: () => _abrir(
                    AtendimentoFormScreen(
                      animalId: widget.animalId,
                      animalNome: widget.animalNome,
                      consultaId: _consultaId,
                    ),
                    atendimento: true,
                  ),
                  aoPrescrever: () => _abrir(
                    PrescricaoFormScreen(
                      animalId: widget.animalId,
                      animalNome: widget.animalNome,
                    ),
                  ),
                  aoVacinar: () => _abrir(
                    VacinaFormScreen(
                      animalId: widget.animalId,
                      animalNome: widget.animalNome,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Histórico (${h.registros.length})', style: Estilos.secao),
                const SizedBox(height: 10),
                if (h.registros.isEmpty)
                  const EstadoVazio(
                    icone: Icons.history,
                    texto: 'Nenhum registro no prontuário ainda.',
                  ),
                // Mais recentes primeiro na tela (a API devolve em ordem cronológica).
                ...h.registros.reversed.map((r) => CartaoRegistro(registro: r)),
              ],
            );
          },
        ),
      ),
    );
  }

  static const _historicoVazio = HistoricoAnimal(
    animalId: '',
    nome: '',
    especie: '',
    raca: '',
    idade: 0,
    registros: [],
  );
}

class _CabecalhoPaciente extends StatelessWidget {
  final HistoricoAnimal historico;
  const _CabecalhoPaciente({required this.historico});

  @override
  Widget build(BuildContext context) {
    final especie = switch (historico.especie) {
      'cachorro' => 'Cachorro',
      'gato' => 'Gato',
      _ => 'Outro',
    };
    final raca = historico.raca.isEmpty ? 'SRD' : historico.raca;
    final idade = historico.idade == 1 ? '1 ano' : '${historico.idade} anos';
    return CartaoLista(
      nomeAvatar: historico.nome,
      titulo: historico.nome,
      subtitulo: '$especie • $raca • $idade',
    );
  }
}

class _Acoes extends StatelessWidget {
  final VoidCallback aoAtender;
  final VoidCallback aoPrescrever;
  final VoidCallback aoVacinar;

  const _Acoes({
    required this.aoAtender,
    required this.aoPrescrever,
    required this.aoVacinar,
  });

  @override
  Widget build(BuildContext context) {
    Widget botao(IconData icone, String texto, VoidCallback onTap) {
      return Expanded(
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            foregroundColor: Cores.primaria,
            side: const BorderSide(color: Cores.linha, width: 2),
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Column(
            children: [
              Icon(icone),
              const SizedBox(height: 4),
              Text(texto, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        botao(Icons.medical_services_outlined, 'Atendimento', aoAtender),
        const SizedBox(width: 8),
        botao(Icons.medication_outlined, 'Prescrição', aoPrescrever),
        const SizedBox(width: 8),
        botao(Icons.vaccines_outlined, 'Vacina', aoVacinar),
      ],
    );
  }
}

/// Cartão de um item do prontuário.
class CartaoRegistro extends StatelessWidget {
  final RegistroMedico registro;
  const CartaoRegistro({super.key, required this.registro});

  IconData get _icone => switch (registro.tipo) {
    'atendimento' => Icons.medical_services_outlined,
    'prescricao' => Icons.medication_outlined,
    'vacina' => Icons.vaccines_outlined,
    _ => Icons.healing_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final quando = registro.criadoEm == null ? '' : dataHoraBr(registro.criadoEm!);
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Cores.linha),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_icone, color: Cores.primaria, size: 20),
                const SizedBox(width: 8),
                Text(registro.tipoRotulo, style: Estilos.rotulo),
                const Spacer(),
                if (registro.versao > 1)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: StatusChip(status: 'agendada', rotulo: 'Corrigido'),
                  ),
                Text(quando, style: Estilos.suave),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              registro.titulo,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Cores.texto),
            ),
            for (final linha in registro.detalhes)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(linha, style: const TextStyle(color: Cores.texto)),
              ),
            const SizedBox(height: 6),
            Text('Por ${registro.autorNome}', style: Estilos.suave),
          ],
        ),
      ),
    );
  }
}
