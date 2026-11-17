import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

const _semConexao =
    'Não foi possível conectar ao servidor. Confira se os emuladores estão rodando.';

/// Erro já traduzido para mostrar ao usuário.
class ErroApp {
  final String mensagem;

  /// Mensagem por campo (chave = nome do campo), para mostrar abaixo de cada input.
  final Map<String, String> campos;

  /// Código de negócio da API (ex.: HORARIO_INDISPONIVEL).
  final String? codigo;

  const ErroApp(this.mensagem, {this.campos = const {}, this.codigo});
}

ErroApp traduzirErro(Object e) {
  if (e is FirebaseFunctionsException) {
    final campos = <String, String>{};
    String? codigo;
    final detalhes = e.details;
    if (detalhes is Map) {
      final c = detalhes['campos'];
      if (c is Map) {
        c.forEach((k, v) => campos[k.toString()] = v.toString());
      }
      codigo = detalhes['codigo']?.toString();
    }
    if (codigo == 'CPF_JA_CADASTRADO') {
      return const ErroApp(
        'Este CPF já está cadastrado.',
        campos: {'cpf': 'CPF já cadastrado.'},
        codigo: 'CPF_JA_CADASTRADO',
      );
    }
    switch (e.code) {
      case 'invalid-argument':
        return ErroApp(
          campos.isEmpty
              ? (e.message ?? 'Dados inválidos.')
              : 'Confira os campos destacados.',
          campos: campos,
          codigo: codigo,
        );
      case 'already-exists':
        if (codigo == 'HORARIO_INDISPONIVEL') {
          return ErroApp(
            'Esse horário acabou de ser ocupado. Escolha outro horário.',
            codigo: codigo,
          );
        }
        return ErroApp(e.message ?? 'Este registro já existe.', codigo: codigo);
      case 'failed-precondition':
        if (codigo == 'CONSULTA_NAO_ATIVA') {
          return ErroApp('Esta consulta não está mais ativa.', codigo: codigo);
        }
        return ErroApp(e.message ?? 'Ação não permitida agora.', codigo: codigo);
      case 'permission-denied':
        return const ErroApp('Você não tem permissão para esta ação.');
      case 'not-found':
        return ErroApp(e.message ?? 'Registro não encontrado.', codigo: codigo);
      case 'unauthenticated':
        return const ErroApp('Sua sessão expirou. Entre novamente.');
      case 'unavailable':
      case 'deadline-exceeded':
        return const ErroApp(_semConexao);
      default:
        return ErroApp(e.message ?? 'Erro inesperado. Tente novamente.');
    }
  }

  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'invalid-email':
        return const ErroApp(
          'E-mail inválido.',
          campos: {'email': 'E-mail inválido.'},
        );
      case 'email-already-in-use':
        return const ErroApp(
          'Este e-mail já está em uso.',
          campos: {'email': 'Este e-mail já está em uso.'},
        );
      case 'weak-password':
        return const ErroApp(
          'Senha muito fraca.',
          campos: {'senha': 'A senha precisa ter pelo menos 6 caracteres.'},
        );
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return const ErroApp('E-mail ou senha incorretos.');
      case 'user-disabled':
        return const ErroApp('Esta conta foi desativada.');
      case 'too-many-requests':
        return const ErroApp(
          'Muitas tentativas. Aguarde um pouco e tente de novo.',
        );
      case 'network-request-failed':
        return const ErroApp(_semConexao);
      default:
        return ErroApp(e.message ?? 'Não foi possível autenticar.');
    }
  }

  return const ErroApp('Não foi possível concluir. Tente novamente.');
}
