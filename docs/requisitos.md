# Requisitos — status na API

Lista completa no documento "Check-up do Pet Care" (37 RF, 16 RNF, 13 RT). Aqui só o que envolve o backend.

| Requisito | Prioridade | Status |
|---|---|---|
| RF01 Cadastrar tutor | Essencial | ✅ `registrarTutor` |
| RF02 Login/logout | Essencial | App (Firebase Auth) |
| RF03 Acesso por perfil | Essencial | ✅ custom claim `perfil` + `firestore.rules` |
| RF04 Cadastrar animal | Essencial | ✅ `cadastrarAnimal` / regras |
| RF06 Agendar consulta | Essencial | ✅ `agendarConsulta` |
| RF07 Impedir horário ocupado | Essencial | ✅ transação + `horariosOcupados` |
| RF08 Agenda da clínica | Essencial | ✅ `agendaDoDia` |
| RF09 Listar consultas do tutor | Essencial | ✅ leitura direta + regras |
| RF10 Remarcar | Essencial | ✅ `remarcarConsulta` |
| RF11 Cancelar | Essencial | ✅ `cancelarConsulta` |
| RF13 Histórico médico | Essencial | ✅ `historicoDoAnimal` |
| RF14 Atendimento (diagnóstico/tratamento) | Essencial | ✅ `registrarAtendimento` |
| RF15 Prescrições | Essencial | ✅ `registrarPrescricao` |
| RF16 Vacinas | Essencial | ✅ `registrarVacina` |
| RF17 Anexar exames | Essencial/Desejável | 🟨 `storage.rules` prontas |
| RF19 Lembrete de consulta | Essencial | ✅ `lembretesDeConsulta` + coleção `notificacoes` (demo: `dispararLembretes`) |
| RF20 Lembrete de vacina | Essencial | ✅ `lembretesDeVacina` + coleção `notificacoes` |
| RF21 Lembrete de medicamento | Desejável | 🟨 API devolve os horários; app agenda localmente |
| RF22 Tutor vê receitas | Desejável | ✅ `historicoDoAnimal` + regras |
| RF24 Tarefas do dia (auxiliar) | Essencial | ⬜ |
| RF25 Animais do dia (auxiliar) | Essencial | ✅ `agendaDoDia` (sem dados pessoais) |
| RF26 Registrar procedimento | Essencial | ✅ `registrarProcedimento` |
| RF30 Faturamento | Essencial | ⬜ (falta definir o valor das consultas) |
| RF31 Relatório financeiro | Essencial | ⬜ |
| RF32 Gerenciar funcionários | Essencial | ✅ `criarFuncionario` / `definirStatusFuncionario` |
| RF33 Quantidade de atendimentos | Essencial | ✅ `relatorioAtendimentos` |
| RF35 Desempenho por veterinário | Desejável | ✅ `relatorioAtendimentos` |
| RNF03 Isolamento de dados (LGPD) | — | ✅ regras |
| RNF04 Validação no servidor | — | ✅ regras + domínio |
| RNF16 Registros médicos imutáveis | — | ✅ `corrigirRegistro` + regras (sem exclusão) |
| RT11 Testes (≥70% nas regras de negócio) | — | ✅ `npm test` |
