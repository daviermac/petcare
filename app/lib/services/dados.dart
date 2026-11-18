import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/animal.dart';
import '../models/consulta.dart';
import '../models/notificacao.dart';

/// Leituras direto no Firestore (as regras garantem que o tutor só vê o que é dele).
class Dados {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String get uid => FirebaseAuth.instance.currentUser!.uid;

  static Stream<String?> nomeTutor() {
    return _db
        .collection('tutores')
        .doc(uid)
        .snapshots()
        .map((d) => d.data()?['nome'] as String?);
  }

  static Stream<List<Animal>> animais() {
    return _db
        .collection('animais')
        .where('tutorId', isEqualTo: uid)
        .snapshots()
        .map((s) {
      final lista = s.docs.map(Animal.fromDoc).toList();
      lista.sort(
        (a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()),
      );
      return lista;
    });
  }

  /// Ordenadas por data e horário (a ordenação é feita aqui, sem precisar de índice).
  static Stream<List<Consulta>> consultas() {
    return _db
        .collection('consultas')
        .where('tutorId', isEqualTo: uid)
        .snapshots()
        .map((s) {
      final lista = s.docs.map(Consulta.fromDoc).toList();
      lista.sort((a, b) => a.chave.compareTo(b.chave));
      return lista;
    });
  }

  static Stream<List<Notificacao>> notificacoes() {
    return _db
        .collection('notificacoes')
        .where('tutorId', isEqualTo: uid)
        .snapshots()
        .map((s) {
      final lista = s.docs.map(Notificacao.fromDoc).toList();
      lista.sort((a, b) => b.criadoEm.compareTo(a.criadoEm));
      return lista;
    });
  }

  static Future<void> marcarNotificacaoLida(String id) {
    return _db.collection('notificacoes').doc(id).update({'lida': true});
  }
}
