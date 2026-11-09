// Funções agendadas (RT08): lembretes de consulta 24 h antes (RF19).
import { getFirestore } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { COLECOES } from '../infrastructure/firestore';
import { REGIAO } from './callables';

const HORA = 60 * 60 * 1000;

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
      const usuario = await db.collection(COLECOES.usuarios).doc(c.tutorId).get();
      const tokens: string[] = usuario.get('fcmTokens') ?? [];
      if (tokens.length) {
        const [ano, mes, dia] = String(c.data).split('-');
        await getMessaging().sendEachForMulticast({
          tokens,
          notification: {
            title: 'Lembrete de consulta',
            body: `${c.animalNome} tem consulta em ${dia}/${mes}/${ano} às ${c.horario} no ${c.local}.`,
          },
          data: { consultaId: doc.id },
        });
      }
      await doc.ref.update({ lembreteEnviado: true });
    }
  },
);
