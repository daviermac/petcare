class ItemAgenda {
  final String consultaId;
  final String horario;
  final String status;
  final String animalId;
  final String animalNome;
  final String especie;
  final String tutorNome;
  final String local;

  const ItemAgenda({
    required this.consultaId,
    required this.horario,
    required this.status,
    required this.animalId,
    required this.animalNome,
    required this.especie,
    required this.tutorNome,
    required this.local,
  });

  factory ItemAgenda.fromMap(Map<String, dynamic> mapa) {
    final animal = mapa['animal'] is Map
        ? Map<String, dynamic>.from(mapa['animal'] as Map)
        : <String, dynamic>{};

    return ItemAgenda(
      consultaId: mapa['consultaId']?.toString() ?? '',
      horario: mapa['horario']?.toString() ?? '',
      status: mapa['status']?.toString() ?? '',
      animalId: animal['id']?.toString() ?? '',
      animalNome: animal['nome']?.toString() ?? 'Animal',
      especie: animal['especie']?.toString() ?? '',
      tutorNome: mapa['tutorNome']?.toString() ?? 'Tutor',
      local: mapa['local']?.toString() ?? '',
    );
  }

  String get statusRotulo {
    switch (status) {
      case 'agendada':
        return 'Agendada';
      case 'cancelada':
        return 'Cancelada';
      case 'realizada':
        return 'Realizada';
      default:
        return status;
    }
  }
}
