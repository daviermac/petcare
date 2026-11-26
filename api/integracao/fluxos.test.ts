// Testes de integração (RT11): chamam a API de verdade nos emuladores do Firebase,
// passando pelo Auth, pelas Callable Functions e pelas regras do Firestore.
//
// Pré-requisitos (pasta api/):
//   Terminal 1: npm run emuladores
//   Terminal 2: npm run seed && npm run test:integracao
import { dataEmSaoPaulo } from '../src/domain/agenda';

const PROJETO = 'demo-petcare';
const HOST = process.env.EMULADOR_HOST ?? '127.0.0.1';
const AUTH = `http://${HOST}:9099/identitytoolkit.googleapis.com/v1`;
const FUNCOES = `http://${HOST}:5001/${PROJETO}/southamerica-east1`;
const FIRESTORE = `http://${HOST}:8080/v1/projects/${PROJETO}/databases/(default)/documents`;
const SENHA = 'Pet@1234';

jest.setTimeout(60_000);

interface Sessao {
  token: string;
  uid: string;
}

async function entrar(email: string, senha = SENHA): Promise<Sessao> {
  const r = await fetch(`${AUTH}/accounts:signInWithPassword?key=demo`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password: senha, returnSecureToken: true }),
  });
  const corpo = (await r.json()) as { idToken?: string; localId?: string; error?: { message: string } };
  if (!corpo.idToken) throw new Error(`Login falhou para ${email}: ${corpo.error?.message}`);
  return { token: corpo.idToken, uid: corpo.localId! };
}

/** Chama uma Callable Function. Devolve { result } ou { error }. */
async function chamar(
  s: Sessao,
  funcao: string,
  data: unknown,
): Promise<{ result?: any; error?: { status: string; message: string; details?: any } }> {
  const r = await fetch(`${FUNCOES}/${funcao}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${s.token}` },
    body: JSON.stringify({ data }),
  });
  return (await r.json()) as any;
}

async function ok(s: Sessao, funcao: string, data: unknown): Promise<any> {
  const r = await chamar(s, funcao, data);
  if (r.error) throw new Error(`${funcao}: ${r.error.status} ${r.error.message}`);
  return r.result;
}

/** Grava o checklist do auxiliar direto no Firestore, como o app faz (RF24). */
async function gravarChecklist(s: Sessao, data: string, campos: Record<string, unknown>): Promise<number> {
  const r = await fetch(`${FIRESTORE}:commit`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${s.token}` },
    body: JSON.stringify({
      writes: [
        {
          update: { name: `projects/${PROJETO}/databases/(default)/documents/tarefasDia/${data}`, fields: campos },
          updateTransforms: [{ fieldPath: 'atualizadoEm', setToServerValue: 'REQUEST_TIME' }],
        },
      ],
    }),
  });
  return r.status;
}

async function lerDocumento(s: Sessao, caminho: string): Promise<number> {
  const r = await fetch(`${FIRESTORE}/${caminho}`, { headers: { Authorization: `Bearer ${s.token}` } });
  return r.status;
}

const hoje = dataEmSaoPaulo(new Date());
const inicioMes = `${hoje.slice(0, 8)}01`;

let vet: Sessao;
let atendente: Sessao;
let gestor: Sessao;
let auxiliar: Sessao;
let ana: Sessao;
let bruno: Sessao;
let thorId: string;

beforeAll(async () => {
  try {
    [vet, atendente, gestor, auxiliar, ana, bruno] = await Promise.all(
      [
        'vet@petconnect.dev',
        'atendente@petconnect.dev',
        'gestor@petconnect.dev',
        'auxiliar@petconnect.dev',
        'ana@email.dev',
        'bruno@email.dev',
      ].map((e) => entrar(e)),
    );
  } catch (e) {
    throw new Error(`Emuladores ou dados de exemplo indisponíveis. Rode "npm run emuladores" e "npm run seed". (${e})`);
  }
  const agenda = await ok(vet, 'agendaDoDia', { data: hoje, incluirCanceladas: true });
  // Pega o Thor pelo histórico de alguma consulta ou pela leitura dos animais da Ana.
  const r = await fetch(`${FIRESTORE}:runQuery`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${ana.token}` },
    body: JSON.stringify({
      structuredQuery: {
        from: [{ collectionId: 'animais' }],
        where: { fieldFilter: { field: { fieldPath: 'tutorId' }, op: 'EQUAL', value: { stringValue: ana.uid } } },
      },
    }),
  });
  const docs = (await r.json()) as { document?: { name: string; fields: any } }[];
  const thor = docs.find((d) => d.document?.fields?.nome?.stringValue === 'Thor');
  thorId = thor!.document!.name.split('/').pop()!;
  expect(Array.isArray(agenda.consultas)).toBe(true);
});

