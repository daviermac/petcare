// Casos de uso do financeiro: faturamento dos atendimentos (RF30) e relatório financeiro (RF31).
import { dataEmSaoPaulo } from '../domain/agenda';
import { DadosAtendimento, Fatura, FormaPagamento, Perfil, RegistroMedico, StatusFatura } from '../domain/entidades';
import { ErroNegocio, ErroValidacao } from '../domain/erros';
import { FORMAS_PAGAMENTO, validarFormaPagamento, validarPeriodo, valorEmCentavos } from '../domain/financeiro';
import { AnimalRepositorio, FaturaRepositorio, Solicitante, TutorRepositorio } from './portas';

/** Quem pode ver cobranças e registrar pagamentos. */
const PODE_RECEBER: Perfil[] = ['atendente', 'gestor'];

export interface RelatorioFinanceiro {
  inicio: string;
  fim: string;
  quantidade: number;
  faturadoCentavos: number;
  recebidoCentavos: number;
  pendenteCentavos: number;
  ticketMedioCentavos: number;
  porFormaPagamento: { formaPagamento: FormaPagamento; quantidade: number; totalCentavos: number }[];
  porVeterinario: { veterinarioId: string; nome: string; quantidade: number; totalCentavos: number }[];
  porDia: { data: string; quantidade: number; totalCentavos: number }[];
}

export class FaturamentoServico {
  constructor(
    private readonly faturas: FaturaRepositorio,
    private readonly animais: AnimalRepositorio,
    private readonly tutores: TutorRepositorio,
    private readonly relogio: () => Date = () => new Date(),
  ) {}

  /**
   * Gera a cobrança de um atendimento (RF30). Chamado logo depois de registrarAtendimento.
   * Sem valor informado, usa o valor padrão da consulta.
   */
  async faturarAtendimento(registro: RegistroMedico, valor?: unknown): Promise<Fatura> {
    if (registro.tipo !== 'atendimento') {
      throw new ErroNegocio('OPERACAO_INVALIDA', 'Só atendimentos geram cobrança.');
    }
    const valorCentavos = valorEmCentavos(valor);
    const [animal, tutor] = await Promise.all([
      this.animais.buscarPorId(registro.animalId),
      this.tutores.buscarPorId(registro.tutorId),
    ]);
    const dados = registro.dados as DadosAtendimento;
    const motivo = dados.motivo?.trim();
    return this.faturas.criar({
      registroId: registro.id,
      consultaId: dados.consultaId ?? null,
      animalId: registro.animalId,
      animalNome: animal?.nome ?? '—',
      tutorId: registro.tutorId,
      tutorNome: tutor?.nome ?? '—',
      veterinarioId: registro.autorId,
      veterinarioNome: registro.autorNome,
      descricao: motivo ? `Consulta veterinária — ${motivo}` : 'Consulta veterinária',
      valorCentavos,
      data: dataEmSaoPaulo(registro.criadoEm),
      status: 'pendente',
      formaPagamento: null,
      criadoEm: registro.criadoEm,
      pagoEm: null,
      recebidoPorId: null,
      recebidoPorNome: null,
    });
  }

  /** Registra o pagamento de uma cobrança pendente (RF30). Atendente ou gestor. */
  async registrarPagamento(
    solicitante: Solicitante,
    entrada: { faturaId?: unknown; formaPagamento?: unknown },
  ): Promise<Fatura> {
    this.exigir(solicitante, PODE_RECEBER, 'Somente atendente ou gestor podem registrar pagamentos.');
    const faturaId = typeof entrada.faturaId === 'string' ? entrada.faturaId : '';
    if (!faturaId) throw new ErroValidacao({ faturaId: 'Informe a cobrança.' });
    const forma = validarFormaPagamento(entrada.formaPagamento);

    const fatura = await this.faturas.buscarPorId(faturaId);
    if (!fatura) throw new ErroNegocio('NAO_ENCONTRADO', 'Cobrança não encontrada.');
    if (fatura.status === 'paga') throw new ErroNegocio('FATURA_JA_PAGA', 'Esta cobrança já foi paga.');

    return this.faturas.registrarPagamento(
      faturaId,
      forma,
      { id: solicitante.uid, nome: solicitante.nome ?? solicitante.email ?? solicitante.uid },
      this.relogio(),
    );
  }

