import { AgendamentoServico } from '../src/application/agendamento-servico';
import { ClinicaServico } from '../src/application/clinica-servico';
import { GestaoServico } from '../src/application/gestao-servico';
import { Solicitante } from '../src/application/portas';
import { ProntuarioServico } from '../src/application/prontuario-servico';
import { TutorServico } from '../src/application/tutor-servico';
import { dataEmSaoPaulo, somarDias } from '../src/domain/agenda';
import { DadosAtendimento, DadosVacina } from '../src/domain/entidades';
import { ErroValidacao } from '../src/domain/erros';
import { horariosDeMedicacao, validarVacina } from '../src/domain/prontuario';
import {
  AnimaisEmMemoria,
  ConsultasEmMemoria,
  RegistrosEmMemoria,
  TutoresEmMemoria,
  UsuariosEmMemoria,
} from './fakes';

// Relógio controlável: começa sexta 06/11/2026 12:00 (São Paulo).
let agora = new Date('2026-11-06T12:00:00-03:00');
const relogio = () => agora;
const avancarMinutos = (m: number) => (agora = new Date(agora.getTime() + m * 60_000));

const tutorA: Solicitante = { uid: 'tutorA', perfil: 'tutor' };
const tutorB: Solicitante = { uid: 'tutorB', perfil: 'tutor' };
const vet: Solicitante = { uid: 'vet1', perfil: 'veterinario', nome: 'Dra. Paula Reis' };
const vet2: Solicitante = { uid: 'vet2', perfil: 'veterinario', nome: 'Dr. Caio Lima' };
const aux: Solicitante = { uid: 'aux1', perfil: 'auxiliar', nome: 'Rafa Auxiliar' };
const atendente: Solicitante = { uid: 'atend1', perfil: 'atendente' };
const gestor: Solicitante = { uid: 'gestor1', perfil: 'gestor' };

async function cenario() {
  agora = new Date('2026-11-06T12:00:00-03:00');
  const tutores = new TutoresEmMemoria();
  const animais = new AnimaisEmMemoria();
  const consultas = new ConsultasEmMemoria();
  const registros = new RegistrosEmMemoria();
  const usuarios = new UsuariosEmMemoria();
  const tutorServico = new TutorServico(tutores, animais, usuarios, relogio);
  const agenda = new AgendamentoServico(consultas, animais, relogio);
  const prontuario = new ProntuarioServico(registros, animais, consultas, relogio);
  const clinica = new ClinicaServico(consultas, animais, tutores, registros);
  const gestao = new GestaoServico(usuarios);

  await tutorServico.registrar('tutorA', { nome: 'Ana Souza', cpf: '52998224725', telefone: '12991021830', email: 'ana@x.com' });
  await tutorServico.registrar('tutorB', { nome: 'Bruno Lima', cpf: '11144477735', telefone: '11988887777', email: 'b@x.com' });
  const thor = await tutorServico.cadastrarAnimal(tutorA, { nome: 'Thor', especie: 'cachorro', raca: 'SRD', idade: 3 });
  const mia = await tutorServico.cadastrarAnimal(tutorB, { nome: 'Mia', especie: 'gato', raca: '', idade: 2 });
  usuarios.perfis.set('gestor1', 'gestor');
  return { agenda, prontuario, clinica, gestao, consultas, registros, usuarios, thor, mia };
}

