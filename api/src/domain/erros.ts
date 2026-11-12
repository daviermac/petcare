// Erros de domínio. A camada de apresentação converte para HttpsError.

/** Dados inválidos: um erro por campo, para o app mostrar abaixo de cada campo (RNF09). */
export class ErroValidacao extends Error {
  constructor(public readonly campos: Record<string, string>) {
    super('Dados inválidos');
    this.name = 'ErroValidacao';
  }
}

export type CodigoErroNegocio =
  | 'HORARIO_INDISPONIVEL'
  | 'NAO_ENCONTRADO'
  | 'SEM_PERMISSAO'
  | 'CPF_JA_CADASTRADO'
  | 'CONSULTA_NAO_ATIVA'
  | 'EMAIL_JA_CADASTRADO'
  | 'OPERACAO_INVALIDA';

export class ErroNegocio extends Error {
  constructor(public readonly codigo: CodigoErroNegocio, mensagem: string) {
    super(mensagem);
    this.name = 'ErroNegocio';
  }
}
