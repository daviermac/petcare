// Casos de uso de agendamento (RF06, RF07, RF09, RF10, RF11).
import {
  HORARIOS_ATENDIMENTO,
  LOCAL_PADRAO,
  paraInstante,
  validarHorario,
} from '../domain/agenda';
import { Consulta, PERFIS_EQUIPE } from '../domain/entidades';
import { ErroNegocio } from '../domain/erros';
import { AnimalRepositorio, ConsultaRepositorio, Solicitante } from './portas';

export interface HorarioDisponivel {
  horario: string;
  disponivel: boolean;
}

export class AgendamentoServico {
  constructor(
    private readonly consultas: ConsultaRepositorio,
    private readonly animais: AnimalRepositorio,
    private readonly relogio: () => Date = () => new Date(),
  ) {}

  /** Grade do dia com os horários ocupados marcados (para riscar na Tela 03). */
  async listarHorarios(data: string): Promise<HorarioDisponivel[]> {
    const ocupados = new Set(await this.consultas.horariosOcupados(data));
    const agora = this.relogio();
    return HORARIOS_ATENDIMENTO.map((horario) => ({
      horario,
      disponivel: !ocupados.has(horario) && paraInstante(data, horario) > agora,
    }));
  }

  async agendar(
    solicitante: Solicitante,
    entrada: { animalId?: string; data?: string; horario?: string },
  ): Promise<Consulta> {
    const data = entrada.data ?? '';
    const horario = entrada.horario ?? '';
    validarHorario(data, horario, this.relogio());

    const animal = entrada.animalId ? await this.animais.buscarPorId(entrada.animalId) : null;
    if (!animal) throw new ErroNegocio('NAO_ENCONTRADO', 'Animal não encontrado.');

    const podeAgendar =
      (solicitante.perfil === 'tutor' && animal.tutorId === solicitante.uid) ||
      solicitante.perfil === 'atendente';
    if (!podeAgendar) throw new ErroNegocio('SEM_PERMISSAO', 'Sem permissão para agendar para este animal.');

    return this.consultas.reservar({
      tutorId: animal.tutorId,
      animalId: animal.id,
      animalNome: animal.nome,
      data,
      horario,
      inicio: paraInstante(data, horario),
      local: LOCAL_PADRAO,
      status: 'agendada',
      lembreteEnviado: false,
      criadoEm: this.relogio(),
    });
  }

  async cancelar(solicitante: Solicitante, consultaId: string): Promise<void> {
    const consulta = await this.consultaAtiva(consultaId);
    const podeCancelar =
      (solicitante.perfil === 'tutor' && consulta.tutorId === solicitante.uid) ||
      solicitante.perfil === 'atendente' ||
      solicitante.perfil === 'gestor';
    if (!podeCancelar) throw new ErroNegocio('SEM_PERMISSAO', 'Sem permissão para cancelar esta consulta.');
    await this.consultas.cancelar(consultaId, solicitante.uid, this.relogio());
  }

  /** Remarcação é feita pelo atendente (RF10). */
  async remarcar(
    solicitante: Solicitante,
    entrada: { consultaId?: string; data?: string; horario?: string },
  ): Promise<Consulta> {
    if (solicitante.perfil !== 'atendente') {
      throw new ErroNegocio('SEM_PERMISSAO', 'Somente o atendente pode remarcar consultas.');
    }
    const data = entrada.data ?? '';
    const horario = entrada.horario ?? '';
    validarHorario(data, horario, this.relogio());
    const consulta = await this.consultaAtiva(entrada.consultaId ?? '');
    if (consulta.data === data && consulta.horario === horario) return consulta;
    return this.consultas.remarcar(consulta.id, data, horario, paraInstante(data, horario));
  }

  private async consultaAtiva(id: string): Promise<Consulta> {
    const consulta = id ? await this.consultas.buscarPorId(id) : null;
    if (!consulta) throw new ErroNegocio('NAO_ENCONTRADO', 'Consulta não encontrada.');
    if (consulta.status !== 'agendada') {
      throw new ErroNegocio('CONSULTA_NAO_ATIVA', 'Esta consulta não está mais agendada.');
    }
    return consulta;
  }
}

export const ehEquipe = (s: Solicitante): boolean => PERFIS_EQUIPE.includes(s.perfil);
