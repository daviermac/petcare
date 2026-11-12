# Contrato da API (Cloud Functions)

## Swagger

A documentação interativa (Swagger UI) é servida pela própria API:

- Emulador: http://127.0.0.1:5001/demo-petcare/southamerica-east1/docs
- Produção: `https://southamerica-east1-<projeto>.cloudfunctions.net/docs`
- Especificação OpenAPI: `/docs/openapi.json` (cópia versionada em `docs/openapi.json`, gerada com `npm run openapi`)

A especificação fica em `api/src/presentation/openapi.ts`. Ao criar ou mudar uma função, atualize esse arquivo e rode `npm run openapi`; o teste `openapi.test.ts` falha se alguma função ficar sem documentação ou se `docs/openapi.json` ficar desatualizado.

**Testar pelo Swagger com os emuladores:** crie um usuário e pegue o token:

```bash
curl -s -X POST 'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=qualquer' \
  -H 'Content-Type: application/json' \
  -d '{"email":"ana@teste.com","password":"Pet@1234","returnSecureToken":true}'
```

Copie o `idToken`, clique em **Authorize** no Swagger e cole. Depois de `registrarTutor`, faça login de novo (`accounts:signInWithPassword`) para o token trazer o perfil `tutor`.

Todas as funções são **Callable Functions** na região `southamerica-east1`. No Flutter:

```dart
final functions = FirebaseFunctions.instanceFor(region: 'southamerica-east1');
final res = await functions.httpsCallable('agendarConsulta').call({
  'animalId': animalId,
  'data': '2026-11-09',
  'horario': '11:00',
});
```

O usuário precisa estar logado (o token do Firebase Auth vai junto automaticamente). Depois de `registrarTutor`, chame `FirebaseAuth.instance.currentUser!.getIdToken(true)` para o app receber o perfil `tutor`.

## Formato dos erros

| `code` | Quando | `details` |
|---|---|---|
| `unauthenticated` | Não logado | — |
| `invalid-argument` | Campo inválido | `{ campos: { cpf: 'CPF inválido.', ... } }` → mostrar cada mensagem abaixo do campo |
| `already-exists` | Horário ocupado ou CPF repetido | `{ codigo: 'HORARIO_INDISPONIVEL' \| 'CPF_JA_CADASTRADO' }` |
| `not-found` | Animal/consulta não existe | `{ codigo }` |
| `permission-denied` | Perfil sem permissão | `{ codigo }` |
| `failed-precondition` | Consulta já cancelada | `{ codigo: 'CONSULTA_NAO_ATIVA' }` |

## Funções

| Função | Perfil | Entrada | Retorno | Requisito |
|---|---|---|---|---|
| `registrarTutor` | logado (sem perfil) | `{ nome, cpf, telefone }` (e-mail vem do Auth) | `{ id, nome }` | RF01 |
| `cadastrarAnimal` | tutor, atendente | `{ nome, especie: 'cachorro'\|'gato'\|'outro', raca, idade, tutorId? }` | `{ id }` | RF04 |
| `listarHorarios` | qualquer perfil | `{ data: 'AAAA-MM-DD' }` | `{ horarios: [{ horario, disponivel }] }` | RF06, RF07 |
| `agendarConsulta` | tutor, atendente | `{ animalId, data, horario }` | `{ id, animalNome, data, horario, local }` | RF06, RF07 |
| `cancelarConsulta` | tutor (dono), atendente, gestor | `{ consultaId }` | `{ ok: true }` | RF11 |
| `remarcarConsulta` | atendente | `{ consultaId, data, horario }` | `{ id, data, horario }` | RF10 |
| `registrarTokenNotificacao` | logado | `{ token }` (FCM) | `{ ok: true }` | RF19 |

### Prontuário

| Função | Perfil | Entrada | Retorno | Requisito |
|---|---|---|---|---|
| `registrarAtendimento` | veterinário | `{ animalId, diagnostico, tratamento, motivo?, observacoes?, consultaId? }` | registro | RF14 |
| `registrarPrescricao` | veterinário | `{ animalId, medicamento, dosagem, frequenciaHoras, duracaoDias, orientacoes? }` | registro + `horariosMedicacao[]` | RF15, RF21 |
| `registrarVacina` | veterinário | `{ animalId, nome, dataAplicacao?, proximaDose?, lote? }` | registro | RF16, RF20 |
| `registrarProcedimento` | auxiliar, veterinário | `{ animalId, descricao, observacoes? }` | registro | RF26 |
| `historicoDoAnimal` | veterinário, tutor dono | `{ animalId }` | `{ animal, registros[] }` (ordem cronológica) | RF13, RF22 |
| `corrigirRegistro` | mesmo perfil que pode registrar | `{ registroId, ...todos os campos do tipo }` | registro com `versao` e `historico` | RNF16 |

