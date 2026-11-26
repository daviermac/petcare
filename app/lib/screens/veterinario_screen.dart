import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/erros.dart';
import '../core/formatadores.dart';
import '../core/tema.dart';
import '../models/animal.dart';
import '../models/item_agenda.dart';
import '../services/api.dart';
import '../widgets/componentes.dart';
import 'prontuario_screen.dart';

/// Área do Veterinário: agenda do dia (RF08) e pacientes, com acesso ao prontuário
/// (RF13), atendimento (RF14), prescrição (RF15/RF21) e vacina (RF16).
class VeterinarioScreen extends StatefulWidget {
  const VeterinarioScreen({super.key});

  @override
  State<VeterinarioScreen> createState() => _VeterinarioScreenState();
}

class _VeterinarioScreenState extends State<VeterinarioScreen> {
  int _aba = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Área do Veterinário'),
        actions: [
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: IndexedStack(
        index: _aba,
        children: const [_AgendaVeterinario(), _Pacientes()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _aba,
        onDestinationSelected: (i) => setState(() => _aba = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Agenda'),
          NavigationDestination(icon: Icon(Icons.pets), label: 'Pacientes'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Agenda

class _AgendaVeterinario extends StatefulWidget {
  const _AgendaVeterinario();

  @override
  State<_AgendaVeterinario> createState() => _AgendaVeterinarioState();
}

class _AgendaVeterinarioState extends State<_AgendaVeterinario> {
  DateTime _data = DateTime.now();
  late Future<List<ItemAgenda>> _agenda;

  @override
  void initState() {
    super.initState();
    _agenda = Api.agendaDoDia(dataIso(_data));
  }

  void _carregar() => setState(() => _agenda = Api.agendaDoDia(dataIso(_data)));

  Future<void> _escolherData() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2025),
      lastDate: DateTime(2035),
      helpText: 'Selecione o dia da agenda',
    );
    if (d == null || !mounted) return;
    _data = d;
    _carregar();
  }

  Future<void> _abrirProntuario(ItemAgenda c) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProntuarioScreen(
          animalId: c.animalId,
          animalNome: c.animalNome,
          consultaId: c.status == 'agendada' ? c.consultaId : null,
        ),
      ),
    );
    if (mounted) _carregar();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        _carregar();
        await _agenda.catchError((_) => <ItemAgenda>[]);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Consultas do dia'),
              subtitle: Text('${diaCurto(_data)} • ${dataBr(dataIso(_data))}'),
              trailing: const Icon(Icons.edit_calendar),
              onTap: _escolherData,
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<ItemAgenda>>(
            future: _agenda,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError) {
                return EstadoVazio(
                  icone: Icons.error_outline,
                  texto: traduzirErro(snap.error!).mensagem,
                  textoBotao: 'Tentar novamente',
                  aoPressionar: _carregar,
                );
              }
              final lista = snap.data ?? [];
              if (lista.isEmpty) {
                return const EstadoVazio(
                  icone: Icons.event_available,
                  texto: 'Nenhuma consulta nesta data.',
                );
              }
              return Column(
                children: lista.map((c) {
                  return CartaoLista(
                    nomeAvatar: c.animalNome,
                    titulo: '${c.horario} • ${c.animalNome}',
                    subtitulo: '${_especie(c.especie)} • Tutor: ${c.tutorNome}',
                    trailing: StatusChip(status: c.status, rotulo: c.statusRotulo),
                    onTap: () => _abrirProntuario(c),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 8),
          const Text(
            'Toque na consulta para abrir o prontuário e registrar o atendimento.',
            style: Estilos.suave,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

String _especie(String e) => switch (e) {
  'cachorro' => 'Cachorro',
  'gato' => 'Gato',
  _ => 'Outro',
};

// ---------------------------------------------------------------- Pacientes

class _Pacientes extends StatefulWidget {
  const _Pacientes();

  @override
  State<_Pacientes> createState() => _PacientesState();
}

class _PacientesState extends State<_Pacientes> {
  final _busca = TextEditingController();
  late final Stream<List<Animal>> _animais = FirebaseFirestore.instance
      .collection('animais')
      .snapshots()
      .map((s) {
        final lista = s.docs.map(Animal.fromDoc).toList();
        lista.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
        return lista;
      });

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: TextField(
            controller: _busca,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Buscar paciente pelo nome',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Animal>>(
            stream: _animais,
            builder: (context, snap) {
              if (snap.hasError) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: EstadoVazio(
                    icone: Icons.error_outline,
                    texto: 'Não foi possível carregar os pacientes.',
                  ),
                );
              }
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final termo = _busca.text.trim().toLowerCase();
              final lista = snap.data!
                  .where((a) => termo.isEmpty || a.nome.toLowerCase().contains(termo))
                  .toList();
              if (lista.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: EstadoVazio(icone: Icons.pets, texto: 'Nenhum paciente encontrado.'),
                );
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: lista.map((a) {
                  return CartaoLista(
                    nomeAvatar: a.nome,
                    titulo: a.nome,
                    subtitulo: '${a.especieRotulo} • ${a.raca.isEmpty ? 'SRD' : a.raca} • ${a.idadeRotulo}',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProntuarioScreen(animalId: a.id, animalNome: a.nome),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}
