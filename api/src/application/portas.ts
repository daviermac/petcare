// Interfaces (portas) que a camada de infraestrutura implementa.
// Os serviços dependem só destas interfaces, o que permite testá-los sem Firestore.
import { Animal, Consulta, DadosRegistro, Perfil, RegistroMedico, Tutor } from '../domain/entidades';

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
  /** Consultas de uma data (qualquer status). */
  listarPorData(data: string): Promise<Consulta[]>;
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
  /** Marca a consulta como realizada (o horário continua ocupado). */
  marcarRealizada(id: string): Promise<void>;
}

export interface RegistroRepositorio {
  buscarPorId(id: string): Promise<RegistroMedico | null>;
  criar(registro: Omit<RegistroMedico, 'id'>): Promise<RegistroMedico>;
  /** Registros do animal em ordem cronológica (mais antigo primeiro). */
  listarPorAnimal(animalId: string): Promise<RegistroMedico[]>;
  /** Substitui os dados guardando a versão anterior no histórico (RNF16). */
  corrigir(id: string, dados: DadosRegistro, proximaDose: string | null, autor: { id: string; nome: string }, quando: Date): Promise<RegistroMedico>;
  /** Atendimentos registrados no período [inicio, fim). */
  listarAtendimentos(inicio: Date, fim: Date): Promise<RegistroMedico[]>;
}

export interface NovoFuncionario {
  nome: string;
  email: string;
  senha: string;
  perfil: Perfil;
}

export interface UsuarioGateway {
  definirPerfil(uid: string, perfil: Perfil): Promise<void>;
  /** Cria login (Firebase Auth) + documento em usuarios. Lança EMAIL_JA_CADASTRADO. */
  criarFuncionario(dados: NovoFuncionario): Promise<string>;
  /** Ativa/desativa o login. Desativado não consegue entrar (RF32). */
  definirAtivo(uid: string, ativo: boolean): Promise<void>;
  buscarPerfil(uid: string): Promise<Perfil | null>;
}

/** Quem está chamando a API (vem do token do Firebase Auth). */
export interface Solicitante {
  uid: string;
  perfil: Perfil;
  email?: string;
  nome?: string;
}
