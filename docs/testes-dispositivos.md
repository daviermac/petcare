# Testes em dispositivos (iPhone / simulador iOS e celular Android)

Roteiro para conferir o app num aparelho de verdade antes da apresentação. Leva uns 20 minutos por aparelho.

## Antes de começar (no notebook)

```bash
cd api
npm run emuladores          # terminal 1 (deixe aberto)
npm run seed                # terminal 2: recria contas e dados (senha de todas: Pet@1234)
```

Descubra o IP do notebook na rede (Windows: `ipconfig` → "Endereço IPv4", ex.: `192.168.0.15`). Celular e notebook precisam estar **na mesma rede Wi-Fi**. Na primeira vez o Windows pergunta se libera o Java e o Node no firewall: permita em **rede privada**.

## Como rodar o app

| Aparelho | Comando (pasta `app/`) |
|---|---|
| Emulador Android | `flutter run` |
| Celular Android físico (cabo USB + depuração USB ligada) | `flutter run --dart-define=EMULADOR_HOST=192.168.0.15` |
| Simulador iOS (só no Mac) | `flutter run` (usa `localhost`) |
| iPhone físico (só no Mac, com Xcode e conta Apple) | `flutter run --dart-define=EMULADOR_HOST=192.168.0.15` |

### Particularidades do iOS (já ajustadas no projeto)

- Versão mínima do iOS: **15.0** (exigência do Firebase). Se o `pod install` reclamar, abra `ios/Podfile` e deixe a linha `platform :ios, '15.0'` (sem o `#`).
- `Info.plist` libera `http://` para o IP do notebook (os emuladores não usam HTTPS) e pede acesso à rede local: no iPhone, aceite o aviso "Permitir que o PetConnect encontre dispositivos na rede local".
- Notificações locais configuradas para iOS (`DarwinInitializationSettings`); o app pede permissão na primeira abertura: toque em **Permitir**.
- iPhone físico: no Xcode, abra `ios/Runner.xcworkspace` → Runner → Signing & Capabilities → escolha seu Team. No iPhone: Ajustes → Geral → VPN e Gerenciamento de Dispositivo → confiar no desenvolvedor.

## Checklist (marque em cada aparelho)

| # | Perfil / conta | O que fazer | Esperado | Android | iOS |
|---|---|---|---|---|---|
| 1 | — | Abrir o app | Tela de login, sem erro de conexão | ☐ | ☐ |
| 2 | Tutor `ana@email.dev` | Ver animais e consultas; agendar uma consulta | Thor e Mia aparecem; horário ocupado some da lista | ☐ | ☐ |
| 3 | Veterinário `vet@petconnect.dev` | Agenda → escolher o próximo dia útil → tocar na consulta do Thor | Abre o prontuário com o histórico (otite, vacina, banho) | ☐ | ☐ |
| 4 | Veterinário | Registrar **atendimento** (valor 180,00) | Consulta vira "Realizada" na agenda | ☐ | ☐ |
| 5 | Veterinário | Registrar **prescrição** (8 em 8 h por 3 dias) | Diálogo mostra lembretes agendados e o próximo horário | ☐ | ☐ |
| 6 | Veterinário | No diálogo, tocar **Testar lembrete (1 min)** e bloquear a tela | Notificação "Hora do medicamento! (teste)" chega em ~1 min (RF21) | ☐ | ☐ |
| 7 | Veterinário | Registrar **vacina** com próxima dose | Aparece no topo do histórico | ☐ | ☐ |
| 8 | Auxiliar `auxiliar@petconnect.dev` | Marcar 2 tarefas, sair e entrar de novo | As 2 continuam marcadas (RF24) | ☐ | ☐ |
| 9 | Gestor `gestor@petconnect.dev` | Equipe → Novo funcionário | Novo login aparece na lista e consegue entrar | ☐ | ☐ |
| 10 | Gestor | Desativar o funcionário criado | Ele não consegue mais entrar | ☐ | ☐ |
| 11 | Gestor | Cobranças → **Receber** a cobrança pendente (Pix) | Vira "Paga" (RF30) | ☐ | ☐ |
| 12 | Gestor | Relatórios (mês atual) | Faturado/recebido batem com as cobranças; gráfico por veterinário (RF31, RF33) | ☐ | ☐ |
| 13 | Tutor `ana@email.dev` | Abrir notificações depois de `/dispararLembretes` no navegador | Lembretes de consulta/vacina aparecem | ☐ | ☐ |
| 14 | — | Girar a tela e usar fonte grande do sistema | Nada corta ou sobrepõe | ☐ | ☐ |

**Observação sobre os lembretes de medicamento (RF21):** eles são agendados no aparelho em que a prescrição é salva. No emulador do Firebase não existe push real (FCM), então lembretes de consulta e vacina aparecem pela coleção `notificacoes` (item 13).

## Testes automáticos no aparelho

Com os emuladores rodando e o seed feito, o teste de integração do app percorre veterinário, gestor e auxiliar sozinho:

```bash
cd app
flutter test integration_test                                            # emulador/simulador
flutter test integration_test --dart-define=EMULADOR_HOST=192.168.0.15   # celular físico
```
