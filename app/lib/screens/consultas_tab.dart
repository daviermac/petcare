import 'package:flutter/material.dart';

import '../core/formatadores.dart';
import '../core/tema.dart';
import '../models/consulta.dart';
import '../services/dados.dart';
import '../widgets/componentes.dart';
import 'detalhe_consulta_screen.dart';

/// HU04: lista dos agendamentos do tutor.
class ConsultasTab extends StatefulWidget {
  final VoidCallback irParaAgendar;
  const ConsultasTab({super.key, required this.irParaAgendar});

  @override
  State<ConsultasTab> createState() => _ConsultasTabState();
}

class _ConsultasTabState extends State<ConsultasTab> {
  late final Stream<List<Consulta>> _consultas = Dados.consultas();

  Future<void> _abrir(Consulta c) async {
    final cancelou = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => DetalheConsultaScreen(consulta: c)),
    );
    if (cancelou == true && mounted) {
      mostrarMensagem(
        context,
        'Consulta cancelada. O horário voltou a ficar disponível.',
      );
    }
  }

  Widget _cartao(Consulta c) {
    return CartaoLista(
      nomeAvatar: c.animalNome,
      titulo: c.animalNome,
      subtitulo: '${diaCurtoIso(c.data)} às ${c.horario}',
      trailing: c.status == 'agendada'
          ? const Icon(Icons.chevron_right)
          : StatusChip(status: c.status, rotulo: c.statusRotulo),
      onTap: () => _abrir(c),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Consulta>>(
      stream: _consultas,
      builder: (context, snap) {
        if (snap.hasError) {
          return const Center(child: Text('Não foi possível carregar suas consultas.'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final todas = snap.data!;
        final proximas = todas.where((c) => c.status == 'agendada').toList();
        final historico =
            todas.where((c) => c.status != 'agendada').toList().reversed.toList();

        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text('Minhas consultas', style: Estilos.titulo),
            const SizedBox(height: 6),
            const Text('Toque para ver os detalhes.', style: Estilos.suave),
            const SizedBox(height: 16),
            if (proximas.isEmpty)
              EstadoVazio(
                icone: Icons.event_busy_outlined,
                texto: 'Você não tem consultas agendadas.',
                textoBotao: 'Agendar consulta',
                aoPressionar: widget.irParaAgendar,
              )
            else
              for (final c in proximas) _cartao(c),
            if (historico.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Text('Histórico', style: Estilos.secao),
              const SizedBox(height: 10),
              for (final c in historico) _cartao(c),
            ],
          ],
        );
      },
    );
  }
}
