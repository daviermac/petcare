import '../core/firebase_setup.dart';
import 'notificacoes_medicacao.dart';

class PrescricaoMedicacaoService {
  /// Registra a prescrição e agenda os lembretes devolvidos pela API.
  static Future<Map<String, dynamic>> registrar({
    required String animalId,
    required String animalNome,
    required String medicamento,
    required String dosagem,
    required int frequenciaHoras,
    required int duracaoDias,
    String orientacoes = '',
  }) async {
    final resposta = await functions.httpsCallable('registrarPrescricao').call({
      'animalId': animalId,
      'medicamento': medicamento,
      'dosagem': dosagem,
      'frequenciaHoras': frequenciaHoras,
      'duracaoDias': duracaoDias,
      'orientacoes': orientacoes,
    });

    final registro = Map<String, dynamic>.from(resposta.data as Map);

    final id = registro['id']?.toString() ?? '';
    if (id.isEmpty) {
      throw Exception('A API não retornou o ID da prescrição.');
    }

    final horarios =
        (registro['horariosMedicacao'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    if (horarios.isNotEmpty) {
      await NotificacoesMedicacao.agendarLembretes(
        idBase: _gerarIdNumerico(id),
        animal: animalNome,
        medicamento: medicamento,
        horarios: horarios,
      );
    }

    return registro;
  }

  /// Gera um identificador numérico estável a partir do ID da prescrição.
  static int _gerarIdNumerico(String id) {
    var hash = 0x811c9dc5;

    for (final unidade in id.codeUnits) {
      hash = ((hash ^ unidade) * 0x01000193) & 0x7fffffff;
    }

    return hash % 2000000000;
  }
}
