// Casos de uso do prontuário (RF13–RF16, RF21, RF26, RNF16).
import { dataEmSaoPaulo } from '../domain/agenda';
import {
  DadosAtendimento,
  DadosPrescricao,
  DadosRegistro,
  DadosVacina,
  RegistroMedico,
  TipoRegistro,
} from '../domain/entidades';
import { ErroNegocio, ErroValidacao } from '../domain/erros';
import { AUTORES_PERMITIDOS, horariosDeMedicacao, validarRegistro } from '../domain/prontuario';
import { AnimalRepositorio, ConsultaRepositorio, RegistroRepositorio, Solicitante } from './portas';

const TIPOS: TipoRegistro[] = ['atendimento', 'prescricao', 'vacina', 'procedimento'];

export interface HistoricoAnimal {
  animal: { id: string; nome: string; especie: string; raca: string; idade: number };
  registros: RegistroMedico[];
}

export class ProntuarioServico {
  constructor(
    private readonly registros: RegistroRepositorio,
    private readonly animais: AnimalRepositorio,
    private readonly consultas: ConsultaRepositorio,
    private readonly relogio: () => Date = () => new Date(),
  ) {}

  /** Registra atendimento, prescrição, vacina ou procedimento no prontuário. */
  async registrar(
    solicitante: Solicitante,
    tipo: TipoRegistro,
    entrada: Record<string, unknown>,
  ): Promise<RegistroMedico & { horariosMedicacao?: string[] }> {
    if (!TIPOS.includes(tipo)) throw new ErroValidacao({ tipo: 'Tipo de registro inválido.' });
    if (!AUTORES_PERMITIDOS[tipo].includes(solicitante.perfil)) {
      throw new ErroNegocio('SEM_PERMISSAO', 'Seu perfil não pode fazer este registro.');
    }
    const agora = this.relogio();
    const animalId = typeof entrada.animalId === 'string' ? entrada.animalId : '';
    const animal = animalId ? await this.animais.buscarPorId(animalId) : null;
    if (!animal) throw new ErroNegocio('NAO_ENCONTRADO', 'Animal não encontrado.');

    const dados = validarRegistro(tipo, entrada, dataEmSaoPaulo(agora));

    // Atendimento ligado a uma consulta: confere a consulta antes de gravar.
    const consultaId = tipo === 'atendimento' ? (dados as DadosAtendimento).consultaId : undefined;
    if (consultaId) {
      const consulta = await this.consultas.buscarPorId(consultaId);
      if (!consulta || consulta.animalId !== animal.id) {
        throw new ErroNegocio('NAO_ENCONTRADO', 'Consulta não encontrada para este animal.');
      }
      if (consulta.status !== 'agendada') {
        throw new ErroNegocio('CONSULTA_NAO_ATIVA', 'Esta consulta não está mais agendada.');
      }
    }

    const registro = await this.registros.criar({
      tipo,
      animalId: animal.id,
      tutorId: animal.tutorId,
      autorId: solicitante.uid,
      autorNome: solicitante.nome ?? solicitante.email ?? solicitante.uid,
      autorPerfil: solicitante.perfil,
      dados,
      proximaDose: tipo === 'vacina' ? (dados as DadosVacina).proximaDose : null,
      criadoEm: agora,
      versao: 1,
      historico: [],
    });
    if (consultaId) await this.consultas.marcarRealizada(consultaId);

    if (tipo === 'prescricao') {
      const p = dados as DadosPrescricao;
      const horarios = horariosDeMedicacao(agora, p.frequenciaHoras, p.duracaoDias);
      return { ...registro, horariosMedicacao: horarios.map((h) => h.toISOString()) };
    }
    return registro;
  }

  /** Histórico médico do animal em ordem cronológica (RF13). Veterinário ou tutor dono. */
  async historico(solicitante: Solicitante, animalId: string): Promise<HistoricoAnimal> {
    const animal = animalId ? await this.animais.buscarPorId(animalId) : null;
    if (!animal) throw new ErroNegocio('NAO_ENCONTRADO', 'Animal não encontrado.');
    const pode =
      solicitante.perfil === 'veterinario' ||
      (solicitante.perfil === 'tutor' && animal.tutorId === solicitante.uid);
    if (!pode) throw new ErroNegocio('SEM_PERMISSAO', 'Sem permissão para ver este histórico.');

    let registros = await this.registros.listarPorAnimal(animal.id);
    // O tutor vê o conteúdo atual, sem o histórico de correções da equipe.
    if (solicitante.perfil === 'tutor') registros = registros.map((r) => ({ ...r, historico: [] }));
    const { id, nome, especie, raca, idade } = animal;
    return { animal: { id, nome, especie, raca, idade }, registros };
  }

  /** Corrige um registro guardando a versão anterior (RNF16). Registros nunca são excluídos. */
  async corrigir(solicitante: Solicitante, registroId: string, entrada: Record<string, unknown>): Promise<RegistroMedico> {
    const registro = registroId ? await this.registros.buscarPorId(registroId) : null;
    if (!registro) throw new ErroNegocio('NAO_ENCONTRADO', 'Registro não encontrado.');
    if (!AUTORES_PERMITIDOS[registro.tipo].includes(solicitante.perfil)) {
      throw new ErroNegocio('SEM_PERMISSAO', 'Seu perfil não pode corrigir este registro.');
    }
    // Mantém o vínculo com a consulta original: correção não reabre nem troca consulta.
    const base: Record<string, unknown> = { ...entrada };
    if (registro.tipo === 'atendimento') {
      base.consultaId = (registro.dados as DadosAtendimento).consultaId;
    }
    const dados: DadosRegistro = validarRegistro(registro.tipo, base, dataEmSaoPaulo(this.relogio()));
    const proximaDose = registro.tipo === 'vacina' ? (dados as DadosVacina).proximaDose : null;
    return this.registros.corrigir(
      registro.id,
      dados,
      proximaDose,
      { id: solicitante.uid, nome: solicitante.nome ?? solicitante.email ?? solicitante.uid },
      this.relogio(),
    );
  }
}
