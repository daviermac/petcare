// Funções agendadas (RT08): lembretes de consulta (RF19) e de vacina (RF20).
import { getFirestore } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { dataEmSaoPaulo, somarDias } from '../domain/agenda';
import { COLECOES } from '../infrastructure/firestore';
import { REGIAO } from './callables';

const HORA = 60 * 60 * 1000;

/** Antecedência do lembrete de vacina, em dias. */
export const DIAS_ANTES_VACINA = 7;

const formatar = (data: string) => data.split('-').reverse().join('/');

/** Envia push para todos os aparelhos do usuário. Retorna quantos receberam. */
async function enviarPush(uid: string, titulo: string, corpo: string, dados: Record<string, string>): Promise<number> {
  const usuario = await getFirestore().collection(COLECOES.usuarios).doc(uid).get();
  const tokens: string[] = usuario.get('fcmTokens') ?? [];
  if (!tokens.length) return 0;
  const r = await getMessaging().sendEachForMulticast({ tokens, notification: { title: titulo, body: corpo }, data: dados });
  return r.successCount;
}

export const lembretesDeConsulta = onSchedule(
  { schedule: 'every 30 minutes', timeZone: 'America/Sao_Paulo', region: REGIAO },
  async () => {
    const db = getFirestore();
    const agora = Date.now();
    const q = await db
      .collection(COLECOES.consultas)
      .where('status', '==', 'agendada')
      .where('inicio', '>=', new Date(agora))
      .where('inicio', '<=', new Date(agora + 24 * HORA))
      .get();

    for (const doc of q.docs) {
      const c = doc.data();
      if (c.lembreteEnviado) continue;
      await enviarPush(
        c.tutorId,
        'Lembrete de consulta',
        `${c.animalNome} tem consulta em ${formatar(c.data)} às ${c.horario} no ${c.local}.`,
        { tipo: 'consulta', consultaId: doc.id },
      );
      await doc.ref.update({ lembreteEnviado: true });
    }
  },
);

/** Todo dia às 9h avisa o tutor das vacinas com próxima dose daqui a 7 dias (RF20). */
export const lembretesDeVacina = onSchedule(
  { schedule: 'every day 09:00', timeZone: 'America/Sao_Paulo', region: REGIAO },
  async () => {
    const db = getFirestore();
    const alvo = somarDias(dataEmSaoPaulo(new Date()), DIAS_ANTES_VACINA);
    const q = await db
      .collection(COLECOES.registrosMedicos)
      .where('tipo', '==', 'vacina')
      .where('proximaDose', '==', alvo)
      .get();

    for (const doc of q.docs) {
      const r = doc.data();
      if (r.lembreteVacinaEnviado) continue;
      const animal = await db.collection(COLECOES.animais).doc(r.animalId).get();
      await enviarPush(
        r.tutorId,
        'Lembrete de vacina',
        `A próxima dose da vacina ${r.dados?.nome} de ${animal.get('nome') ?? 'seu pet'} é em ${formatar(alvo)}.`,
        { tipo: 'vacina', registroId: doc.id, animalId: r.animalId },
      );
      await doc.ref.update({ lembreteVacinaEnviado: true });
    }
  },
);
