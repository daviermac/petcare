// Lembretes de consulta (RF19) e de vacina (RF20).
//
// Cada lembrete é gravado em `notificacoes` (o app mostra a lista e pode exibir uma
// notificação local) e, fora do emulador, também enviado por push (FCM).
// Como o emulador não roda funções agendadas sozinho, `dispararLembretes` permite
// disparar na hora durante a apresentação.
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { onRequest } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { dataEmSaoPaulo, somarDias } from '../domain/agenda';
import { COLECOES } from '../infrastructure/firestore';
import { REGIAO } from './callables';

const HORA = 60 * 60 * 1000;

/** Antecedência padrão do lembrete de vacina, em dias. */
export const DIAS_ANTES_VACINA = 7;

const noEmulador = () => process.env.FUNCTIONS_EMULATOR === 'true';
const formatar = (data: string) => data.split('-').reverse().join('/');

export interface Notificacao {
  tutorId: string;
  tipo: 'consulta' | 'vacina';
  titulo: string;
  corpo: string;
  dados: Record<string, string>;
}

/** Grava a notificação para o tutor e, fora do emulador, envia push para os aparelhos dele. */
async function notificar(n: Notificacao): Promise<void> {
  const db = getFirestore();
  await db.collection(COLECOES.notificacoes).add({ ...n, lida: false, criadoEm: FieldValue.serverTimestamp() });
  if (noEmulador()) return; // o emulador não envia push de verdade
  const usuario = await db.collection(COLECOES.usuarios).doc(n.tutorId).get();
  const tokens: string[] = usuario.get('fcmTokens') ?? [];
  if (!tokens.length) return;
  try {
    await getMessaging().sendEachForMulticast({
      tokens,
      notification: { title: n.titulo, body: n.corpo },
      data: { tipo: n.tipo, ...n.dados },
    });
  } catch (e) {
    console.error('Falha ao enviar push', e);
  }
}

/** Consultas agendadas que começam dentro da janela e ainda não foram lembradas. */
export async function processarLembretesConsulta(janelaHoras = 24): Promise<Notificacao[]> {
  const db = getFirestore();
  const agora = Date.now();
  const q = await db
    .collection(COLECOES.consultas)
    .where('status', '==', 'agendada')
    .where('inicio', '>=', new Date(agora))
    .where('inicio', '<=', new Date(agora + janelaHoras * HORA))
    .get();

  const enviadas: Notificacao[] = [];
  for (const doc of q.docs) {
    const c = doc.data();
    if (c.lembreteEnviado) continue;
    const n: Notificacao = {
      tutorId: c.tutorId,
      tipo: 'consulta',
      titulo: 'Lembrete de consulta',
      corpo: `${c.animalNome} tem consulta em ${formatar(c.data)} às ${c.horario} no ${c.local}.`,
      dados: { consultaId: doc.id },
    };
    await notificar(n);
    await doc.ref.update({ lembreteEnviado: true });
    enviadas.push(n);
  }
  return enviadas;
}

/** Vacinas cuja próxima dose é daqui a `diasAntes` dias e ainda não foram lembradas. */
export async function processarLembretesVacina(diasAntes = DIAS_ANTES_VACINA): Promise<Notificacao[]> {
  const db = getFirestore();
  const alvo = somarDias(dataEmSaoPaulo(new Date()), diasAntes);
  const q = await db
    .collection(COLECOES.registrosMedicos)
    .where('tipo', '==', 'vacina')
    .where('proximaDose', '==', alvo)
    .get();

  const enviadas: Notificacao[] = [];
  for (const doc of q.docs) {
    const r = doc.data();
    if (r.lembreteVacinaEnviado) continue;
    const animal = await db.collection(COLECOES.animais).doc(r.animalId).get();
    const n: Notificacao = {
      tutorId: r.tutorId,
      tipo: 'vacina',
      titulo: 'Lembrete de vacina',
      corpo: `A próxima dose da vacina ${r.dados?.nome} de ${animal.get('nome') ?? 'seu pet'} é em ${formatar(alvo)}.`,
      dados: { registroId: doc.id, animalId: r.animalId },
    };
    await notificar(n);
    await doc.ref.update({ lembreteVacinaEnviado: true });
    enviadas.push(n);
  }
  return enviadas;
}

export const lembretesDeConsulta = onSchedule(
  { schedule: 'every 30 minutes', timeZone: 'America/Sao_Paulo', region: REGIAO },
  async () => {
    await processarLembretesConsulta();
  },
);

/** Todo dia às 9h avisa o tutor das vacinas com próxima dose daqui a 7 dias (RF20). */
export const lembretesDeVacina = onSchedule(
  { schedule: 'every day 09:00', timeZone: 'America/Sao_Paulo', region: REGIAO },
  async () => {
    await processarLembretesVacina();
  },
);

/**
 * Só no emulador: dispara os lembretes na hora (para a apresentação).
 * GET /dispararLembretes?janelaHoras=24&diasVacina=7
 */
export const dispararLembretes = onRequest({ region: REGIAO }, async (req, res) => {
  if (!noEmulador()) {
    res.status(404).send('Não encontrado');
    return;
  }
  const janelaHoras = Number(req.query.janelaHoras ?? 24);
  const diasVacina = Number(req.query.diasVacina ?? DIAS_ANTES_VACINA);
  const consultas = await processarLembretesConsulta(janelaHoras > 0 ? janelaHoras : 24);
  const vacinas = await processarLembretesVacina(diasVacina >= 0 ? diasVacina : DIAS_ANTES_VACINA);
  res.json({ enviadas: consultas.length + vacinas.length, consultas, vacinas });
});
