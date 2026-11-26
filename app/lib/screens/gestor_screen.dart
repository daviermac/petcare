import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/erros.dart';
import '../core/formatadores.dart';
import '../core/tema.dart';
import '../core/validacoes.dart';
import '../models/financeiro.dart';
import '../models/funcionario.dart';
import '../services/api.dart';
import '../widgets/componentes.dart';
import '../widgets/gestao.dart';

/// Área do Gestor: equipe (RF32), relatórios (RF31, RF33, RF35) e cobranças (RF30).
class GestorScreen extends StatefulWidget {
  const GestorScreen({super.key});

  @override
  State<GestorScreen> createState() => _GestorScreenState();
}

class _GestorScreenState extends State<GestorScreen> {
  int _aba = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Área do Gestor'),
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
        children: const [_Equipe(), _Relatorios(), _Cobrancas()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _aba,
        onDestinationSelected: (i) => setState(() => _aba = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.group), label: 'Equipe'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Relatórios'),
          NavigationDestination(icon: Icon(Icons.payments), label: 'Cobranças'),
        ],
      ),
    );
  }
}

/// Seletor de período usado nos relatórios e nas cobranças (padrão: mês atual).
class _SeletorPeriodo extends StatelessWidget {
  final DateTimeRange periodo;
  final ValueChanged<DateTimeRange> aoMudar;
  const _SeletorPeriodo({required this.periodo, required this.aoMudar});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.date_range),
        title: const Text('Período'),
        subtitle: Text('${dataBr(dataIso(periodo.start))} a ${dataBr(dataIso(periodo.end))}'),
        trailing: const Icon(Icons.edit_calendar),
        onTap: () async {
          final novo = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2025),
            lastDate: DateTime(2035),
            initialDateRange: periodo,
            helpText: 'Escolha o período',
          );
          if (novo != null) aoMudar(novo);
        },
      ),
    );
  }
}

DateTimeRange _mesAtual() {
  final hoje = DateTime.now();
  return DateTimeRange(
    start: DateTime(hoje.year, hoje.month, 1),
    end: DateTime(hoje.year, hoje.month + 1, 0),
  );
}

// ---------------------------------------------------------------- Equipe (RF32)

class _Equipe extends StatefulWidget {
  const _Equipe();

  @override
  State<_Equipe> createState() => _EquipeState();
}

class _EquipeState extends State<_Equipe> {
  // Um stream por tela (não estático), para funcionar depois de sair e entrar de novo.
  late final Stream<List<Funcionario>> _funcionarios = FirebaseFirestore.instance
      .collection('usuarios')
      .where('perfil', whereIn: perfisFuncionario)
      .snapshots()
      .map((s) {
        final lista = s.docs.map(Funcionario.fromDoc).toList();
        lista.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
        return lista;
      });

  Future<void> _alternar(BuildContext context, Funcionario f, bool ativo) async {
    if (!ativo) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Desativar funcionário?'),
          content: Text('${f.nome} perde o acesso ao sistema na hora.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Desativar')),
          ],
        ),
      );
      if (ok != true) return;
    }
    try {
      await Api.definirStatusFuncionario(f.uid, ativo);
      if (context.mounted) {
        mostrarMensagem(context, ativo ? '${f.nome} foi reativado(a).' : '${f.nome} foi desativado(a).');
      }
    } catch (e) {
      if (context.mounted) mostrarMensagem(context, traduzirErro(e).mensagem);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        StreamBuilder<List<Funcionario>>(
          stream: _funcionarios,
          builder: (context, snap) {
            if (snap.hasError) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: EstadoVazio(icone: Icons.error_outline, texto: 'Não foi possível carregar a equipe.'),
              );
            }
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                Text('Equipe (${snap.data!.length})', style: Estilos.secao),
                const SizedBox(height: 10),
                ListaFuncionarios(
                  funcionarios: snap.data!,
                  uidAtual: FirebaseAuth.instance.currentUser?.uid,
                  aoAlternar: (f, ativo) => _alternar(context, f, ativo),
                ),
              ],
            );
          },
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NovoFuncionarioScreen()),
            ),
            icon: const Icon(Icons.person_add),
            label: const Text('Novo funcionário'),
          ),
        ),
      ],
    );
  }
}

/// Dados do formulário de novo funcionário.
class DadosFuncionarioForm {
  final String nome;
  final String email;
  final String senha;
  final String perfil;
  const DadosFuncionarioForm(this.nome, this.email, this.senha, this.perfil);
}

/// Cadastro de funcionário (RF32). [enviar] é opcional para os testes de widget.
class NovoFuncionarioScreen extends StatefulWidget {
  final Future<void> Function(DadosFuncionarioForm dados)? enviar;
  const NovoFuncionarioScreen({super.key, this.enviar});

  @override
  State<NovoFuncionarioScreen> createState() => _NovoFuncionarioScreenState();
}

class _NovoFuncionarioScreenState extends State<NovoFuncionarioScreen> {
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  String _perfil = 'atendente';
  Map<String, String> _erros = {};
  bool _enviando = false;

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final erros = <String, String>{};
    if (!nomeCompletoValido(_nome.text)) erros['nome'] = 'Informe nome e sobrenome.';
    if (!emailValido(_email.text)) erros['email'] = 'E-mail inválido.';
    if (_senha.text.length < 8) erros['senha'] = 'Mínimo de 8 caracteres.';
    setState(() => _erros = erros);
    if (erros.isNotEmpty) return;

