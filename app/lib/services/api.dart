import '../core/firebase_setup.dart';
import '../models/financeiro.dart';
import '../models/item_agenda.dart';
import '../models/registro_medico.dart';

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

  // ------------------------------------------------------------ Prontuário

  /// RF13 - Histórico médico do animal (veterinário ou tutor dono).
  static Future<HistoricoAnimal> historicoDoAnimal(String animalId) async {
    final r = await _chamar('historicoDoAnimal', {'animalId': animalId});
    return HistoricoAnimal.fromMap(r);
  }

  /// RF14/RF30 - Registrar atendimento. Com [consultaId], a consulta fica "realizada".
  /// Gera a cobrança do atendimento ([valor] em reais; vazio = valor padrão).
  static Future<Map<String, dynamic>> registrarAtendimento({
    required String animalId,
    String? consultaId,
    String motivo = '',
    required String diagnostico,
    required String tratamento,
    String observacoes = '',
    double? valor,
  }) {
    return _chamar('registrarAtendimento', {
      'animalId': animalId,
      if (consultaId != null && consultaId.isNotEmpty) 'consultaId': consultaId,
      'motivo': motivo,
      'diagnostico': diagnostico,
      'tratamento': tratamento,
      'observacoes': observacoes,
      'valor': ?valor,
    });
  }

  /// RF16 - Registrar vacina (com próxima dose para o lembrete, RF20).
  static Future<Map<String, dynamic>> registrarVacina({
    required String animalId,
    required String nome,
    String? dataAplicacao,
    String? proximaDose,
    String lote = '',
  }) {
    return _chamar('registrarVacina', {
      'animalId': animalId,
      'nome': nome,
      'dataAplicacao': ?dataAplicacao,
      'proximaDose': ?proximaDose,
      'lote': lote,
    });
  }

  // ------------------------------------------------------------ Gestão

  /// RF32 - Criar login de funcionário.
  static Future<void> criarFuncionario({
    required String nome,
    required String email,
    required String senha,
    required String perfil,
  }) async {
    await _chamar('criarFuncionario', {
      'nome': nome,
      'email': email,
      'senha': senha,
      'perfil': perfil,
    });
  }

  /// RF32 - Ativar ou desativar funcionário.
  static Future<void> definirStatusFuncionario(String uid, bool ativo) async {
    await _chamar('definirStatusFuncionario', {'uid': uid, 'ativo': ativo});
  }

  /// RF33/RF35 - Atendimentos no período, por veterinário.
  static Future<RelatorioAtendimentos> relatorioAtendimentos(
    String inicio,
    String fim,
  ) async {
    final r = await _chamar('relatorioAtendimentos', {
      'inicio': inicio,
      'fim': fim,
    });
    return RelatorioAtendimentos.fromMap(r);
  }

  // ------------------------------------------------------------ Financeiro

  /// RF31 - Relatório financeiro do período.
  static Future<RelatorioFinanceiro> relatorioFinanceiro(
    String inicio,
    String fim,
  ) async {
    final r = await _chamar('relatorioFinanceiro', {
      'inicio': inicio,
      'fim': fim,
    });
    return RelatorioFinanceiro.fromMap(r);
  }

  /// RF30 - Cobranças do período (status opcional: pendente | paga).
  static Future<List<Fatura>> listarFaturas(
    String inicio,
    String fim, {
    String? status,
  }) async {
    final r = await _chamar('listarFaturas', {
      'inicio': inicio,
      'fim': fim,
      'status': ?status,
    });
    final lista = (r['faturas'] as List?) ?? const [];
    return lista
        .map((e) => Fatura.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// RF30 - Registrar pagamento de uma cobrança.
  static Future<void> registrarPagamento(
    String faturaId,
    String formaPagamento,
  ) async {
    await _chamar('registrarPagamento', {
      'faturaId': faturaId,
      'formaPagamento': formaPagamento,
    });
  }
}
