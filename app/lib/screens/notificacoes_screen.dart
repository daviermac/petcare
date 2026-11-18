import 'package:flutter/material.dart';

import '../core/formatadores.dart';
import '../core/tema.dart';
import '../models/notificacao.dart';
import '../services/dados.dart';
import '../widgets/componentes.dart';

/// RF19 / RF20: lembretes de consulta e vacina (coleção "notificacoes").
class NotificacoesScreen extends StatefulWidget {
  const NotificacoesScreen({super.key});

  @override
  State<NotificacoesScreen> createState() => _NotificacoesScreenState();
}

class _NotificacoesScreenState extends State<NotificacoesScreen> {
  late final Stream<List<Notificacao>> _notificacoes = Dados.notificacoes();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Cores.fundo,
        title: const Text('Notificações'),
      ),
      body: SafeArea(
        child: StreamBuilder<List<Notificacao>>(
          stream: _notificacoes,
          builder: (context, snap) {
            if (snap.hasError) {
              return const Center(
                child: Text('Não foi possível carregar as notificações.'),
              );
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final lista = snap.data!;
            if (lista.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(18),
                children: const [
                  EstadoVazio(
                    icone: Icons.notifications_none,
                    texto: 'Você não tem notificações.',
                  ),
                ],
              );
            }
            return ListView(
              padding: const EdgeInsets.all(18),
              children: [
                for (final n in lista)
                  Card(
                    elevation: 0,
                    color: n.lida ? Colors.white : Cores.fundoSuave,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Cores.linha),
                    ),
                    child: ListTile(
                      title: Text(
                        n.titulo,
                        style: TextStyle(
                          fontWeight: n.lida ? FontWeight.w500 : FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        '${n.corpo}\n${dataBr(dataIso(n.criadoEm))} ${horaTexto(n.criadoEm)}',
                      ),
                      isThreeLine: true,
                      trailing: n.lida
                          ? null
                          : const Icon(Icons.circle, size: 10, color: Cores.primaria),
                      onTap: n.lida
                          ? null
                          : () => Dados.marcarNotificacaoLida(n.id),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
