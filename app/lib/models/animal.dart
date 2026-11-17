import 'package:cloud_firestore/cloud_firestore.dart';

class Animal {
  final String id;
  final String nome;
  final String especie; // cachorro | gato | outro
  final String raca;
  final int idade;

  const Animal({
    required this.id,
    required this.nome,
    required this.especie,
    required this.raca,
    required this.idade,
  });

  factory Animal.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data();
    return Animal(
      id: doc.id,
      nome: (m['nome'] ?? '') as String,
      especie: (m['especie'] ?? 'outro') as String,
      raca: (m['raca'] ?? '') as String,
      idade: (m['idade'] as num?)?.toInt() ?? 0,
    );
  }

  String get especieRotulo {
    switch (especie) {
      case 'cachorro':
        return 'Cachorro';
      case 'gato':
        return 'Gato';
      default:
        return 'Outro';
    }
  }

  String get idadeRotulo => idade == 1 ? '1 ano' : '$idade anos';
}
