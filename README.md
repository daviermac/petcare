# App Flutter (PetConnect / Pet Care)

Aplicativo mobile (Android e iOS) do Hospital Veterinário PetConnect. Hoje o app está completo para o perfil **Tutor** (histórias de usuário HU01 a HU05). Ele roda contra os **emuladores do Firebase** no computador, sem projeto em produção, então **não precisa** de `flutterfire configure` nem de conta no console do Firebase.

**Front-end (app Flutter):** Matias Henrique Gonçalves
**Back-end (API, regras e emuladores):** Davi (pasta `api/`)

<!--
## Telas
Adicione prints em app/docs/prints/ e descomente:
| Início | Animais | Agendar | Consultas |
|---|---|---|---|
| ![Início](docs/prints/inicio.png) | ![Animais](docs/prints/animais.png) | ![Agendar](docs/prints/agendar.png) | ![Consultas](docs/prints/consultas.png) |
-->

## O que o app faz

| História | Requisito | Tela |
|---|---|---|
| HU01 | RF01, RF02 | Login e cadastro do tutor (nome, CPF, telefone, e-mail e senha), com mensagem de erro em cada campo inválido |
| HU02 | RF04 | Meus animais e cadastro de animal (nome, espécie, raça e idade) |
| HU03 | RF06, RF07 | Agendar consulta: animal, dia, horário (os ocupados aparecem riscados) e tela de confirmação |
| HU04 | RF09 | Minhas consultas, detalhes da consulta e aviso quando não há agendamentos |
| HU05 | RF11 | Cancelar consulta com confirmação; o horário volta a ficar livre |
| Extra | RF19, RF20 | Notificações (lembretes de consulta e vacina) com contador de não lidas no sino |

Quem entra com um perfil de equipe (atendente, veterinário, auxiliar ou gestor) vê uma tela avisando que as telas desse perfil ainda estão em desenvolvimento.

Os caminhos de erro do diagrama de atividades do agendamento estão no app: dados inválidos, dia sem horário livre e horário ocupado (inclusive quando outra pessoa reserva o mesmo horário ao mesmo tempo).

## Estrutura de `lib/`

```
lib/
├── main.dart                 # inicia o Firebase e o app
├── core/                     # tema, Firebase/emuladores, validações, erros e formatadores
├── models/                   # Animal, Consulta, Notificacao
├── services/
│   ├── api.dart              # chamadas às Cloud Functions (escritas com regra de negócio)
│   └── dados.dart            # leituras no Firestore (animais, consultas, notificações)
├── widgets/                  # componentes reutilizáveis (campos, botões, cartões)
└── screens/                  # telas (auth_gate, login, cadastro, abas do tutor, detalhes...)
```

Como as camadas se dividem: **escritas** (cadastrar, agendar, cancelar) passam pela API; **leituras** (listar animais e consultas) vão direto no Firestore, protegidas pelas regras em `firestore.rules`. O `AuthGate` lê o perfil do usuário no token (`claims['perfil']`) e decide qual tela mostrar.

## Como rodar na sua máquina

### 1. Instalar uma vez

| Ferramenta | Versão |
|---|---|
| Git | qualquer recente |
| Node.js | 22 (o 24 funciona, com um aviso) |
| **JDK** | **21 ou superior** (os emuladores do Firebase exigem) |
| Flutter | 3.x estável |
| Android Studio | com um emulador Android criado |
| Firebase CLI | `npm install -g firebase-tools` |

### 2. Subir o backend (emuladores)

```bash
cd api
npm install
npm run emuladores      # deixe este terminal aberto
```

Em **outro terminal**:

```bash
cd api
npm run seed            # cria contas e dados de exemplo
```

### 3. Criar o projeto Flutter (só na primeira vez)

```bash
cd app
flutter create --org br.com.petconnect --project-name petcare --platforms android,ios .
flutter pub add firebase_core firebase_auth cloud_firestore cloud_functions
```

Depois do `flutter create`, apague `app/test/widget_test.dart` (ele não combina com o `main.dart` do app) e faça os dois ajustes de Android abaixo.

### 4. Ajustes no Android

Os emuladores usam `http://` e o Android bloqueia isso por padrão.

