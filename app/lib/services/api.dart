import '../core/firebase_setup.dart';

class HorarioDisponivel {
  final String horario;
  final bool disponivel;
  const HorarioDisponivel(this.horario, this.disponivel);
}

/// Chamadas às Cloud Functions do Davi (contrato em docs/api.md).
/// Erros chegam como FirebaseFunctionsException; use traduzirErro().
class Api {
  static Future<Map<String, dynamic>> _chamar(
    String nome,
    Map<String, dynamic> dados,
  ) async {
    final res = await functions.httpsCallable(nome).call(dados);
    final d = res.data;
    if (d is Map) return Map<String, dynamic>.from(d);
    return <String, dynamic>{};
  }

  /// RF01. O e-mail vem do Firebase Auth.
  static Future<void> registrarTutor({
    required String nome,
    required String cpf,
    required String telefone,
  }) async {
    await _chamar('registrarTutor', {
      'nome': nome,
      'cpf': cpf,
      'telefone': telefone,
    });
  }

  /// RF04. especie: 'cachorro' | 'gato' | 'outro'.
  static Future<void> cadastrarAnimal({
    required String nome,
    required String especie,
    required String raca,
    required int idade,
  }) async {
    await _chamar('cadastrarAnimal', {
      'nome': nome,
      'especie': especie,
      'raca': raca,
      'idade': idade,
    });
  }

  /// RF06/RF07. data no formato AAAA-MM-DD.
  static Future<List<HorarioDisponivel>> listarHorarios(String data) async {
    final r = await _chamar('listarHorarios', {'data': data});
    final lista = (r['horarios'] as List?) ?? const [];
    return lista.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return HorarioDisponivel(m['horario'] as String, m['disponivel'] == true);
    }).toList();
  }

  /// RF06. Retorna { id, animalNome, data, horario, local }.
  static Future<Map<String, dynamic>> agendarConsulta({
    required String animalId,
    required String data,
    required String horario,
  }) {
    return _chamar('agendarConsulta', {
      'animalId': animalId,
      'data': data,
      'horario': horario,
    });
  }

  /// RF11.
  static Future<void> cancelarConsulta(String consultaId) async {
    await _chamar('cancelarConsulta', {'consultaId': consultaId});
  }
}
