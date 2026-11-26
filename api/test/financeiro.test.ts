import { FaturamentoServico } from '../src/application/faturamento-servico';
import { Solicitante } from '../src/application/portas';
import { ProntuarioServico } from '../src/application/prontuario-servico';
import { TutorServico } from '../src/application/tutor-servico';
import { ErroNegocio, ErroValidacao } from '../src/domain/erros';
import {
  VALOR_CONSULTA_PADRAO_CENTAVOS,
  validarFormaPagamento,
  validarPeriodo,
  valorEmCentavos,
} from '../src/domain/financeiro';
import {
  AnimaisEmMemoria,
  ConsultasEmMemoria,
  FaturasEmMemoria,
  RegistrosEmMemoria,
  TutoresEmMemoria,
  UsuariosEmMemoria,
} from './fakes';

// Relógio controlável: começa segunda 23/11/2026 10:00 (São Paulo).
let agora = new Date('2026-11-23T10:00:00-03:00');
const relogio = () => agora;
const irPara = (iso: string) => (agora = new Date(iso));

const vet: Solicitante = { uid: 'vet1', perfil: 'veterinario', nome: 'Paula Reis' };
const vet2: Solicitante = { uid: 'vet2', perfil: 'veterinario', nome: 'Caio Lima' };
const atendente: Solicitante = { uid: 'atend1', perfil: 'atendente', nome: 'Carla Mendes' };
const gestor: Solicitante = { uid: 'gestor1', perfil: 'gestor', nome: 'Marina Costa' };
const auxiliar: Solicitante = { uid: 'aux1', perfil: 'auxiliar' };
const tutor: Solicitante = { uid: 'tutorA', perfil: 'tutor' };

async function cenario() {
  irPara('2026-11-23T10:00:00-03:00');
  const tutores = new TutoresEmMemoria();
  const animais = new AnimaisEmMemoria();
  const registros = new RegistrosEmMemoria();
  const faturas = new FaturasEmMemoria();
  const tutorServico = new TutorServico(tutores, animais, new UsuariosEmMemoria(), relogio);
  const prontuario = new ProntuarioServico(registros, animais, new ConsultasEmMemoria(), relogio);
  const financeiro = new FaturamentoServico(faturas, animais, tutores, relogio);
  await tutorServico.registrar('tutorA', { nome: 'Ana Souza', cpf: '52998224725', telefone: '12991021830', email: 'a@x.com' });
  const thor = await tutorServico.cadastrarAnimal(tutor, { nome: 'Thor', especie: 'cachorro', raca: 'SRD', idade: 3 });

  /** Mesmo fluxo da callable registrarAtendimento: registra e fatura. */
  async function atender(quem: Solicitante, valor?: unknown, motivo = '') {
    const r = await prontuario.registrar(quem, 'atendimento', {
      animalId: thor.id,
      motivo,
      diagnostico: 'Ok',
      tratamento: 'Nenhum',
    });
    return financeiro.faturarAtendimento(r, valor);
  }
  return { financeiro, faturas, prontuario, thor, atender };
}

describe('Valor e período (domínio financeiro)', () => {
  it('usa o valor padrão quando nada é informado e converte reais em centavos', () => {
    expect(valorEmCentavos(undefined)).toBe(VALOR_CONSULTA_PADRAO_CENTAVOS);
    expect(valorEmCentavos('')).toBe(VALOR_CONSULTA_PADRAO_CENTAVOS);
    expect(valorEmCentavos(180)).toBe(18000);
    expect(valorEmCentavos(99.9)).toBe(9990);
    expect(valorEmCentavos('120,50')).toBe(12050);
  });

  it('recusa valor zero, negativo, com 3 casas ou absurdo', () => {
    for (const v of [0, -10, 'abc', 10.555, 200000]) {
      expect(() => valorEmCentavos(v)).toThrow(ErroValidacao);
    }
  });

  it('valida forma de pagamento e período', () => {
    expect(validarFormaPagamento('pix')).toBe('pix');
    expect(() => validarFormaPagamento('cheque')).toThrow(ErroValidacao);
    expect(() => validarPeriodo('2026-11-01', '2026-11-30')).not.toThrow();
    expect(() => validarPeriodo('2026-11-30', '2026-11-01')).toThrow(ErroValidacao);
    expect(() => validarPeriodo('2026-02-30', '2026-03-01')).toThrow(ErroValidacao);
    expect(() => validarPeriodo('2025-01-01', '2026-12-31')).toThrow(ErroValidacao);
  });
});

