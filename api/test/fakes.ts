// Repositórios em memória para testar os serviços sem Firestore.
import {
  AnimalRepositorio,
  ConsultaRepositorio,
  NovoFuncionario,
  RegistroRepositorio,
  TutorRepositorio,
  UsuarioGateway,
} from '../src/application/portas';
import { idDoHorario } from '../src/domain/agenda';
import { Animal, Consulta, DadosRegistro, Perfil, RegistroMedico, Tutor } from '../src/domain/entidades';
import { ErroNegocio } from '../src/domain/erros';

let seq = 0;
const novoId = () => `id${++seq}`;

export class TutoresEmMemoria implements TutorRepositorio {
  itens = new Map<string, Tutor>();
  async buscarPorId(id: string) { return this.itens.get(id) ?? null; }
  async existeCpf(cpf: string) { return [...this.itens.values()].some((t) => t.cpf === cpf); }
  async salvar(t: Tutor) { this.itens.set(t.id, t); }
}

export class AnimaisEmMemoria implements AnimalRepositorio {
  itens = new Map<string, Animal>();
  async buscarPorId(id: string) { return this.itens.get(id) ?? null; }
  async criar(a: Omit<Animal, 'id'>) {
    const animal = { id: novoId(), ...a };
    this.itens.set(animal.id, animal);
    return animal;
  }
}

export class ConsultasEmMemoria implements ConsultaRepositorio {
  itens = new Map<string, Consulta>();
  slots = new Set<string>();
  async buscarPorId(id: string) { return this.itens.get(id) ?? null; }
  async listarPorData(data: string) { return [...this.itens.values()].filter((c) => c.data === data); }
  async marcarRealizada(id: string) { this.itens.set(id, { ...this.itens.get(id)!, status: 'realizada' }); }
  async horariosOcupados(data: string) {
    return [...this.itens.values()].filter((c) => c.data === data && c.status === 'agendada').map((c) => c.horario);
  }
  async reservar(c: Omit<Consulta, 'id'>) {
    const slot = idDoHorario(c.data, c.horario);
    if (this.slots.has(slot)) throw new ErroNegocio('HORARIO_INDISPONIVEL', 'ocupado');
    this.slots.add(slot);
    const consulta = { id: novoId(), ...c };
    this.itens.set(consulta.id, consulta);
    return consulta;
  }
  async cancelar(id: string, canceladoPor: string, quando: Date) {
    const c = this.itens.get(id)!;
    this.slots.delete(idDoHorario(c.data, c.horario));
    this.itens.set(id, { ...c, status: 'cancelada', canceladoPor, canceladoEm: quando });
  }
  async remarcar(id: string, data: string, horario: string, inicio: Date) {
    const c = this.itens.get(id)!;
    const novo = idDoHorario(data, horario);
    if (this.slots.has(novo)) throw new ErroNegocio('HORARIO_INDISPONIVEL', 'ocupado');
    this.slots.delete(idDoHorario(c.data, c.horario));
    this.slots.add(novo);
    const atualizada = { ...c, data, horario, inicio };
    this.itens.set(id, atualizada);
    return atualizada;
  }
}

export class RegistrosEmMemoria implements RegistroRepositorio {
  itens = new Map<string, RegistroMedico>();
  async buscarPorId(id: string) { return this.itens.get(id) ?? null; }
  async criar(r: Omit<RegistroMedico, 'id'>) {
    const registro = { id: novoId(), ...r };
    this.itens.set(registro.id, registro);
    return registro;
  }
  async listarPorAnimal(animalId: string) {
    return [...this.itens.values()]
      .filter((r) => r.animalId === animalId)
      .sort((a, b) => a.criadoEm.getTime() - b.criadoEm.getTime());
  }
  ultimoAutor = new Map<string, { id: string; nome: string }>();
  async corrigir(id: string, dados: DadosRegistro, proximaDose: string | null, autor: { id: string; nome: string }, quando: Date) {
    const r = this.itens.get(id)!;
    const quemEscreveu = this.ultimoAutor.get(id) ?? { id: r.autorId, nome: r.autorNome };
    const atualizado: RegistroMedico = {
      ...r,
      dados,
      proximaDose,
      versao: r.versao + 1,
      historico: [...r.historico, { dados: r.dados, autorId: quemEscreveu.id, autorNome: quemEscreveu.nome, alteradoEm: quando }],
    };
    this.ultimoAutor.set(id, autor);
    this.itens.set(id, atualizado);
    return atualizado;
  }
  async listarAtendimentos(inicio: Date, fim: Date) {
    return [...this.itens.values()].filter((r) => r.tipo === 'atendimento' && r.criadoEm >= inicio && r.criadoEm < fim);
  }
}

export class UsuariosEmMemoria implements UsuarioGateway {
  perfis = new Map<string, Perfil>();
  ativos = new Map<string, boolean>();
  emails = new Set<string>();
  async definirPerfil(uid: string, perfil: Perfil) { this.perfis.set(uid, perfil); }
  async criarFuncionario(d: NovoFuncionario) {
    if (this.emails.has(d.email)) throw new ErroNegocio('EMAIL_JA_CADASTRADO', 'existe');
    this.emails.add(d.email);
    const uid = novoId();
    this.perfis.set(uid, d.perfil);
    this.ativos.set(uid, true);
    return uid;
  }
  async definirAtivo(uid: string, ativo: boolean) { this.ativos.set(uid, ativo); }
  async buscarPerfil(uid: string) { return this.perfis.get(uid) ?? null; }
}
