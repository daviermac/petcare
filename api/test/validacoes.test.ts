import { ErroValidacao } from '../src/domain/erros';
import { cpfValido, telefoneValido, validarAnimal, validarTutor } from '../src/domain/validacoes';

describe('cpfValido', () => {
  it('aceita CPF válido com ou sem máscara', () => {
    expect(cpfValido('529.982.247-25')).toBe(true);
    expect(cpfValido('52998224725')).toBe(true);
  });
  it('recusa dígitos repetidos, tamanho errado e dígito verificador errado', () => {
    expect(cpfValido('11111111111')).toBe(false);
    expect(cpfValido('1234567890')).toBe(false);
    expect(cpfValido('52998224724')).toBe(false);
  });
});

describe('telefoneValido', () => {
  it('aceita celular e fixo com DDD', () => {
    expect(telefoneValido('(12) 99102-1830')).toBe(true);
    expect(telefoneValido('1233334444')).toBe(true);
  });
  it('recusa sem DDD ou celular sem 9', () => {
    expect(telefoneValido('991021830')).toBe(false);
    expect(telefoneValido('12891021830')).toBe(false);
  });
});

describe('validarTutor (RF01 / RNF09)', () => {
  it('normaliza dados válidos', () => {
    const t = validarTutor({
      nome: '  Ana   Souza ',
      cpf: '529.982.247-25',
      telefone: '(12) 99102-1830',
      email: 'Ana@Email.com ',
    });
    expect(t).toEqual({ nome: 'Ana Souza', cpf: '52998224725', telefone: '12991021830', email: 'ana@email.com' });
  });

  it('retorna uma mensagem para cada campo inválido', () => {
    try {
      validarTutor({ nome: 'Ana', cpf: '123', telefone: '1', email: 'x' });
      fail('deveria lançar');
    } catch (e) {
      expect(e).toBeInstanceOf(ErroValidacao);
      expect(Object.keys((e as ErroValidacao).campos).sort()).toEqual(['cpf', 'email', 'nome', 'telefone']);
    }
  });
});

describe('validarAnimal (RF04 / RNF04)', () => {
  it('aceita animal válido e preenche raça padrão', () => {
    expect(validarAnimal({ nome: 'Apolo', especie: 'gato', raca: '', idade: 6 })).toEqual({
      nome: 'Apolo',
      especie: 'gato',
      raca: 'sem raça definida',
      idade: 6,
    });
  });
  it('recusa idade negativa e espécie desconhecida', () => {
    expect(() => validarAnimal({ nome: 'Rex', especie: 'peixe' as never, idade: -1 })).toThrow(ErroValidacao);
  });
});
