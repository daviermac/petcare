// Especificação OpenAPI (Swagger) das Callable Functions.
// Protocolo das callables: POST /{funcao} com corpo { "data": {...} } e resposta { "result": {...} }.
// Ao criar ou alterar uma função em callables.ts, atualize este arquivo (o teste openapi.test.ts confere).

type Schema = Record<string, unknown>;

const ref = (nome: string): Schema => ({ $ref: `#/components/schemas/${nome}` });

const data = { type: 'string', pattern: '^\\d{4}-\\d{2}-\\d{2}$', example: '2026-11-09', description: 'AAAA-MM-DD' };
const horario = { type: 'string', enum: ['08:00', '09:30', '11:00', '14:00', '15:30'], example: '11:00' };

interface Operacao {
  resumo: string;
  descricao: string;
  tag: string;
  entrada: Schema;
  saida: Schema;
  erros: string[];
}

const OPERACOES: Record<string, Operacao> = {
  registrarTutor: {
    resumo: 'Completa o cadastro do tutor (RF01)',
    descricao:
      'Chamar logo após criar a conta no Firebase Auth. O e-mail vem do token. Define o perfil "tutor"; ' +
      'depois o app deve renovar o token (getIdToken(true)).',
    tag: 'Tutor',
    entrada: {
      type: 'object',
      required: ['nome', 'cpf', 'telefone'],
      properties: {
        nome: { type: 'string', example: 'Ana Souza' },
        cpf: { type: 'string', example: '52998224725', description: 'Com ou sem máscara' },
        telefone: { type: 'string', example: '12991021830', description: 'DDD + número' },
      },
    },
    saida: { type: 'object', properties: { id: { type: 'string' }, nome: { type: 'string' } } },
    erros: ['400', '401', '409'],
  },
  cadastrarAnimal: {
    resumo: 'Cadastra um animal (RF04)',
    descricao: 'Tutor cadastra para si. Atendente informa o tutorId.',
    tag: 'Tutor',
    entrada: {
      type: 'object',
      required: ['nome', 'especie', 'idade'],
      properties: {
        nome: { type: 'string', example: 'Apolo' },
        especie: { type: 'string', enum: ['cachorro', 'gato', 'outro'], example: 'gato' },
        raca: { type: 'string', example: 'sem raça definida' },
        idade: { type: 'integer', minimum: 0, maximum: 40, example: 6 },
        tutorId: { type: 'string', description: 'Obrigatório só para atendente' },
      },
    },
    saida: { type: 'object', properties: { id: { type: 'string' } } },
    erros: ['400', '401', '403', '404'],
  },
  listarHorarios: {
    resumo: 'Horários do dia com os ocupados marcados (RF06, RF07)',
    descricao: 'Horários com disponivel=false aparecem riscados na Tela 03.',
    tag: 'Agendamento',
    entrada: { type: 'object', required: ['data'], properties: { data } },
    saida: {
      type: 'object',
      properties: {
        horarios: {
          type: 'array',
          items: { type: 'object', properties: { horario, disponivel: { type: 'boolean' } } },
        },
      },
    },
    erros: ['401', '403'],
  },
  agendarConsulta: {
    resumo: 'Agenda uma consulta (RF06, RF07)',
    descricao: 'Usa transação: se dois usuários confirmarem o mesmo horário, só um consegue (409 para o outro).',
    tag: 'Agendamento',
    entrada: {
      type: 'object',
      required: ['animalId', 'data', 'horario'],
      properties: { animalId: { type: 'string' }, data, horario },
    },
    saida: ref('Consulta'),
    erros: ['400', '401', '403', '404', '409'],
  },
  cancelarConsulta: {
    resumo: 'Cancela uma consulta e libera o horário (RF11)',
    descricao: 'Permitido ao tutor dono, atendente e gestor.',
    tag: 'Agendamento',
    entrada: { type: 'object', required: ['consultaId'], properties: { consultaId: { type: 'string' } } },
    saida: ref('Ok'),
    erros: ['400', '401', '403', '404'],
  },
  remarcarConsulta: {
    resumo: 'Remarca uma consulta (RF10)',
    descricao: 'Somente atendente. Libera o horário antigo e ocupa o novo.',
    tag: 'Agendamento',
    entrada: {
      type: 'object',
      required: ['consultaId', 'data', 'horario'],
      properties: { consultaId: { type: 'string' }, data, horario },
    },
    saida: {
      type: 'object',
      properties: { id: { type: 'string' }, data: { type: 'string' }, horario: { type: 'string' } },
    },
    erros: ['400', '401', '403', '404', '409'],
  },
  registrarTokenNotificacao: {
    resumo: 'Registra o token FCM do aparelho (RF19)',
    descricao: 'Necessário para receber os lembretes de consulta.',
    tag: 'Notificações',
    entrada: { type: 'object', required: ['token'], properties: { token: { type: 'string' } } },
    saida: ref('Ok'),
    erros: ['400', '401'],
  },
};

