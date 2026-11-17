import 'package:cloud_firestore/cloud_firestore.dart';

class Notificacao {
  final String id;
  final String titulo;
  final String corpo;
  final bool lida;
  final DateTime criadoEm;

  const Notificacao({
    required this.id,
    required this.titulo,
    required this.corpo,
    required this.lida,
    required this.criadoEm,
  });

  factory Notificacao.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data();
    final criado = m['criadoEm'];
    return Notificacao(
      id: doc.id,
      titulo: (m['titulo'] ?? '') as String,
      corpo: (m['corpo'] ?? '') as String,
      lida: m['lida'] == true,
      criadoEm: criado is Timestamp
          ? criado.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
