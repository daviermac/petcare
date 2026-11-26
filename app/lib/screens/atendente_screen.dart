import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/item_agenda.dart';
import '../services/api.dart';
import '../services/exames.dart';

class AtendenteScreen extends StatefulWidget {
  const AtendenteScreen({super.key});

  @override
  State<AtendenteScreen> createState() => _AtendenteScreenState();
}

class _AtendenteScreenState extends State<AtendenteScreen> {
  DateTime _dataSelecionada = DateTime.now();
  late Future<List<ItemAgenda>> _agendaFuture;

  final Map<String, Future<List<Reference>>> _examesFutures = {};

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
      _agendaFuture = Api.agendaDoDia(_dataIso(data));
    });
  }

  Future<void> _remarcar(ItemAgenda consulta) async {
    if (consulta.status != 'agendada') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Somente consultas agendadas podem ser remarcadas.'),
        ),
      );
      return;
    }

    final data = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada.isBefore(DateTime.now())
          ? DateTime.now()
          : _dataSelecionada,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Escolha a nova data',
    );

    if (data == null || !mounted) return;

    try {
      final horarios = await Api.listarHorarios(_dataIso(data));
      final disponiveis = horarios.where((h) => h.disponivel).toList();

      if (!mounted) return;

      if (disponiveis.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não há horários disponíveis nessa data.'),
          ),
        );
        return;
      }

      String horarioEscolhido = disponiveis.first.horario;

      final horario = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, atualizarDialogo) {
              return AlertDialog(
                title: const Text('Escolher horário'),
                content: DropdownButtonFormField<String>(
                  initialValue: horarioEscolhido,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Horário disponível',
                  ),
                  items: disponiveis.map((h) {
                    return DropdownMenuItem(
                      value: h.horario,
                      child: Text(h.horario),
                    );
                  }).toList(),
                  onChanged: (valor) {
                    if (valor != null) {
                      atualizarDialogo(() {
                        horarioEscolhido = valor;
                      });
                    }
                  },
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(dialogContext, horarioEscolhido);
                    },
                    child: const Text('Confirmar'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (horario == null || !mounted) return;

      await Api.remarcarConsulta(
        consultaId: consulta.consultaId,
        data: _dataIso(data),
        horario: horario,
      );

      if (!mounted) return;

      setState(() {
        _dataSelecionada = data;
        _agendaFuture = Api.agendaDoDia(_dataIso(data));
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Consulta remarcada com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível remarcar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _anexarExame(ItemAgenda consulta) async {
    if (consulta.status != 'realizada') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Só é possível anexar exames em consultas realizadas.'),
        ),
      );
      return;
    }

    if (consulta.animalId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível identificar o animal desta consulta.',
          ),
        ),
      );
      return;
    }

    try {
      final arquivo = await FilePicker.pickFile(
        dialogTitle: 'Selecione o exame do animal',
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (arquivo == null || !mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enviando exame...'),
          duration: Duration(seconds: 2),
        ),
      );

      await ExamesService.enviar(animalId: consulta.animalId, arquivo: arquivo);

      if (!mounted) return;

      setState(() {
        _examesFutures.remove(consulta.animalId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Exame anexado com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível anexar o exame: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<List<Reference>> _buscarExames(String animalId) {
    return _examesFutures.putIfAbsent(
      animalId,
      () => ExamesService.listar(animalId),
    );
  }

  Future<void> _abrirExame(Reference referencia) async {
    try {
      final url = await ExamesService.obterUrl(referencia);
      final uri = Uri.parse(url);

      final abriu = await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!abriu && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o arquivo.')),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao abrir exame: $e')));
    }
  }

  String _nomeArquivo(Reference referencia) {
    final nome = referencia.name;
    final partes = nome.split('_');

    if (partes.length > 1) {
      return partes.sublist(1).join('_');
    }

    return nome;
  }

  String _dataEnvio(Reference referencia) {
    final partes = referencia.name.split('_');

    if (partes.isNotEmpty) {
      final timestamp = int.tryParse(partes.first);

      if (timestamp != null) {
        final data = DateTime.fromMillisecondsSinceEpoch(timestamp);
        return _dataLegivel(data);
      }
    }

    return 'Data não disponível';
  }

  Widget _listaExames(String animalId) {
    return FutureBuilder<List<Reference>>(
      future: _buscarExames(animalId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Column(
            children: [
              const Text('Não foi possível carregar os exames.'),
              TextButton(
                onPressed: () {
                  setState(() {
                    _examesFutures.remove(animalId);
                  });
                },
                child: const Text('Tentar novamente'),
              ),
            ],
          );
        }

        final exames = snapshot.data ?? [];

        if (exames.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Nenhum exame anexado ainda.'),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: exames.map((exame) {
            final nome = _nomeArquivo(exame);
            final extensao = nome.split('.').last.toLowerCase();
            final ehImagem = ['jpg', 'jpeg', 'png'].contains(extensao);

            return Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              margin: const EdgeInsets.only(top: 8),
              child: ListTile(
                leading: ehImagem
                    ? FutureBuilder<String>(
                        future: ExamesService.obterUrl(exame),
                        builder: (context, urlSnapshot) {
                          if (urlSnapshot.hasData) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                urlSnapshot.data!,
                                width: 52,
                                height: 52,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const Icon(Icons.broken_image, size: 36),
                              ),
                            );
                          }

                          return const SizedBox(
                            width: 52,
                            height: 52,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        },
                      )
                    : const Icon(
                        Icons.picture_as_pdf,
                        color: Colors.red,
                        size: 36,
                      ),
                title: Text(nome, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text('Enviado em ${_dataEnvio(exame)}'),
                trailing: IconButton(
                  tooltip: 'Abrir exame',
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () => _abrirExame(exame),
                ),
                onTap: () => _abrirExame(exame),
              ),
            );
          }).toList(),
        );
      },
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda do Atendente'),
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
                title: const Text('Agenda do dia'),
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
            const Text(
              'Consultas',
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
                            'Nenhuma consulta para esta data.',
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
                            if (consulta.status == 'agendada') ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => _remarcar(consulta),
                                  icon: const Icon(Icons.edit_calendar),
                                  label: const Text('Remarcar consulta'),
                                ),
                              ),
                            ],
                            if (consulta.status == 'realizada') ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => _anexarExame(consulta),
                                  icon: const Icon(Icons.attach_file),
                                  label: const Text('Anexar exame'),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Exames anexados',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              _listaExames(consulta.animalId),
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
