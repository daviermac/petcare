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
    descricao: 'Necessário para receber os lembretes de consulta e de vacina.',
    tag: 'Notificações',
    entrada: { type: 'object', required: ['token'], properties: { token: { type: 'string' } } },
    saida: ref('Ok'),
    erros: ['400', '401'],
  },
  registrarAtendimento: {
    resumo: 'Registra atendimento: diagnóstico e tratamento (RF14)',
    descricao:
      'Somente veterinário. Com consultaId, a consulta passa para "realizada". O registro guarda autor e data e não pode ser excluído (RNF16).',
    tag: 'Prontuário',
    entrada: {
      type: 'object',
      required: ['animalId', 'diagnostico', 'tratamento'],
      properties: {
        animalId: { type: 'string' },
        consultaId: { type: 'string', description: 'Opcional: consulta atendida' },
        motivo: { type: 'string', example: 'Coceira na orelha' },
        diagnostico: { type: 'string', example: 'Otite externa' },
        tratamento: { type: 'string', example: 'Limpeza e gotas otológicas por 7 dias' },
        observacoes: { type: 'string' },
      },
    },
    saida: ref('RegistroMedico'),
    erros: ['400', '401', '403', '404'],
  },
  registrarPrescricao: {
    resumo: 'Registra prescrição de medicamento (RF15, RF21)',
    descricao:
      'Somente veterinário. A resposta traz horariosMedicacao (ISO 8601) para o app agendar lembretes locais com flutter_local_notifications. Fica visível para o tutor no histórico (RF22).',
    tag: 'Prontuário',
    entrada: {
      type: 'object',
      required: ['animalId', 'medicamento', 'dosagem', 'frequenciaHoras', 'duracaoDias'],
      properties: {
        animalId: { type: 'string' },
        medicamento: { type: 'string', example: 'Amoxicilina 250 mg' },
        dosagem: { type: 'string', example: '1 comprimido' },
        frequenciaHoras: { type: 'integer', minimum: 1, maximum: 168, example: 8 },
        duracaoDias: { type: 'integer', minimum: 1, maximum: 365, example: 3 },
        orientacoes: { type: 'string', example: 'Dar junto com a comida' },
      },
    },
    saida: {
      allOf: [
        ref('RegistroMedico'),
        {
          type: 'object',
          properties: { horariosMedicacao: { type: 'array', items: { type: 'string', format: 'date-time' } } },
        },
      ],
    },
    erros: ['400', '401', '403', '404'],
  },
  registrarVacina: {
    resumo: 'Registra vacina aplicada (RF16)',
    descricao: 'Somente veterinário. Com proximaDose, o tutor recebe lembrete 7 dias antes (RF20).',
    tag: 'Prontuário',
    entrada: {
      type: 'object',
      required: ['animalId', 'nome'],
      properties: {
        animalId: { type: 'string' },
        nome: { type: 'string', example: 'V10' },
        dataAplicacao: { ...data, description: 'AAAA-MM-DD (padrão: hoje)', example: '2026-11-11' },
        proximaDose: { ...data, example: '2027-11-11' },
        lote: { type: 'string', example: 'L2026-118' },
      },
    },
    saida: ref('RegistroMedico'),
    erros: ['400', '401', '403', '404'],
  },
  registrarProcedimento: {
    resumo: 'Registra procedimento realizado (RF26)',
    descricao: 'Auxiliar ou veterinário. Aparece no histórico do animal com o nome de quem fez e o horário.',
    tag: 'Prontuário',
    entrada: {
      type: 'object',
      required: ['animalId', 'descricao'],
      properties: {
        animalId: { type: 'string' },
        descricao: { type: 'string', example: 'Curativo na pata traseira' },
        observacoes: { type: 'string', example: 'Manter em jejum até 18h' },
      },
    },
    saida: ref('RegistroMedico'),
    erros: ['400', '401', '403', '404'],
  },
  historicoDoAnimal: {
    resumo: 'Histórico médico do animal em ordem cronológica (RF13)',
    descricao: 'Veterinário ou tutor dono do animal. O tutor não recebe o histórico de correções.',
    tag: 'Prontuário',
    entrada: { type: 'object', required: ['animalId'], properties: { animalId: { type: 'string' } } },
    saida: {
      type: 'object',
      properties: {
        animal: {
          type: 'object',
          properties: {
            id: { type: 'string' },
            nome: { type: 'string', example: 'Thor' },
            especie: { type: 'string', example: 'cachorro' },
            raca: { type: 'string' },
            idade: { type: 'integer' },
          },
        },
        registros: { type: 'array', items: ref('RegistroMedico') },
      },
    },
    erros: ['401', '403', '404'],
  },
  corrigirRegistro: {
    resumo: 'Corrige um registro do prontuário mantendo a versão anterior (RNF16)',
    descricao:
      'Envie registroId e TODOS os campos do tipo do registro (como no cadastro). A versão anterior vai para "historico" com autor e data. Não existe exclusão.',
    tag: 'Prontuário',
    entrada: {
      type: 'object',
      required: ['registroId'],
      properties: {
        registroId: { type: 'string' },
        diagnostico: { type: 'string', example: 'Otite externa bilateral' },
        tratamento: { type: 'string', example: 'Gotas por 10 dias' },
      },
      additionalProperties: true,
    },
    saida: ref('RegistroMedico'),
    erros: ['400', '401', '403', '404'],
  },
  agendaDoDia: {
    resumo: 'Agenda da clínica no dia, em ordem de horário (RF08, RF25)',
    descricao:
      'Atendente, veterinário, auxiliar ou gestor. Traz só dados básicos (animal, espécie, nome do tutor), sem CPF, telefone ou valores.',
    tag: 'Clínica',
    entrada: {
      type: 'object',
      required: ['data'],
      properties: { data, incluirCanceladas: { type: 'boolean', default: false } },
    },
    saida: { type: 'object', properties: { consultas: { type: 'array', items: ref('ItemAgenda') } } },
    erros: ['400', '401', '403'],
  },
  relatorioAtendimentos: {
    resumo: 'Quantidade de atendimentos no período, por veterinário (RF33, RF35)',
    descricao: 'Somente gestor. Período inclusivo, no horário de São Paulo.',
    tag: 'Clínica',
    entrada: {
      type: 'object',
      required: ['inicio', 'fim'],
      properties: { inicio: { ...data, example: '2026-11-01' }, fim: { ...data, example: '2026-11-30' } },
    },
    saida: {
      type: 'object',
      properties: {
        inicio: { type: 'string' },
        fim: { type: 'string' },
        total: { type: 'integer', example: 5 },
        porVeterinario: {
          type: 'array',
          items: {
            type: 'object',
            properties: {
              veterinarioId: { type: 'string' },
              nome: { type: 'string', example: 'Dra. Paula Reis' },
              total: { type: 'integer', example: 3 },
            },
          },
        },
      },
    },
    erros: ['400', '401', '403'],
  },
  criarFuncionario: {
    resumo: 'Cria login de funcionário (RF32)',
    descricao: 'Somente gestor. O funcionário entra com o e-mail e a senha temporária e já recebe o perfil.',
    tag: 'Gestão',
    entrada: {
      type: 'object',
      required: ['nome', 'email', 'senha', 'perfil'],
      properties: {
        nome: { type: 'string', example: 'Carla Mendes' },
        email: { type: 'string', example: 'carla@petconnect.com' },
        senha: { type: 'string', minLength: 8, example: 'Temp@2026' },
        perfil: { type: 'string', enum: ['atendente', 'veterinario', 'auxiliar', 'gestor'] },
      },
    },
    saida: { type: 'object', properties: { uid: { type: 'string' }, perfil: { type: 'string' } } },
    erros: ['400', '401', '403', '409'],
  },
  definirStatusFuncionario: {
    resumo: 'Ativa ou desativa um funcionário (RF32)',
    descricao: 'Somente gestor. Desativado não consegue fazer login e perde o acesso à API na hora.',
    tag: 'Gestão',
    entrada: {
      type: 'object',
      required: ['uid', 'ativo'],
      properties: { uid: { type: 'string' }, ativo: { type: 'boolean', example: false } },
    },
    saida: ref('Ok'),
    erros: ['400', '401', '403', '404'],
  },
};

