import 'package:flutter/material.dart';

import '../core/formatadores.dart';
import '../core/tema.dart';
import '../widgets/componentes.dart';

/// HU03: confirmação do agendamento. Fecha com true para ir às consultas.
class ConfirmacaoScreen extends StatelessWidget {
  final Map<String, dynamic> dados;
  const ConfirmacaoScreen({super.key, required this.dados});

  @override
  Widget build(BuildContext context) {
    final animal = (dados['animalNome'] ?? '') as String;
    final data = (dados['data'] ?? '') as String;
    final horario = (dados['horario'] ?? '') as String;
    final local = (dados['local'] ?? 'Hospital PetConnect') as String;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            const SizedBox(height: 32),
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Cores.sucesso,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 44),
              ),
            ),
            const SizedBox(height: 18),
            const Center(child: Text('Consulta agendada', style: Estilos.titulo)),
            const SizedBox(height: 6),
            const Center(
              child: Text(
                'Ela já está salva em "Consultas".',
                style: Estilos.suave,
              ),
            ),
            const SizedBox(height: 20),
            LinhaDetalhe(rotulo: 'Animal', valor: animal),
            LinhaDetalhe(rotulo: 'Data', valor: dataBr(data)),
            LinhaDetalhe(rotulo: 'Horário', valor: horario),
            LinhaDetalhe(rotulo: 'Local', valor: local),
            const SizedBox(height: 24),
            BotaoPrimario(
              texto: 'Ver minhas consultas',
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 10),
            BotaoSecundario(
              texto: 'Agendar outra consulta',
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}
