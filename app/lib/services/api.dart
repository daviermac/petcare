import '../core/firebase_setup.dart';
import '../models/item_agenda.dart';

class HorarioDisponivel {
  final String horario;
  final bool disponivel;

  const HorarioDisponivel(this.horario, this.disponivel);
}

/// Chamadas às Cloud Functions do PetConnect.
class Api {
  static Future<Map<String, dynamic>> _chamar(
    String nome,
    Map<String, dynamic> dados,
  ) async {
    final res = await functions.httpsCallable(nome).call(dados);
    final d = res.data;

    if (d is Map) {
      return Map<String, dynamic>.from(d);
    }

    return <String, dynamic>{};
  }

  /// RF01 - Registrar tutor.
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

  /// RF04 - Cadastrar animal.
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

  /// RF06/RF07 - Consultar horários disponíveis.
  static Future<List<HorarioDisponivel>> listarHorarios(String data) async {
    final r = await _chamar('listarHorarios', {'data': data});
    final lista = (r['horarios'] as List?) ?? const [];

    return lista.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return HorarioDisponivel(m['horario'] as String, m['disponivel'] == true);
    }).toList();
  }

  /// RF06 - Agendar consulta.
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

  /// RF11 - Cancelar consulta.
  static Future<void> cancelarConsulta(String consultaId) async {
    await _chamar('cancelarConsulta', {'consultaId': consultaId});
  }

  /// RF08/RF25 - Buscar agenda do dia.
  static Future<List<ItemAgenda>> agendaDoDia(
    String data, {
    bool incluirCanceladas = false,
  }) async {
    final r = await _chamar('agendaDoDia', {
      'data': data,
      'incluirCanceladas': incluirCanceladas,
    });

    final lista = (r['consultas'] as List?) ?? const [];

    return lista.map((e) {
      return ItemAgenda.fromMap(Map<String, dynamic>.from(e as Map));
    }).toList();
  }

  /// RF10 - Remarcar consulta (atendente).
  static Future<Map<String, dynamic>> remarcarConsulta({
    required String consultaId,
    required String data,
    required String horario,
  }) {
    return _chamar('remarcarConsulta', {
      'consultaId': consultaId,
      'data': data,
      'horario': horario,
    });
  }

  /// RF26 - Registrar procedimento (auxiliar e veterinário).
  static Future<Map<String, dynamic>> registrarProcedimento({
    required String animalId,
    required String descricao,
    String? observacoes,
  }) {
    return _chamar('registrarProcedimento', {
      'animalId': animalId,
      'descricao': descricao,
      if (observacoes != null && observacoes.trim().isNotEmpty)
        'observacoes': observacoes.trim(),
    });
  }
}
