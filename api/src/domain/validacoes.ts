// Validações puras dos dados de entrada (RF01, RF04, RNF09).
import { ErroValidacao } from './erros';
import { Especie } from './entidades';

export const somenteDigitos = (v: string): string => (v ?? '').replace(/\D/g, '');

export function cpfValido(valor: string): boolean {
  const cpf = somenteDigitos(valor);
  if (cpf.length !== 11 || /^(\d)\1{10}$/.test(cpf)) return false;
  const digito = (base: string, pesoInicial: number): number => {
    let soma = 0;
    for (let i = 0; i < base.length; i++) soma += Number(base[i]) * (pesoInicial - i);
    const resto = (soma * 10) % 11;
    return resto === 10 ? 0 : resto;
  };
  const d1 = digito(cpf.slice(0, 9), 10);
  const d2 = digito(cpf.slice(0, 10), 11);
  return d1 === Number(cpf[9]) && d2 === Number(cpf[10]);
}

/** Telefone com DDD: 10 (fixo) ou 11 (celular) dígitos, DDD entre 11 e 99. */
export function telefoneValido(valor: string): boolean {
  const tel = somenteDigitos(valor);
  if (tel.length !== 10 && tel.length !== 11) return false;
  if (Number(tel.slice(0, 2)) < 11) return false;
  return tel.length === 10 || tel[2] === '9';
}

export function emailValido(valor: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test((valor ?? '').trim());
}

export interface DadosTutor {
  nome: string;
  cpf: string;
  telefone: string;
  email: string;
}

/** Valida e normaliza os dados do tutor. Lança ErroValidacao com todos os campos inválidos. */
export function validarTutor(entrada: Partial<DadosTutor>): DadosTutor {
  const erros: Record<string, string> = {};
  const nome = (entrada.nome ?? '').trim().replace(/\s+/g, ' ');
  if (nome.split(' ').length < 2 || nome.length > 100) erros.nome = 'Informe nome e sobrenome.';
  if (!cpfValido(entrada.cpf ?? '')) erros.cpf = 'CPF inválido.';
  if (!telefoneValido(entrada.telefone ?? '')) erros.telefone = 'Telefone inválido. Use DDD + número.';
  if (!emailValido(entrada.email ?? '')) erros.email = 'E-mail inválido.';
  if (Object.keys(erros).length) throw new ErroValidacao(erros);
  return {
    nome,
    cpf: somenteDigitos(entrada.cpf!),
    telefone: somenteDigitos(entrada.telefone!),
    email: entrada.email!.trim().toLowerCase(),
  };
}

export interface DadosAnimal {
  nome: string;
  especie: Especie;
  raca: string;
  idade: number;
}

export function validarAnimal(entrada: Partial<DadosAnimal>): DadosAnimal {
  const erros: Record<string, string> = {};
  const nome = (entrada.nome ?? '').trim();
  if (!nome || nome.length > 60) erros.nome = 'Informe o nome do animal.';
  if (!['cachorro', 'gato', 'outro'].includes(entrada.especie as string)) {
    erros.especie = 'Selecione a espécie.';
  }
  const raca = (entrada.raca ?? '').trim();
  if (raca.length > 60) erros.raca = 'Raça muito longa.';
  const idade = Number(entrada.idade);
  if (!Number.isInteger(idade) || idade < 0 || idade > 40) erros.idade = 'Idade inválida.';
  if (Object.keys(erros).length) throw new ErroValidacao(erros);
  return { nome, especie: entrada.especie as Especie, raca: raca || 'sem raça definida', idade };
}
