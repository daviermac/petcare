// Casos de uso de tutor e animal (RF01, RF04).
import { Animal, Tutor } from '../domain/entidades';
import { ErroNegocio } from '../domain/erros';
import { DadosAnimal, DadosTutor, validarAnimal, validarTutor } from '../domain/validacoes';
import { AnimalRepositorio, Solicitante, TutorRepositorio, UsuarioGateway } from './portas';

export class TutorServico {
  constructor(
    private readonly tutores: TutorRepositorio,
    private readonly animais: AnimalRepositorio,
    private readonly usuarios: UsuarioGateway,
    private readonly relogio: () => Date = () => new Date(),
  ) {}

  /**
   * Completa o cadastro do tutor depois que o app criou a conta no Firebase Auth.
   * O uid vem do token, então cada um só cadastra a si mesmo.
   */
  async registrar(uid: string, entrada: Partial<DadosTutor>): Promise<Tutor> {
    const dados = validarTutor(entrada);
    const existente = await this.tutores.buscarPorId(uid);
    if (existente) return existente;
    if (await this.tutores.existeCpf(dados.cpf)) {
      throw new ErroNegocio('CPF_JA_CADASTRADO', 'Já existe um tutor com este CPF.');
    }
    const tutor: Tutor = { id: uid, ...dados, criadoEm: this.relogio() };
    await this.tutores.salvar(tutor);
    await this.usuarios.definirPerfil(uid, 'tutor');
    return tutor;
  }

  /** Cadastra animal. Tutor cadastra para si; atendente informa o tutorId. */
  async cadastrarAnimal(
    solicitante: Solicitante,
    entrada: Partial<DadosAnimal> & { tutorId?: string },
  ): Promise<Animal> {
    let tutorId: string;
    if (solicitante.perfil === 'tutor') tutorId = solicitante.uid;
    else if (solicitante.perfil === 'atendente' && entrada.tutorId) tutorId = entrada.tutorId;
    else throw new ErroNegocio('SEM_PERMISSAO', 'Sem permissão para cadastrar animal.');

    const dados = validarAnimal(entrada);
    if (!(await this.tutores.buscarPorId(tutorId))) {
      throw new ErroNegocio('NAO_ENCONTRADO', 'Tutor não encontrado.');
    }
    return this.animais.criar({ tutorId, ...dados, criadoEm: this.relogio() });
  }
}
