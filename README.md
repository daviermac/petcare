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

## Como rodar a API localmente

Pré-requisitos: Node.js 22, Java 11+ (para os emuladores) e Firebase CLI (`npm i -g firebase-tools`).

```bash
cd api
npm install
npm test            # testes unitários
cd ..
firebase emulators:start   # Auth, Firestore, Functions e Storage locais
```

A interface dos emuladores fica em http://localhost:4000 e o **Swagger da API** em http://127.0.0.1:5001/demo-petcare/southamerica-east1/docs.

## Fluxo de trabalho com Git

- `main` sempre estável; ninguém faz push direto nela.
- Crie uma branch por tarefa: `feat/api-agendamento`, `feat/app-tela-cadastro`, `fix/...`.
- Abra um Pull Request e peça revisão de pelo menos 1 colega.
- Mensagens de commit no formato `tipo: descrição` (`feat`, `fix`, `docs`, `test`, `refactor`).

## Contrato da API

Ver `docs/api.md` e o Swagger (`/docs`). A especificação OpenAPI também está em `docs/openapi.json` — dá para abrir no https://editor.swagger.io ou importar no Postman/Insomnia.
