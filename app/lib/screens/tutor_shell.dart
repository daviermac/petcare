import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/dados.dart';
import '../widgets/componentes.dart';
import 'agendar_tab.dart';
import 'animais_tab.dart';
import 'consultas_tab.dart';
import 'inicio_tab.dart';
import 'notificacoes_screen.dart';

/// Estrutura do app do tutor: 4 abas (Início, Animais, Agendar, Consultas).
class TutorShell extends StatefulWidget {
  const TutorShell({super.key});

  @override
  State<TutorShell> createState() => _TutorShellState();
}

class _TutorShellState extends State<TutorShell> {
  int _aba = 0;

  void _ir(int indice) => setState(() => _aba = indice);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const LogoPetConnect(tamanho: 28),
        actions: [
          const _SinoNotificacoes(),
          PopupMenuButton<String>(
            onSelected: (valor) {
              if (valor == 'sair') FirebaseAuth.instance.signOut();
            },
            itemBuilder: (_) => const [
              PopupMenuItem<String>(value: 'sair', child: Text('Sair')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _aba,
          children: [
            InicioTab(irParaAba: _ir),
            const AnimaisTab(),
            AgendarTab(
              aoConcluir: () => _ir(3),
              irParaAnimais: () => _ir(1),
            ),
            ConsultasTab(irParaAgendar: () => _ir(2)),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _aba,
        onDestinationSelected: _ir,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.pets_outlined),
            selectedIcon: Icon(Icons.pets),
            label: 'Animais',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'Agendar',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Consultas',
          ),
        ],
      ),
    );
  }
}

/// Sino com o número de notificações não lidas (RF19, RF20).
class _SinoNotificacoes extends StatefulWidget {
  const _SinoNotificacoes();

  @override
  State<_SinoNotificacoes> createState() => _SinoNotificacoesState();
}

class _SinoNotificacoesState extends State<_SinoNotificacoes> {
  late final Stream<int> _naoLidas =
      Dados.notificacoes().map((l) => l.where((n) => !n.lida).length);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _naoLidas,
      builder: (context, snap) {
        final n = snap.data ?? 0;
        return IconButton(
          tooltip: 'Notificações',
          icon: Badge(
            label: Text('$n'),
            isLabelVisible: n > 0,
            child: const Icon(Icons.notifications_outlined),
          ),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const NotificacoesScreen()),
          ),
        );
      },
    );
  }
}