describe('Prontuário (RF13–RF16, RF26)', () => {
  it('veterinário registra atendimento e o histórico mostra em ordem cronológica (RF13, RF14)', async () => {
    const { prontuario, thor } = await cenario();
    await prontuario.registrar(vet, 'atendimento', { animalId: thor.id, diagnostico: 'Otite', tratamento: 'Limpeza + gotas' });
    avancarMinutos(60);
    await prontuario.registrar(vet2, 'atendimento', { animalId: thor.id, diagnostico: 'Retorno ok', tratamento: 'Alta' });

    const h = await prontuario.historico(vet, thor.id);
    expect(h.registros.map((r) => (r.dados as DadosAtendimento).diagnostico)).toEqual(['Otite', 'Retorno ok']);
    expect(h.registros[0]).toMatchObject({ autorNome: 'Dra. Paula Reis', autorPerfil: 'veterinario' });
  });

  it('atendimento ligado a consulta marca a consulta como realizada', async () => {
    const { agenda, prontuario, consultas, thor } = await cenario();
    const c = await agenda.agendar(tutorA, { animalId: thor.id, data: '2026-11-09', horario: '08:00' });
    await prontuario.registrar(vet, 'atendimento', { animalId: thor.id, consultaId: c.id, diagnostico: 'Ok', tratamento: 'Nenhum' });
    expect((await consultas.buscarPorId(c.id))!.status).toBe('realizada');
    await expect(
      prontuario.registrar(vet, 'atendimento', { animalId: thor.id, consultaId: c.id, diagnostico: 'X', tratamento: 'Y' }),
    ).rejects.toMatchObject({ codigo: 'CONSULTA_NAO_ATIVA' });
  });

  it('prescrição de 8 em 8 horas por 3 dias gera 9 horários de lembrete (RF15, RF21)', async () => {
    const { prontuario, thor } = await cenario();
    const p = await prontuario.registrar(vet, 'prescricao', {
      animalId: thor.id, medicamento: 'Amoxicilina', dosagem: '1 comprimido', frequenciaHoras: 8, duracaoDias: 3,
    });
    expect(p.horariosMedicacao).toHaveLength(9);
    expect(horariosDeMedicacao(new Date('2026-11-06T15:00:00Z'), 12, 7)).toHaveLength(14);
  });

  it('vacina guarda a próxima dose e valida as datas (RF16)', async () => {
    const { prontuario, thor } = await cenario();
    const v = await prontuario.registrar(vet, 'vacina', { animalId: thor.id, nome: 'V10', proximaDose: '2027-11-06' });
    expect(v.proximaDose).toBe('2027-11-06');
    expect((v.dados as DadosVacina).dataAplicacao).toBe('2026-11-06');
    expect(() => validarVacina({ nome: 'V10', proximaDose: '2026-11-01' }, '2026-11-06')).toThrow(ErroValidacao);
    expect(() => validarVacina({ nome: 'V10', dataAplicacao: '2026-12-01' }, '2026-11-06')).toThrow(ErroValidacao);
  });

  it('auxiliar registra procedimento, mas não atendimento (RF26, RF03)', async () => {
    const { prontuario, thor } = await cenario();
    const r = await prontuario.registrar(aux, 'procedimento', { animalId: thor.id, descricao: 'Banho e tosa' });
    expect(r).toMatchObject({ tipo: 'procedimento', autorNome: 'Rafa Auxiliar' });
    await expect(
      prontuario.registrar(aux, 'atendimento', { animalId: thor.id, diagnostico: 'x', tratamento: 'y' }),
    ).rejects.toMatchObject({ codigo: 'SEM_PERMISSAO' });
    await expect(
      prontuario.registrar(atendente, 'vacina', { animalId: thor.id, nome: 'V10' }),
    ).rejects.toMatchObject({ codigo: 'SEM_PERMISSAO' });
  });

  it('tutor vê o histórico do próprio animal, mas não o de outro (RF13, RNF03)', async () => {
    const { prontuario, thor, mia } = await cenario();
    await prontuario.registrar(vet, 'prescricao', {
      animalId: mia.id, medicamento: 'Vermífugo', dosagem: '1/2 comp', frequenciaHoras: 24, duracaoDias: 1,
    });
    expect((await prontuario.historico(tutorB, mia.id)).registros).toHaveLength(1);
    await expect(prontuario.historico(tutorA, mia.id)).rejects.toMatchObject({ codigo: 'SEM_PERMISSAO' });
    await expect(prontuario.historico(aux, thor.id)).rejects.toMatchObject({ codigo: 'SEM_PERMISSAO' });
  });

  it('correção guarda a versão anterior com autor e data (RNF16)', async () => {
    const { prontuario, thor } = await cenario();
    const r = await prontuario.registrar(vet, 'atendimento', { animalId: thor.id, diagnostico: 'Otite', tratamento: 'Gotas' });
    avancarMinutos(30);
    const corrigido = await prontuario.corrigir(vet2, r.id, { diagnostico: 'Otite externa', tratamento: 'Gotas' });
    expect(corrigido.versao).toBe(2);
    expect((corrigido.dados as DadosAtendimento).diagnostico).toBe('Otite externa');
    expect(corrigido.historico[0]).toMatchObject({ autorNome: 'Dra. Paula Reis', dados: { diagnostico: 'Otite' } });
    await expect(prontuario.corrigir(aux, r.id, { diagnostico: 'x', tratamento: 'y' })).rejects.toMatchObject({ codigo: 'SEM_PERMISSAO' });
  });
});