describe('Faturamento (RF30)', () => {
  it('atendimento gera cobrança pendente com animal, tutor, veterinário e data', async () => {
    const { atender } = await cenario();
    const f = await atender(vet, undefined, 'Coceira');
    expect(f).toMatchObject({
      status: 'pendente',
      valorCentavos: 15000,
      animalNome: 'Thor',
      tutorNome: 'Ana Souza',
      veterinarioNome: 'Paula Reis',
      data: '2026-11-23',
      descricao: 'Consulta veterinária — Coceira',
      formaPagamento: null,
    });
  });

  it('só atendimento gera cobrança', async () => {
    const { prontuario, financeiro, thor } = await cenario();
    const vacina = await prontuario.registrar(vet, 'vacina', { animalId: thor.id, nome: 'V10' });
    await expect(financeiro.faturarAtendimento(vacina)).rejects.toMatchObject({ codigo: 'OPERACAO_INVALIDA' });
  });

  it('atendente registra pagamento uma única vez', async () => {
    const { atender, financeiro } = await cenario();
    const f = await atender(vet, 200);
    const paga = await financeiro.registrarPagamento(atendente, { faturaId: f.id, formaPagamento: 'pix' });
    expect(paga).toMatchObject({ status: 'paga', formaPagamento: 'pix', recebidoPorNome: 'Carla Mendes' });
    expect(paga.pagoEm).toEqual(agora);
    await expect(
      financeiro.registrarPagamento(gestor, { faturaId: f.id, formaPagamento: 'dinheiro' }),
    ).rejects.toMatchObject({ codigo: 'FATURA_JA_PAGA' });
  });

  it('valida pagamento: perfil, cobrança e forma', async () => {
    const { atender, financeiro } = await cenario();
    const f = await atender(vet);
    for (const quem of [vet, auxiliar, tutor]) {
      await expect(
        financeiro.registrarPagamento(quem, { faturaId: f.id, formaPagamento: 'pix' }),
      ).rejects.toMatchObject({ codigo: 'SEM_PERMISSAO' });
    }
    await expect(financeiro.registrarPagamento(atendente, { formaPagamento: 'pix' })).rejects.toThrow(ErroValidacao);
    await expect(financeiro.registrarPagamento(atendente, { faturaId: f.id, formaPagamento: 'cheque' })).rejects.toThrow(
      ErroValidacao,
    );
    await expect(
      financeiro.registrarPagamento(atendente, { faturaId: 'nao-existe', formaPagamento: 'pix' }),
    ).rejects.toMatchObject({ codigo: 'NAO_ENCONTRADO' });
  });

  it('lista cobranças do período, mais recentes primeiro, com filtro de status', async () => {
    const { atender, financeiro } = await cenario();
    const a = await atender(vet);
    irPara('2026-11-24T15:00:00-03:00');
    const b = await atender(vet2);
    await financeiro.registrarPagamento(atendente, { faturaId: a.id, formaPagamento: 'dinheiro' });

    const todas = await financeiro.listarFaturas(atendente, '2026-11-01', '2026-11-30');
    expect(todas.map((f) => f.id)).toEqual([b.id, a.id]);
    expect((await financeiro.listarFaturas(gestor, '2026-11-01', '2026-11-30', 'pendente')).map((f) => f.id)).toEqual([b.id]);
    expect(await financeiro.listarFaturas(atendente, '2026-11-24', '2026-11-24', 'paga')).toEqual([]);
    await expect(financeiro.listarFaturas(atendente, '2026-11-01', '2026-11-30', 'cancelada')).rejects.toThrow(ErroValidacao);
    await expect(financeiro.listarFaturas(vet, '2026-11-01', '2026-11-30')).rejects.toThrow(ErroNegocio);
  });
});

describe('Relatório financeiro (RF31)', () => {
  it('soma faturado, recebido e pendente, por forma, por veterinário e por dia', async () => {
    const { atender, financeiro } = await cenario();
    const a = await atender(vet, 150);
    const b = await atender(vet, 250);
    irPara('2026-11-25T09:00:00-03:00');
    const c = await atender(vet2, 100);
    irPara('2026-12-02T09:00:00-03:00');
    await atender(vet2, 999); // fora do período
    await financeiro.registrarPagamento(atendente, { faturaId: a.id, formaPagamento: 'pix' });
    await financeiro.registrarPagamento(atendente, { faturaId: c.id, formaPagamento: 'pix' });
    await financeiro.registrarPagamento(gestor, { faturaId: b.id, formaPagamento: 'cartao_credito' });

    const r = await financeiro.relatorioFinanceiro(gestor, '2026-11-01', '2026-11-30');
    expect(r).toMatchObject({
      quantidade: 3,
      faturadoCentavos: 50000,
      recebidoCentavos: 50000,
      pendenteCentavos: 0,
      ticketMedioCentavos: 16667,
    });
    expect(r.porFormaPagamento).toEqual([
      { formaPagamento: 'pix', quantidade: 2, totalCentavos: 25000 },
      { formaPagamento: 'cartao_credito', quantidade: 1, totalCentavos: 25000 },
    ]);
    expect(r.porVeterinario).toEqual([
      { veterinarioId: 'vet1', nome: 'Paula Reis', quantidade: 2, totalCentavos: 40000 },
      { veterinarioId: 'vet2', nome: 'Caio Lima', quantidade: 1, totalCentavos: 10000 },
    ]);
    expect(r.porDia).toEqual([
      { data: '2026-11-23', quantidade: 2, totalCentavos: 40000 },
      { data: '2026-11-25', quantidade: 1, totalCentavos: 10000 },
    ]);
  });

  it('período sem movimento devolve zeros; só gestor gera', async () => {
    const { financeiro } = await cenario();
    const r = await financeiro.relatorioFinanceiro(gestor, '2026-01-01', '2026-01-31');
    expect(r).toMatchObject({ quantidade: 0, faturadoCentavos: 0, ticketMedioCentavos: 0, porDia: [] });
    await expect(financeiro.relatorioFinanceiro(atendente, '2026-01-01', '2026-01-31')).rejects.toMatchObject({
      codigo: 'SEM_PERMISSAO',
    });
    await expect(financeiro.relatorioFinanceiro(gestor, 'x', '2026-01-31')).rejects.toThrow(ErroValidacao);
  });
});
