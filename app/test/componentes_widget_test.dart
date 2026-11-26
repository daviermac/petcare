// Testes de widget dos componentes visuais compartilhados.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcare/core/tema.dart';
import 'package:petcare/models/financeiro.dart';
import 'package:petcare/models/funcionario.dart';
import 'package:petcare/services/tarefas.dart';
import 'package:petcare/widgets/checklist_tarefas.dart';
import 'package:petcare/widgets/componentes.dart';
import 'package:petcare/widgets/gestao.dart';

Widget _app(Widget filho) => MaterialApp(
  theme: criarTema(),
  home: Scaffold(body: SingleChildScrollView(child: filho)),
);

void main() {
  testWidgets('CampoTexto mostra a mensagem de erro', (tester) async {
    final c = TextEditingController();
    await tester.pumpWidget(_app(CampoTexto(rotulo: 'CPF', controller: c, erro: 'CPF inválido.')));
    expect(find.text('CPF'), findsOneWidget);
    expect(find.text('CPF inválido.'), findsOneWidget);
  });

  testWidgets('BotaoPrimario chama a ação e fica desabilitado carregando', (tester) async {
    var cliques = 0;
    await tester.pumpWidget(_app(BotaoPrimario(texto: 'Salvar', onPressed: () => cliques++)));
    await tester.tap(find.text('Salvar'));
    expect(cliques, 1);

    await tester.pumpWidget(
      _app(BotaoPrimario(texto: 'Salvar', carregando: true, onPressed: () => cliques++)),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    expect(cliques, 1);
  });

  testWidgets('EstadoVazio com botão e CartaoLista com toque', (tester) async {
    var acoes = 0;
    await tester.pumpWidget(
      _app(
        Column(
          children: [
            EstadoVazio(icone: Icons.pets, texto: 'Nada aqui', textoBotao: 'Criar', aoPressionar: () => acoes++),
            CartaoLista(nomeAvatar: 'Thor', titulo: 'Thor', subtitulo: 'Cachorro', onTap: () => acoes++),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Criar'));
    await tester.tap(find.text('Cachorro'));
    expect(acoes, 2);
    expect(find.text('T'), findsOneWidget); // inicial do avatar
  });

  testWidgets('Checklist do auxiliar mostra progresso e avisa ao marcar (RF24)', (tester) async {
    final marcadas = <String, bool>{};
    await tester.pumpWidget(
      _app(
        ChecklistTarefas(
          tarefas: tarefasPadrao,
          concluidas: {tarefasPadrao.first.id},
          aoAlternar: (t, v) => marcadas[t.id] = v,
        ),
      ),
    );
    expect(find.text('1/4'), findsOneWidget);
    await tester.tap(find.text(tarefasPadrao[1].texto));
    expect(marcadas, {tarefasPadrao[1].id: true});
    expect(find.text('Todas as tarefas foram concluídas!'), findsNothing);

    await tester.pumpWidget(
      _app(
        ChecklistTarefas(
          tarefas: tarefasPadrao,
          concluidas: tarefasPadrao.map((t) => t.id).toSet(),
          aoAlternar: null,
        ),
      ),
    );
    expect(find.text('4/4'), findsOneWidget);
    expect(find.text('Todas as tarefas foram concluídas!'), findsOneWidget);
  });

  testWidgets('Painel de relatórios mostra os totais em reais (RF31, RF33)', (tester) async {
    await tester.pumpWidget(
      _app(
        const PainelRelatorios(
          financeiro: RelatorioFinanceiro(
            quantidade: 2,
            faturadoCentavos: 33000,
            recebidoCentavos: 18000,
            pendenteCentavos: 15000,
            ticketMedioCentavos: 16500,
            porFormaPagamento: [LinhaRelatorio('Pix', 1, 18000)],
            porVeterinario: [LinhaRelatorio('Paula Reis', 1, 18000), LinhaRelatorio('Caio Lima', 1, 15000)],
            porDia: [],
          ),
          atendimentos: RelatorioAtendimentos(total: 5, porVeterinario: [LinhaRelatorio('Paula Reis', 3, 0)]),
        ),
      ),
    );
    expect(find.text('R\$ 330,00'), findsOneWidget);
    expect(find.text('R\$ 150,00'), findsOneWidget); // a receber
    expect(find.text('R\$ 165,00'), findsOneWidget); // ticket médio
    expect(find.text('Caio Lima'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('Sem dados no período.'), findsOneWidget);
  });

  testWidgets('Lista de funcionários: chave liga/desliga e o gestor não se desativa (RF32)', (tester) async {
    final mudancas = <String, bool>{};
    await tester.pumpWidget(
      _app(
        ListaFuncionarios(
          uidAtual: 'g1',
          funcionarios: const [
            Funcionario(uid: 'g1', nome: 'Marina Costa', email: 'g@x.dev', perfil: 'gestor', ativo: true),
            Funcionario(uid: 'a1', nome: 'Carla Mendes', email: 'c@x.dev', perfil: 'atendente', ativo: true),
          ],
          aoAlternar: (f, v) => mudancas[f.uid] = v,
        ),
      ),
    );
    final chaves = find.byType(Switch);
    expect(chaves, findsNWidgets(2));
    expect(tester.widget<Switch>(chaves.at(0)).onChanged, isNull);
    await tester.tap(chaves.at(1));
    expect(mudancas, {'a1': false});
  });
}
