// Cria os dados de exemplo da apresentação nos emuladores.
// Uso: com os emuladores rodando, em outro terminal: npm run seed   (na pasta api/)
// ATENÇÃO: apaga tudo o que estiver nos emuladores antes de criar.

// Aponta o Admin SDK para os emuladores (precisa vir antes de qualquer uso do Firebase).
const PROJETO = 'demo-petcare';
process.env.GCLOUD_PROJECT = PROJETO;
process.env.METADATA_SERVER_DETECTION ??= 'none'; // evita procurar credenciais do Google Cloud
process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST ??= '127.0.0.1:9099';

import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { AgendamentoServico } from '../application/agendamento-servico';
import { Solicitante } from '../application/portas';
import { ProntuarioServico } from '../application/prontuario-servico';
import { TutorServico } from '../application/tutor-servico';
import { dataEmSaoPaulo, LOCAL_PADRAO, paraInstante, somarDias } from '../domain/agenda';
import { Perfil } from '../domain/entidades';
import {
  FirebaseUsuarioGateway,
  FirestoreAnimalRepositorio,
  FirestoreConsultaRepositorio,
  FirestoreRegistroRepositorio,
  FirestoreTutorRepositorio,
} from '../infrastructure/firestore';

export const SENHA_PADRAO = 'Pet@1234';

const EQUIPE: { nome: string; email: string; perfil: Perfil }[] = [
  { nome: 'Marina Costa', email: 'gestor@petconnect.dev', perfil: 'gestor' },
  { nome: 'Paula Reis', email: 'vet@petconnect.dev', perfil: 'veterinario' },
  { nome: 'Caio Lima', email: 'vet2@petconnect.dev', perfil: 'veterinario' },
  { nome: 'Carla Mendes', email: 'atendente@petconnect.dev', perfil: 'atendente' },
  { nome: 'Rafael Souza', email: 'auxiliar@petconnect.dev', perfil: 'auxiliar' },
];

const TUTORES = [
  { nome: 'Ana Souza', email: 'ana@email.dev', cpf: '52998224725', telefone: '12991021830' },
  { nome: 'Bruno Lima', email: 'bruno@email.dev', cpf: '11144477735', telefone: '11988887777' },
];

/** Próximo dia útil (seg–sex) a partir de `data`, contando `pular` dias úteis. */
function diaUtil(data: string, pular: number): string {
  let d = data;
  let contados = 0;
  while (contados < Math.abs(pular)) {
    d = somarDias(d, pular > 0 ? 1 : -1);
    const semana = paraInstante(d, '12:00').getUTCDay();
    if (semana >= 1 && semana <= 5) contados++;
  }
  return d;
}

async function emuladoresNoAr(): Promise<boolean> {
  try {
    await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/`);
    await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/`);
    return true;
  } catch {
    return false;
  }
}

