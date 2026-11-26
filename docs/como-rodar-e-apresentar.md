# Como rodar o Pet Care e roteiro da apresentação

Tudo roda local, nos emuladores do Firebase (projeto `demo-petcare`). Não precisa de conta no Firebase.

## 1. Instalar uma vez (no Windows)

| O quê | Como conferir | Onde baixar |
|---|---|---|
| Git | `git --version` | git-scm.com |
| Node.js 22 | `node -v` → v22.x | nodejs.org (versão 22 LTS) |
| Java 21 (JDK) | `java -version` → 21 ou mais | adoptium.net (Temurin 21) |
| Firebase CLI | `firebase --version` | `npm install -g firebase-tools` |
| Flutter | `flutter doctor` | docs.flutter.dev → Windows → Android |
| Android Studio (SDK + emulador) | `flutter doctor` sem ❌ em Android | developer.android.com/studio |

Depois de instalar o Flutter, rode `flutter doctor --android-licenses` e aceite tudo (`y`).

No Android Studio: **Device Manager → Create device** → um Pixel com Android recente. Pode fechar o Android Studio depois; o emulador abre pelo Antigravity.

## 2. Abrir no Antigravity

1. **File → Open Folder** → a pasta do repositório (`petcare`, a que tem `api/`, `app/` e `docs/`).
2. Na aba de extensões, instale **Flutter** (já traz a extensão Dart).
3. Abra o terminal integrado (**Terminal → New Terminal**). Você vai usar **3 terminais**: o botão **+** abre outro, e eles ficam lado a lado.

> Se for clonar de novo: `git clone https://github.com/daviermac/petcare.git` e abra essa pasta.

## 3. Preparar (primeira vez ou depois de um `git pull`)

```bash
cd api
npm install
cd ../app
flutter pub get
```

## 4. Subir tudo (toda vez)

**Terminal 1 — emuladores + API** (deixe aberto o tempo todo):

```bash
cd api
npm run emuladores
```

Espere aparecer **"All emulators ready!"** (na primeira vez demora porque baixa o emulador do Firestore). Se o Windows perguntar sobre o firewall do Java/Node, permita em **rede privada**.

**Terminal 2 — dados de exemplo** (apaga tudo e recria; use também para "resetar"):

```bash
cd api
npm run seed
```

Contas (senha de todas: `Pet@1234`):

| Perfil | E-mail |
|---|---|
| Gestor | gestor@petconnect.dev |
| Veterinário | vet@petconnect.dev (Paula) / vet2@petconnect.dev (Caio) |
| Atendente | atendente@petconnect.dev |
| Auxiliar | auxiliar@petconnect.dev |
| Tutor | ana@email.dev (Thor e Mia) / bruno@email.dev (Apolo) |

**Terminal 3 — app:**

1. Abra o emulador Android: canto inferior direito do Antigravity (nome do dispositivo) ou `Ctrl+Shift+P` → **Flutter: Launch Emulator**.
2. Rode:

```bash
cd app
flutter run
```

| Onde roda o app | Comando |
|---|---|
| Emulador Android | `flutter run` |
| Celular Android pelo cabo (depuração USB ligada, mesmo Wi-Fi do notebook) | `flutter run --dart-define=EMULADOR_HOST=SEU_IP` |
| Simulador iOS / iPhone (só num Mac) | `flutter run` / `flutter run --dart-define=EMULADOR_HOST=SEU_IP` |

`SEU_IP`: no Windows, `ipconfig` → "Endereço IPv4" do Wi-Fi (ex.: `192.168.0.15`).

Com o app rodando: `r` no terminal recarrega o código, `R` reinicia o app, `q` fecha.

**Endereços úteis (no navegador do notebook):**

- Dados, usuários e logs: http://localhost:4000
- Swagger da API: http://localhost:5001/demo-petcare/southamerica-east1/docs
- Gerar lembretes de consulta/vacina na hora: http://localhost:5001/demo-petcare/southamerica-east1/dispararLembretes

## 5. Rodar os testes (para mostrar o RT11)

```bash
cd api
npm test                    # unidade (não precisa dos emuladores)
npm run test:coverage       # mesma coisa, com a cobertura
npm run test:integracao     # precisa do Terminal 1 aberto e do seed feito

cd ../app
flutter test                # unidade + widget
flutter test integration_test   # app de verdade no emulador (Terminal 1 aberto + seed)
```

Rode `npm run seed` de novo depois dos testes de integração: eles criam registros extras.

## 6. Roteiro da apresentação (~12 min)

Antes de começar: Terminal 1 rodando, `npm run seed` recém-feito, app aberto no emulador na tela de login, abas do navegador com o painel (localhost:4000) e o Swagger.

| Tempo | Quem entra | O que mostrar | Requisitos |
|---|---|---|---|
| 1 min | — | Problema e solução: app da clínica PetConnect com 5 perfis; Flutter + Firebase, API em camadas | — |
| 2 min | **Tutor** ana@email.dev | Meus animais (Thor e Mia) → agendar consulta → tentar o mesmo horário de novo (some da lista) → Minhas consultas | RF04, RF06, RF07, RF09 |
| 1 min | **Atendente** | Agenda do dia (escolher o próximo dia útil) → remarcar a consulta que a Ana acabou de marcar | RF08, RF10 |
| 3 min | **Veterinário** vet@petconnect.dev | Agenda → tocar na consulta do **Thor** → prontuário com histórico (otite corrigida, vacina, banho) → **Atendimento** (valor 180,00) → **Prescrição** de 8 em 8 h → no diálogo, **Testar lembrete (1 min)** → **Vacina** com próxima dose | RF13–RF16, RF21, RNF16 |
| 1 min | **Auxiliar** | Animais do dia → registrar procedimento → marcar 2 tarefas do checklist, sair e entrar de novo (continuam marcadas) | RF24–RF26 |
| 3 min | **Gestor** gestor@petconnect.dev | **Equipe**: criar funcionário e desativar → **Cobranças**: a do Thor que acabou de gerar aparece pendente → **Receber** no Pix → **Relatórios**: faturado/recebido/a receber, por veterinário, por dia, atendimentos | RF30–RF33, RF35 |
| 1 min | — | Notificação do lembrete de teste já deve ter chegado. Swagger (contrato da API) e `npm test` rodando | RF21, RT11 |

**Frases-chave:**
- "Duas pessoas tentando o mesmo horário: só uma consegue — é uma transação no banco."
- "Registro médico nunca é apagado; uma correção guarda a versão anterior."
- "Funcionário desativado perde o acesso na hora, mesmo já logado."
- "Cada atendimento gera a cobrança automaticamente; o pagamento não pode ser registrado duas vezes."

## 7. Se algo der errado

| Problema | Solução |
|---|---|
| App diz "Não foi possível conectar ao servidor" | Terminal 1 está aberto e mostrou "All emulators ready!"? No celular físico, confira o IP e o Wi-Fi |
| `npm run emuladores` reclama de Java | Instale o JDK 21 e abra um terminal novo |
| Porta em uso (8080, 9099, 5001) | Feche outro `npm run emuladores` aberto; em último caso reinicie o notebook |
| Login não funciona / dados estranhos | `npm run seed` (recria tudo) |
| Tela não atualiza depois de mudar o código | `R` no Terminal 3 |
| Lembrete de teste não chegou | Permissão de notificação do app (Configurações do Android → Apps → petcare → Notificações) e "Alarmes e lembretes" liberado |
| `flutter run` não acha dispositivo | `flutter devices`; abra o emulador antes |
