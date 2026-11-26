/// Item do prontuário (atendimento, prescrição, vacina ou procedimento) — RF13.
class RegistroMedico {
  final String id;
  final String tipo; // atendimento | prescricao | vacina | procedimento
  final String autorNome;
  final String autorPerfil;
  final Map<String, dynamic> dados;
  final DateTime? criadoEm;
  final int versao;

  const RegistroMedico({
    required this.id,
    required this.tipo,
    required this.autorNome,
    required this.autorPerfil,
    required this.dados,
    required this.criadoEm,
    required this.versao,
  });

  factory RegistroMedico.fromMap(Map<String, dynamic> m) {
    return RegistroMedico(
      id: m['id']?.toString() ?? '',
      tipo: m['tipo']?.toString() ?? '',
      autorNome: m['autorNome']?.toString() ?? '—',
      autorPerfil: m['autorPerfil']?.toString() ?? '',
      dados: m['dados'] is Map
          ? Map<String, dynamic>.from(m['dados'] as Map)
          : <String, dynamic>{},
      criadoEm: DateTime.tryParse(m['criadoEm']?.toString() ?? ''),
      versao: (m['versao'] as num?)?.toInt() ?? 1,
    );
  }

  String _t(String campo) => dados[campo]?.toString().trim() ?? '';

  String get tipoRotulo => switch (tipo) {
    'atendimento' => 'Atendimento',
    'prescricao' => 'Prescrição',
    'vacina' => 'Vacina',
    'procedimento' => 'Procedimento',
    _ => tipo,
  };

  /// Linha principal mostrada no histórico.
  String get titulo => switch (tipo) {
    'atendimento' => _t('diagnostico'),
    'prescricao' => '${_t('medicamento')} — ${_t('dosagem')}',
    'vacina' => _t('nome'),
    'procedimento' => _t('descricao'),
    _ => '',
  };

  /// Detalhes (uma linha por informação preenchida).
  List<String> get detalhes {
    final linhas = <String>[];
    void add(String rotulo, String valor) {
      if (valor.isNotEmpty) linhas.add('$rotulo: $valor');
    }

    switch (tipo) {
      case 'atendimento':
        add('Motivo', _t('motivo'));
        add('Tratamento', _t('tratamento'));
        add('Observações', _t('observacoes'));
      case 'prescricao':
        final freq = dados['frequenciaHoras'];
        final dias = dados['duracaoDias'];
        if (freq != null && dias != null) {
          linhas.add('De $freq em $freq horas por $dias dia(s)');
        }
        add('Orientações', _t('orientacoes'));
      case 'vacina':
        add('Aplicação', _dataBr(_t('dataAplicacao')));
        add('Próxima dose', _dataBr(_t('proximaDose')));
        add('Lote', _t('lote'));
      case 'procedimento':
        add('Observações', _t('observacoes'));
    }
    return linhas;
  }

  static String _dataBr(String iso) {
    final p = iso.split('-');
    return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : iso;
  }
}

/// Resposta de historicoDoAnimal.
class HistoricoAnimal {
  final String animalId;
  final String nome;
  final String especie;
  final String raca;
  final int idade;
  final List<RegistroMedico> registros;

  const HistoricoAnimal({
    required this.animalId,
    required this.nome,
    required this.especie,
    required this.raca,
    required this.idade,
    required this.registros,
  });

  factory HistoricoAnimal.fromMap(Map<String, dynamic> m) {
    final a = m['animal'] is Map
        ? Map<String, dynamic>.from(m['animal'] as Map)
        : <String, dynamic>{};
    final lista = (m['registros'] as List?) ?? const [];
    return HistoricoAnimal(
      animalId: a['id']?.toString() ?? '',
      nome: a['nome']?.toString() ?? 'Animal',
      especie: a['especie']?.toString() ?? '',
      raca: a['raca']?.toString() ?? '',
      idade: (a['idade'] as num?)?.toInt() ?? 0,
      registros: lista
          .map((e) => RegistroMedico.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}
