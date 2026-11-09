import { AgendamentoServico } from '../src/application/agendamento-servico';
import { Solicitante } from '../src/application/portas';
import { TutorServico } from '../src/application/tutor-servico';
import { ErroNegocio, ErroValidacao } from '../src/domain/erros';
import { AnimaisEmMemoria, ConsultasEmMemoria, TutoresEmMemoria, UsuariosEmMemoria } from './fakes';

// "Agora" fixo: sexta, 06/11/2026 12:00 (São Paulo). Segunda seguinte = 09/11.
const agora = new Date('2026-11-06T12:00:00-03:00');
const relogio = () => agora;
const SEGUNDA = '2026-11-09';

const tutorA: Solicitante = { uid: 'tutorA', perfil: 'tutor' };
const tutorB: Solicitante = { uid: 'tutorB', perfil: 'tutor' };
const atendente: Solicitante = { uid: 'atend1', perfil: 'atendente' };
const auxiliar: Solicitante = { uid: 'aux1', perfil: 'auxiliar' };

async function cenario() {
  const tutores = new TutoresEmMemoria();
  const animais = new AnimaisEmMemoria();
  const consultas = new ConsultasEmMemoria();
  const usuarios = new UsuariosEmMemoria();
  const tutorServico = new TutorServico(tutores, animais, usuarios, relogio);
  const agenda = new AgendamentoServico(consultas, animais, relogio);

  await tutorServico.registrar('tutorA', { nome: 'Ana Souza', cpf: '52998224725', telefone: '12991021830', email: 'ana@x.com' });
  await tutorServico.registrar('tutorB', { nome: 'Bruno Lima', cpf: '11144477735', telefone: '11988887777', email: 'b@x.com' });
  const thor = await tutorServico.cadastrarAnimal(tutorA, { nome: 'Thor', especie: 'cachorro', raca: 'SRD', idade: 3 });
  const mia = await tutorServico.cadastrarAnimal(tutorB, { nome: 'Mia', especie: 'gato', raca: '', idade: 2 });
  return { tutorServico, agenda, consultas, usuarios, thor, mia };
}

describe('TutorServico', () => {
  it('registra tutor e define perfil "tutor" (RF01)', async () => {
    const { usuarios } = await cenario();
    expect(usuarios.perfis.get('tutorA')).toBe('tutor');
  });

  it('recusa CPF já cadastrado', async () => {
    const { tutorServico } = await cenario();
    await expect(
      tutorServico.registrar('outro', { nome: 'Carla Dias', cpf: '52998224725', telefone: '12991021830', email: 'c@x.com' }),
    ).rejects.toMatchObject({ codigo: 'CPF_JA_CADASTRADO' });
  });

  it('auxiliar não cadastra animal', async () => {
    const { tutorServico } = await cenario();
    await expect(
      tutorServico.cadastrarAnimal(auxiliar, { tutorId: 'tutorA', nome: 'X', especie: 'gato', idade: 1 }),
    ).rejects.toMatchObject({ codigo: 'SEM_PERMISSAO' });
  });
});

describe('AgendamentoServico', () => {
  it('agenda consulta em horário livre (RF06)', async () => {
    const { agenda, thor } = await cenario();
    const c = await agenda.agendar(tutorA, { animalId: thor.id, data: SEGUNDA, horario: '11:00' });
    expect(c).toMatchObject({ animalNome: 'Thor', status: 'agendada', local: 'Hospital PetConnect' });
    expect(c.inicio.toISOString()).toBe('2026-11-09T14:00:00.000Z');
  });

  it('marca horário ocupado e impede agendamento duplicado (RF07)', async () => {
    const { agenda, thor, mia } = await cenario();
    await agenda.agendar(tutorA, { animalId: thor.id, data: SEGUNDA, horario: '09:30' });

    const horarios = await agenda.listarHorarios(SEGUNDA);
    expect(horarios.find((h) => h.horario === '09:30')?.disponivel).toBe(false);
    expect(horarios.find((h) => h.horario === '11:00')?.disponivel).toBe(true);

    await expect(
      agenda.agendar(tutorB, { animalId: mia.id, data: SEGUNDA, horario: '09:30' }),
    ).rejects.toMatchObject({ codigo: 'HORARIO_INDISPONIVEL' });
  });

  it('recusa fim de semana, horário fora da grade e horário passado', async () => {
    const { agenda, thor } = await cenario();
    await expect(agenda.agendar(tutorA, { animalId: thor.id, data: '2026-11-07', horario: '08:00' })).rejects.toBeInstanceOf(ErroValidacao);
    await expect(agenda.agendar(tutorA, { animalId: thor.id, data: SEGUNDA, horario: '10:00' })).rejects.toBeInstanceOf(ErroValidacao);
    await expect(agenda.agendar(tutorA, { animalId: thor.id, data: '2026-11-06', horario: '11:00' })).rejects.toBeInstanceOf(ErroValidacao);
  });

  it('tutor não agenda para animal de outro tutor (RNF03)', async () => {
    const { agenda, mia } = await cenario();
    await expect(
      agenda.agendar(tutorA, { animalId: mia.id, data: SEGUNDA, horario: '08:00' }),
    ).rejects.toBeInstanceOf(ErroNegocio);
  });

  it('cancelar libera o horário para outro tutor (RF11)', async () => {
    const { agenda, thor, mia } = await cenario();
    const c = await agenda.agendar(tutorA, { animalId: thor.id, data: SEGUNDA, horario: '14:00' });

    await expect(agenda.cancelar(tutorB, c.id)).rejects.toMatchObject({ codigo: 'SEM_PERMISSAO' });
    await agenda.cancelar(tutorA, c.id);

    const nova = await agenda.agendar(tutorB, { animalId: mia.id, data: SEGUNDA, horario: '14:00' });
    expect(nova.status).toBe('agendada');
    await expect(agenda.cancelar(tutorA, c.id)).rejects.toMatchObject({ codigo: 'CONSULTA_NAO_ATIVA' });
  });

  it('remarcar libera o horário antigo e ocupa o novo (RF10)', async () => {
    const { agenda, thor } = await cenario();
    const c = await agenda.agendar(tutorA, { animalId: thor.id, data: SEGUNDA, horario: '08:00' });

    await expect(agenda.remarcar(tutorA, { consultaId: c.id, data: SEGUNDA, horario: '15:30' })).rejects.toMatchObject({ codigo: 'SEM_PERMISSAO' });
    await agenda.remarcar(atendente, { consultaId: c.id, data: SEGUNDA, horario: '15:30' });

    const horarios = await agenda.listarHorarios(SEGUNDA);
    expect(horarios.find((h) => h.horario === '08:00')?.disponivel).toBe(true);
    expect(horarios.find((h) => h.horario === '15:30')?.disponivel).toBe(false);
  });
});
