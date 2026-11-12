// Casos de uso da equipe da clínica: agenda do dia (RF08, RF25) e relatório de atendimentos (RF33, RF35).
import { paraInstante } from '../domain/agenda';
import { Perfil, StatusConsulta } from '../domain/entidades';
import { ErroNegocio, ErroValidacao } from '../domain/erros';
import { AnimalRepositorio, ConsultaRepositorio, RegistroRepositorio, Solicitante, TutorRepositorio } from './portas';

export interface ItemAgenda {
  consultaId: string;
  horario: string;
  status: StatusConsulta;
  animal: { id: string; nome: string; especie: string };
  tutorNome: string;
  local: string;
}

export interface RelatorioAtendimentos {
  inicio: string;
  fim: string;
  total: number;
  porVeterinario: { veterinarioId: string; nome: string; total: number }[];
}

const PODE_VER_AGENDA: Perfil[] = ['atendente', 'veterinario', 'auxiliar', 'gestor'];

export class ClinicaServico {
  constructor(
    private readonly consultas: ConsultaRepositorio,
    private readonly animais: AnimalRepositorio,
    private readonly tutores: TutorRepositorio,
    private readonly registros: RegistroRepositorio,
  ) {}

  /**
   * Agenda da clínica num dia, em ordem de horário (RF08). Também serve ao auxiliar
   * para ver os animais do dia (RF25): só dados básicos, sem CPF, telefone ou valores.
   */
  async agendaDoDia(solicitante: Solicitante, data: string, incluirCanceladas = false): Promise<ItemAgenda[]> {
    if (!PODE_VER_AGENDA.includes(solicitante.perfil)) {
      throw new ErroNegocio('SEM_PERMISSAO', 'Sem permissão para ver a agenda da clínica.');
    }
    if (!/^\d{4}-\d{2}-\d{2}$/.test(data ?? '')) throw new ErroValidacao({ data: 'Data inválida.' });

    const consultas = (await this.consultas.listarPorData(data))
      .filter((c) => incluirCanceladas || c.status !== 'cancelada')
      .sort((a, b) => a.horario.localeCompare(b.horario));

    const cacheTutor = new Map<string, string>();
    return Promise.all(
      consultas.map(async (c) => {
        const animal = await this.animais.buscarPorId(c.animalId);
        if (!cacheTutor.has(c.tutorId)) {
          cacheTutor.set(c.tutorId, (await this.tutores.buscarPorId(c.tutorId))?.nome ?? '—');
        }
        return {
          consultaId: c.id,
          horario: c.horario,
          status: c.status,
          animal: { id: c.animalId, nome: animal?.nome ?? c.animalNome, especie: animal?.especie ?? '—' },
          tutorNome: cacheTutor.get(c.tutorId)!,
          local: c.local,
        };
      }),
    );
  }

  /** Quantidade de atendimentos no período, total e por veterinário (RF33, RF35). Só gestor. */
  async relatorioAtendimentos(solicitante: Solicitante, inicio: string, fim: string): Promise<RelatorioAtendimentos> {
    if (solicitante.perfil !== 'gestor') {
      throw new ErroNegocio('SEM_PERMISSAO', 'Somente o gestor pode gerar relatórios.');
    }
    const erros: Record<string, string> = {};
    const dataOk = (d: string) => /^\d{4}-\d{2}-\d{2}$/.test(d ?? '') && !isNaN(paraInstante(d, '00:00').getTime());
    if (!dataOk(inicio)) erros.inicio = 'Data inválida.';
    if (!dataOk(fim)) erros.fim = 'Data inválida.';
    if (!Object.keys(erros).length && fim < inicio) erros.fim = 'O fim deve ser igual ou depois do início.';
    if (Object.keys(erros).length) throw new ErroValidacao(erros);

    // Período inclusivo em horário de São Paulo: [inicio 00:00, fim+1 00:00)
    const de = paraInstante(inicio, '00:00');
    const ate = new Date(paraInstante(fim, '00:00').getTime() + 24 * 3600_000);
    const atendimentos = await this.registros.listarAtendimentos(de, ate);

    const porVet = new Map<string, { veterinarioId: string; nome: string; total: number }>();
    for (const a of atendimentos) {
      const item = porVet.get(a.autorId) ?? { veterinarioId: a.autorId, nome: a.autorNome, total: 0 };
      item.total++;
      porVet.set(a.autorId, item);
    }
    return {
      inicio,
      fim,
      total: atendimentos.length,
      porVeterinario: [...porVet.values()].sort((a, b) => b.total - a.total),
    };
  }
}
