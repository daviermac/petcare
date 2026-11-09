// Interfaces (portas) que a camada de infraestrutura implementa.
// Os serviços dependem só destas interfaces, o que permite testá-los sem Firestore.
import { Animal, Consulta, Perfil, Tutor } from '../domain/entidades';

export interface TutorRepositorio {
  buscarPorId(id: string): Promise<Tutor | null>;
  existeCpf(cpf: string): Promise<boolean>;
  salvar(tutor: Tutor): Promise<void>;
}

export interface AnimalRepositorio {
  buscarPorId(id: string): Promise<Animal | null>;
  criar(animal: Omit<Animal, 'id'>): Promise<Animal>;
}

export interface ConsultaRepositorio {
  buscarPorId(id: string): Promise<Consulta | null>;
  /** Retorna os horários (HH:mm) já ocupados na data. */
  horariosOcupados(data: string): Promise<string[]>;
  /**
   * Cria a consulta e reserva o horário de forma atômica (transação).
   * Lança ErroNegocio('HORARIO_INDISPONIVEL') se o horário já estiver reservado.
   */
  reservar(consulta: Omit<Consulta, 'id'>): Promise<Consulta>;
  /** Cancela a consulta e libera o horário de forma atômica. */
  cancelar(id: string, canceladoPor: string, quando: Date): Promise<void>;
  /** Move a consulta para outro horário: libera o antigo e reserva o novo atomicamente. */
  remarcar(id: string, data: string, horario: string, inicio: Date): Promise<Consulta>;
}

export interface UsuarioGateway {
  definirPerfil(uid: string, perfil: Perfil): Promise<void>;
}

/** Quem está chamando a API (vem do token do Firebase Auth). */
export interface Solicitante {
  uid: string;
  perfil: Perfil;
  email?: string;
}
