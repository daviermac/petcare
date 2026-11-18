# Pet Care (PetConnect)

Aplicativo mobile (Android e iOS) para agendamento de consultas e acompanhamento de animais do Hospital Veterinário PetConnect. Projeto da faculdade, feito em grupo.

## Stack

| Parte | Tecnologia |
|---|---|
| App (`/app`) | Flutter 3.x (Dart) |
| API / backend (`/api`) | Firebase Cloud Functions (Node.js 22 + TypeScript) |
| Autenticação | Firebase Authentication (e-mail e senha) |
| Banco de dados | Cloud Firestore |
| Arquivos | Firebase Storage (PDF, JPG, PNG até 10 MB) |
| Notificações | Firebase Cloud Messaging |

## Arquitetura

Monólito organizado em camadas (ver `docs/arquitetura.md`). No backend:

```
api/src/
├── domain/          # Entidades (Tutor, Animal, Consulta), regras puras e validações
├── application/     # Serviços / casos de uso (agendar, cancelar, remarcar...)
├── infrastructure/  # Acesso ao Firestore (repositórios)
└── presentation/    # Endpoints chamados pelo app (Callable Functions)
```

O app Flutter chama a API com o pacote `cloud_functions` (`FirebaseFunctions.instance.httpsCallable('agendarConsulta')`). Leituras simples (listar animais, listar consultas) podem ir direto no Firestore, protegidas pelas regras em `firestore.rules`. Escritas com regra de negócio (agendamento, cancelamento) passam obrigatoriamente pela API.

## Estrutura do repositório

```
petcare/
├── api/               # Backend (responsável: Davi)
├── app/               # App Flutter (responsáveis: resto do grupo)
├── docs/              # Requisitos, arquitetura e contrato da API
├── firestore.rules    # Regras de segurança do Firestore
├── storage.rules      # Regras de segurança do Storage
└── firebase.json      # Configuração do Firebase e dos emuladores
```

## Como rodar (tudo local, com os emuladores do Firebase)

O projeto não tem ambiente de produção: a apresentação roda nos emuladores do Firebase (projeto `demo-petcare`), sem precisar de conta, cartão ou projeto no console.

**Pré-requisitos (uma vez):** Node.js 22, Java 11 ou mais novo (o emulador do Firestore usa Java) e a Firebase CLI:

```bash
npm install -g firebase-tools
cd api
npm install
```

**Terminal 1 — subir os emuladores com a API:**

```bash
cd api
npm run emuladores
```

**Terminal 2 — criar os dados de exemplo** (contas, animais, consultas e prontuário):

```bash
cd api
npm run seed
```

O `seed` **apaga tudo** e recria os dados, então serve também para "resetar" antes da apresentação. As contas criadas (senha `Pet@1234`) estão em `app/README.md`.

| O quê | Endereço |
|---|---|
| Interface dos emuladores (dados, usuários, logs) | http://localhost:4000 |
| Swagger da API (funciona sem internet) | http://localhost:5001/demo-petcare/southamerica-east1/docs |
| Disparar lembretes na hora (demo) | http://localhost:5001/demo-petcare/southamerica-east1/dispararLembretes |

- Ao fechar os emuladores com **Ctrl+C**, os dados são salvos na pasta `.emulador/` e voltam na próxima execução. Se algo der errado, rode `npm run seed` de novo.
- **Celular físico:** os emuladores aceitam conexões da rede. Rode o app com o IP do notebook (`--dart-define=EMULADOR_HOST=192.168.x.x`). Na primeira vez, o Windows pergunta se libera o Java e o Node no firewall: permita em rede privada.
- Testes da API: `cd api && npm test`.

## Fluxo de trabalho com Git

- `main` sempre estável; ninguém faz push direto nela.
- Crie uma branch por tarefa: `feat/api-agendamento`, `feat/app-tela-cadastro`, `fix/...`.
- Abra um Pull Request e peça revisão de pelo menos 1 colega.
- Mensagens de commit no formato `tipo: descrição` (`feat`, `fix`, `docs`, `test`, `refactor`).

## Contrato da API

Ver `docs/api.md` e o Swagger (`/docs`). A especificação OpenAPI também está em `docs/openapi.json` — dá para abrir no https://editor.swagger.io ou importar no Postman/Insomnia.
