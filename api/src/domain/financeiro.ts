// Regras do financeiro: valor da consulta, formas de pagamento e período dos relatórios (RF30, RF31).
import { FormaPagamento } from './entidades';
import { ErroValidacao } from './erros';

/**
 * Valor padrão da consulta, em centavos. O documento de requisitos não define o preço,
 * então o veterinário pode informar outro valor no atendimento (campo "valor", em reais).
 */
export const VALOR_CONSULTA_PADRAO_CENTAVOS = 15000;

/** Maior valor aceito para uma cobrança (R$ 100.000,00), para evitar erro de digitação. */
export const VALOR_MAXIMO_CENTAVOS = 10_000_000;

export const FORMAS_PAGAMENTO: readonly FormaPagamento[] = ['dinheiro', 'pix', 'cartao_debito', 'cartao_credito'];

/** Relatórios aceitam no máximo um ano por vez. */
export const PERIODO_MAXIMO_DIAS = 366;

/**
 * Converte o valor informado (reais, ex.: 180 ou 180.5) em centavos.
 * Vazio ou ausente → valor padrão da consulta.
 */
export function valorEmCentavos(valor: unknown): number {
  if (valor === undefined || valor === null || valor === '') return VALOR_CONSULTA_PADRAO_CENTAVOS;
  const numero = typeof valor === 'string' ? Number(valor.replace(',', '.')) : Number(valor);
  if (!Number.isFinite(numero) || numero <= 0) {
    throw new ErroValidacao({ valor: 'Informe um valor maior que zero.' });
  }
  const centavos = Math.round(numero * 100);
  if (Math.abs(numero * 100 - centavos) > 1e-6) {
    throw new ErroValidacao({ valor: 'Use no máximo 2 casas decimais.' });
  }
  if (centavos > VALOR_MAXIMO_CENTAVOS) throw new ErroValidacao({ valor: 'Valor acima do permitido.' });
  return centavos;
}

export function validarFormaPagamento(forma: unknown): FormaPagamento {
  if (!FORMAS_PAGAMENTO.includes(forma as FormaPagamento)) {
    throw new ErroValidacao({ formaPagamento: 'Escolha dinheiro, pix, cartao_debito ou cartao_credito.' });
  }
  return forma as FormaPagamento;
}

function dataValida(d: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(d ?? '')) return false;
  const x = new Date(`${d}T12:00:00Z`);
  return !isNaN(x.getTime()) && x.toISOString().slice(0, 10) === d;
}

/** Valida um período inclusivo AAAA-MM-DD → AAAA-MM-DD. */
export function validarPeriodo(inicio: string, fim: string): void {
  const erros: Record<string, string> = {};
  if (!dataValida(inicio)) erros.inicio = 'Data inválida.';
  if (!dataValida(fim)) erros.fim = 'Data inválida.';
  if (!Object.keys(erros).length) {
    if (fim < inicio) erros.fim = 'O fim deve ser igual ou depois do início.';
    else {
      const dias = (Date.parse(`${fim}T12:00:00Z`) - Date.parse(`${inicio}T12:00:00Z`)) / 86_400_000 + 1;
      if (dias > PERIODO_MAXIMO_DIAS) erros.fim = 'O período pode ter no máximo 1 ano.';
    }
  }
  if (Object.keys(erros).length) throw new ErroValidacao(erros);
}
