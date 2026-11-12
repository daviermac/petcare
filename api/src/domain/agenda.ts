// Regras da agenda da clínica (RF06, RF07).
import { ErroValidacao } from './erros';

/** Grade de horários da clínica (igual ao protótipo da Tela 03). */
export const HORARIOS_ATENDIMENTO = ['08:00', '09:30', '11:00', '14:00', '15:30'] as const;

/** Clínica atende de segunda (1) a sexta (5). */
export const DIAS_ATENDIMENTO = [1, 2, 3, 4, 5];

/** Quantos dias à frente o tutor pode agendar. */
export const JANELA_AGENDAMENTO_DIAS = 60;

export const LOCAL_PADRAO = 'Hospital PetConnect';

/** Fuso de São Paulo (sem horário de verão desde 2019). */
const OFFSET_SP = '-03:00';

/** Converte data (AAAA-MM-DD) + horário (HH:mm) de São Paulo para Date. */
export function paraInstante(data: string, horario: string): Date {
  return new Date(`${data}T${horario}:00${OFFSET_SP}`);
}

/** Data (AAAA-MM-DD) no fuso de São Paulo. */
export function dataEmSaoPaulo(instante: Date): string {
  return new Date(instante.getTime() - 3 * 3600_000).toISOString().slice(0, 10);
}

/** Soma dias a uma data AAAA-MM-DD. */
export function somarDias(data: string, dias: number): string {
  const d = new Date(`${data}T12:00:00Z`);
  d.setUTCDate(d.getUTCDate() + dias);
  return d.toISOString().slice(0, 10);
}

/** ID determinístico do horário: garante que só exista uma reserva por slot. */
export function idDoHorario(data: string, horario: string): string {
  return `${data}_${horario.replace(':', '')}`;
}

export function validarHorario(data: string, horario: string, agora: Date = new Date()): void {
  const erros: Record<string, string> = {};
  if (!/^\d{4}-\d{2}-\d{2}$/.test(data ?? '') || isNaN(paraInstante(data, '12:00').getTime())) {
    erros.data = 'Data inválida.';
  } else {
    const diaSemana = paraInstante(data, '12:00').getUTCDay();
    if (!DIAS_ATENDIMENTO.includes(diaSemana)) erros.data = 'A clínica não atende neste dia.';
  }
  if (!HORARIOS_ATENDIMENTO.includes(horario as (typeof HORARIOS_ATENDIMENTO)[number])) {
    erros.horario = 'Horário fora da grade de atendimento.';
  }
  if (!erros.data && !erros.horario) {
    const inicio = paraInstante(data, horario);
    const limite = new Date(agora.getTime() + JANELA_AGENDAMENTO_DIAS * 24 * 60 * 60 * 1000);
    if (inicio <= agora) erros.horario = 'Esse horário já passou.';
    else if (inicio > limite) erros.data = `Agende com no máximo ${JANELA_AGENDAMENTO_DIAS} dias de antecedência.`;
  }
  if (Object.keys(erros).length) throw new ErroValidacao(erros);
}