const RESPOSTAS_ERRO: Record<string, { descricao: string; status: string }> = {
  '400': {
    descricao:
      'Dados inválidos (details.campos tem uma mensagem por campo) ou consulta que não está mais agendada',
    status: 'INVALID_ARGUMENT / FAILED_PRECONDITION',
  },
  '401': { descricao: 'Não logado (token ausente ou inválido)', status: 'UNAUTHENTICATED' },
  '403': { descricao: 'Perfil sem permissão', status: 'PERMISSION_DENIED' },
  '404': { descricao: 'Animal ou consulta não encontrado', status: 'NOT_FOUND' },
  '409': { descricao: 'Horário ocupado ou CPF já cadastrado', status: 'ALREADY_EXISTS' },
};

export const NOMES_OPERACOES = Object.keys(OPERACOES);

export function gerarOpenApi(servidores: { url: string; description: string }[]): Schema {
  const paths: Schema = {};
  for (const [nome, op] of Object.entries(OPERACOES)) {
    const respostas: Schema = {
      '200': {
        description: 'Sucesso',
        content: {
          'application/json': {
            schema: { type: 'object', required: ['result'], properties: { result: op.saida } },
          },
        },
      },
    };
    for (const codigo of op.erros) {
      respostas[codigo] = {
        description: `${RESPOSTAS_ERRO[codigo].descricao} (${RESPOSTAS_ERRO[codigo].status})`,
        content: { 'application/json': { schema: ref('Erro') } },
      };
    }
    paths[`/${nome}`] = {
      post: {
        operationId: nome,
        summary: op.resumo,
        description: op.descricao,
        tags: [op.tag],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: { type: 'object', required: ['data'], properties: { data: op.entrada } },
            },
          },
        },
        responses: respostas,
      },
    };
  }

  return {
    openapi: '3.0.3',
    info: {
      title: 'Pet Care API',
      version: '0.1.0',
      description:
        'API do Pet Care (PetConnect) em Firebase Callable Functions.\n\n' +
        'Todas as chamadas são `POST` com o corpo `{ "data": { ... } }` e respondem `{ "result": { ... } }`. ' +
        'No Flutter use `FirebaseFunctions.instanceFor(region: "southamerica-east1").httpsCallable(nome)`, ' +
        'que faz isso automaticamente.\n\n' +
        'Para testar aqui: clique em **Authorize** e cole um ID token do Firebase Auth (veja `docs/api.md`).',
    },
    servers: servidores,
    security: [{ firebaseIdToken: [] }],
    tags: [
      { name: 'Tutor', description: 'Cadastro de tutores e animais' },
      { name: 'Agendamento', description: 'Consultas e horários' },
      { name: 'Notificações', description: 'Push e lembretes' },
    ],
    paths,
    components: {
      securitySchemes: {
        firebaseIdToken: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT',
          description: 'ID token do Firebase Auth do usuário logado',
        },
      },
      schemas: {
        Consulta: {
          type: 'object',
          properties: {
            id: { type: 'string' },
            animalNome: { type: 'string', example: 'Thor' },
            data,
            horario,
            local: { type: 'string', example: 'Hospital PetConnect' },
          },
        },
        Ok: { type: 'object', properties: { ok: { type: 'boolean', example: true } } },
        Erro: {
          type: 'object',
          properties: {
            error: {
              type: 'object',
              properties: {
                status: { type: 'string', example: 'INVALID_ARGUMENT' },
                message: { type: 'string', example: 'Dados inválidos' },
                details: {
                  type: 'object',
                  properties: {
                    campos: {
                      type: 'object',
                      additionalProperties: { type: 'string' },
                      example: { cpf: 'CPF inválido.' },
                    },
                    codigo: { type: 'string', example: 'HORARIO_INDISPONIVEL' },
                  },
                },
              },
            },
          },
        },
      },
    },
  };
}
