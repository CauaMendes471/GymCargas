import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EvolucaoPage extends StatefulWidget {
  const EvolucaoPage({super.key});

  @override
  State<EvolucaoPage> createState() => _EvolucaoPageState();
}

class _EvolucaoPageState extends State<EvolucaoPage> {
  final _db = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  // Todos os nomes de exercícios encontrados nos treinos
  List<String> _exercicios = [];
  String? _exercicioSelecionado;

  // Pontos do gráfico: {data, cargaMax}
  List<Map<String, dynamic>> _pontos = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarExercicios();
  }

  // Busca todos os exercícios únicos do usuário
  Future<void> _carregarExercicios() async {
    setState(() => _carregando = true);
    try {
      final snap = await _db
          .collection('treinos')
          .where('userId', isEqualTo: _uid)
          .get();

      final Set<String> nomes = {};
      for (final doc in snap.docs) {
        final exs = (doc.data()['exercicios'] as List? ?? []);
        for (final ex in exs) {
          final nome = (ex['nome'] as String? ?? '').trim();
          if (nome.isNotEmpty) nomes.add(nome);
        }
      }

      final lista = nomes.toList()..sort();
      setState(() {
        _exercicios = lista;
        _carregando = false;
        if (lista.isNotEmpty) {
          _exercicioSelecionado = lista.first;
          _carregarEvolucao(lista.first);
        }
      });
    } catch (e) {
      setState(() => _carregando = false);
    }
  }

  // Busca a evolução de carga máxima de um exercício ao longo do tempo
  Future<void> _carregarEvolucao(String exercicio) async {
    setState(() => _carregando = true);
    try {
      final snap = await _db
          .collection('treinos')
          .where('userId', isEqualTo: _uid)
          .get();

      final List<Map<String, dynamic>> pontos = [];

      for (final doc in snap.docs) {
        final data = doc.data();
        final ts = data['data_treino'];
        if (ts is! Timestamp) continue;
        final date = ts.toDate();

        final exs = (data['exercicios'] as List? ?? []);
        for (final ex in exs) {
          final nome = (ex['nome'] as String? ?? '').trim();
          if (nome.toLowerCase() != exercicio.toLowerCase()) continue;

          // Pega a maior carga das séries desse exercício nesse treino
          double cargaMax = 0;
          for (final s in (ex['series'] as List? ?? [])) {
            final c = double.tryParse(s['carga']?.toString() ?? '') ?? 0;
            if (c > cargaMax) cargaMax = c;
          }
          if (cargaMax > 0) {
            pontos.add({'data': date, 'carga': cargaMax});
          }
        }
      }

      // Ordena por data
      pontos.sort((a, b) =>
          (a['data'] as DateTime).compareTo(b['data'] as DateTime));

      setState(() {
        _pontos = pontos;
        _carregando = false;
      });
    } catch (e) {
      setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("EVOLUÇÃO",
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.orangeAccent),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _carregando
          ? const Center(
              child: CircularProgressIndicator(color: Colors.orangeAccent))
          : _exercicios.isEmpty
              ? _buildVazio()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("SELECIONE O EXERCÍCIO",
                          style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2)),
                      const SizedBox(height: 10),
                      _buildDropdown(),
                      const SizedBox(height: 28),
                      if (_pontos.isEmpty)
                        _buildSemDados()
                      else ...[
                        _buildResumo(),
                        const SizedBox(height: 24),
                        const Text("CARGA MÁXIMA POR SESSÃO",
                            style: TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2)),
                        const SizedBox(height: 16),
                        _buildGrafico(),
                        const SizedBox(height: 24),
                        const Text("HISTÓRICO DETALHADO",
                            style: TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2)),
                        const SizedBox(height: 12),
                        _buildListaHistorico(),
                      ],
                    ],
                  ),
                ),
    );
  }

  // ── DROPDOWN ──────────────────────────────────────────────────────────────
  Widget _buildDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _exercicioSelecionado,
          isExpanded: true,
          dropdownColor: const Color(0xFF1A1A1A),
          icon: const Icon(Icons.keyboard_arrow_down,
              color: Colors.orangeAccent),
          style: const TextStyle(
              color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          items: _exercicios
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (val) {
            if (val == null) return;
            setState(() => _exercicioSelecionado = val);
            _carregarEvolucao(val);
          },
        ),
      ),
    );
  }

  // ── CARDS DE RESUMO ───────────────────────────────────────────────────────
  Widget _buildResumo() {
    final cargas = _pontos.map((p) => p['carga'] as double).toList();
    final cargaMax = cargas.reduce((a, b) => a > b ? a : b);
    final cargaInicial = cargas.first;
    final evolucao = cargaMax - cargaInicial;
    final evolucaoPct =
        cargaInicial > 0 ? (evolucao / cargaInicial * 100) : 0.0;
    final isPR = _pontos.last['carga'] == cargaMax;

    return Row(
      children: [
        _buildResumoCard("RECORDE", "${cargaMax.toStringAsFixed(1)} kg",
            Icons.emoji_events, Colors.amberAccent),
        const SizedBox(width: 12),
        _buildResumoCard(
            "EVOLUÇÃO",
            "${evolucao >= 0 ? '+' : ''}${evolucao.toStringAsFixed(1)} kg\n(${evolucaoPct.toStringAsFixed(0)}%)",
            evolucao >= 0 ? Icons.trending_up : Icons.trending_down,
            evolucao >= 0 ? Colors.greenAccent : Colors.redAccent),
        const SizedBox(width: 12),
        _buildResumoCard(
            "SESSÕES",
            "${_pontos.length}",
            Icons.repeat,
            Colors.blueAccent),
      ],
    );
  }

  Widget _buildResumoCard(
      String label, String valor, IconData icon, Color cor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: cor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cor.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: cor, size: 20),
            const SizedBox(height: 6),
            Text(valor,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: cor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  // ── GRÁFICO DE LINHA MANUAL ───────────────────────────────────────────────
  Widget _buildGrafico() {
    final cargas = _pontos.map((p) => p['carga'] as double).toList();
    final maxCarga = cargas.reduce((a, b) => a > b ? a : b);
    final minCarga = cargas.reduce((a, b) => a < b ? a : b);
    final range = (maxCarga - minCarga).clamp(1.0, double.infinity);

    const double alturaGrafico = 180;
    const double larguraPonto = 48;
    final double larguraTotal = _pontos.length * larguraPonto;

    return Container(
      height: alturaGrafico + 60,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: SizedBox(
          width: larguraTotal.clamp(300, double.infinity),
          height: alturaGrafico + 60,
          child: CustomPaint(
            painter: _GraficoPainter(
              pontos: _pontos,
              maxCarga: maxCarga,
              minCarga: minCarga,
              range: range,
              alturaGrafico: alturaGrafico,
            ),
          ),
        ),
      ),
    );
  }

  // ── LISTA HISTÓRICO ───────────────────────────────────────────────────────
  Widget _buildListaHistorico() {
    final cargaMax =
        _pontos.map((p) => p['carga'] as double).reduce((a, b) => a > b ? a : b);

    return Column(
      children: _pontos.reversed.map((p) {
        final data = p['data'] as DateTime;
        final carga = p['carga'] as double;
        final isPR = carga == cargaMax;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isPR
                ? Colors.amberAccent.withOpacity(0.07)
                : Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: isPR
                    ? Colors.amberAccent.withOpacity(0.3)
                    : Colors.white10),
          ),
          child: Row(
            children: [
              Icon(
                isPR ? Icons.emoji_events : Icons.fitness_center,
                color: isPR ? Colors.amberAccent : Colors.orangeAccent,
                size: 20,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  DateFormat('dd/MM/yyyy').format(data),
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 14),
                ),
              ),
              Text(
                "${carga.toStringAsFixed(1)} kg",
                style: TextStyle(
                    color: isPR ? Colors.amberAccent : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              if (isPR) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.amberAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text("PR",
                      style: TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildVazio() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_rounded,
                size: 64, color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 16),
            const Text("Nenhum treino registrado ainda",
                style: TextStyle(color: Colors.white38, fontSize: 16)),
            const SizedBox(height: 8),
            const Text("Registre treinos para ver sua evolução!",
                style: TextStyle(color: Colors.white24, fontSize: 13)),
          ],
        ),
      );

  Widget _buildSemDados() => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text(
            "Nenhum dado encontrado para este exercício.\nVerifique se as cargas foram preenchidas.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ),
      );
}

