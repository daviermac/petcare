// Implementações dos repositórios usando o Firestore (camada de Persistência).
import { getAuth } from 'firebase-admin/auth';
import { DocumentSnapshot, FieldValue, Firestore, Timestamp } from 'firebase-admin/firestore';
import {
  AnimalRepositorio,
  ConsultaRepositorio,
  NovoFuncionario,
  RegistroRepositorio,
  TutorRepositorio,
  UsuarioGateway,
} from '../application/portas';
import { idDoHorario } from '../domain/agenda';
import { Animal, Consulta, DadosRegistro, Perfil, RegistroMedico, Tutor } from '../domain/entidades';
import { ErroNegocio } from '../domain/erros';

export const COLECOES = {
  usuarios: 'usuarios',
  tutores: 'tutores',
  animais: 'animais',
  consultas: 'consultas',
  horariosOcupados: 'horariosOcupados',
  registrosMedicos: 'registrosMedicos',
} as const;

/** Converte Timestamps do Firestore em Date (inclusive dentro de listas e objetos). */
function converter(v: unknown): unknown {
  if (v instanceof Timestamp) return v.toDate();
  if (Array.isArray(v)) return v.map(converter);
  if (v && typeof v === 'object' && !(v instanceof Date)) {
    return Object.fromEntries(Object.entries(v).map(([k, x]) => [k, converter(x)]));
  }
  return v;
}

function comDatas<T>(snap: DocumentSnapshot): T {
  return { id: snap.id, ...(converter(snap.data()) as object) } as T;
}

function semId<T extends { id: string }>(obj: T): Omit<T, 'id'> {
  const { id: _id, ...resto } = obj;
  return resto;
}

export class FirestoreTutorRepositorio implements TutorRepositorio {
  constructor(private readonly db: Firestore) {}

  async buscarPorId(id: string): Promise<Tutor | null> {
    const snap = await this.db.collection(COLECOES.tutores).doc(id).get();
    return snap.exists ? comDatas<Tutor>(snap) : null;
  }

  async existeCpf(cpf: string): Promise<boolean> {
    const q = await this.db.collection(COLECOES.tutores).where('cpf', '==', cpf).limit(1).get();
    return !q.empty;
  }

  async salvar(tutor: Tutor): Promise<void> {
    await this.db.collection(COLECOES.tutores).doc(tutor.id).set(semId(tutor));
  }
}

export class FirestoreAnimalRepositorio implements AnimalRepositorio {
  constructor(private readonly db: Firestore) {}

  async buscarPorId(id: string): Promise<Animal | null> {
    const snap = await this.db.collection(COLECOES.animais).doc(id).get();
    return snap.exists ? comDatas<Animal>(snap) : null;
  }

  async criar(animal: Omit<Animal, 'id'>): Promise<Animal> {
    const ref = await this.db.collection(COLECOES.animais).add(animal);
    return { id: ref.id, ...animal };
  }
}

export class FirestoreConsultaRepositorio implements ConsultaRepositorio {
  constructor(private readonly db: Firestore) {}

  private get consultas() {
    return this.db.collection(COLECOES.consultas);
  }
  private slot(data: string, horario: string) {
    return this.db.collection(COLECOES.horariosOcupados).doc(idDoHorario(data, horario));
  }

  async buscarPorId(id: string): Promise<Consulta | null> {
    const snap = await this.consultas.doc(id).get();
    return snap.exists ? comDatas<Consulta>(snap) : null;
  }

  async listarPorData(data: string): Promise<Consulta[]> {
    const q = await this.consultas.where('data', '==', data).get();
    return q.docs.map((d) => comDatas<Consulta>(d));
  }

  async marcarRealizada(id: string): Promise<void> {
    await this.consultas.doc(id).update({ status: 'realizada', realizadaEm: FieldValue.serverTimestamp() });
  }

  async horariosOcupados(data: string): Promise<string[]> {
    const q = await this.db.collection(COLECOES.horariosOcupados).where('data', '==', data).get();
    return q.docs.map((d) => d.get('horario') as string);
  }

  async reservar(consulta: Omit<Consulta, 'id'>): Promise<Consulta> {
    const ref = this.consultas.doc();
    const slotRef = this.slot(consulta.data, consulta.horario);
    // Transação: se dois celulares confirmarem o mesmo horário, só um vence (RF07).
    await this.db.runTransaction(async (tx) => {
      const slot = await tx.get(slotRef);
      if (slot.exists) {
        throw new ErroNegocio('HORARIO_INDISPONIVEL', 'Esse horário acabou de ser reservado. Escolha outro.');
      }
      tx.create(slotRef, { data: consulta.data, horario: consulta.horario, consultaId: ref.id });
      tx.create(ref, consulta);
    });
    return { id: ref.id, ...consulta };
  }

