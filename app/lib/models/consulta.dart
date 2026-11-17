import 'package:cloud_firestore/cloud_firestore.dart';

class Consulta {
  final String id;
  final String animalId;
  final String animalNome;
  final String data; // AAAA-MM-DD
  final String horario; // HH:mm
  final String local;
  final String status; // agendada | cancelada | realizada

  const Consulta({
    required this.id,
    required this.animalId,
    required this.animalNome,
    required this.data,
    required this.horario,
    required this.local,
    required this.status,
  });

  factory Consulta.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data();
    return Consulta(
      id: doc.id,
      animalId: (m['animalId'] ?? '') as String,
      animalNome: (m['animalNome'] ?? '') as String,
      data: (m['data'] ?? '') as String,
      horario: (m['horario'] ?? '') as String,
      local: (m['local'] ?? 'Hospital PetConnect') as String,
      status: (m['status'] ?? 'agendada') as String,
    );
  }

  /// "AAAA-MM-DD HH:mm": serve para ordenar e comparar com agora.
  String get chave => '$data $horario';

  String get statusRotulo {
    switch (status) {
      case 'cancelada':
        return 'Cancelada';
      case 'realizada':
        return 'Realizada';
      default:
        return 'Agendada';
    }
  }
}