// ── CUSTOM PAINTER DO GRÁFICO ─────────────────────────────────────────────
class _GraficoPainter extends CustomPainter {
  final List<Map<String, dynamic>> pontos;
  final double maxCarga;
  final double minCarga;
  final double range;
  final double alturaGrafico;

  _GraficoPainter({
    required this.pontos,
    required this.maxCarga,
    required this.minCarga,
    required this.range,
    required this.alturaGrafico,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (pontos.length < 1) return;

    final larguraPonto = size.width / pontos.length;

    // Calcula posições dos pontos
    List<Offset> offsets = [];
    for (int i = 0; i < pontos.length; i++) {
      final carga = pontos[i]['carga'] as double;
      final x = i * larguraPonto + larguraPonto / 2;
      final y = alturaGrafico -
          ((carga - minCarga) / range) * (alturaGrafico - 20) -
          10;
      offsets.add(Offset(x, y));
    }

    // Linha de grade
    final paintGrade = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = (alturaGrafico / 4) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintGrade);
    }

    // Área preenchida sob a linha
    if (offsets.length > 1) {
      final pathArea = Path();
      pathArea.moveTo(offsets.first.dx, alturaGrafico);
      for (final o in offsets) {
        pathArea.lineTo(o.dx, o.dy);
      }
      pathArea.lineTo(offsets.last.dx, alturaGrafico);
      pathArea.close();

      final paintArea = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFFF8F00).withOpacity(0.3),
            const Color(0xFFFF5722).withOpacity(0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, alturaGrafico));
      canvas.drawPath(pathArea, paintArea);

      // Linha conectando os pontos
      final paintLinha = Paint()
        ..color = const Color(0xFFFF8F00)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final pathLinha = Path();
      pathLinha.moveTo(offsets.first.dx, offsets.first.dy);
      for (int i = 1; i < offsets.length; i++) {
        pathLinha.lineTo(offsets[i].dx, offsets[i].dy);
      }
      canvas.drawPath(pathLinha, paintLinha);
    }

    // Pontos e labels
    for (int i = 0; i < offsets.length; i++) {
      final o = offsets[i];
      final carga = pontos[i]['carga'] as double;
      final data = pontos[i]['data'] as DateTime;
      final isPR = carga == maxCarga;

      // Círculo
      final paintPonto = Paint()
        ..color = isPR ? Colors.amberAccent : const Color(0xFFFF8F00)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(o, isPR ? 7 : 5, paintPonto);

      // Borda branca
      final paintBorda = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(o, isPR ? 7 : 5, paintBorda);

      // Label de carga acima do ponto
      final textPainter = TextPainter(
        text: TextSpan(
          text: "${carga.toStringAsFixed(0)}kg",
          style: TextStyle(
            color: isPR ? Colors.amberAccent : Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
          canvas, Offset(o.dx - textPainter.width / 2, o.dy - 22));

      // Data abaixo
      final dataPainter = TextPainter(
        text: TextSpan(
          text: DateFormat('dd/MM').format(data),
          style: const TextStyle(color: Colors.white38, fontSize: 9),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      dataPainter.layout();
      dataPainter.paint(
          canvas,
          Offset(o.dx - dataPainter.width / 2, alturaGrafico + 8));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}