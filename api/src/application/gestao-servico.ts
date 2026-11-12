// Gestão de usuários e funcionários (RF32). Só o gestor.
import { PERFIS_FUNCIONARIO, Perfil } from '../domain/entidades';
import { ErroNegocio, ErroValidacao } from '../domain/erros';
import { emailValido } from '../domain/validacoes';
import { Solicitante, UsuarioGateway } from './portas';

export class GestaoServico {
  constructor(private readonly usuarios: UsuarioGateway) {}

  private exigirGestor(s: Solicitante): void {
    if (s.perfil !== 'gestor') throw new ErroNegocio('SEM_PERMISSAO', 'Somente o gestor pode gerenciar funcionários.');
  }

  async criarFuncionario(
    solicitante: Solicitante,
    entrada: { nome?: string; email?: string; senha?: string; perfil?: string },
  ): Promise<{ uid: string; perfil: Perfil }> {
    this.exigirGestor(solicitante);
    const erros: Record<string, string> = {};
    const nome = (entrada.nome ?? '').trim().replace(/\s+/g, ' ');
    const email = (entrada.email ?? '').trim().toLowerCase();
    const senha = entrada.senha ?? '';
    if (nome.split(' ').length < 2 || nome.length > 100) erros.nome = 'Informe nome e sobrenome.';
    if (!emailValido(email)) erros.email = 'E-mail inválido.';
    if (senha.length < 8) erros.senha = 'A senha temporária precisa de pelo menos 8 caracteres.';
    if (!PERFIS_FUNCIONARIO.includes(entrada.perfil as Perfil)) {
      erros.perfil = 'Perfil deve ser atendente, veterinario, auxiliar ou gestor.';
    }
    if (Object.keys(erros).length) throw new ErroValidacao(erros);

    const perfil = entrada.perfil as Perfil;
    const uid = await this.usuarios.criarFuncionario({ nome, email, senha, perfil });
    return { uid, perfil };
  }

  /** Desativar bloqueia o login; ativar libera de novo (RF32). */
  async definirStatus(solicitante: Solicitante, uid: string, ativo: boolean): Promise<void> {
    this.exigirGestor(solicitante);
    if (!uid) throw new ErroValidacao({ uid: 'Informe o funcionário.' });
    if (typeof ativo !== 'boolean') throw new ErroValidacao({ ativo: 'Informe true ou false.' });
    if (uid === solicitante.uid && !ativo) {
      throw new ErroNegocio('OPERACAO_INVALIDA', 'Você não pode desativar o próprio usuário.');
    }
    const perfil = await this.usuarios.buscarPerfil(uid);
    if (!perfil) throw new ErroNegocio('NAO_ENCONTRADO', 'Usuário não encontrado.');
    if (perfil === 'tutor') throw new ErroNegocio('OPERACAO_INVALIDA', 'Use esta função apenas para funcionários.');
    await this.usuarios.definirAtivo(uid, ativo);
  }
}
