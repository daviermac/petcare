import 'package:flutter/material.dart';

import '../core/formatadores.dart';
import '../core/tema.dart';
import '../models/financeiro.dart';
import '../models/funcionario.dart';
import 'componentes.dart';

// Widgets do perfil Gestor que não dependem do Firebase (testados em test/).

/// Indicador grande (número + rótulo).
class Indicador extends StatelessWidget {
  final String rotulo;
  final String valor;
  final Color? cor;
  const Indicador({super.key, required this.rotulo, required this.valor, this.cor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Cores.linha),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rotulo, style: Estilos.suave),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valor,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: cor ?? Cores.texto),
            ),
          ),
        ],
      ),
    );
  }
}

/// Barras horizontais simples para um agrupamento do relatório.
class BarrasRelatorio extends StatelessWidget {
  final String titulo;
  final List<LinhaRelatorio> linhas;
  final bool emDinheiro;

  const BarrasRelatorio({
    super.key,
    required this.titulo,
    required this.linhas,
    this.emDinheiro = true,
  });

  int _valor(LinhaRelatorio l) => emDinheiro ? l.totalCentavos : l.quantidade;

  @override
  Widget build(BuildContext context) {
    final maior = linhas.fold<int>(0, (m, l) => _valor(l) > m ? _valor(l) : m);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: Estilos.rotulo),
        const SizedBox(height: 8),
        if (linhas.isEmpty) const Text('Sem dados no período.', style: Estilos.suave),
        for (final l in linhas)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(l.rotulo, overflow: TextOverflow.ellipsis)),
                    Text(
                      emDinheiro ? '${moeda(l.totalCentavos)} (${l.quantidade})' : '${l.quantidade}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: maior == 0 ? 0 : _valor(l) / maior,
                    backgroundColor: Cores.fundoSuave,
                    color: Cores.primaria,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Conteúdo da aba de relatórios (RF31, RF33, RF35).
class PainelRelatorios extends StatelessWidget {
  final RelatorioFinanceiro financeiro;
  final RelatorioAtendimentos atendimentos;

  const PainelRelatorios({super.key, required this.financeiro, required this.atendimentos});

  @override
  Widget build(BuildContext context) {
    Widget cartao(List<Widget> filhos) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Cores.linha),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: filhos),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Financeiro', style: Estilos.secao),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.9,
          children: [
            Indicador(rotulo: 'Faturado', valor: moeda(financeiro.faturadoCentavos)),
            Indicador(rotulo: 'Recebido', valor: moeda(financeiro.recebidoCentavos), cor: Cores.sucesso),
            Indicador(rotulo: 'A receber', valor: moeda(financeiro.pendenteCentavos), cor: Cores.erro),
            Indicador(rotulo: 'Ticket médio', valor: moeda(financeiro.ticketMedioCentavos)),
          ],
        ),
        const SizedBox(height: 14),
        cartao([BarrasRelatorio(titulo: 'Recebido por forma de pagamento', linhas: financeiro.porFormaPagamento)]),
        cartao([BarrasRelatorio(titulo: 'Faturamento por veterinário', linhas: financeiro.porVeterinario)]),
        cartao([BarrasRelatorio(titulo: 'Faturamento por dia', linhas: financeiro.porDia)]),
        const SizedBox(height: 6),
        const Text('Atendimentos', style: Estilos.secao),
        const SizedBox(height: 10),
        Indicador(rotulo: 'Total de atendimentos no período', valor: '${atendimentos.total}'),
        const SizedBox(height: 14),
        cartao([
          BarrasRelatorio(
            titulo: 'Atendimentos por veterinário',
            linhas: atendimentos.porVeterinario,
            emDinheiro: false,
          ),
        ]),
      ],
    );
  }
}

/// Lista de funcionários com chave ativo/inativo (RF32).
class ListaFuncionarios extends StatelessWidget {
  final List<Funcionario> funcionarios;
  final String? uidAtual;
  final void Function(Funcionario funcionario, bool ativo) aoAlternar;

  const ListaFuncionarios({
    super.key,
    required this.funcionarios,
    required this.aoAlternar,
    this.uidAtual,
  });

  @override
  Widget build(BuildContext context) {
    if (funcionarios.isEmpty) {
      return const EstadoVazio(icone: Icons.group_outlined, texto: 'Nenhum funcionário cadastrado.');
    }
    return Column(
      children: funcionarios.map((f) {
        final euMesmo = f.uid == uidAtual;
        return CartaoLista(
          nomeAvatar: f.nome,
          titulo: f.nome,
          subtitulo: '${perfilRotulo(f.perfil)} • ${f.email}${f.ativo ? '' : ' • desativado'}',
          trailing: Switch(
            value: f.ativo,
            // O gestor não pode desativar a si mesmo (a API também bloqueia).
            onChanged: euMesmo ? null : (v) => aoAlternar(f, v),
          ),
        );
      }).toList(),
    );
  }
}
