import 'package:flutter/material.dart';

import '../core/formatadores.dart';
import '../core/tema.dart';
import '../models/consulta.dart';
import '../services/dados.dart';
import '../widgets/componentes.dart';
import 'detalhe_consulta_screen.dart';

class InicioTab extends StatefulWidget {
  final void Function(int) irParaAba;
  const InicioTab({super.key, required this.irParaAba});

  @override
  State<InicioTab> createState() => _InicioTabState();
}

class _InicioTabState extends State<InicioTab> {
  late final Stream<String?> _nome = Dados.nomeTutor();
  late final Stream<List<Consulta>> _consultas = Dados.consultas();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        StreamBuilder<String?>(
          stream: _nome,
          builder: (context, snap) {
            final primeiro = (snap.data ?? '').trim().split(' ').first;
            return Text(
              primeiro.isEmpty ? 'Olá!' : 'Olá, $primeiro',
              style: Estilos.titulo,
            );
          },
        ),
        const SizedBox(height: 6),
        const Text('O que você precisa hoje?', style: Estilos.suave),
        const SizedBox(height: 20),
        const Text('Próxima consulta', style: Estilos.secao),
        const SizedBox(height: 10),
        StreamBuilder<List<Consulta>>(
          stream: _consultas,
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final agora = agoraComoChave();
            Consulta? proxima;
            for (final c in snap.data!) {
              if (c.status == 'agendada' && c.chave.compareTo(agora) >= 0) {
                proxima = c;
                break;
              }
            }
            if (proxima == null) {
              return const EstadoVazio(
                icone: Icons.event_available_outlined,
                texto: 'Nenhuma consulta marcada.',
              );
            }
            final consulta = proxima;
            return CartaoLista(
              nomeAvatar: consulta.animalNome,
              titulo: consulta.animalNome,
              subtitulo: '${diaCurtoIso(consulta.data)} às ${consulta.horario}',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<bool>(
                  builder: (_) => DetalheConsultaScreen(consulta: consulta),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        BotaoPrimario(
          texto: 'Agendar consulta',
          onPressed: () => widget.irParaAba(2),
        ),
        const SizedBox(height: 10),
        BotaoSecundario(
          texto: 'Meus animais',
          onPressed: () => widget.irParaAba(1),
        ),
      ],
    );
  }
}