async function limpar(): Promise<void> {
  await fetch(
    `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROJETO}/databases/(default)/documents`,
    { method: 'DELETE' },
  );
  await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/emulator/v1/projects/${PROJETO}/accounts`, {
    method: 'DELETE',
  });
}

async function main(): Promise<void> {
  if (!(await emuladoresNoAr())) {
    console.error('Não encontrei os emuladores. Inicie com "npm run emuladores" e rode o seed em outro terminal.');
    process.exit(1);
  }
  console.log('Limpando os dados dos emuladores...');
  await limpar();

  initializeApp({ projectId: PROJETO });
  const db = getFirestore();
  const usuarios = new FirebaseUsuarioGateway(db);
  const tutores = new FirestoreTutorRepositorio(db);
  const animais = new FirestoreAnimalRepositorio(db);
  const consultas = new FirestoreConsultaRepositorio(db);
  const registros = new FirestoreRegistroRepositorio(db);
  const tutorServico = new TutorServico(tutores, animais, usuarios);
  const agenda = new AgendamentoServico(consultas, animais);
  const prontuario = new ProntuarioServico(registros, animais, consultas);

  // Equipe
  const equipe: Record<string, Solicitante> = {};
  for (const f of EQUIPE) {
    const uid = await usuarios.criarFuncionario({ ...f, senha: SENHA_PADRAO });
    equipe[f.email] = { uid, perfil: f.perfil, nome: f.nome, email: f.email };
  }
  const vet = equipe['vet@petconnect.dev'];
  const vet2 = equipe['vet2@petconnect.dev'];
  const aux = equipe['auxiliar@petconnect.dev'];

  // Tutores (mesmo fluxo do app: conta no Auth + registrarTutor)
  const tut: Solicitante[] = [];
  for (const t of TUTORES) {
    const user = await getAuth().createUser({ email: t.email, password: SENHA_PADRAO, displayName: t.nome });
    await tutorServico.registrar(user.uid, t);
    tut.push({ uid: user.uid, perfil: 'tutor', nome: t.nome, email: t.email });
  }
  const [ana, bruno] = tut;

  // Animais
  const thor = await tutorServico.cadastrarAnimal(ana, { nome: 'Thor', especie: 'cachorro', raca: 'Labrador', idade: 3 });
  const mia = await tutorServico.cadastrarAnimal(ana, { nome: 'Mia', especie: 'gato', raca: 'Siamês', idade: 2 });
  const apolo = await tutorServico.cadastrarAnimal(bruno, { nome: 'Apolo', especie: 'gato', raca: '', idade: 6 });

  // Consulta passada, já atendida (vai para o histórico e para o relatório)
  const hoje = dataEmSaoPaulo(new Date());
  const passada = diaUtil(hoje, -3);
  const consultaPassada = await consultas.reservar({
    tutorId: ana.uid, animalId: thor.id, animalNome: thor.nome, data: passada, horario: '09:30',
    inicio: paraInstante(passada, '09:30'), local: LOCAL_PADRAO, status: 'agendada',
    lembreteEnviado: true, criadoEm: new Date(),
  });
  const atendimento = await prontuario.registrar(vet, 'atendimento', {
    animalId: thor.id, consultaId: consultaPassada.id, motivo: 'Coceira na orelha',
    diagnostico: 'Otite', tratamento: 'Limpeza e gotas otológicas por 7 dias',
  });
  // Correção para mostrar o histórico de versões (RNF16)
  await prontuario.corrigir(vet, atendimento.id, {
    motivo: 'Coceira na orelha', diagnostico: 'Otite externa bilateral',
    tratamento: 'Limpeza e gotas otológicas por 7 dias', observacoes: 'Retorno em 10 dias',
  });
  await prontuario.registrar(vet, 'prescricao', {
    animalId: thor.id, medicamento: 'Otomax (gotas)', dosagem: '4 gotas em cada orelha',
    frequenciaHoras: 12, duracaoDias: 7, orientacoes: 'Limpar a orelha antes de aplicar.',
  });
  // Próxima dose daqui a 7 dias: aparece no disparo de lembretes de vacina
  await prontuario.registrar(vet, 'vacina', { animalId: thor.id, nome: 'V10', proximaDose: somarDias(hoje, 7), lote: 'L2026-118' });
  await prontuario.registrar(aux, 'procedimento', { animalId: thor.id, descricao: 'Banho e tosa', observacoes: 'Pele sem lesões.' });
  await prontuario.registrar(vet2, 'vacina', { animalId: mia.id, nome: 'Antirrábica', proximaDose: somarDias(hoje, 365) });
  await prontuario.registrar(vet2, 'atendimento', { animalId: apolo.id, diagnostico: 'Check-up sem alterações', tratamento: 'Nenhum' });

  // Consultas futuras
  const d1 = diaUtil(hoje, 1);
  const d2 = diaUtil(hoje, 2);
  await agenda.agendar(ana, { animalId: thor.id, data: d1, horario: '09:30' });
  await agenda.agendar(bruno, { animalId: apolo.id, data: d1, horario: '11:00' });
  await agenda.agendar(ana, { animalId: mia.id, data: d2, horario: '14:00' });

  console.log('\nDados de exemplo criados. Contas (senha de todas: ' + SENHA_PADRAO + '):\n');
  console.table([
    ...EQUIPE.map((f) => ({ perfil: f.perfil, nome: f.nome, email: f.email })),
    ...TUTORES.map((t) => ({ perfil: 'tutor', nome: t.nome, email: t.email })),
  ]);
  console.log(`Animais: Thor e Mia (Ana), Apolo (Bruno). Consultas em ${d1} e ${d2}; uma já realizada em ${passada}.`);
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
