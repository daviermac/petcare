import 'package:flutter/material.dart';

import '../core/erros.dart';
import '../core/formatadores.dart';
import '../core/tema.dart';
import '../models/consulta.dart';
import '../services/api.dart';
import '../widgets/componentes.dart';

/// HU04 (detalhes) e HU05 (cancelamento com confirmação).
/// Fecha com true quando a consulta é cancelada.
class DetalheConsultaScreen extends StatefulWidget {
  final Consulta consulta;
  const DetalheConsultaScreen({super.key, required this.consulta});

  @override
  State<DetalheConsultaScreen> createState() => _DetalheConsultaScreenState();
}

class _DetalheConsultaScreenState extends State<DetalheConsultaScreen> {
  bool _cancelando = false;

  Future<void> _cancelar() async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar esta consulta?'),
        content: const Text('O horário será liberado para outros tutores.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Manter consulta'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Cores.erro),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sim, cancelar consulta'),
          ),
        ],
      ),
    );
    if (confirmou != true) return;

    setState(() => _cancelando = true);
    try {
      await Api.cancelarConsulta(widget.consulta.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _cancelando = false);
      mostrarMensagem(context, traduzirErro(e).mensagem);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.consulta;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Cores.fundo,
        title: const Text('Detalhes da consulta'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            LinhaDetalhe(rotulo: 'Animal', valor: c.animalNome),
            LinhaDetalhe(rotulo: 'Data', valor: dataBr(c.data)),
            LinhaDetalhe(rotulo: 'Horário', valor: c.horario),
            LinhaDetalhe(rotulo: 'Local', valor: c.local),
            LinhaDetalhe(rotulo: 'Situação', valor: c.statusRotulo),
            const SizedBox(height: 24),
            if (c.status == 'agendada')
              BotaoPrimario(
                texto: 'Cancelar consulta',
                perigo: true,
                carregando: _cancelando,
                onPressed: _cancelar,
              ),
          ],
        ),
      ),
    );
  }
}
