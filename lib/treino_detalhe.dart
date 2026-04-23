import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'novo_treino.dart' show NovoTreinoPage;

// Cores dos músculos
const _kMusculoCores = <String, Color>{
  'Peito': Color(0xFFE53935),
  'Costas': Color(0xFF8E24AA),
  'Ombro': Color(0xFF1E88E5),
  'Bíceps': Color(0xFF00ACC1),
  'Tríceps': Color(0xFF43A047),
  'Pernas': Color(0xFFFB8C00),
  'Glúteos': Color(0xFFD81B60),
  'Abdômen': Color(0xFF6D4C41),
  'Panturrilha': Color(0xFF00897B),
  'Antebraço': Color(0xFF546E7A),
  'Cardio': Color(0xFFE53935),
  'Full Body': Color(0xFFFF8F00),
};

const _kDificuldadeCor = <String, Color>{
  'facil': Color(0xFF43A047),
  'medio': Color(0xFFFB8C00),
  'dificil': Color(0xFFE53935),
};

const _kDificuldadeLabel = <String, String>{
  'facil': 'Fácil',
  'medio': 'Médio',
  'dificil': 'Difícil',
};

class TreinoDetalhePage extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> dados;

  const TreinoDetalhePage({
    super.key,
    required this.docId,
    required this.dados,
  });

  @override
  Widget build(BuildContext context) {
    final nome = dados['nome_treino'] ?? 'Treino';
    final ts = dados['data_treino'] as Timestamp?;
    final dataStr = ts != null
        ? DateFormat('dd/MM/yyyy').format(ts.toDate())
        : '-';
    final musculos =
        (dados['musculos'] as List? ?? []).cast<String>();
    final exercicios =
        (dados['exercicios'] as List? ?? []);

    // Volume total
    double volume = 0;
    int totalSeries = 0;
    for (final ex in exercicios) {
      for (final s in (ex['series'] as List? ?? [])) {
        final c = double.tryParse(s['carga']?.toString() ?? '') ?? 0;
        final r = double.tryParse(s['reps']?.toString() ?? '') ?? 0;
        volume += c * r;
        totalSeries++;
      }
    }
    final volumeStr =
        '${(volume / 1000).toStringAsFixed(2)}t';

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: CustomScrollView(
        slivers: [
          // ── APP BAR EXPANDIDA ──────────────────────────────────────
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: const Color(0xFF141414),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios,
                  color: Colors.orangeAccent),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              TextButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NovoTreinoPage(
                        docId: docId,
                        dadosIniciais: dados,
                      ),
                    ),
                  );
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.edit_rounded,
                    color: Colors.orangeAccent, size: 16),
                label: const Text('Editar',
                    style: TextStyle(
                        color: Colors.orangeAccent,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF141414),
                ),
                padding: const EdgeInsets.fromLTRB(20, 80, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(nome,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(dataStr,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 13)),
                    const SizedBox(height: 8),
                    Text('Volume total: $volumeStr',
                        style: const TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── RESUMO ─────────────────────────────────────────
                  _buildResumoRow(
                      exercicios.length, totalSeries, volumeStr),
                  const SizedBox(height: 16),

                  // ── MÚSCULOS ───────────────────────────────────────
                  if (musculos.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: musculos.map((m) {
                        final cor =
                            _kMusculoCores[m] ?? Colors.orangeAccent;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: cor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border:
                                Border.all(color: cor.withOpacity(0.35)),
                          ),
                          child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.bolt_rounded,
                                    color: cor, size: 13),
                                const SizedBox(width: 4),
                                Text(m,
                                    style: TextStyle(
                                        color: cor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                              ]),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  const Divider(color: Colors.white10),
                  const SizedBox(height: 8),

                  // ── EXERCÍCIOS ─────────────────────────────────────
                  ...exercicios.asMap().entries.map((entry) {
                    return _buildCardExercicio(
                        entry.key, entry.value as Map<String, dynamic>);
                  }),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── RESUMO ROW ─────────────────────────────────────────────────────────────
  Widget _buildResumoRow(int exs, int series, String vol) {
    return Row(children: [
      _buildStatMini(Icons.list_alt_rounded,
          '$exs\nexercícios', Colors.orangeAccent),
      const SizedBox(width: 10),
      _buildStatMini(Icons.repeat_rounded,
          '$series\nséries', Colors.blueAccent),
      const SizedBox(width: 10),
      _buildStatMini(Icons.monitor_weight_outlined,
          '$vol\nvolume', Colors.greenAccent),
    ]);
  }

  Widget _buildStatMini(IconData icon, String label, Color cor) {
    final parts = label.split('\n');
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: cor.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cor.withOpacity(0.2)),
        ),
        child: Column(children: [
          Icon(icon, color: cor, size: 18),
          const SizedBox(height: 6),
          Text(parts[0],
              style: TextStyle(
                  color: cor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          Text(parts[1],
              style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  // ── CARD DE EXERCÍCIO ──────────────────────────────────────────────────────
  Widget _buildCardExercicio(int idx, Map<String, dynamic> ex) {
    final nome = (ex['nome'] as String? ?? '').trim();
    final series = (ex['series'] as List? ?? []);

    // Acha a carga máxima para marcar PR
    double cargaMax = 0;
    for (final s in series) {
      final c = double.tryParse(s['carga']?.toString() ?? '') ?? 0;
      if (c > cargaMax) cargaMax = c;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── NOME DO EXERCÍCIO ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(Icons.bolt_rounded,
                      color: Colors.orangeAccent, size: 16),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(nome,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
              ),
            ]),
          ),

          // ── CABEÇALHO COLUNAS ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: const [
              SizedBox(width: 28),
              SizedBox(width: 16),
              Expanded(
                child: Text('CARGA',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8)),
              ),
              Expanded(
                child: Text('REPS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8)),
              ),
              SizedBox(
                width: 80,
                child: Text('DIFICULDADE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8)),
              ),
            ]),
          ),
          const SizedBox(height: 6),
          const Divider(color: Colors.white10, height: 1),

          // ── SÉRIES ────────────────────────────────────────────
          ...series.asMap().entries.map((entry) {
            final sIdx = entry.key;
            final s = entry.value as Map<String, dynamic>;
            final carga =
                double.tryParse(s['carga']?.toString() ?? '') ?? 0;
            final reps = s['reps']?.toString() ?? '0';
            final dificuldade =
                (s['dificuldade'] as String? ?? '').toLowerCase();
            final isPR = carga > 0 && carga == cargaMax;

            final difCor = _kDificuldadeCor[dificuldade];
            final difLabel = _kDificuldadeLabel[dificuldade];

            return Container(
              decoration: BoxDecoration(
                color: isPR
                    ? Colors.amberAccent.withOpacity(0.04)
                    : Colors.transparent,
                border: Border(
                    bottom: BorderSide(color: Colors.white10, width: 0.5)),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                // Número série
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isPR
                        ? Colors.amberAccent.withOpacity(0.15)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text('${sIdx + 1}',
                        style: TextStyle(
                            color: isPR
                                ? Colors.amberAccent
                                : Colors.white38,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),

                // Carga
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${carga % 1 == 0 ? carga.toInt() : carga} kg',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color:
                                isPR ? Colors.amberAccent : Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold),
                      ),
                      if (isPR) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.amberAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('PR',
                              style: TextStyle(
                                  color: Colors.amberAccent,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                ),

                // Reps
                Expanded(
                  child: Text('$reps reps',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 14)),
                ),

                // Dificuldade
                SizedBox(
                  width: 80,
                  child: difLabel != null && difCor != null
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: difCor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: difCor.withOpacity(0.4)),
                          ),
                          child: Text(difLabel,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: difCor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        )
                      : const Text('-',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white24, fontSize: 12)),
                ),
              ]),
            );
          }).toList(),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}