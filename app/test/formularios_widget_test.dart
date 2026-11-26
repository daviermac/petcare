// Testes de widget dos formulários do veterinário e do gestor.
// As telas recebem a função "enviar" por parâmetro, então rodam sem Firebase.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcare/core/tema.dart';
import 'package:petcare/screens/formularios_veterinario.dart';
import 'package:petcare/screens/gestor_screen.dart';

/// Abre [tela] por cima de uma tela inicial e guarda o resultado do pop.
Future<List<Object?>> _abrir(WidgetTester tester, Widget tela) async {
  final resultados = <Object?>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: criarTema(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                resultados.add(
                  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => tela)),
                );
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return resultados;
}

Finder _campo(String rotulo) => find.widgetWithText(TextField, rotulo);

Future<void> _tocar(WidgetTester tester, String texto) async {
  await tester.ensureVisible(find.text(texto));
  await tester.tap(find.text(texto));
  await tester.pumpAndSettle();
}

void main() {
  group('Atendimento (RF14, RF30)', () {
    testWidgets('não envia sem diagnóstico e tratamento', (tester) async {
      var enviados = 0;
      await _abrir(
        tester,
        AtendimentoFormScreen(animalId: 'a1', animalNome: 'Thor', enviar: (_) async => enviados++),
      );
      await _tocar(tester, 'Salvar atendimento');
      expect(find.text('Informe o diagnóstico.'), findsOneWidget);
      expect(find.text('Informe o tratamento.'), findsOneWidget);
      expect(enviados, 0);
    });

    testWidgets('valida o valor e envia com consulta e valor em reais', (tester) async {
      DadosAtendimentoForm? enviado;
      final resultado = await _abrir(
        tester,
        AtendimentoFormScreen(
          animalId: 'a1',
          animalNome: 'Thor',
          consultaId: 'c1',
          enviar: (d) async => enviado = d,
        ),
      );
      await tester.enterText(_campo('Diagnóstico *'), 'Otite');
      await tester.enterText(_campo('Tratamento *'), 'Gotas por 7 dias');
      await tester.enterText(_campo('Valor da consulta (R\$)'), 'abc');
      await _tocar(tester, 'Salvar atendimento');
      expect(find.text('Valor inválido. Ex.: 150,00'), findsOneWidget);
      expect(enviado, isNull);

      await tester.enterText(_campo('Valor da consulta (R\$)'), '180,50');
      await _tocar(tester, 'Salvar atendimento');
      expect(enviado!.consultaId, 'c1');
      expect(enviado!.diagnostico, 'Otite');
      expect(enviado!.valor, 180.5);
      expect(resultado, [true]);
    });
  });

  group('Prescrição (RF15, RF21)', () {
    testWidgets('valida frequência e duração', (tester) async {
      await _abrir(
        tester,
        PrescricaoFormScreen(animalId: 'a1', animalNome: 'Thor', enviar: (_) async => {}),
      );
      await tester.enterText(_campo('Medicamento *'), 'Amoxicilina');
      await tester.enterText(_campo('Dosagem *'), '1 comprimido');
      await tester.enterText(_campo('A cada (horas) *'), '0');
      await tester.enterText(_campo('Por (dias) *'), '400');
      await _tocar(tester, 'Salvar prescrição');
      expect(find.text('De 1 a 168 horas.'), findsOneWidget);
      expect(find.text('De 1 a 365 dias.'), findsOneWidget);
    });

    testWidgets('envia e mostra quantos lembretes ficaram agendados', (tester) async {
      DadosPrescricaoForm? enviado;
      final proximo = DateTime.now().add(const Duration(hours: 8));
      final resultado = await _abrir(
        tester,
        PrescricaoFormScreen(
          animalId: 'a1',
          animalNome: 'Thor',
          enviar: (d) async {
            enviado = d;
            return {
              'id': 'r1',
              'horariosMedicacao': [DateTime.now().toIso8601String(), proximo.toIso8601String()],
              'lembretesAgendados': 1,
            };
          },
        ),
      );
      await tester.enterText(_campo('Medicamento *'), 'Amoxicilina');
      await tester.enterText(_campo('Dosagem *'), '1 comprimido');
      // O botão fica girando enquanto o diálogo está aberto: pump em vez de pumpAndSettle.
      await tester.tap(find.text('Salvar prescrição'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(enviado!.frequenciaHoras, 8);
      expect(enviado!.duracaoDias, 7);
      expect(enviado!.animalNome, 'Thor');
      expect(find.text('Prescrição registrada'), findsOneWidget);
      expect(find.textContaining('1 lembrete(s)'), findsOneWidget);
      expect(find.textContaining('Próximo:'), findsOneWidget);
      await _tocar(tester, 'OK');
      expect(resultado, [true]);
    });
  });

  group('Vacina (RF16)', () {
    testWidgets('próxima dose precisa ser depois da aplicação', (tester) async {
      DadosVacinaForm? enviado;
      final resultado = await _abrir(
        tester,
        VacinaFormScreen(animalId: 'a1', animalNome: 'Thor', enviar: (d) async => enviado = d),
      );
      await tester.enterText(_campo('Vacina *'), 'V10');
      await tester.enterText(_campo('Data da aplicação *'), '10/11/2026');
      await tester.enterText(_campo('Próxima dose'), '01/11/2026');
      await _tocar(tester, 'Salvar vacina');
      expect(find.text('Deve ser depois da aplicação.'), findsOneWidget);
      expect(enviado, isNull);

      await tester.enterText(_campo('Próxima dose'), '10/11/2027');
      await _tocar(tester, 'Salvar vacina');
      expect(enviado!.dataAplicacao, '2026-11-10');
      expect(enviado!.proximaDose, '2027-11-10');
      expect(resultado, [true]);
    });
  });

  group('Novo funcionário (RF32)', () {
    testWidgets('valida os campos e envia com o perfil escolhido', (tester) async {
      DadosFuncionarioForm? enviado;
      await _abrir(tester, NovoFuncionarioScreen(enviar: (d) async => enviado = d));
      await _tocar(tester, 'Criar funcionário');
      expect(find.text('Informe nome e sobrenome.'), findsOneWidget);
      expect(find.text('E-mail inválido.'), findsOneWidget);
      expect(find.text('Mínimo de 8 caracteres.'), findsOneWidget);

      await tester.enterText(_campo('Nome completo *'), 'João Pereira');
      await tester.enterText(_campo('E-mail *'), 'Joao@PetConnect.dev');
      await tester.enterText(_campo('Senha temporária *'), 'Temp@2026');
      await tester.tap(find.text('Atendente'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Veterinário(a)').last);
      await tester.pumpAndSettle();
      await _tocar(tester, 'Criar funcionário');

      expect(enviado!.email, 'joao@petconnect.dev');
      expect(enviado!.perfil, 'veterinario');
    });
  });
}
