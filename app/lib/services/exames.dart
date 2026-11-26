import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';

class ExamesService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static Future<void> enviar({
    required String animalId,
    required PlatformFile arquivo,
  }) async {
    final extensao = arquivo.extension?.toLowerCase();

    const extensoesPermitidas = ['pdf', 'jpg', 'jpeg', 'png'];

    if (extensao == null || !extensoesPermitidas.contains(extensao)) {
      throw Exception('Selecione um arquivo PDF, JPG ou PNG.');
    }

    final bytes = await arquivo.readAsBytes();

    if (bytes.length > 10 * 1024 * 1024) {
      throw Exception('O arquivo deve ter no máximo 10 MB.');
    }

    final nomeSeguro = arquivo.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

    final nomeFinal = '${DateTime.now().millisecondsSinceEpoch}_$nomeSeguro';

    final referencia = _storage.ref('exames/$animalId/$nomeFinal');

    final tipoConteudo = switch (extensao) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      _ => 'application/octet-stream',
    };

    await referencia.putData(
      bytes,
      SettableMetadata(
        contentType: tipoConteudo,
        customMetadata: {'nomeOriginal': arquivo.name},
      ),
    );
  }

  static Future<List<Reference>> listar(String animalId) async {
    final pasta = _storage.ref('exames/$animalId');
    final resultado = await pasta.listAll();

    return resultado.items;
  }

  static Future<String> obterUrl(Reference referencia) {
    return referencia.getDownloadURL();
  }
}