  /** Cobranças do período, mais recentes primeiro (opcionalmente só pendentes ou só pagas). */
  async listarFaturas(
    solicitante: Solicitante,
    inicio: string,
    fim: string,
    status?: unknown,
  ): Promise<Fatura[]> {
    this.exigir(solicitante, PODE_RECEBER, 'Somente atendente ou gestor podem ver as cobranças.');
    validarPeriodo(inicio, fim);
    if (status !== undefined && status !== null && status !== '' && status !== 'pendente' && status !== 'paga') {
      throw new ErroValidacao({ status: 'Use pendente ou paga.' });
    }
    const lista = await this.faturas.listarPorPeriodo(inicio, fim);
    return lista
      .filter((f) => !status || f.status === (status as StatusFatura))
      .sort((a, b) => b.criadoEm.getTime() - a.criadoEm.getTime());
  }

  /** Relatório financeiro do período (RF31). Só gestor. Período inclusivo, horário de São Paulo. */
  async relatorioFinanceiro(solicitante: Solicitante, inicio: string, fim: string): Promise<RelatorioFinanceiro> {
    this.exigir(solicitante, ['gestor'], 'Somente o gestor pode gerar relatórios.');
    validarPeriodo(inicio, fim);
    const faturas = await this.faturas.listarPorPeriodo(inicio, fim);

    let faturado = 0;
    let recebido = 0;
    const porForma = new Map<FormaPagamento, { formaPagamento: FormaPagamento; quantidade: number; totalCentavos: number }>();
    const porVet = new Map<string, { veterinarioId: string; nome: string; quantidade: number; totalCentavos: number }>();
    const porDia = new Map<string, { data: string; quantidade: number; totalCentavos: number }>();

    for (const f of faturas) {
      faturado += f.valorCentavos;
      if (f.status === 'paga' && f.formaPagamento) {
        recebido += f.valorCentavos;
        const item = porForma.get(f.formaPagamento) ?? { formaPagamento: f.formaPagamento, quantidade: 0, totalCentavos: 0 };
        item.quantidade++;
        item.totalCentavos += f.valorCentavos;
        porForma.set(f.formaPagamento, item);
      }
      const vet = porVet.get(f.veterinarioId) ?? {
        veterinarioId: f.veterinarioId,
        nome: f.veterinarioNome,
        quantidade: 0,
        totalCentavos: 0,
      };
      vet.quantidade++;
      vet.totalCentavos += f.valorCentavos;
      porVet.set(f.veterinarioId, vet);

      const dia = porDia.get(f.data) ?? { data: f.data, quantidade: 0, totalCentavos: 0 };
      dia.quantidade++;
      dia.totalCentavos += f.valorCentavos;
      porDia.set(f.data, dia);
    }

    return {
      inicio,
      fim,
      quantidade: faturas.length,
      faturadoCentavos: faturado,
      recebidoCentavos: recebido,
      pendenteCentavos: faturado - recebido,
      ticketMedioCentavos: faturas.length ? Math.round(faturado / faturas.length) : 0,
      porFormaPagamento: FORMAS_PAGAMENTO.filter((f) => porForma.has(f)).map((f) => porForma.get(f)!),
      porVeterinario: [...porVet.values()].sort((a, b) => b.totalCentavos - a.totalCentavos),
      porDia: [...porDia.values()].sort((a, b) => a.data.localeCompare(b.data)),
    };
  }

  private exigir(s: Solicitante, perfis: Perfil[], mensagem: string): void {
    if (!perfis.includes(s.perfil)) throw new ErroNegocio('SEM_PERMISSAO', mensagem);
  }
}
