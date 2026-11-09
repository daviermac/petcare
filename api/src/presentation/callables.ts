// Endpoints chamados pelo app Flutter (camada de Apresentação).
// No app: FirebaseFunctions.instanceFor(region: 'southamerica-east1').httpsCallable('agendarConsulta')
import { getApps, initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { CallableRequest, HttpsError, onCall } from 'firebase-functions/v2/https';
import { AgendamentoServico } from '../application/agendamento-servico';
import { Solicitante } from '../application/portas';
import { TutorServico } from '../application/tutor-servico';
import { Perfil } from '../domain/entidades';
import { ErroNegocio, ErroValidacao } from '../domain/erros';
import {
  COLECOES,
  FirebaseUsuarioGateway,
  FirestoreAnimalRepositorio,
  FirestoreConsultaRepositorio,
  FirestoreTutorRepositorio,
} from '../infrastructure/firestore';

export const REGIAO = 'southamerica-east1';

if (!getApps().length) initializeApp();
const db = getFirestore();

const tutores = new FirestoreTutorRepositorio(db);
const animais = new FirestoreAnimalRepositorio(db);
const consultas = new FirestoreConsultaRepositorio(db);
const tutorServico = new TutorServico(tutores, animais, new FirebaseUsuarioGateway(db));
const agendamentoServico = new AgendamentoServico(consultas, animais);

const opcoes = { region: REGIAO };

function exigirLogin(req: CallableRequest): { uid: string; email?: string } {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Faça login para continuar.');
  return { uid: req.auth.uid, email: req.auth.token.email };
}

function solicitante(req: CallableRequest): Solicitante {
  const { uid, email } = exigirLogin(req);
  const perfil = req.auth!.token.perfil as Perfil | undefined;
  if (!perfil) throw new HttpsError('permission-denied', 'Cadastro incompleto. Finalize o cadastro do tutor.');
  return { uid, email, perfil };
}

/** Converte erros de domínio para erros que o app entende. */
async function executar<T>(fn: () => Promise<T>): Promise<T> {
  try {
    return await fn();
  } catch (e) {
    if (e instanceof ErroValidacao) {
      throw new HttpsError('invalid-argument', e.message, { campos: e.campos });
    }
    if (e instanceof ErroNegocio) {
      const mapa = {
        HORARIO_INDISPONIVEL: 'already-exists',
        CPF_JA_CADASTRADO: 'already-exists',
        NAO_ENCONTRADO: 'not-found',
        SEM_PERMISSAO: 'permission-denied',
        CONSULTA_NAO_ATIVA: 'failed-precondition',
      } as const;
      throw new HttpsError(mapa[e.codigo], e.message, { codigo: e.codigo });
    }
    if (e instanceof HttpsError) throw e;
    console.error(e);
    throw new HttpsError('internal', 'Erro inesperado. Tente novamente.');
  }
}

/** RF01 — completa o cadastro do tutor após o createUserWithEmailAndPassword no app. */
export const registrarTutor = onCall(opcoes, (req) =>
  executar(async () => {
    const { uid, email } = exigirLogin(req);
    const tutor = await tutorServico.registrar(uid, { ...req.data, email: email ?? req.data?.email });
    return { id: tutor.id, nome: tutor.nome };
  }),
);

/** RF04 — cadastra animal. */
export const cadastrarAnimal = onCall(opcoes, (req) =>
  executar(async () => {
    const animal = await tutorServico.cadastrarAnimal(solicitante(req), req.data ?? {});
    return { id: animal.id };
  }),
);

/** RF06/RF07 — horários do dia, com os ocupados marcados. */
export const listarHorarios = onCall(opcoes, (req) =>
  executar(async () => {
    solicitante(req);
    return { horarios: await agendamentoServico.listarHorarios(String(req.data?.data ?? '')) };
  }),
);

/** RF06/RF07 — agenda consulta (transação impede horário duplicado). */
export const agendarConsulta = onCall(opcoes, (req) =>
  executar(async () => {
    const c = await agendamentoServico.agendar(solicitante(req), req.data ?? {});
    return { id: c.id, animalNome: c.animalNome, data: c.data, horario: c.horario, local: c.local };
  }),
);

/** RF11 — cancela consulta e libera o horário. */
export const cancelarConsulta = onCall(opcoes, (req) =>
  executar(async () => {
    await agendamentoServico.cancelar(solicitante(req), String(req.data?.consultaId ?? ''));
    return { ok: true };
  }),
);

/** RF10 — remarca consulta (atendente). */
export const remarcarConsulta = onCall(opcoes, (req) =>
  executar(async () => {
    const c = await agendamentoServico.remarcar(solicitante(req), req.data ?? {});
    return { id: c.id, data: c.data, horario: c.horario };
  }),
);

/** RF19 — o app registra o token FCM do aparelho para receber lembretes. */
export const registrarTokenNotificacao = onCall(opcoes, (req) =>
  executar(async () => {
    const { uid } = exigirLogin(req);
    const token = String(req.data?.token ?? '');
    if (!token) throw new ErroValidacao({ token: 'Token ausente.' });
    await db
      .collection(COLECOES.usuarios)
      .doc(uid)
      .set({ fcmTokens: FieldValue.arrayUnion(token) }, { merge: true });
    return { ok: true };
  }),
);
