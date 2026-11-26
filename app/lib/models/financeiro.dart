/// Cobrança gerada no atendimento (RF30). Valores em centavos.
class Fatura {
  final String id;
  final String animalNome;
  final String tutorNome;
  final String veterinarioNome;
  final String descricao;
  final int valorCentavos;
  final String data; // AAAA-MM-DD
  final String status; // pendente | paga
  final String? formaPagamento;
  final DateTime? pagoEm;
  final String? recebidoPorNome;

  const Fatura({
    required this.id,
    required this.animalNome,
    required this.tutorNome,
    required this.veterinarioNome,
    required this.descricao,
    required this.valorCentavos,
    required this.data,
    required this.status,
    this.formaPagamento,
    this.pagoEm,
    this.recebidoPorNome,
  });

  bool get paga => status == 'paga';

  factory Fatura.fromMap(Map<String, dynamic> m) {
    return Fatura(
      id: m['id']?.toString() ?? '',
      animalNome: m['animalNome']?.toString() ?? '—',
      tutorNome: m['tutorNome']?.toString() ?? '—',
      veterinarioNome: m['veterinarioNome']?.toString() ?? '—',
      descricao: m['descricao']?.toString() ?? '',
      valorCentavos: (m['valorCentavos'] as num?)?.toInt() ?? 0,
      data: m['data']?.toString() ?? '',
      status: m['status']?.toString() ?? 'pendente',
      formaPagamento: m['formaPagamento']?.toString(),
      pagoEm: DateTime.tryParse(m['pagoEm']?.toString() ?? ''),
      recebidoPorNome: m['recebidoPorNome']?.toString(),
    );
  }
}

const formasPagamento = ['dinheiro', 'pix', 'cartao_debito', 'cartao_credito'];

String formaPagamentoRotulo(String? forma) => switch (forma) {
  'dinheiro' => 'Dinheiro',
  'pix' => 'Pix',
  'cartao_debito' => 'Cartão de débito',
  'cartao_credito' => 'Cartão de crédito',
  _ => '—',
};

/// Linha de um agrupamento do relatório (por veterinário, forma de pagamento ou dia).
class LinhaRelatorio {
  final String rotulo;
  final int quantidade;
  final int totalCentavos;

  const LinhaRelatorio(this.rotulo, this.quantidade, this.totalCentavos);
}

/// Relatório financeiro do período (RF31).
class RelatorioFinanceiro {
  final int quantidade;
  final int faturadoCentavos;
  final int recebidoCentavos;
  final int pendenteCentavos;
  final int ticketMedioCentavos;
  final List<LinhaRelatorio> porFormaPagamento;
  final List<LinhaRelatorio> porVeterinario;
  final List<LinhaRelatorio> porDia;

  const RelatorioFinanceiro({
    required this.quantidade,
    required this.faturadoCentavos,
    required this.recebidoCentavos,
    required this.pendenteCentavos,
    required this.ticketMedioCentavos,
    required this.porFormaPagamento,
    required this.porVeterinario,
    required this.porDia,
  });

  factory RelatorioFinanceiro.fromMap(Map<String, dynamic> m) {
    int n(String k) => (m[k] as num?)?.toInt() ?? 0;
    List<LinhaRelatorio> linhas(String k, String Function(Map) rotulo) {
      final lista = (m[k] as List?) ?? const [];
      return lista.map((e) {
        final x = e as Map;
        return LinhaRelatorio(
          rotulo(x),
          (x['quantidade'] as num?)?.toInt() ?? 0,
          (x['totalCentavos'] as num?)?.toInt() ?? 0,
        );
      }).toList();
    }

    return RelatorioFinanceiro(
      quantidade: n('quantidade'),
      faturadoCentavos: n('faturadoCentavos'),
      recebidoCentavos: n('recebidoCentavos'),
      pendenteCentavos: n('pendenteCentavos'),
      ticketMedioCentavos: n('ticketMedioCentavos'),
      porFormaPagamento: linhas(
        'porFormaPagamento',
        (x) => formaPagamentoRotulo(x['formaPagamento']?.toString()),
      ),
      porVeterinario: linhas('porVeterinario', (x) => x['nome']?.toString() ?? '—'),
      porDia: linhas('porDia', (x) {
        final p = (x['data']?.toString() ?? '').split('-');
        return p.length == 3 ? '${p[2]}/${p[1]}' : '';
      }),
    );
  }
}

/// Relatório de atendimentos (RF33, RF35).
class RelatorioAtendimentos {
  final int total;
  final List<LinhaRelatorio> porVeterinario;

  const RelatorioAtendimentos({required this.total, required this.porVeterinario});

  factory RelatorioAtendimentos.fromMap(Map<String, dynamic> m) {
    final lista = (m['porVeterinario'] as List?) ?? const [];
    return RelatorioAtendimentos(
      total: (m['total'] as num?)?.toInt() ?? 0,
      porVeterinario: lista.map((e) {
        final x = e as Map;
        final total = (x['total'] as num?)?.toInt() ?? 0;
        return LinhaRelatorio(x['nome']?.toString() ?? '—', total, 0);
      }).toList(),
    );
  }
}
