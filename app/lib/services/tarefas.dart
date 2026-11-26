import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Tarefa fixa do checklist diário do auxiliar.
class Tarefa {
  final String id;
  final String texto;
  const Tarefa(this.id, this.texto);
}

/// Checklist padrão do auxiliar (RF24).
const tarefasPadrao = [
  Tarefa('preparar_ambiente', 'Preparar o ambiente de atendimento'),
  Tarefa('conferir_materiais', 'Conferir os materiais necessários'),
  Tarefa('organizar_materiais', 'Organizar os materiais após os atendimentos'),
  Tarefa('verificar_limpeza', 'Verificar se o ambiente está limpo e organizado'),
];

/// Persistência do checklist no Firestore: `tarefasDia/{AAAA-MM-DD}` (RF24).
/// As regras em firestore.rules só deixam o auxiliar gravar.
class TarefasService {
  static DocumentReference<Map<String, dynamic>> _doc(String data) =>
      FirebaseFirestore.instance.collection('tarefasDia').doc(data);

  /// Ids das tarefas concluídas no dia, em tempo real.
  static Stream<Set<String>> concluidas(String data) {
    return _doc(data).snapshots().map((s) {
      final lista = (s.data()?['concluidas'] as List?) ?? const [];
      return lista.map((e) => e.toString()).toSet();
    });
  }

  /// Salva o novo conjunto de tarefas concluídas do dia.
  static Future<void> salvar(String data, Set<String> concluidas) {
    return _doc(data).set({
      'concluidas': concluidas.toList()..sort(),
      'atualizadoEm': FieldValue.serverTimestamp(),
      'atualizadoPor': FirebaseAuth.instance.currentUser!.uid,
    });
  }
}