const RESPOSTAS_ERRO: Record<string, { descricao: string; status: string }> = {
  '400': {
    descricao:
      'Dados inválidos (details.campos tem uma mensagem por campo), consulta que não está mais agendada ou operação não permitida',
    status: 'INVALID_ARGUMENT / FAILED_PRECONDITION',
  },
  '401': { descricao: 'Não logado (token ausente ou inválido)', status: 'UNAUTHENTICATED' },
  '403': { descricao: 'Perfil sem permissão', status: 'PERMISSION_DENIED' },
  '404': { descricao: 'Animal ou consulta não encontrado', status: 'NOT_FOUND' },
  '409': { descricao: 'Horário ocupado, CPF ou e-mail já cadastrado', status: 'ALREADY_EXISTS' },
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
      version: '0.2.0',
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
      { name: 'Prontuário', description: 'Histórico médico, atendimentos, prescrições, vacinas e procedimentos' },
      { name: 'Clínica', description: 'Agenda do dia e relatórios' },
      { name: 'Gestão', description: 'Usuários e funcionários' },
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
        RegistroMedico: {
          type: 'object',
          properties: {
            id: { type: 'string' },
            tipo: { type: 'string', enum: ['atendimento', 'prescricao', 'vacina', 'procedimento'] },
            animalId: { type: 'string' },
            tutorId: { type: 'string' },
            autorId: { type: 'string' },
            autorNome: { type: 'string', example: 'Dra. Paula Reis' },
            autorPerfil: { type: 'string', example: 'veterinario' },
            dados: { type: 'object', description: 'Campos do tipo (os mesmos enviados no registro)' },
            proximaDose: { type: 'string', nullable: true },
            criadoEm: { type: 'string', format: 'date-time' },
            versao: { type: 'integer', example: 1 },
            historico: {
              type: 'array',
              description: 'Versões anteriores (RNF16)',
              items: {
                type: 'object',
                properties: {
                  dados: { type: 'object' },
                  autorId: { type: 'string' },
                  autorNome: { type: 'string' },
                  alteradoEm: { type: 'string', format: 'date-time' },
                },
              },
            },
          },
        },
        ItemAgenda: {
          type: 'object',
          properties: {
            consultaId: { type: 'string' },
            horario,
            status: { type: 'string', enum: ['agendada', 'realizada', 'cancelada'] },
            animal: {
              type: 'object',
              properties: {
                id: { type: 'string' },
                nome: { type: 'string', example: 'Thor' },
                especie: { type: 'string', example: 'cachorro' },
              },
            },
            tutorNome: { type: 'string', example: 'Ana Souza' },
            local: { type: 'string', example: 'Hospital PetConnect' },
          },
        },
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
