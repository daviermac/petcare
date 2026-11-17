// Mesmas regras de validação da API (api/src/domain/validacoes.ts),
// para avisar o usuário antes de chamar o servidor (RNF09).

String soDigitos(String v) => v.replaceAll(RegExp(r'\D'), '');

bool cpfValido(String valor) {
  final cpf = soDigitos(valor);
  if (cpf.length != 11 || RegExp(r'^(\d)\1{10}$').hasMatch(cpf)) return false;
  int digito(String base, int pesoInicial) {
    var soma = 0;
    for (var i = 0; i < base.length; i++) {
      soma += int.parse(base[i]) * (pesoInicial - i);
    }
    final resto = (soma * 10) % 11;
    return resto == 10 ? 0 : resto;
  }

  return digito(cpf.substring(0, 9), 10) == int.parse(cpf[9]) &&
      digito(cpf.substring(0, 10), 11) == int.parse(cpf[10]);
}

/// Telefone com DDD: 10 (fixo) ou 11 (celular) dígitos.
bool telefoneValido(String valor) {
  final tel = soDigitos(valor);
  if (tel.length != 10 && tel.length != 11) return false;
  if (int.parse(tel.substring(0, 2)) < 11) return false;
  return tel.length == 10 || tel[2] == '9';
}

bool emailValido(String valor) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(valor.trim());

bool nomeCompletoValido(String valor) {
  final nome = valor.trim().replaceAll(RegExp(r'\s+'), ' ');
  return nome.split(' ').length >= 2 && nome.length <= 100;
}
