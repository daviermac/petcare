// Repositórios em memória para testar os serviços sem Firestore.
import { AnimalRepositorio, ConsultaRepositorio, TutorRepositorio, UsuarioGateway } from '../src/application/portas';
import { idDoHorario } from '../src/domain/agenda';
import { Animal, Consulta, Perfil, Tutor } from '../src/domain/entidades';
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

export class UsuariosEmMemoria implements UsuarioGateway {
  perfis = new Map<string, Perfil>();
  async definirPerfil(uid: string, perfil: Perfil) { this.perfis.set(uid, perfil); }
}
