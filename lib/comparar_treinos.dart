import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CompararTreinosPage extends StatefulWidget {
  const CompararTreinosPage({super.key});

  @override
  State<CompararTreinosPage> createState() => _CompararTreinosPageState();
}

class _CompararTreinosPageState extends State<CompararTreinosPage> {
  final _db = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  List<QueryDocumentSnapshot> _todosTreinos = [];
  QueryDocumentSnapshot? _treinoA;
  QueryDocumentSnapshot? _treinoB;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarTreinos();
  }

  Future<void> _carregarTreinos() async {
    try {
      final snap = await _db
          .collection('treinos')
          .where('userId', isEqualTo: _uid)
          .orderBy('data_treino', descending: true)
          .get();
      // Filtra client-side: ignora templates e docs sem data_treino
      final validos = snap.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final isTemplate = data['is_template'] == true;
        final temData = data['data_treino'] != null;
        return !isTemplate && temData;
      }).toList();
      setState(() {
        _todosTreinos = validos;
        _carregando = false;
      });
    } catch (e) {
      setState(() => _carregando = false);
    }
  }

  double _calcularVolume(QueryDocumentSnapshot doc) {
    double v = 0;
    for (final ex in (doc['exercicios'] as List? ?? [])) {
      for (final s in (ex['series'] as List? ?? [])) {
        v += (double.tryParse(s['carga']?.toString() ?? '') ?? 0) *
            (double.tryParse(s['reps']?.toString() ?? '') ?? 0);
      }
    }
    return v;
  }

  double _cargaMaxExercicio(QueryDocumentSnapshot doc, String nomeEx) {
    double max = 0;
    for (final ex in (doc['exercicios'] as List? ?? [])) {
      if ((ex['nome'] as String? ?? '').toLowerCase() ==
          nomeEx.toLowerCase()) {
        for (final s in (ex['series'] as List? ?? [])) {
          final c = double.tryParse(s['carga']?.toString() ?? '') ?? 0;
          if (c > max) max = c;
        }
      }
    }
    return max;
  }

  Set<String> _exerciciosDoTreino(QueryDocumentSnapshot doc) {
    return (doc['exercicios'] as List? ?? [])
        .map((ex) =>
            ((ex['nome'] as String? ?? '').trim().toLowerCase()))
        .where((n) => n.isNotEmpty)
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141414),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: Colors.orangeAccent),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('COMPARAR TREINOS',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17)),
        centerTitle: true,
      ),
      body: _carregando
          ? const Center(
              child:
                  CircularProgressIndicator(color: Colors.orangeAccent))
          : _todosTreinos.isEmpty
              ? _buildVazio()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── SELETORES ──────────────────────────────────
                      Row(children: [
                        Expanded(
                            child: _buildSeletor(
                                'TREINO A',
                                Colors.orangeAccent,
                                _treinoA,
                                (doc) => setState(() => _treinoA = doc))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _buildSeletor(
                                'TREINO B',
                                Colors.blueAccent,
                                _treinoB,
                                (doc) => setState(() => _treinoB = doc))),
                      ]),
                      const SizedBox(height: 24),

                      if (_treinoA != null && _treinoB != null) ...[
                        _buildComparacao(),
                      ] else
                        _buildInstrucoes(),
                    ],
                  ),
                ),
    );
  }

  // ── SELETOR DE TREINO ──────────────────────────────────────────────────────
  Widget _buildSeletor(
    String label,
    Color cor,
    QueryDocumentSnapshot? selecionado,
    Function(QueryDocumentSnapshot) onSelecionado,
  ) {
    return GestureDetector(
      onTap: () => _abrirSeletor(label, cor, onSelecionado),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selecionado != null
              ? cor.withOpacity(0.08)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selecionado != null
                  ? cor.withOpacity(0.4)
                  : Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: cor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1)),
            const SizedBox(height: 8),
            if (selecionado == null) ...[
              Row(children: [
                Icon(Icons.add_circle_outline, color: cor, size: 16),
                const SizedBox(width: 6),
                Text('Selecionar',
                    style: TextStyle(color: cor, fontSize: 13)),
              ]),
            ] else ...[
              Text(
                selecionado['nome_treino'] ?? '-',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('dd/MM/yyyy').format(
                    (selecionado['data_treino'] as Timestamp).toDate()),
                style:
                    const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _abrirSeletor(
    String label,
    Color cor,
    Function(QueryDocumentSnapshot) onSelecionado,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, controller) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Text('SELECIONAR $label',
                style: TextStyle(
                    color: cor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1)),
            const SizedBox(height: 12),
            const Divider(color: Colors.white10),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: _todosTreinos.length,
                itemBuilder: (_, i) {
                  final doc = _todosTreinos[i];
                  final nome = doc['nome_treino'] ?? '-';
                  final ts = doc['data_treino'] as Timestamp?;
                  final data = ts != null
                      ? DateFormat('dd/MM/yyyy')
                          .format(ts.toDate())
                      : '-';
                  return ListTile(
                    onTap: () {
                      onSelecionado(doc);
                      Navigator.pop(ctx);
                    },
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: cor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.fitness_center,
                          color: cor, size: 20),
                    ),
                    title: Text(nome,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    subtitle: Text(data,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── COMPARAÇÃO ─────────────────────────────────────────────────────────────
  Widget _buildComparacao() {
    final volA = _calcularVolume(_treinoA!);
    final volB = _calcularVolume(_treinoB!);
    final exsA = _exerciciosDoTreino(_treinoA!);
    final exsB = _exerciciosDoTreino(_treinoB!);
    final emComum = exsA.intersection(exsB).toList()..sort();
    final somenteA = exsA.difference(exsB).toList()..sort();
    final somenteB = exsB.difference(exsA).toList()..sort();

    final seriesA = (_treinoA!['exercicios'] as List? ?? [])
        .fold<int>(0, (s, ex) => s + ((ex['series'] as List?)?.length ?? 0));
    final seriesB = (_treinoB!['exercicios'] as List? ?? [])
        .fold<int>(0, (s, ex) => s + ((ex['series'] as List?)?.length ?? 0));

    final exCountA =
        (_treinoA!['exercicios'] as List? ?? []).length;
    final exCountB =
        (_treinoB!['exercicios'] as List? ?? []).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── STATS GERAIS ────────────────────────────────────────────
        _buildSecLabel('VISÃO GERAL'),
        const SizedBox(height: 10),
        _buildLinhaComparacao(
          label: 'Volume total',
          valA: '${(volA / 1000).toStringAsFixed(2)}t',
          valB: '${(volB / 1000).toStringAsFixed(2)}t',
          melhorA: volA >= volB,
          melhorB: volB >= volA,
        ),
        _buildLinhaComparacao(
          label: 'Exercícios',
          valA: '$exCountA',
          valB: '$exCountB',
          melhorA: exCountA >= exCountB,
          melhorB: exCountB >= exCountA,
        ),
        _buildLinhaComparacao(
          label: 'Séries totais',
          valA: '$seriesA',
          valB: '$seriesB',
          melhorA: seriesA >= seriesB,
          melhorB: seriesB >= seriesA,
        ),

        const SizedBox(height: 24),

        // ── NOTAS ───────────────────────────────────────────────────
        if (((_treinoA!.data() as Map<String, dynamic>)['notas'] as String? ?? '').isNotEmpty ||
            ((_treinoB!.data() as Map<String, dynamic>)['notas'] as String? ?? '').isNotEmpty) ...[
          _buildSecLabel('NOTAS'),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: _buildNotaCard(
                    ((_treinoA!.data() as Map<String, dynamic>)['notas'] as String? ?? ''), Colors.orangeAccent)),
            const SizedBox(width: 12),
            Expanded(
                child: _buildNotaCard(
                    ((_treinoB!.data() as Map<String, dynamic>)['notas'] as String? ?? ''), Colors.blueAccent)),
          ]),
          const SizedBox(height: 24),
        ],

        // ── EXERCÍCIOS EM COMUM ─────────────────────────────────────
        if (emComum.isNotEmpty) ...[
          _buildSecLabel('EXERCÍCIOS EM COMUM (${emComum.length})'),
          const SizedBox(height: 10),
          ...emComum.map((nome) {
            final cA = _cargaMaxExercicio(_treinoA!, nome);
            final cB = _cargaMaxExercicio(_treinoB!, nome);
            final diff = cB - cA;
            return _buildLinhaExercicio(nome, cA, cB, diff);
          }),
          const SizedBox(height: 24),
        ],

        // ── SÓ NO A ─────────────────────────────────────────────────
        if (somenteA.isNotEmpty) ...[
          _buildSecLabel(
              'SÓ NO TREINO A (${somenteA.length})',
              Colors.orangeAccent),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: somenteA
                .map((n) => _buildChipEx(
                    n.toUpperCase(), Colors.orangeAccent))
                .toList(),
          ),
          const SizedBox(height: 20),
        ],

        // ── SÓ NO B ─────────────────────────────────────────────────
        if (somenteB.isNotEmpty) ...[
          _buildSecLabel(
              'SÓ NO TREINO B (${somenteB.length})',
              Colors.blueAccent),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: somenteB
                .map((n) =>
                    _buildChipEx(n.toUpperCase(), Colors.blueAccent))
                .toList(),
          ),
          const SizedBox(height: 20),
        ],

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildSecLabel(String label, [Color cor = Colors.white38]) {
    return Text(label,
        style: TextStyle(
            color: cor,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2));
  }

  Widget _buildLinhaComparacao({
    required String label,
    required String valA,
    required String valB,
    required bool melhorA,
    required bool melhorB,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(children: [
        Expanded(
          child: Text(valA,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: melhorA
                      ? Colors.orangeAccent
                      : Colors.white54,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ),
        Expanded(
          flex: 2,
          child: Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Text(valB,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: melhorB
                      ? Colors.blueAccent
                      : Colors.white54,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }

  Widget _buildLinhaExercicio(
      String nome, double cA, double cB, double diff) {
    final melhorA = cA >= cB;
    final melhorB = cB >= cA;
    final igual = cA == cB;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Text(nome,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: Text(
                cA > 0 ? '${cA.toStringAsFixed(0)} kg' : '-',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: melhorA && !igual
                        ? Colors.orangeAccent
                        : Colors.white54,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
            ),
            // Seta de diferença
            Expanded(
              child: Column(children: [
                Icon(
                  igual
                      ? Icons.drag_handle_rounded
                      : diff > 0
                          ? Icons.arrow_forward_rounded
                          : Icons.arrow_back_rounded,
                  color: igual
                      ? Colors.white24
                      : diff > 0
                          ? Colors.blueAccent
                          : Colors.orangeAccent,
                  size: 20,
                ),
                if (!igual)
                  Text(
                    '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(0)} kg',
                    style: TextStyle(
                        color: diff > 0
                            ? Colors.blueAccent
                            : Colors.orangeAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
              ]),
            ),
            Expanded(
              child: Text(
                cB > 0 ? '${cB.toStringAsFixed(0)} kg' : '-',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: melhorB && !igual
                        ? Colors.blueAccent
                        : Colors.white54,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildNotaCard(String nota, Color cor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor.withOpacity(0.2)),
      ),
      child: Text(
        nota.isEmpty ? 'Sem notas' : nota,
        style: TextStyle(
            color: nota.isEmpty ? Colors.white24 : Colors.white70,
            fontSize: 12),
      ),
    );
  }

  Widget _buildChipEx(String label, Color cor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: cor, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildInstrucoes() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(children: [
        const Icon(Icons.compare_arrows_rounded,
            size: 48, color: Colors.white24),
        const SizedBox(height: 16),
        const Text('Selecione dois treinos acima',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 15)),
        const SizedBox(height: 8),
        const Text(
            'Compare volume, cargas por exercício\ne veja a diferença entre os treinos.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white24, fontSize: 12)),
      ]),
    );
  }

  Widget _buildVazio() {
    return const Center(
      child: Text('Nenhum treino registrado ainda.',
          style: TextStyle(color: Colors.white38)),
    );
  }
}