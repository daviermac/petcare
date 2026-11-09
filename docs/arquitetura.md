# Arquitetura

**Monólito organizado em camadas**, conforme o estudo de caso da disciplina: equipe de 4 pessoas, uma clínica, orçamento limitado. Microserviços seriam overengineering; um monólito sem camadas fica difícil de manter.

| Camada | No app (Flutter) | Na API (`api/src`) |
|---|---|---|
| Apresentação | Telas e widgets | `presentation/` — Callable Functions e funções agendadas |
| Aplicação/Serviço | Controllers / state | `application/` — agendar, cancelar, remarcar, cadastrar |
| Domínio | Models | `domain/` — entidades, validações, regras da agenda |
| Persistência | Firebase SDK | `infrastructure/` — repositórios do Firestore |

Os serviços da API dependem de interfaces (`application/portas.ts`), não do Firestore. Por isso os testes rodam com repositórios em memória, e trocar o banco afeta só `infrastructure/`.

Infraestrutura mínima: um projeto Firebase (Auth, Firestore, Functions, Storage, FCM), sem servidores para gerenciar.
