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
| RF08 Agenda da clínica | Essencial | ⬜ |
| RF09 Listar consultas do tutor | Essencial | ✅ leitura direta + regras |
| RF10 Remarcar | Essencial | ✅ `remarcarConsulta` |
| RF11 Cancelar | Essencial | ✅ `cancelarConsulta` |
| RF13–RF16 Prontuário, prescrições, vacinas | Essencial | ⬜ |
| RF17 Anexar exames | Essencial/Desejável | 🟨 `storage.rules` prontas |
| RF19 Lembrete de consulta | Essencial | ✅ `lembretesDeConsulta` |
| RF20 Lembrete de vacina | Essencial | ⬜ |
| RF24–RF26 Auxiliar | Essencial | ⬜ |
| RF30–RF33 Gestor | Essencial | ⬜ |
| RNF03 Isolamento de dados (LGPD) | — | ✅ regras |
| RNF04 Validação no servidor | — | ✅ regras + domínio |
| RNF16 Registros médicos imutáveis | — | ⬜ |
| RT11 Testes (≥70% nas regras de negócio) | — | ✅ `npm test` |