describe('Faturamento ponta a ponta (RF14, RF30)', () => {
  let faturaId: string;

  it('atendimento do veterinário gera cobrança com o valor informado', async () => {
    const r = await ok(vet, 'registrarAtendimento', {
      animalId: thorId,
      motivo: 'Teste de integração',
      diagnostico: 'Sem alterações',
      tratamento: 'Nenhum',
      valor: 99.9,
    });
    expect(r.tipo).toBe('atendimento');
    expect(r.valorCentavos).toBe(9990);
    faturaId = r.faturaId;
  });

  it('valor inválido é recusado antes de gravar o atendimento', async () => {
    const r = await chamar(vet, 'registrarAtendimento', {
      animalId: thorId,
      diagnostico: 'X',
      tratamento: 'Y',
      valor: -5,
    });
    expect(r.error?.status).toBe('INVALID_ARGUMENT');
    expect(r.error?.details?.campos?.valor).toBeDefined();
  });

  it('atendente vê a cobrança pendente e registra o pagamento uma vez só', async () => {
    const pendentes = await ok(atendente, 'listarFaturas', { inicio: hoje, fim: hoje, status: 'pendente' });
    expect(pendentes.faturas.map((f: any) => f.id)).toContain(faturaId);

    const paga = await ok(atendente, 'registrarPagamento', { faturaId, formaPagamento: 'cartao_debito' });
    expect(paga.status).toBe('paga');

    const repetido = await chamar(gestor, 'registrarPagamento', { faturaId, formaPagamento: 'pix' });
    expect(repetido.error?.status).toBe('FAILED_PRECONDITION');
    expect(repetido.error?.details?.codigo).toBe('FATURA_JA_PAGA');
  });

  it('veterinário não registra pagamento nem vê relatório financeiro', async () => {
    expect((await chamar(vet, 'registrarPagamento', { faturaId, formaPagamento: 'pix' })).error?.status).toBe(
      'PERMISSION_DENIED',
    );
    expect((await chamar(atendente, 'relatorioFinanceiro', { inicio: inicioMes, fim: hoje })).error?.status).toBe(
      'PERMISSION_DENIED',
    );
  });

  it('tutor dono lê a própria cobrança; outro tutor não (regras)', async () => {
    expect(await lerDocumento(ana, `faturas/${faturaId}`)).toBe(200);
    expect(await lerDocumento(bruno, `faturas/${faturaId}`)).toBe(403);
  });
});

describe('Relatórios do gestor (RF31, RF33)', () => {
  it('relatório financeiro soma o que foi recebido no cartão de débito', async () => {
    const r = await ok(gestor, 'relatorioFinanceiro', { inicio: inicioMes, fim: hoje });
    expect(r.faturadoCentavos).toBeGreaterThanOrEqual(9990);
    expect(r.recebidoCentavos + r.pendenteCentavos).toBe(r.faturadoCentavos);
    const debito = r.porFormaPagamento.find((x: any) => x.formaPagamento === 'cartao_debito');
    expect(debito.totalCentavos).toBeGreaterThanOrEqual(9990);
  });

  it('relatório de atendimentos conta por veterinário', async () => {
    const r = await ok(gestor, 'relatorioAtendimentos', { inicio: inicioMes, fim: hoje });
    expect(r.total).toBeGreaterThanOrEqual(1);
    expect(r.porVeterinario.some((v: any) => v.nome === 'Paula Reis')).toBe(true);
  });
});

describe('Prescrição com horários dos lembretes (RF15, RF21)', () => {
  it('devolve um horário por dose', async () => {
    const r = await ok(vet, 'registrarPrescricao', {
      animalId: thorId,
      medicamento: 'Amoxicilina 250 mg',
      dosagem: '1 comprimido',
      frequenciaHoras: 8,
      duracaoDias: 2,
    });
    expect(r.horariosMedicacao).toHaveLength(6);
    expect(new Date(r.horariosMedicacao[1]).getTime() - new Date(r.horariosMedicacao[0]).getTime()).toBe(8 * 3600_000);
  });
});

describe('Checklist do auxiliar (RF24, regras do Firestore)', () => {
  const campos = (uid: string) => ({
    concluidas: { arrayValue: { values: [{ stringValue: 'conferir_materiais' }] } },
    atualizadoPor: { stringValue: uid },
  });

  it('auxiliar grava e lê o checklist do dia', async () => {
    expect(await gravarChecklist(auxiliar, hoje, campos(auxiliar.uid))).toBe(200);
    expect(await lerDocumento(auxiliar, `tarefasDia/${hoje}`)).toBe(200);
    expect(await lerDocumento(gestor, `tarefasDia/${hoje}`)).toBe(200);
  });

  it('outros perfis, campos extras ou outro autor são bloqueados', async () => {
    expect(await gravarChecklist(atendente, hoje, campos(atendente.uid))).toBe(403);
    expect(await gravarChecklist(auxiliar, hoje, { ...campos(auxiliar.uid), extra: { stringValue: 'x' } })).toBe(403);
    expect(await gravarChecklist(auxiliar, hoje, campos('outro-uid'))).toBe(403);
    expect(await gravarChecklist(auxiliar, 'amanha', campos(auxiliar.uid))).toBe(403);
    expect(await lerDocumento(ana, `tarefasDia/${hoje}`)).toBe(403);
  });
});

describe('Gestão de funcionários (RF32)', () => {
  it('gestor cria funcionário, que entra; depois de desativado, não entra mais', async () => {
    const email = `temp${Date.now()}@petconnect.dev`;
    const criado = await ok(gestor, 'criarFuncionario', {
      nome: 'Teste Integração',
      email,
      senha: 'Temp@2026',
      perfil: 'auxiliar',
    });
    const sessao = await entrar(email, 'Temp@2026');
    expect(sessao.uid).toBe(criado.uid);

    await ok(gestor, 'definirStatusFuncionario', { uid: criado.uid, ativo: false });
    await expect(entrar(email, 'Temp@2026')).rejects.toThrow(/USER_DISABLED/);
    // Token antigo também perde o acesso à API na hora.
    expect((await chamar(sessao, 'agendaDoDia', { data: hoje })).error?.status).toBe('PERMISSION_DENIED');
  });
});
