import 'package:flutter/material.dart';

import '../services/tarefas.dart';

/// Cartão "Tarefas do dia" do auxiliar (RF24). Só desenha; quem salva é a tela.
class ChecklistTarefas extends StatelessWidget {
  final List<Tarefa> tarefas;
  final Set<String> concluidas;
  final void Function(Tarefa tarefa, bool concluida)? aoAlternar;
  final bool salvando;

  const ChecklistTarefas({
    super.key,
    required this.tarefas,
    required this.concluidas,
    required this.aoAlternar,
    this.salvando = false,
  });

  @override
  Widget build(BuildContext context) {
    final feitas = tarefas.where((t) => concluidas.contains(t.id)).length;
    final total = tarefas.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.checklist, size: 26),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Tarefas do dia',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                if (salvando)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                Text(
                  '$feitas/$total',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: total == 0 ? 0 : feitas / total),
            const SizedBox(height: 12),
            ...tarefas.map((t) {
              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(t.texto),
                value: concluidas.contains(t.id),
                onChanged: aoAlternar == null ? null : (v) => aoAlternar!(t, v == true),
              );
            }),
            if (total > 0 && feitas == total)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Todas as tarefas foram concluídas!',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
