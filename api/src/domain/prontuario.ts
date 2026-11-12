// Regras do prontuário: validações dos registros médicos e horários de medicação (RF14–RF16, RF21, RF26).
import {
  DadosAtendimento,
  DadosPrescricao,
  DadosProcedimento,
  DadosRegistro,
  DadosVacina,
  Perfil,
  TipoRegistro,
} from './entidades';
import { ErroValidacao } from './erros';

type Entrada = Record<string, unknown>;

const texto = (v: unknown): string => (typeof v === 'string' ? v.trim() : '');

function obrigatorio(erros: Record<string, string>, campo: string, valor: string, max = 2000): void {
  if (!valor) erros[campo] = 'Campo obrigatório.';
  else if (valor.length > max) erros[campo] = `Máximo de ${max} caracteres.`;
}

function opcional(erros: Record<string, string>, campo: string, valor: string, max = 2000): void {
  if (valor.length > max) erros[campo] = `Máximo de ${max} caracteres.`;
}

function dataValida(valor: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(valor)) return false;
  const d = new Date(`${valor}T12:00:00Z`);
  return !isNaN(d.getTime()) && d.toISOString().slice(0, 10) === valor;
}

function inteiro(erros: Record<string, string>, campo: string, v: unknown, min: number, max: number): number {
  const n = Number(v);
  if (!Number.isInteger(n) || n < min || n > max) erros[campo] = `Informe um número inteiro entre ${min} e ${max}.`;
  return n;
}

function concluir<T>(erros: Record<string, string>, dados: T): T {
  if (Object.keys(erros).length) throw new ErroValidacao(erros);
  return dados;
}

export function validarAtendimento(e: Entrada): DadosAtendimento {
  const erros: Record<string, string> = {};
  const dados: DadosAtendimento = {
    motivo: texto(e.motivo),
    diagnostico: texto(e.diagnostico),
    tratamento: texto(e.tratamento),
    observacoes: texto(e.observacoes),
  };
  if (texto(e.consultaId)) dados.consultaId = texto(e.consultaId);
  opcional(erros, 'motivo', dados.motivo, 300);
  obrigatorio(erros, 'diagnostico', dados.diagnostico);
  obrigatorio(erros, 'tratamento', dados.tratamento);
  opcional(erros, 'observacoes', dados.observacoes);
  return concluir(erros, dados);
}

export function validarPrescricao(e: Entrada): DadosPrescricao {
  const erros: Record<string, string> = {};
  const dados: DadosPrescricao = {
    medicamento: texto(e.medicamento),
    dosagem: texto(e.dosagem),
    frequenciaHoras: inteiro(erros, 'frequenciaHoras', e.frequenciaHoras, 1, 168),
    duracaoDias: inteiro(erros, 'duracaoDias', e.duracaoDias, 1, 365),
    orientacoes: texto(e.orientacoes),
  };
  obrigatorio(erros, 'medicamento', dados.medicamento, 120);
  obrigatorio(erros, 'dosagem', dados.dosagem, 120);
  opcional(erros, 'orientacoes', dados.orientacoes);
  return concluir(erros, dados);
}

export function validarVacina(e: Entrada, hoje: string): DadosVacina {
  const erros: Record<string, string> = {};
  const dados: DadosVacina = {
    nome: texto(e.nome),
    dataAplicacao: texto(e.dataAplicacao) || hoje,
    proximaDose: texto(e.proximaDose) || null,
    lote: texto(e.lote),
  };
  obrigatorio(erros, 'nome', dados.nome, 120);
  opcional(erros, 'lote', dados.lote, 60);
  if (!dataValida(dados.dataAplicacao)) erros.dataAplicacao = 'Data inválida (AAAA-MM-DD).';
  else if (dados.dataAplicacao > hoje) erros.dataAplicacao = 'A aplicação não pode ser no futuro.';
  if (dados.proximaDose !== null) {
    if (!dataValida(dados.proximaDose)) erros.proximaDose = 'Data inválida (AAAA-MM-DD).';
    else if (!erros.dataAplicacao && dados.proximaDose <= dados.dataAplicacao) {
      erros.proximaDose = 'A próxima dose deve ser depois da aplicação.';
    }
  }
  return concluir(erros, dados);
}

export function validarProcedimento(e: Entrada): DadosProcedimento {
  const erros: Record<string, string> = {};
  const dados: DadosProcedimento = { descricao: texto(e.descricao), observacoes: texto(e.observacoes) };
  obrigatorio(erros, 'descricao', dados.descricao, 500);
  opcional(erros, 'observacoes', dados.observacoes);
  return concluir(erros, dados);
}

export function validarRegistro(tipo: TipoRegistro, e: Entrada, hoje: string): DadosRegistro {
  switch (tipo) {
    case 'atendimento':
      return validarAtendimento(e);
    case 'prescricao':
      return validarPrescricao(e);
    case 'vacina':
      return validarVacina(e, hoje);
    case 'procedimento':
      return validarProcedimento(e);
  }
}

/** Quem pode registrar cada tipo no prontuário. */
export const AUTORES_PERMITIDOS: Record<TipoRegistro, readonly Perfil[]> = {
  atendimento: ['veterinario'],
  prescricao: ['veterinario'],
  vacina: ['veterinario'],
  procedimento: ['veterinario', 'auxiliar'],
};

/**
 * Horários das doses de uma prescrição (RF21), usados pelo app para agendar
 * lembretes locais. Ex.: de 8 em 8 horas por 3 dias → 9 horários.
 */
export function horariosDeMedicacao(inicio: Date, frequenciaHoras: number, duracaoDias: number): Date[] {
  const total = Math.floor((duracaoDias * 24) / frequenciaHoras);
  return Array.from({ length: total }, (_, i) => new Date(inicio.getTime() + i * frequenciaHoras * 3600_000));
}
