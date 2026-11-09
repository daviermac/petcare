// Implementações dos repositórios usando o Firestore (camada de Persistência).
import { getAuth } from 'firebase-admin/auth';
import { DocumentSnapshot, FieldValue, Firestore, Timestamp } from 'firebase-admin/firestore';
import {
  AnimalRepositorio,
  ConsultaRepositorio,
  TutorRepositorio,
  UsuarioGateway,
} from '../application/portas';
import { idDoHorario } from '../domain/agenda';
import { Animal, Consulta, Perfil, Tutor } from '../domain/entidades';
import { ErroNegocio } from '../domain/erros';

export const COLECOES = {
  usuarios: 'usuarios',
  tutores: 'tutores',
  animais: 'animais',
  consultas: 'consultas',
  horariosOcupados: 'horariosOcupados',
} as const;

/** Converte Timestamps do Firestore em Date. */
function comDatas<T>(snap: DocumentSnapshot): T {
  const dados: Record<string, unknown> = { id: snap.id, ...snap.data() };
  for (const [k, v] of Object.entries(dados)) if (v instanceof Timestamp) dados[k] = v.toDate();
  return dados as T;
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

export class FirebaseUsuarioGateway implements UsuarioGateway {
  constructor(private readonly db: Firestore) {}

  async definirPerfil(uid: string, perfil: Perfil): Promise<void> {
    await getAuth().setCustomUserClaims(uid, { perfil });
    await this.db
      .collection(COLECOES.usuarios)
      .doc(uid)
      .set({ perfil, ativo: true, atualizadoEm: FieldValue.serverTimestamp() }, { merge: true });
  }
}