  async cancelar(id: string, canceladoPor: string, quando: Date): Promise<void> {
    const ref = this.consultas.doc(id);
    await this.db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists || snap.get('status') !== 'agendada') {
        throw new ErroNegocio('CONSULTA_NAO_ATIVA', 'Esta consulta não está mais agendada.');
      }
      tx.update(ref, { status: 'cancelada', canceladoPor, canceladoEm: quando });
      tx.delete(this.slot(snap.get('data'), snap.get('horario')));
    });
  }

  async remarcar(id: string, data: string, horario: string, inicio: Date): Promise<Consulta> {
    const ref = this.consultas.doc(id);
    const novoSlot = this.slot(data, horario);
    await this.db.runTransaction(async (tx) => {
      const [snap, slot] = await Promise.all([tx.get(ref), tx.get(novoSlot)]);
      if (!snap.exists || snap.get('status') !== 'agendada') {
        throw new ErroNegocio('CONSULTA_NAO_ATIVA', 'Esta consulta não está mais agendada.');
      }
      if (slot.exists) {
        throw new ErroNegocio('HORARIO_INDISPONIVEL', 'Esse horário já está ocupado.');
      }
      tx.delete(this.slot(snap.get('data'), snap.get('horario')));
      tx.create(novoSlot, { data, horario, consultaId: id });
      tx.update(ref, { data, horario, inicio, lembreteEnviado: false });
    });
    return (await this.buscarPorId(id))!;
  }
}

export class FirestoreRegistroRepositorio implements RegistroRepositorio {
  constructor(private readonly db: Firestore) {}

  private get registros() {
    return this.db.collection(COLECOES.registrosMedicos);
  }

  async buscarPorId(id: string): Promise<RegistroMedico | null> {
    const snap = await this.registros.doc(id).get();
    return snap.exists ? comDatas<RegistroMedico>(snap) : null;
  }

  async criar(registro: Omit<RegistroMedico, 'id'>): Promise<RegistroMedico> {
    const ref = await this.registros.add(registro);
    return { id: ref.id, ...registro };
  }

  async listarPorAnimal(animalId: string): Promise<RegistroMedico[]> {
    const q = await this.registros.where('animalId', '==', animalId).orderBy('criadoEm', 'asc').get();
    return q.docs.map((d) => comDatas<RegistroMedico>(d));
  }

  async corrigir(
    id: string,
    dados: DadosRegistro,
    proximaDose: string | null,
    autor: { id: string; nome: string },
    quando: Date,
  ): Promise<RegistroMedico> {
    const ref = this.registros.doc(id);
    await this.db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) throw new ErroNegocio('NAO_ENCONTRADO', 'Registro não encontrado.');
      const atual = snap.data()!;
      tx.update(ref, {
        dados,
        proximaDose,
        lembreteVacinaEnviado: false,
        versao: (atual.versao ?? 1) + 1,
        // A versão anterior fica guardada com quem a escreveu e quando foi substituída.
        historico: FieldValue.arrayUnion({
          dados: atual.dados,
          autorId: atual.ultimoAutorId ?? atual.autorId,
          autorNome: atual.ultimoAutorNome ?? atual.autorNome,
          alteradoEm: quando,
        }),
        ultimoAutorId: autor.id,
        ultimoAutorNome: autor.nome,
        atualizadoEm: quando,
      });
    });
    return (await this.buscarPorId(id))!;
  }

  async listarAtendimentos(inicio: Date, fim: Date): Promise<RegistroMedico[]> {
    const q = await this.registros
      .where('tipo', '==', 'atendimento')
      .where('criadoEm', '>=', inicio)
      .where('criadoEm', '<', fim)
      .get();
    return q.docs.map((d) => comDatas<RegistroMedico>(d));
  }
}

export class FirebaseUsuarioGateway implements UsuarioGateway {
  constructor(private readonly db: Firestore) {}

  async criarFuncionario(dados: NovoFuncionario): Promise<string> {
    let uid: string;
    try {
      const user = await getAuth().createUser({
        email: dados.email,
        password: dados.senha,
        displayName: dados.nome,
      });
      uid = user.uid;
    } catch (e) {
      if ((e as { code?: string }).code === 'auth/email-already-exists') {
        throw new ErroNegocio('EMAIL_JA_CADASTRADO', 'Já existe um usuário com este e-mail.');
      }
      throw e;
    }
    await getAuth().setCustomUserClaims(uid, { perfil: dados.perfil });
    await this.db.collection(COLECOES.usuarios).doc(uid).set({
      nome: dados.nome,
      email: dados.email,
      perfil: dados.perfil,
      ativo: true,
      criadoEm: FieldValue.serverTimestamp(),
    });
    return uid;
  }

  async definirAtivo(uid: string, ativo: boolean): Promise<void> {
    await getAuth().updateUser(uid, { disabled: !ativo });
    // Derruba as sessões abertas: o app precisa logar de novo.
    if (!ativo) await getAuth().revokeRefreshTokens(uid);
    await this.db
      .collection(COLECOES.usuarios)
      .doc(uid)
      .set({ ativo, atualizadoEm: FieldValue.serverTimestamp() }, { merge: true });
  }

  async buscarPerfil(uid: string): Promise<Perfil | null> {
    const snap = await this.db.collection(COLECOES.usuarios).doc(uid).get();
    return snap.exists ? ((snap.get('perfil') as Perfil) ?? null) : null;
  }

  async definirPerfil(uid: string, perfil: Perfil): Promise<void> {
    await getAuth().setCustomUserClaims(uid, { perfil });
    await this.db
      .collection(COLECOES.usuarios)
      .doc(uid)
      .set({ perfil, ativo: true, atualizadoEm: FieldValue.serverTimestamp() }, { merge: true });
  }
}