- Com `consultaId`, o atendimento marca a consulta como **realizada**.
- `horariosMedicacao` são os horários das doses (ISO 8601). O app agenda lembretes locais com `flutter_local_notifications` (RF21). Ex.: 8 em 8 h por 3 dias = 9 horários.
- Registros **nunca são excluídos**. A correção guarda a versão anterior com autor e data (RNF16).

### Clínica e gestão

| Função | Perfil | Entrada | Retorno | Requisito |
|---|---|---|---|---|
| `agendaDoDia` | atendente, veterinário, auxiliar, gestor | `{ data, incluirCanceladas? }` | `{ consultas: [{ consultaId, horario, status, animal, tutorNome, local }] }` | RF08, RF25 |
| `relatorioAtendimentos` | gestor | `{ inicio, fim }` | `{ total, porVeterinario[] }` | RF33, RF35 |
| `criarFuncionario` | gestor | `{ nome, email, senha, perfil }` | `{ uid, perfil }` | RF32 |
| `definirStatusFuncionario` | gestor | `{ uid, ativo }` | `{ ok: true }` | RF32 |

- Funcionário desativado não consegue logar (`USER_DISABLED`) e perde o acesso à API na hora.
- **Primeiro gestor:** como só gestor cria funcionário, o primeiro precisa receber o perfil manualmente. No emulador, use a aba Authentication da interface (http://localhost:4000) → editar usuário → *Custom claims* `{"perfil":"gestor"}`. Em produção, rode uma vez um script com o Admin SDK (`setCustomUserClaims(uid, { perfil: 'gestor' })`).

### Funções agendadas

- `lembretesDeConsulta`: a cada 30 min, push para consultas nas próximas 24 h (RF19).
- `lembretesDeVacina`: todo dia às 9h, push para vacinas com próxima dose daqui a 7 dias (RF20).

## Leituras direto no Firestore

Listas simples o app lê direto (com `snapshots()` dá atualização em tempo real e cache offline, RNF13). As regras em `firestore.rules` garantem que cada tutor só vê o que é dele.

```dart
// Meus animais (Tela 02/03)
db.collection('animais').where('tutorId', isEqualTo: uid);
// Minhas consultas (Tela 04)
db.collection('consultas').where('tutorId', isEqualTo: uid).orderBy('inicio');
```

## Modelo de dados

| Coleção | Campos |
|---|---|
| `usuarios/{uid}` | `perfil`, `ativo`, `fcmTokens[]` |
| `tutores/{uid}` | `nome`, `cpf`, `telefone`, `email`, `criadoEm` |
| `animais/{id}` | `tutorId`, `nome`, `especie`, `raca`, `idade`, `criadoEm` |
| `consultas/{id}` | `tutorId`, `animalId`, `animalNome`, `data`, `horario`, `inicio`, `local`, `status`, `lembreteEnviado`, `criadoEm`, `canceladoEm?`, `canceladoPor?` |
| `horariosOcupados/{AAAA-MM-DD_HHmm}` | `data`, `horario`, `consultaId` (trava do horário) |
| `registrosMedicos/{id}` | `tipo` (atendimento, prescricao, vacina, procedimento), `animalId`, `tutorId`, `autorId`, `autorNome`, `autorPerfil`, `dados`, `proximaDose`, `criadoEm`, `versao`, `historico[]` |

`consultas.status` agora pode ser `agendada`, `cancelada` ou `realizada`.

**Relação com o diagrama de classes:** `Usuario` = `usuarios` + `tutores` (dados do tutor), `Pet` = `animais`, `Consulta` = `consultas`. Os registros médicos ficam em `registrosMedicos`, ligados ao animal.

Grade de horários (igual ao protótipo): 08:00, 09:30, 11:00, 14:00, 15:30, de segunda a sexta, até 60 dias à frente.
