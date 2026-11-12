// Entidades do domínio (camada de Domínio).

export type Perfil = 'tutor' | 'atendente' | 'veterinario' | 'gestor' | 'auxiliar';

export const PERFIS_EQUIPE: readonly Perfil[] = ['atendente', 'veterinario', 'gestor', 'auxiliar'];

export type Especie = 'cachorro' | 'gato' | 'outro';

export interface Tutor {
  id: string; // mesmo uid do Firebase Auth
  nome: string;
  cpf: string; // só dígitos
  telefone: string; // só dígitos, com DDD
  email: string;
  criadoEm: Date;
}

export interface Animal {
  id: string;
  tutorId: string;
  nome: string;
  especie: Especie;
  raca: string;
  idade: number;
  criadoEm: Date;
}

export type StatusConsulta = 'agendada' | 'cancelada' | 'realizada';

/** Perfis que o gestor pode criar para a equipe (RF32). */
export const PERFIS_FUNCIONARIO: readonly Perfil[] = ['atendente', 'veterinario', 'auxiliar', 'gestor'];

export type TipoRegistro = 'atendimento' | 'prescricao' | 'vacina' | 'procedimento';

export interface DadosAtendimento {
  consultaId?: string;
  motivo: string;
  diagnostico: string;
  tratamento: string;
  observacoes: string;
}

export interface DadosPrescricao {
  medicamento: string;
  dosagem: string;
  frequenciaHoras: number;
  duracaoDias: number;
  orientacoes: string;
}

export interface DadosVacina {
  nome: string;
  dataAplicacao: string; // AAAA-MM-DD
  proximaDose: string | null; // AAAA-MM-DD
  lote: string;
}

export interface DadosProcedimento {
  descricao: string;
  observacoes: string;
}

export type DadosRegistro = DadosAtendimento | DadosPrescricao | DadosVacina | DadosProcedimento;

/** Versão anterior de um registro corrigido (RNF16). */
export interface VersaoRegistro {
  dados: DadosRegistro;
  autorId: string;
  autorNome: string;
  alteradoEm: Date;
}

/** Item do prontuário do animal. Nunca é apagado; correções guardam a versão anterior (RNF16). */
export interface RegistroMedico {
  id: string;
  tipo: TipoRegistro;
  animalId: string;
  tutorId: string;
  autorId: string;
  autorNome: string;
  autorPerfil: Perfil;
  dados: DadosRegistro;
  /** Só para vacinas: usado na busca dos lembretes (RF20). */
  proximaDose: string | null;
  criadoEm: Date;
  versao: number;
  historico: VersaoRegistro[];
}

export interface Consulta {
  id: string;
  tutorId: string;
  animalId: string;
  animalNome: string;
  data: string; // AAAA-MM-DD
  horario: string; // HH:mm
  inicio: Date;
  local: string;
  status: StatusConsulta;
  lembreteEnviado: boolean;
  criadoEm: Date;
  canceladoEm?: Date;
  canceladoPor?: string;
}
