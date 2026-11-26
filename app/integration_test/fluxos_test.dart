// Testes de integração (RT11): rodam o app de verdade contra os emuladores do Firebase.
//
// Pré-requisitos (na pasta api/):
//   Terminal 1: npm run emuladores
//   Terminal 2: npm run seed        (recria as contas e os dados de exemplo)
// Depois, com um emulador Android, simulador iOS ou celular conectado (pasta app/):
//   flutter test integration_test
//   (celular físico: flutter test integration_test --dart-define=EMULADOR_HOST=192.168.x.x)
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:petcare/main.dart' as app;

const _senha = 'Pet@1234';

/// Espera um texto aparecer (as chamadas aos emuladores levam alguns segundos).
Future<void> _esperar(WidgetTester tester, Finder alvo, {int segundos = 20}) async {
  for (var i = 0; i < segundos * 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
    if (alvo.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Não apareceu na tela: $alvo');
}

Future<void> _tocar(WidgetTester tester, Finder alvo) async {
  await tester.ensureVisible(alvo.first);
  await tester.tap(alvo.first);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _entrar(WidgetTester tester, String email) async {
  await _esperar(tester, find.text('Entrar'));
  await tester.enterText(find.widgetWithText(TextField, 'E-mail'), email);
  await tester.enterText(find.widgetWithText(TextField, 'Senha'), _senha);
  await _tocar(tester, find.text('Entrar'));
}

Future<void> _sair(WidgetTester tester) async {
  await FirebaseAuth.instance.signOut();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('fluxos da equipe contra os emuladores', (tester) async {
    await app.main();
    await tester.pump();
    await _sair(tester); // começa sempre deslogado

    // ---------------- Veterinário: prontuário e vacina (RF13, RF16)
    await _entrar(tester, 'vet@petconnect.dev');
    await _esperar(tester, find.text('Área do Veterinário'));
    await _tocar(tester, find.text('Pacientes'));
    await _esperar(tester, find.text('Thor'));
    await _tocar(tester, find.text('Thor'));
    await _esperar(tester, find.text('Prontuário — Thor'));
    await _esperar(tester, find.textContaining('Histórico ('));
    expect(find.text('Otite externa bilateral'), findsWidgets); // atendimento do seed

    final nomeVacina = 'Giárdia ${DateTime.now().millisecondsSinceEpoch % 100000}';
    await _tocar(tester, find.text('Vacina'));
    await _esperar(tester, find.text('Registrar vacina'));
    await tester.enterText(find.widgetWithText(TextField, 'Vacina *'), nomeVacina);
    await _tocar(tester, find.text('Salvar vacina'));
    await _esperar(tester, find.text(nomeVacina));

    // ---------------- Veterinário: atendimento gera cobrança (RF14, RF30)
    await _tocar(tester, find.text('Atendimento'));
    await _esperar(tester, find.text('Registrar atendimento'));
    await tester.enterText(find.widgetWithText(TextField, 'Diagnóstico *'), 'Teste de integração');
    await tester.enterText(find.widgetWithText(TextField, 'Tratamento *'), 'Nenhum');
    await tester.enterText(find.widgetWithText(TextField, 'Valor da consulta (R\$)'), '99,90');
    await _tocar(tester, find.text('Salvar atendimento'));
    await _esperar(tester, find.text('Teste de integração'));
    await _sair(tester);

    // ---------------- Gestor: relatórios e cobranças (RF31, RF30)
    await _entrar(tester, 'gestor@petconnect.dev');
    await _esperar(tester, find.text('Área do Gestor'));
    await _esperar(tester, find.text('Paula Reis')); // equipe (RF32)
    await _tocar(tester, find.text('Relatórios'));
    await _esperar(tester, find.text('Faturado'));
    await _tocar(tester, find.text('Cobranças'));
    await _esperar(tester, find.text('R\$ 99,90 • Thor'));
    await _sair(tester);

    // ---------------- Auxiliar: checklist salvo no Firestore (RF24)
    await _entrar(tester, 'auxiliar@petconnect.dev');
    await _esperar(tester, find.text('Área do Auxiliar'));
    await _esperar(tester, find.textContaining('/4'));
    final tarefa = find.text('Conferir os materiais necessários');
    final antes = tester.widget<CheckboxListTile>(
      find.ancestor(of: tarefa, matching: find.byType(CheckboxListTile)),
    ).value;
    await _tocar(tester, tarefa);
    await tester.pump(const Duration(seconds: 2));
    final depois = tester.widget<CheckboxListTile>(
      find.ancestor(of: tarefa, matching: find.byType(CheckboxListTile)),
    ).value;
    expect(depois, isNot(antes));
    await _sair(tester);
  });
}
