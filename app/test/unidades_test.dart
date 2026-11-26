// Testes de unidade das regras do app (formatação, validação e modelos).
import 'package:flutter_test/flutter_test.dart';
import 'package:petcare/core/formatadores.dart';
import 'package:petcare/core/validacoes.dart';
import 'package:petcare/models/financeiro.dart';
import 'package:petcare/models/funcionario.dart';
import 'package:petcare/models/item_agenda.dart';
import 'package:petcare/models/registro_medico.dart';

void main() {
  group('Formatadores', () {
    test('moeda em reais com milhar e centavos', () {
      expect(moeda(15000), 'R\$ 150,00');
      expect(moeda(5), 'R\$ 0,05');
      expect(moeda(123456789), 'R\$ 1.234.567,89');
      expect(moeda(-2550), '-R\$ 25,50');
    });

    test('datas no formato da API e brasileiro', () {
      expect(dataIso(DateTime(2026, 3, 7)), '2026-03-07');
      expect(dataBr('2026-11-26'), '26/11/2026');
      expect(diaCurto(DateTime(2026, 11, 26)), 'Qui 26/11');
      expect(mesDe(DateTime(2026, 2, 10)), ('2026-02-01', '2026-02-28'));
    });

    test('próximos dias úteis não incluem fim de semana', () {
      final dias = proximosDiasUteis(10);
      expect(dias, hasLength(10));
      expect(dias.every((d) => d.weekday <= 5), isTrue);
    });
  });

  group('Validações', () {
    test('CPF, telefone, e-mail e nome', () {
      expect(cpfValido('529.982.247-25'), isTrue);
      expect(cpfValido('111.111.111-11'), isFalse);
      expect(telefoneValido('(12) 99102-1830'), isTrue);
      expect(telefoneValido('12 8102-183'), isFalse);
      expect(emailValido('vet@petconnect.dev'), isTrue);
      expect(emailValido('vet@'), isFalse);
      expect(nomeCompletoValido('Paula Reis'), isTrue);
      expect(nomeCompletoValido('Paula'), isFalse);
    });

    test('valor em reais', () {
      expect(lerValorReais('150'), 150);
      expect(lerValorReais('150,50'), 150.5);
      expect(lerValorReais('R\$ 1.234,56'), 1234.56);
      expect(lerValorReais(''), isNull);
      expect(lerValorReais('0'), isNull);
      expect(lerValorReais('10,555'), isNull);
      expect(lerValorReais('abc'), isNull);
    });

    test('inteiro em faixa e data dd/mm/aaaa', () {
      expect(lerInteiro('8', 1, 168), 8);
      expect(lerInteiro('0', 1, 168), isNull);
      expect(lerInteiro('x', 1, 168), isNull);
      expect(lerDataBr('26/11/2026'), '2026-11-26');
      expect(lerDataBr('31/02/2026'), isNull);
      expect(lerDataBr('2026-11-26'), isNull);
    });
  });

  group('Modelos', () {
    test('ItemAgenda lê a resposta de agendaDoDia', () {
      final item = ItemAgenda.fromMap({
        'consultaId': 'c1',
        'horario': '09:30',
        'status': 'realizada',
        'animal': {'id': 'a1', 'nome': 'Thor', 'especie': 'cachorro'},
        'tutorNome': 'Ana Souza',
        'local': 'Hospital PetConnect',
      });
      expect(item.animalId, 'a1');
      expect(item.statusRotulo, 'Realizada');
    });

    test('HistoricoAnimal e RegistroMedico (prescrição e vacina)', () {
      final h = HistoricoAnimal.fromMap({
        'animal': {'id': 'a1', 'nome': 'Thor', 'especie': 'cachorro', 'raca': 'Labrador', 'idade': 3},
        'registros': [
          {
            'id': 'r1',
            'tipo': 'prescricao',
            'autorNome': 'Paula Reis',
            'dados': {
              'medicamento': 'Otomax',
              'dosagem': '4 gotas',
              'frequenciaHoras': 12,
              'duracaoDias': 7,
              'orientacoes': '',
            },
            'criadoEm': '2026-11-20T13:00:00.000Z',
            'versao': 1,
          },
          {
            'id': 'r2',
            'tipo': 'vacina',
            'autorNome': 'Paula Reis',
            'dados': {'nome': 'V10', 'dataAplicacao': '2026-11-20', 'proximaDose': '2027-11-20', 'lote': ''},
            'criadoEm': '2026-11-20T14:00:00.000Z',
            'versao': 2,
          },
        ],
      });
      expect(h.nome, 'Thor');
      expect(h.registros, hasLength(2));
      expect(h.registros[0].titulo, 'Otomax — 4 gotas');
      expect(h.registros[0].detalhes, ['De 12 em 12 horas por 7 dia(s)']);
      expect(h.registros[1].tipoRotulo, 'Vacina');
      expect(h.registros[1].detalhes, ['Aplicação: 20/11/2026', 'Próxima dose: 20/11/2027']);
      expect(h.registros[1].versao, 2);
    });

    test('Fatura e relatório financeiro', () {
      final f = Fatura.fromMap({
        'id': 'f1',
        'animalNome': 'Thor',
        'valorCentavos': 18000,
        'data': '2026-11-20',
        'status': 'paga',
        'formaPagamento': 'pix',
      });
      expect(f.paga, isTrue);
      expect(formaPagamentoRotulo(f.formaPagamento), 'Pix');

      final r = RelatorioFinanceiro.fromMap({
        'quantidade': 2,
        'faturadoCentavos': 33000,
        'recebidoCentavos': 18000,
        'pendenteCentavos': 15000,
        'ticketMedioCentavos': 16500,
        'porFormaPagamento': [
          {'formaPagamento': 'pix', 'quantidade': 1, 'totalCentavos': 18000},
        ],
        'porVeterinario': [
          {'veterinarioId': 'v1', 'nome': 'Paula Reis', 'quantidade': 1, 'totalCentavos': 18000},
        ],
        'porDia': [
          {'data': '2026-11-20', 'quantidade': 2, 'totalCentavos': 33000},
        ],
      });
      expect(r.pendenteCentavos, 15000);
      expect(r.porFormaPagamento.single.rotulo, 'Pix');
      expect(r.porDia.single.rotulo, '20/11');
    });

    test('Funcionário e rótulos de perfil', () {
      final f = Funcionario.fromMap('u1', {'nome': 'Carla', 'email': 'c@x.dev', 'perfil': 'atendente'});
      expect(f.ativo, isTrue);
      expect(perfilRotulo('veterinario'), 'Veterinário(a)');
    });
  });
}
