import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/formatadores.dart';
import '../core/tema.dart';

class LogoPetConnect extends StatelessWidget {
  final double tamanho;
  const LogoPetConnect({super.key, this.tamanho = 34});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: tamanho,
          height: tamanho,
          decoration: BoxDecoration(
            color: Cores.destaque,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(tamanho / 2),
              topRight: Radius.circular(tamanho / 2),
              bottomRight: Radius.circular(tamanho / 2),
              bottomLeft: const Radius.circular(8),
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'PetConnect',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Cores.primaria,
          ),
        ),
      ],
    );
  }
}

class CampoTexto extends StatelessWidget {
  final String rotulo;
  final TextEditingController controller;
  final String? erro;
  final String? dica;
  final TextInputType? teclado;
  final bool senha;
  final bool apenasDigitos;
  final int? maxCaracteres;
  final bool habilitado;
  final TextInputAction? acao;

  const CampoTexto({
    super.key,
    required this.rotulo,
    required this.controller,
    this.erro,
    this.dica,
    this.teclado,
    this.senha = false,
    this.apenasDigitos = false,
    this.maxCaracteres,
    this.habilitado = true,
    this.acao,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        enabled: habilitado,
        obscureText: senha,
        autocorrect: !senha,
        keyboardType: teclado,
        textInputAction: acao,
        maxLength: maxCaracteres,
        inputFormatters:
            apenasDigitos ? [FilteringTextInputFormatter.digitsOnly] : null,
        decoration: InputDecoration(
          labelText: rotulo,
          hintText: dica,
          errorText: erro,
          counterText: '',
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class BotaoPrimario extends StatelessWidget {
  final String texto;
  final VoidCallback? onPressed;
  final bool carregando;
  final bool perigo;

  const BotaoPrimario({
    super.key,
    required this.texto,
    required this.onPressed,
    this.carregando = false,
    this.perigo = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton(
        onPressed: carregando ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: perigo ? Cores.erro : Cores.primaria,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        child: carregando
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : Text(texto),
      ),
    );
  }
}

class BotaoSecundario extends StatelessWidget {
  final String texto;
  final VoidCallback? onPressed;

  const BotaoSecundario({super.key, required this.texto, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Cores.primaria,
          side: const BorderSide(color: Cores.primaria, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        child: Text(texto),
      ),
    );
  }
}

class AvatarInicial extends StatelessWidget {
  final String nome;
  const AvatarInicial({super.key, required this.nome});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Cores.fundoSuave,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        inicialDe(nome),
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: Cores.primaria,
        ),
      ),
    );
  }
}

/// Cartão de lista (animal, consulta...), igual ao do protótipo.
class CartaoLista extends StatelessWidget {
  final String nomeAvatar;
  final String titulo;
  final String subtitulo;
  final Widget? trailing;
  final VoidCallback? onTap;

  const CartaoLista({
    super.key,
    required this.nomeAvatar,
    required this.titulo,
    required this.subtitulo,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Cores.linha),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              AvatarInicial(nome: nomeAvatar),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Cores.texto,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitulo, style: Estilos.suave),
                  ],
                ),
              ),
              if (trailing != null) ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class EstadoVazio extends StatelessWidget {
  final IconData icone;
  final String texto;
  final String? textoBotao;
  final VoidCallback? aoPressionar;

  const EstadoVazio({
    super.key,
    required this.icone,
    required this.texto,
    this.textoBotao,
    this.aoPressionar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Cores.linha, width: 2),
      ),
      child: Column(
        children: [
          Icon(icone, size: 40, color: Cores.textoSuave),
          const SizedBox(height: 10),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Cores.textoSuave, fontSize: 15),
          ),
          if (textoBotao != null && aoPressionar != null) ...[
            const SizedBox(height: 16),
            BotaoPrimario(texto: textoBotao!, onPressed: aoPressionar),
          ],
        ],
      ),
    );
  }
}

class LinhaDetalhe extends StatelessWidget {
  final String rotulo;
  final String valor;
  const LinhaDetalhe({super.key, required this.rotulo, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Cores.linha)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(rotulo, style: Estilos.suave),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              valor,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Cores.texto,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final String status;
  final String rotulo;
  const StatusChip({super.key, required this.status, required this.rotulo});

  @override
  Widget build(BuildContext context) {
    Color fundo = Cores.fundoSuave;
    Color texto = Cores.primaria;
    if (status == 'cancelada') {
      fundo = Cores.erroFundo;
      texto = Cores.erro;
    } else if (status == 'realizada') {
      fundo = Cores.sucessoFundo;
      texto = Cores.sucesso;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        rotulo,
        style: TextStyle(color: texto, fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}

void mostrarMensagem(BuildContext context, String mensagem) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(mensagem)));
}
