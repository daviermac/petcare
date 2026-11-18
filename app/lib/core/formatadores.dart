const _diasSemana = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

String _dois(int n) => n.toString().padLeft(2, '0');

/// DateTime -> "AAAA-MM-DD" (formato que a API espera).
String dataIso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${_dois(d.month)}-${_dois(d.day)}';

/// "2026-11-16" -> "16/11/2026"
String dataBr(String iso) {
  final p = iso.split('-');
  if (p.length != 3) return iso;
  return '${p[2]}/${p[1]}/${p[0]}';
}

/// "2026-11-16" -> "Seg 16/11"
String diaCurtoIso(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return diaCurto(d);
}

String diaCurto(DateTime d) =>
    '${_diasSemana[d.weekday - 1]} ${_dois(d.day)}/${_dois(d.month)}';

String horaTexto(DateTime d) => '${_dois(d.hour)}:${_dois(d.minute)}';

/// "AAAA-MM-DD HH:mm" de agora, para comparar com a chave de uma consulta.
String agoraComoChave() {
  final n = DateTime.now();
  return '${dataIso(n)} ${horaTexto(n)}';
}

/// Próximos dias úteis (segunda a sexta), a partir de hoje.
List<DateTime> proximosDiasUteis(int quantidade) {
  final lista = <DateTime>[];
  final hoje = DateTime.now();
  var d = DateTime(hoje.year, hoje.month, hoje.day);
  while (lista.length < quantidade) {
    if (d.weekday <= 5) lista.add(d);
    d = d.add(const Duration(days: 1));
  }
  return lista;
}

String inicialDe(String texto) {
  final t = texto.trim();
  return t.isEmpty ? '?' : t[0].toUpperCase();
}
