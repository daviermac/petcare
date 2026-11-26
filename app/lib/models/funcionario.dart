import 'package:cloud_firestore/cloud_firestore.dart';

/// Funcionário da clínica (coleção `usuarios`, perfil diferente de tutor) — RF32.
class Funcionario {
  final String uid;
  final String nome;
  final String email;
  final String perfil;
  final bool ativo;

  const Funcionario({
    required this.uid,
    required this.nome,
    required this.email,
    required this.perfil,
    required this.ativo,
  });

  factory Funcionario.fromMap(String uid, Map<String, dynamic> m) {
    return Funcionario(
      uid: uid,
      nome: m['nome']?.toString() ?? m['email']?.toString() ?? 'Sem nome',
      email: m['email']?.toString() ?? '',
      perfil: m['perfil']?.toString() ?? '',
      ativo: m['ativo'] != false,
    );
  }

  factory Funcionario.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
      Funcionario.fromMap(doc.id, doc.data());
}

const perfisFuncionario = ['atendente', 'veterinario', 'auxiliar', 'gestor'];

String perfilRotulo(String perfil) => switch (perfil) {
  'atendente' => 'Atendente',
  'veterinario' => 'Veterinário(a)',
  'auxiliar' => 'Auxiliar',
  'gestor' => 'Gestor(a)',
  'tutor' => 'Tutor',
  _ => perfil,
};
