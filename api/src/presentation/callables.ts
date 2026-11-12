// Endpoints chamados pelo app Flutter (camada de Apresentação).
// No app: FirebaseFunctions.instanceFor(region: 'southamerica-east1').httpsCallable('agendarConsulta')
import { getApps, initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { CallableRequest, HttpsError, onCall } from 'firebase-functions/v2/https';
import { AgendamentoServico } from '../application/agendamento-servico';
import { ClinicaServico } from '../application/clinica-servico';
import { GestaoServico } from '../application/gestao-servico';
import { Solicitante } from '../application/portas';
import { ProntuarioServico } from '../application/prontuario-servico';
import { TutorServico } from '../application/tutor-servico';
import { Perfil, TipoRegistro } from '../domain/entidades';
import { ErroNegocio, ErroValidacao } from '../domain/erros';
import {
  COLECOES,
  FirebaseUsuarioGateway,
  FirestoreAnimalRepositorio,
  FirestoreConsultaRepositorio,
  FirestoreRegistroRepositorio,
  FirestoreTutorRepositorio,
} from '../infrastructure/firestore';

export const REGIAO = 'southamerica-east1';

if (!getApps().length) initializeApp();
const db = getFirestore();

const tutores = new FirestoreTutorRepositorio(db);
const animais = new FirestoreAnimalRepositorio(db);
const consultas = new FirestoreConsultaRepositorio(db);
const registros = new FirestoreRegistroRepositorio(db);
const usuarios = new FirebaseUsuarioGateway(db);
const tutorServico = new TutorServico(tutores, animais, usuarios);
const agendamentoServico = new AgendamentoServico(consultas, animais);
const prontuarioServico = new ProntuarioServico(registros, animais, consultas);
const clinicaServico = new ClinicaServico(consultas, animais, tutores, registros);
const gestaoServico = new GestaoServico(usuarios);

const opcoes = { region: REGIAO };

function exigirLogin(req: CallableRequest): { uid: string; email?: string } {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Faça login para continuar.');
  return { uid: req.auth.uid, email: req.auth.token.email };
}

async function solicitante(req: CallableRequest): Promise<Solicitante> {
  const { uid, email } = exigirLogin(req);
  const perfil = req.auth!.token.perfil as Perfil | undefined;
  if (!perfil) throw new HttpsError('permission-denied', 'Cadastro incompleto. Finalize o cadastro do tutor.');
  // Funcionário desativado pelo gestor perde o acesso na hora, mesmo com token ainda válido (RF32).
  if (perfil !== 'tutor') {
    const usuario = await db.collection(COLECOES.usuarios).doc(uid).get();
    if (usuario.get('ativo') === false) throw new HttpsError('permission-denied', 'Usuário desativado.');
  }
  return { uid, email, perfil, nome: req.auth!.token.name as string | undefined };
}

/** Datas viram texto ISO 8601 (o protocolo das callables não serializa Date). */
export function serializar(v: unknown): unknown {
  if (v instanceof Date) return v.toISOString();
  if (Array.isArray(v)) return v.map(serializar);
  if (v && typeof v === 'object') {
    return Object.fromEntries(Object.entries(v).map(([k, x]) => [k, serializar(x)]));
  }
  return v;
}

/** Converte erros de domínio para erros que o app entende. */
async function executar<T>(fn: () => Promise<T>): Promise<unknown> {
  try {
    return serializar(await fn());
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
        EMAIL_JA_CADASTRADO: 'already-exists',
        OPERACAO_INVALIDA: 'failed-precondition',
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
    const animal = await tutorServico.cadastrarAnimal(await solicitante(req), req.data ?? {});
    return { id: animal.id };
  }),
);

/** RF06/RF07 — horários do dia, com os ocupados marcados. */
export const listarHorarios = onCall(opcoes, (req) =>
  executar(async () => {
    await solicitante(req);
    return { horarios: await agendamentoServico.listarHorarios(String(req.data?.data ?? '')) };
  }),
);

/** RF06/RF07 — agenda consulta (transação impede horário duplicado). */
export const agendarConsulta = onCall(opcoes, (req) =>
  executar(async () => {
    const c = await agendamentoServico.agendar(await solicitante(req), req.data ?? {});
    return { id: c.id, animalNome: c.animalNome, data: c.data, horario: c.horario, local: c.local };
  }),
);

/** RF11 — cancela consulta e libera o horário. */
export const cancelarConsulta = onCall(opcoes, (req) =>
  executar(async () => {
    await agendamentoServico.cancelar(await solicitante(req), String(req.data?.consultaId ?? ''));
    return { ok: true };
  }),
);

/** RF10 — remarca consulta (atendente). */
export const remarcarConsulta = onCall(opcoes, (req) =>
  executar(async () => {
    const c = await agendamentoServico.remarcar(await solicitante(req), req.data ?? {});
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

// ---------------------------------------------------------------- Prontuário

function registrar(tipo: TipoRegistro) {
  return onCall(opcoes, (req) =>
    executar(async () => prontuarioServico.registrar(await solicitante(req), tipo, req.data ?? {})),
  );
}

/** RF14 — atendimento (diagnóstico e tratamento). Com consultaId, marca a consulta como realizada. */
export const registrarAtendimento = registrar('atendimento');

/** RF15 — prescrição. Devolve os horários das doses para o app agendar lembretes (RF21). */
export const registrarPrescricao = registrar('prescricao');

/** RF16 — vacina (com data da próxima dose para o lembrete, RF20). */
export const registrarVacina = registrar('vacina');

/** RF26 — procedimento feito pelo auxiliar ou veterinário. */
export const registrarProcedimento = registrar('procedimento');

/** RF13 — histórico médico do animal em ordem cronológica. */
export const historicoDoAnimal = onCall(opcoes, (req) =>
  executar(async () => prontuarioServico.historico(await solicitante(req), String(req.data?.animalId ?? ''))),
);

/** RNF16 — corrige um registro mantendo a versão anterior. Não existe exclusão. */
export const corrigirRegistro = onCall(opcoes, (req) =>
  executar(async () => {
    const { registroId, ...dados } = req.data ?? {};
    return prontuarioServico.corrigir(await solicitante(req), String(registroId ?? ''), dados);
  }),
);

// ---------------------------------------------------------------- Clínica

/** RF08 / RF25 — agenda do dia para a equipe. */
export const agendaDoDia = onCall(opcoes, (req) =>
  executar(async () => ({
    consultas: await clinicaServico.agendaDoDia(
      await solicitante(req),
      String(req.data?.data ?? ''),
      req.data?.incluirCanceladas === true,
    ),
  })),
);

/** RF33 / RF35 — quantidade de atendimentos no período, por veterinário. */
export const relatorioAtendimentos = onCall(opcoes, (req) =>
  executar(async () =>
    clinicaServico.relatorioAtendimentos(
      await solicitante(req),
      String(req.data?.inicio ?? ''),
      String(req.data?.fim ?? ''),
    ),
  ),
);

// ---------------------------------------------------------------- Gestão

/** RF32 — gestor cria login de funcionário com perfil. */
export const criarFuncionario = onCall(opcoes, (req) =>
  executar(async () => gestaoServico.criarFuncionario(await solicitante(req), req.data ?? {})),
);

/** RF32 — gestor ativa ou desativa um funcionário (desativado não consegue logar). */
export const definirStatusFuncionario = onCall(opcoes, (req) =>
  executar(async () => {
    await gestaoServico.definirStatus(await solicitante(req), String(req.data?.uid ?? ''), req.data?.ativo);
    return { ok: true };
  }),
);