describe('Clínica (RF08, RF25, RF33, RF35)', () => {
  it('agenda do dia lista as consultas em ordem de horário, sem dados pessoais (RF08, RF25)', async () => {
    const { agenda, clinica, thor, mia } = await cenario();
    await agenda.agendar(tutorA, { animalId: thor.id, data: '2026-11-09', horario: '14:00' });
    await agenda.agendar(tutorB, { animalId: mia.id, data: '2026-11-09', horario: '08:00' });
    const c3 = await agenda.agendar(tutorA, { animalId: thor.id, data: '2026-11-09', horario: '11:00' });
    await agenda.cancelar(tutorA, c3.id);

    const dia = await clinica.agendaDoDia(aux, '2026-11-09');
    expect(dia.map((i) => i.horario)).toEqual(['08:00', '14:00']);
    expect(dia[0]).toEqual({
      consultaId: expect.any(String), horario: '08:00', status: 'agendada',
      animal: { id: mia.id, nome: 'Mia', especie: 'gato' }, tutorNome: 'Bruno Lima', local: 'Hospital PetConnect',
    });
    expect(await clinica.agendaDoDia(atendente, '2026-11-09', true)).toHaveLength(3);
    await expect(clinica.agendaDoDia(tutorA, '2026-11-09')).rejects.toMatchObject({ codigo: 'SEM_PERMISSAO' });
  });

  it('relatório conta atendimentos do período por veterinário (RF33, RF35)', async () => {
    const { prontuario, clinica, thor } = await cenario();
    for (let i = 0; i < 3; i++) await prontuario.registrar(vet, 'atendimento', { animalId: thor.id, diagnostico: 'a', tratamento: 'b' });
    for (let i = 0; i < 2; i++) await prontuario.registrar(vet2, 'atendimento', { animalId: thor.id, diagnostico: 'a', tratamento: 'b' });
    await prontuario.registrar(vet, 'vacina', { animalId: thor.id, nome: 'V10' });

    const rel = await clinica.relatorioAtendimentos(gestor, '2026-11-06', '2026-11-06');
    expect(rel.total).toBe(5);
    expect(rel.porVeterinario).toEqual([
      { veterinarioId: 'vet1', nome: 'Dra. Paula Reis', total: 3 },
      { veterinarioId: 'vet2', nome: 'Dr. Caio Lima', total: 2 },
    ]);
    expect((await clinica.relatorioAtendimentos(gestor, '2026-11-07', '2026-11-30')).total).toBe(0);
    await expect(clinica.relatorioAtendimentos(vet, '2026-11-06', '2026-11-06')).rejects.toMatchObject({ codigo: 'SEM_PERMISSAO' });
  });
});

describe('Gestão de funcionários (RF32)', () => {
  it('gestor cria funcionário com perfil e pode desativar', async () => {
    const { gestao, usuarios } = await cenario();
    const { uid } = await gestao.criarFuncionario(gestor, {
      nome: 'Carla Atendente', email: 'carla@clinica.com', senha: 'Temp@1234', perfil: 'atendente',
    });
    expect(usuarios.perfis.get(uid)).toBe('atendente');
    await gestao.definirStatus(gestor, uid, false);
    expect(usuarios.ativos.get(uid)).toBe(false);
  });

  it('valida campos, e-mail repetido e permissões', async () => {
    const { gestao } = await cenario();
    await expect(gestao.criarFuncionario(gestor, { nome: 'X', email: 'x', senha: '1', perfil: 'tutor' })).rejects.toBeInstanceOf(ErroValidacao);
    await gestao.criarFuncionario(gestor, { nome: 'Dr. Caio', email: 'caio@c.com', senha: '12345678', perfil: 'veterinario' });
    await expect(
      gestao.criarFuncionario(gestor, { nome: 'Outro Nome', email: 'caio@c.com', senha: '12345678', perfil: 'auxiliar' }),
    ).rejects.toMatchObject({ codigo: 'EMAIL_JA_CADASTRADO' });
    await expect(gestao.criarFuncionario(atendente, { nome: 'A B', email: 'a@b.com', senha: '12345678', perfil: 'gestor' }))
      .rejects.toMatchObject({ codigo: 'SEM_PERMISSAO' });
    await expect(gestao.definirStatus(gestor, 'gestor1', false)).rejects.toMatchObject({ codigo: 'OPERACAO_INVALIDA' });
    await expect(gestao.definirStatus(gestor, 'tutorA', false)).rejects.toMatchObject({ codigo: 'OPERACAO_INVALIDA' });
  });
});

describe('datas em São Paulo', () => {
  it('converte o instante para a data local e soma dias', () => {
    expect(dataEmSaoPaulo(new Date('2026-11-07T01:00:00Z'))).toBe('2026-11-06');
    expect(somarDias('2026-12-28', 7)).toBe('2027-01-04');
  });
});
