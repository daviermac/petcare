// Ponto de entrada das Cloud Functions do Pet Care.
export {
  // Tutor e animais
  registrarTutor,
  cadastrarAnimal,
  // Agendamento
  listarHorarios,
  agendarConsulta,
  cancelarConsulta,
  remarcarConsulta,
  // Prontuário
  registrarAtendimento,
  registrarPrescricao,
  registrarVacina,
  registrarProcedimento,
  historicoDoAnimal,
  corrigirRegistro,
  // Clínica
  agendaDoDia,
  relatorioAtendimentos,
  // Gestão
  criarFuncionario,
  definirStatusFuncionario,
  // Notificações
  registrarTokenNotificacao,
} from './presentation/callables';

export { lembretesDeConsulta, lembretesDeVacina, dispararLembretes } from './presentation/agendadas';

export { docs } from './presentation/docs';
