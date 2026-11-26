import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/item_agenda.dart';
import '../services/api.dart';

class AuxiliarScreen extends StatefulWidget {
  const AuxiliarScreen({super.key});

  @override
  State<AuxiliarScreen> createState() => _AuxiliarScreenState();
}

class _AuxiliarScreenState extends State<AuxiliarScreen> {
  DateTime _dataSelecionada = DateTime.now();
  late Future<List<ItemAgenda>> _agendaFuture;

  final List<String> _tarefas = [
    'Preparar o ambiente de atendimento',
    'Conferir os materiais necessários',
    'Organizar os materiais após os atendimentos',
    'Verificar se o ambiente está limpo e organizado',
  ];

  final Set<String> _tarefasConcluidas = {};

  @override
  void initState() {
    super.initState();
    _agendaFuture = Api.agendaDoDia(_dataIso(_dataSelecionada));
  }

  String _dataIso(DateTime data) {
    final ano = data.year.toString().padLeft(4, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final dia = data.day.toString().padLeft(2, '0');

    return '$ano-$mes-$dia';
  }

  String _dataLegivel(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    return '$dia/$mes/${data.year}';
  }

  void _carregarAgenda() {
    setState(() {
      _agendaFuture = Api.agendaDoDia(_dataIso(_dataSelecionada));
    });
  }

  Future<void> _selecionarData() async {
    final data = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada,
      firstDate: DateTime(2025),
      lastDate: DateTime(2035),
      helpText: 'Selecione o dia da agenda',
    );

    if (data == null || !mounted) return;

    setState(() {
      _dataSelecionada = data;
      _tarefasConcluidas.clear();
      _agendaFuture = Api.agendaDoDia(_dataIso(data));
    });
  }

  void _alternarTarefa(String tarefa, bool? concluida) {
    setState(() {
      if (concluida == true) {
        _tarefasConcluidas.add(tarefa);
      } else {
        _tarefasConcluidas.remove(tarefa);
      }
    });
  }

  Future<void> _registrarProcedimento(ItemAgenda consulta) async {
    String descricao = '';
    String observacoes = '';

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Registrar procedimento'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Animal: ${consulta.animalNome}'),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Descrição do procedimento',
                    hintText: 'Ex.: Limpeza, curativo...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  onChanged: (valor) => descricao = valor,
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Observações (opcional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  onChanged: (valor) => observacoes = valor,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (descricao.trim().isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Informe a descrição do procedimento.'),
                    ),
                  );
                  return;
                }

                Navigator.pop(dialogContext, true);
              },
              child: const Text('Registrar'),
            ),
          ],
        );
      },
    );

    if (confirmado != true || !mounted) return;

    try {
      await Api.registrarProcedimento(
        animalId: consulta.animalId,
        descricao: descricao.trim(),
        observacoes: observacoes.trim().isEmpty ? null : observacoes.trim(),
      );

      if (!mounted) return;

      _carregarAgenda();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Procedimento registrado com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível registrar o procedimento: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color _corStatus(String status) {
    switch (status) {
      case 'agendada':
        return Colors.blue;
      case 'cancelada':
        return Colors.red;
      case 'realizada':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _nomeStatus(String status) {
    switch (status) {
      case 'agendada':
        return 'Agendada';
      case 'cancelada':
        return 'Cancelada';
      case 'realizada':
        return 'Realizada';
      default:
        return status;
    }
  }

  Widget _construirTarefas() {
    final concluidas = _tarefasConcluidas.length;
    final total = _tarefas.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.checklist, size: 26),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Tarefas do dia',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '$concluidas/$total',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: total == 0 ? 0 : concluidas / total),
            const SizedBox(height: 12),
            ..._tarefas.map((tarefa) {
              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(tarefa),
                value: _tarefasConcluidas.contains(tarefa),
                onChanged: (valor) => _alternarTarefa(tarefa, valor),
              );
            }),
            if (concluidas == total)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Todas as tarefas foram concluídas!',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Área do Auxiliar'),
        actions: [
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _carregarAgenda();
          await _agendaFuture;
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_month),
                title: const Text('Animais do dia'),
                subtitle: Text(_dataLegivel(_dataSelecionada)),
                trailing: IconButton(
                  tooltip: 'Escolher data',
                  icon: const Icon(Icons.edit_calendar),
                  onPressed: _selecionarData,
                ),
                onTap: _selecionarData,
              ),
            ),
            const SizedBox(height: 16),

            _construirTarefas(),

            const SizedBox(height: 20),
            const Text(
              'Agenda de atendimentos',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            FutureBuilder<List<ItemAgenda>>(
              future: _agendaFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Icon(Icons.error_outline, size: 40),
                          const SizedBox(height: 8),
                          const Text('Não foi possível carregar a agenda.'),
                          TextButton(
                            onPressed: _carregarAgenda,
                            child: const Text('Tentar novamente'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final consultas = snapshot.data ?? [];

                if (consultas.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(Icons.event_available, size: 42),
                          SizedBox(height: 12),
                          Text(
                            'Nenhum animal agendado para esta data.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: consultas.map((consulta) {
                    final cor = _corStatus(consulta.status);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.access_time),
                                const SizedBox(width: 8),
                                Text(
                                  consulta.horario,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _nomeStatus(consulta.status),
                                    style: TextStyle(
                                      color: cor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Text(
                              consulta.animalNome,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text('Espécie: ${consulta.especie}'),
                            Text('Tutor: ${consulta.tutorNome}'),
                            Text('Local: ${consulta.local}'),
                            if (consulta.status != 'cancelada') ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: () =>
                                      _registrarProcedimento(consulta),
                                  icon: const Icon(Icons.medical_services),
                                  label: const Text('Registrar procedimento'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
