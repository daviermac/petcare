import 'package:flutter/material.dart';

import '../core/tema.dart';
import '../models/animal.dart';
import '../services/dados.dart';
import '../widgets/componentes.dart';
import 'novo_animal_screen.dart';

/// HU02: lista dos animais do tutor.
class AnimaisTab extends StatefulWidget {
  const AnimaisTab({super.key});

  @override
  State<AnimaisTab> createState() => _AnimaisTabState();
}

class _AnimaisTabState extends State<AnimaisTab> {
  late final Stream<List<Animal>> _animais = Dados.animais();

  Future<void> _novoAnimal() async {
    final salvou = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const NovoAnimalScreen()),
    );
    if (salvou == true && mounted) {
      mostrarMensagem(context, 'Animal salvo e vinculado à sua conta.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Animal>>(
      stream: _animais,
      builder: (context, snap) {
        if (snap.hasError) {
          return const Center(child: Text('Não foi possível carregar seus animais.'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final animais = snap.data!;
        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text('Meus animais', style: Estilos.titulo),
            const SizedBox(height: 6),
            const Text('Animais vinculados à sua conta.', style: Estilos.suave),
            const SizedBox(height: 16),
            if (animais.isEmpty)
              const EstadoVazio(
                icone: Icons.pets,
                texto: 'Você ainda não cadastrou nenhum animal.',
              )
            else
              for (final a in animais)
                CartaoLista(
                  nomeAvatar: a.nome,
                  titulo: a.nome,
                  subtitulo: '${a.especieRotulo} · ${a.raca} · ${a.idadeRotulo}',
                ),
            const SizedBox(height: 8),
            BotaoPrimario(texto: 'Cadastrar animal', onPressed: _novoAnimal),
          ],
        );
      },
    );
  }
}