    final dados = DadosFuncionarioForm(
      _nome.text.trim(),
      _email.text.trim().toLowerCase(),
      _senha.text,
      _perfil,
    );
    setState(() => _enviando = true);
    try {
      await (widget.enviar ??
          (d) => Api.criarFuncionario(nome: d.nome, email: d.email, senha: d.senha, perfil: d.perfil))(dados);
      if (!mounted) return;
      mostrarMensagem(context, 'Funcionário criado. Ele já pode entrar com a senha temporária.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final erro = traduzirErro(e);
      setState(() {
        _erros = erro.campos;
        if (erro.codigo == 'EMAIL_JA_CADASTRADO') _erros = {'email': 'Já existe um usuário com este e-mail.'};
      });
      mostrarMensagem(context, erro.mensagem);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novo funcionário')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          CampoTexto(rotulo: 'Nome completo *', controller: _nome, erro: _erros['nome']),
          CampoTexto(
            rotulo: 'E-mail *',
            controller: _email,
            erro: _erros['email'],
            teclado: TextInputType.emailAddress,
          ),
          CampoTexto(
            rotulo: 'Senha temporária *',
            controller: _senha,
            erro: _erros['senha'],
            senha: true,
          ),
          DropdownButtonFormField<String>(
            initialValue: _perfil,
            decoration: InputDecoration(
              labelText: 'Perfil',
              errorText: _erros['perfil'],
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: perfisFuncionario
                .map((p) => DropdownMenuItem(value: p, child: Text(perfilRotulo(p))))
                .toList(),
            onChanged: (p) => setState(() => _perfil = p ?? _perfil),
          ),
          const SizedBox(height: 20),
          BotaoPrimario(texto: 'Criar funcionário', carregando: _enviando, onPressed: _salvar),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Relatórios

class _Relatorios extends StatefulWidget {
  const _Relatorios();

  @override
  State<_Relatorios> createState() => _RelatoriosState();
}

class _RelatoriosState extends State<_Relatorios> {
  DateTimeRange _periodo = _mesAtual();
  late Future<(RelatorioFinanceiro, RelatorioAtendimentos)> _dados;

  @override
  void initState() {
    super.initState();
    _dados = _buscar();
  }

  Future<(RelatorioFinanceiro, RelatorioAtendimentos)> _buscar() async {
    final inicio = dataIso(_periodo.start);
    final fim = dataIso(_periodo.end);
    final resultados = await Future.wait([
      Api.relatorioFinanceiro(inicio, fim),
      Api.relatorioAtendimentos(inicio, fim),
    ]);
    return (resultados[0] as RelatorioFinanceiro, resultados[1] as RelatorioAtendimentos);
  }

  void _carregar() => setState(() => _dados = _buscar());

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        _carregar();
        await _dados.then((_) {}, onError: (_) {});
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SeletorPeriodo(
            periodo: _periodo,
            aoMudar: (p) {
              _periodo = p;
              _carregar();
            },
          ),
          const SizedBox(height: 14),
          FutureBuilder<(RelatorioFinanceiro, RelatorioAtendimentos)>(
            future: _dados,
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
              final (fin, atend) = snap.data!;
              return PainelRelatorios(financeiro: fin, atendimentos: atend);
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Cobranças (RF30)

class _Cobrancas extends StatefulWidget {
  const _Cobrancas();

  @override
  State<_Cobrancas> createState() => _CobrancasState();
}

class _CobrancasState extends State<_Cobrancas> {
  DateTimeRange _periodo = _mesAtual();
  bool _soPendentes = false;
  late Future<List<Fatura>> _faturas;

  @override
  void initState() {
    super.initState();
    _faturas = _buscar();
  }

  Future<List<Fatura>> _buscar() => Api.listarFaturas(
    dataIso(_periodo.start),
    dataIso(_periodo.end),
    status: _soPendentes ? 'pendente' : null,
  );

  void _carregar() => setState(() => _faturas = _buscar());

  Future<void> _receber(Fatura f) async {
    String forma = 'pix';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Registrar pagamento'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${f.animalNome} • ${f.tutorNome}'),
              Text(moeda(f.valorCentavos), style: Estilos.secao),
              const SizedBox(height: 8),
              RadioGroup<String>(
                groupValue: forma,
                onChanged: (v) => setD(() => forma = v ?? forma),
                child: Column(
                  children: formasPagamento
                      .map(
                        (fp) => RadioListTile<String>(
                          value: fp,
                          title: Text(formaPagamentoRotulo(fp)),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await Api.registrarPagamento(f.id, forma);
      if (!mounted) return;
      mostrarMensagem(context, 'Pagamento registrado.');
      _carregar();
    } catch (e) {
      if (mounted) mostrarMensagem(context, traduzirErro(e).mensagem);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        _carregar();
        await _faturas.then((_) {}, onError: (_) {});
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SeletorPeriodo(
            periodo: _periodo,
            aoMudar: (p) {
              _periodo = p;
              _carregar();
            },
          ),
          SwitchListTile(
            title: const Text('Mostrar só as pendentes'),
            value: _soPendentes,
            onChanged: (v) {
              _soPendentes = v;
              _carregar();
            },
          ),
          FutureBuilder<List<Fatura>>(
            future: _faturas,
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
                return const EstadoVazio(icone: Icons.receipt_long, texto: 'Nenhuma cobrança no período.');
              }
              return Column(
                children: lista.map((f) {
                  return CartaoLista(
                    nomeAvatar: f.animalNome,
                    titulo: '${moeda(f.valorCentavos)} • ${f.animalNome}',
                    subtitulo: f.paga
                        ? '${dataBr(f.data)} • ${formaPagamentoRotulo(f.formaPagamento)} • ${f.veterinarioNome}'
                        : '${dataBr(f.data)} • ${f.tutorNome} • ${f.veterinarioNome}',
                    trailing: f.paga
                        ? const StatusChip(status: 'realizada', rotulo: 'Paga')
                        : FilledButton(onPressed: () => _receber(f), child: const Text('Receber')),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
