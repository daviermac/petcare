// Ponto de entrada das Cloud Functions do Pet Care.
export {
  registrarTutor,
  cadastrarAnimal,
  listarHorarios,
  agendarConsulta,
  cancelarConsulta,
  remarcarConsulta,
  registrarTokenNotificacao,
} from './presentation/callables';

export { lembretesDeConsulta } from './presentation/agendadas';

export { docs } from './presentation/docs';