**`android/app/src/debug/AndroidManifest.xml`** (só para desenvolvimento):

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    <application android:usesCleartextTraffic="true" />
</manifest>
```

**`android/app/src/main/AndroidManifest.xml`**: acrescente, logo dentro de `<manifest>` e antes de `<application>`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

Se o build reclamar de `minSdkVersion`, ajuste para `minSdk = 23` em `android/app/build.gradle(.kts)`.

### 5. Rodar o app

Ligue um emulador Android e, na pasta `app/`:

```bash
flutter analyze
flutter run
```

| Situação | Como rodar |
|---|---|
| Emulador Android | `flutter run` (usa `10.0.2.2` automaticamente) |
| Simulador iOS | `flutter run` (usa `localhost`) |
| Celular físico | `flutter run --dart-define=EMULADOR_HOST=IP_DO_COMPUTADOR` |
| Porta 8080 ocupada | veja "Problemas comuns" |

### Contas de teste

Depois de `npm run seed`, todas usam a senha `Pet@1234`:

| Perfil | E-mail |
|---|---|
| Tutor | ana@email.dev (Thor e Mia) / bruno@email.dev (Apolo) |
| Veterinário | vet@petconnect.dev / vet2@petconnect.dev |
| Atendente | atendente@petconnect.dev |
| Auxiliar | auxiliar@petconnect.dev |
| Gestor | gestor@petconnect.dev |

Para testar um **cadastro novo**, use um CPF válido, como `39053344705`, e telefone com DDD, como `11999998888`.

Para gerar lembretes na hora (e ver o sino das notificações), abra no navegador: http://localhost:5001/demo-petcare/southamerica-east1/dispararLembretes

## Decisões técnicas

- **Chave de API fictícia.** O Android valida o formato da chave do Firebase antes de chamar as Cloud Functions. Um valor como `demo-key` é rejeitado (erro "Please set a valid API key"), então o app usa uma chave fictícia no formato correto (`A` + 38 caracteres). Ela só funciona com os emuladores.
- **Cadastro em dois passos.** O app cria o usuário no Firebase Auth e chama `registrarTutor`; depois força a renovação do token (`getIdToken(true)`) para o app receber o perfil `tutor`. Se o segundo passo falhar, a conta já existe: o app mostra "Complete seu cadastro" com nome, CPF e telefone.
- **Validação em duas camadas.** As mesmas regras da API (CPF, telefone, e-mail, nome) são conferidas no app antes de enviar, e os erros devolvidos pela API (`e.details['campos']`) aparecem abaixo de cada campo.
- **Espécie em minúsculo.** A tela mostra "Cachorro, Gato, Outro" e envia `cachorro`, `gato`, `outro`, que é o que a API espera.
- **Horários do dia.** A lista vem de `listarHorarios`; horários ocupados ou que já passaram (no dia de hoje) aparecem riscados e não podem ser escolhidos.
- **Ordenação no app.** As consultas e animais são ordenados no app, o que evita depender de índices compostos do Firestore.
- **Tema** com as cores do protótipo HTML (teal `#0F5C5C` e amarelo `#F2B632`).

## Problemas comuns

| Mensagem | Causa e solução |
|---|---|
| `firebase-tools no longer supports Java version before 21` | Instale o JDK 21 ou superior e abra um terminal novo |
| `Could not spawn java -version` | Java fora do PATH: reinstale marcando "Add to PATH" e abra um terminal novo |
| `Port 8080 is not open ... could not start Firestore Emulator` | Algum programa já usa a porta 8080. Troque a porta do Firestore (abaixo) |
| `Cleartext HTTP traffic to 10.0.2.2 not permitted` | Falta `usesCleartextTraffic` no manifesto de debug (passo 4). Rode `flutter clean` e depois `flutter run` |
| `Please set a valid API key` | Chave de API em formato inválido em `lib/core/firebase_setup.dart` |
| `No supported devices connected` | Ligue um emulador (`flutter emulators --launch NOME`) |
| `This application is not configured to build on the web` | O projeto é só Android e iOS. Use o emulador |

**Trocar a porta do Firestore (só na sua máquina):**

1. Em `firebase.json`, mude a porta do `firestore` (por exemplo, para `8081`). Não envie essa alteração ao Git (`git update-index --assume-unchanged firebase.json`).
2. Rode o seed com `$env:FIRESTORE_EMULATOR_HOST = "127.0.0.1:8081"` (PowerShell) ou `FIRESTORE_EMULATOR_HOST=127.0.0.1:8081` (Linux e macOS).
3. Rode o app com `flutter run --dart-define=FIRESTORE_PORT=8081`.

## Chamando a API

```dart
final res = await functions.httpsCallable('agendarConsulta').call({
  'animalId': animalId,
  'data': '2026-11-16',
  'horario': '11:00',
});
```

Erros chegam como `FirebaseFunctionsException`. Em `invalid-argument`, `e.details['campos']` traz uma mensagem por campo. Contrato completo: `../docs/api.md` ou o Swagger, com os emuladores rodando: http://localhost:5001/demo-petcare/southamerica-east1/docs

## O que ainda não foi feito

- Telas dos perfis de equipe (agenda da clínica, prontuário, relatórios, gestão de funcionários).
- Lembretes de medicamento no aparelho (RF21) e notificações locais com `flutter_local_notifications`.
- Anexo de exames (RF17, `firebase_storage`).
- Testes automatizados de widget e de integração (RT11).
- Testes em iPhone/simulador iOS e em celular físico.
