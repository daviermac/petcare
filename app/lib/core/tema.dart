import 'package:flutter/material.dart';

/// Cores do protótipo do PetConnect.
class Cores {
  static const primaria = Color(0xFF0F5C5C);
  static const destaque = Color(0xFFF2B632);
  static const fundo = Color(0xFFF6FBF9);
  static const fundoSuave = Color(0xFFE4F1EC);
  static const texto = Color(0xFF12302F);
  static const textoSuave = Color(0xFF5B7573);
  static const linha = Color(0xFFCFE2DC);
  static const erro = Color(0xFFB3261E);
  static const erroFundo = Color(0xFFFBE9E7);
  static const sucesso = Color(0xFF1E7A4F);
  static const sucessoFundo = Color(0xFFE3F4EA);
}

class Estilos {
  static const titulo = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    color: Cores.texto,
    height: 1.15,
  );
  static const secao = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: Cores.texto,
  );
  static const rotulo = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: Cores.texto,
  );
  static const suave = TextStyle(fontSize: 14, color: Cores.textoSuave);
  static const erro = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: Cores.erro,
  );
}

ThemeData criarTema() {
  final esquema = ColorScheme.fromSeed(
    seedColor: Cores.primaria,
    primary: Cores.primaria,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    scaffoldBackgroundColor: Cores.fundo,
  );
}
