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

/// Valor em reais digitado pelo usuário ("150", "150,50", "1.234,56").
/// Devolve o número ou null se for inválido. Vazio devolve null.
double? lerValorReais(String texto) {
  var t = texto.trim().replaceAll('R\$', '').replaceAll(' ', '');
  if (t.isEmpty) return null;
  if (t.contains(',')) t = t.replaceAll('.', '').replaceAll(',', '.');
  final v = double.tryParse(t);
  if (v == null || v <= 0 || v > 100000) return null;
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(t)) return null;
  return v;
}

/// Inteiro entre [min] e [max] (inclusive) ou null.
int? lerInteiro(String texto, int min, int max) {
  final v = int.tryParse(texto.trim());
  if (v == null || v < min || v > max) return null;
  return v;
}

/// Data no formato dd/mm/aaaa -> "AAAA-MM-DD" (ou null se inválida).
String? lerDataBr(String texto) {
  final m = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(texto.trim());
  if (m == null) return null;
  final dia = int.parse(m.group(1)!);
  final mes = int.parse(m.group(2)!);
  final ano = int.parse(m.group(3)!);
  final d = DateTime(ano, mes, dia);
  if (d.year != ano || d.month != mes || d.day != dia) return null;
  return '${m.group(3)}-${m.group(2)}-${m.group(1)}';
}
