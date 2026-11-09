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
